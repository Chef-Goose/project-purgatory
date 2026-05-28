-- Supabase leaderboard setup for Project Purgatory.
-- Goal:
--   - Public clients can read vote stats.
--   - Public clients cannot modify the table directly.
--   - A single RPC can safely increment counts.
--
-- Expected table shape:
--   character_id text primary key
--   heaven_count bigint not null default 0
--   hell_count bigint not null default 0
--   updated_at timestamptz not null default now()

create table if not exists public.character_vote_stats (
  character_id text primary key,
  heaven_count bigint not null default 0,
  hell_count bigint not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.character_vote_stats enable row level security;

revoke all on table public.character_vote_stats from anon, authenticated;
grant select on table public.character_vote_stats to anon, authenticated;

drop policy if exists "Public can read character vote stats" on public.character_vote_stats;

create policy "Public can read character vote stats"
on public.character_vote_stats
for select
using (true);

create or replace function public.record_character_vote(
  p_character_id text,
  p_choice text
)
returns table (
  character_id text,
  heaven_count bigint,
  hell_count bigint,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_choice not in ('heaven', 'hell') then
    raise exception 'choice must be heaven or hell';
  end if;

  insert into public.character_vote_stats (
    character_id,
    heaven_count,
    hell_count,
    updated_at
  )
  values (
    p_character_id,
    case when p_choice = 'heaven' then 1 else 0 end,
    case when p_choice = 'hell' then 1 else 0 end,
    now()
  )
  on conflict on constraint character_vote_stats_pkey
  do update set
    heaven_count = public.character_vote_stats.heaven_count
      + case when p_choice = 'heaven' then 1 else 0 end,
    hell_count = public.character_vote_stats.hell_count
      + case when p_choice = 'hell' then 1 else 0 end,
    updated_at = now();

  return query
  select
    stats.character_id,
    stats.heaven_count,
    stats.hell_count,
    stats.updated_at
  from public.character_vote_stats as stats
  where stats.character_id = p_character_id;
end;
$$;

grant execute on function public.record_character_vote(text, text) to anon, authenticated;
