# Project Purgatory Copilot Notes

## Project Context
- Godot 4.6 project.
- This is a story-first visual novel with supporting gameplay systems.
- The main structure is a repeating day cycle: story setup, desk/work interactions, end-of-day summary, overworld exploration, lunch-break transition, then the next day.
- Core gameplay includes an isometric, table-based object interaction system and an overhead overworld for exploration, secrets, and easter eggs.
- Keep changes small and focused on the requested feature or bug, but always think in terms of the larger narrative project.

## Narrative Vision
- The tone is dark comedy with an endearing, character-driven story about flawed humanity.
- God is a character in the premise and the player is working in purgatory as part of a divine bureaucracy.
- Characters can lie in purgatory, so dialogue, documents, and other evidence may conflict.
- The player talks to each desk character through an initial introduction and follow-up questioning before deciding their fate.
- Day summaries should support progression and the larger story, not just scorekeeping.
- The overworld exists between work days to add atmosphere, discovery, and optional content.

## Design Priorities
- Story and character content are the primary pillars.
- The table gameplay, overworld exploration, and hidden content should support the narrative rather than replace it.
- Save-scumming is intentionally part of the fiction through special save-family characters, and it should remain a meaningful moral/choice system.
- Build features with scalability in mind: prefer parent scenes, reusable systems, and data-driven structure when it helps the larger game.

## Repo Rules
- Do not commit or edit the `.godot/` directory.
- Do not edit scenes you were not assigned to unless everyone involved is aware.
- One feature per branch.

## Working Style
- Prefer existing patterns in nearby scripts before introducing new abstractions.
- Preserve current scene and script structure unless a change requires otherwise.
- Avoid unrelated formatting or refactors.
- When touching gameplay scripts, keep exported properties, node paths, and scene wiring consistent with the current setup.
- If a change affects story structure, dialogue flow, or progression, check whether it should live in a shared parent scene or reusable system instead of a one-off implementation.

## Useful Areas
- `scripts/core/` contains shared gameplay logic.
- `scenes/` contains gameplay and UI scenes.
- `addons/` contains third-party or bundled editor tooling.

## Tier 1 Systems (Game Loop & Character Management)

### DayCycleManager (Autoload)
- **Location**: `scripts/core/day_cycle_manager.gd`
- **Purpose**: Orchestrates the entire day flow: intro → characters → fate decisions → summary → overworld → lunch break → next day
- **Key Methods**:
  - `intro_complete()` — Called when opening dialogue finishes
  - `on_character_conversation_complete(character)` — Called after each NPC interaction
  - `assign_fate(character, fate)` — Records heaven/hell decision
  - `go_to_overworld()` / `go_to_lunch_break()` / `next_day()` — Transitions

### CharacterData (Resource)
- **Location**: `scripts/core/character_data.gd`
- **Purpose**: Encapsulates all NPC data: name, portrait, passport info, dialogue, morality weight, lie flags, fate
- **Used By**: DayCycleManager for character selection and tracking

### FateDecisionUI
- **Location**: `scripts/ui/fate_decision_ui.gd`
- **Purpose**: Heaven/Hell button UI always available via toggle button during character interactions
- **Key Methods**:
  - `set_current_character(character)` — Update the UI for the active character
  - `_toggle_panel()` — Show/hide the decision panel
- **Integration**: Add `scenes/ui/fate_decision_ui.tscn` as a CanvasLayer child in the table scene
- **Design**: Player can open the fate panel at any time and decide without waiting for dialogue to finish

### DaySummaryUI
- **Location**: `scripts/ui/day_summary_ui.gd`
- **Purpose**: Displays end-of-day results (heaven/hell counts) and transitions to overworld

## If You Need More Context
- Check `README.md` first for project-level rules.
- Check `TIER1_SETUP.md` for wiring instructions and testing the game loop.
- Inspect nearby scripts and scenes before making broad changes.
