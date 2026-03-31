# Dialogue Tags Reference

This file documents the dialogue tags currently used by this project.

## Quick Syntax

Use tags at the end of a dialogue line:

```text
Character Name: Dialogue text here [#tag=value]
Character Name: Dialogue text here [#tag_a=value, #tag_b=value]
```

## Project Tags

### `#mood=<value>`

Controls the portrait mood used by `DialogueUI`.

- Supported values right now: `idle`, `talking`, `angry`, `sad`
- Used by: `scripts/dialogue/dialogue_ui.gd`

Example:

```text
Sample Sam: I am upset right now [#mood=angry]
Sample Sam: Things are okay again [#mood=idle]
```

### `#scroll_speed=<seconds_per_character>`

Overrides typing speed for a single line.

- Used by: `scripts/dialogue/dialogue_ui.gd`
- Smaller number = faster typing
- Must be greater than `0`

Example:

```text
Sample Sam: This line types quickly [#scroll_speed=0.01]
Sample Sam: This line types slowly [#scroll_speed=0.06]
```

### `#auto_advance=1`

Auto-advances to the next line once typing is finished (no click/confirm needed).

- Used by: `scripts/dialogue/dialogue_ui.gd`
- Useful for cinematic lines
- If omitted, line behaves normally and waits for input

Optional disable values:

```text
[#auto_advance=0]
[#auto_advance=false]
```

### `#auto_advance_delay=<seconds>`

Optional delay before auto-advance triggers.

- Used with `#auto_advance=1`
- Must be `0` or higher

Example:

```text
Sample Sam: This continues in one second... [#auto_advance=1, #auto_advance_delay=1.0]
```

### `#music=<cue>`

Triggers dialogue music cues through `DialogueMusicBridge`.

- Used by: `scripts/audio/dialogue_music_bridge.gd`
- `<cue>` must match a key in `DialogueMusicBridge.cue_tracks`
- Special value: `stop` to fade/stop currently playing track

Example:

```text
Sample Sam: Let's get serious [#music=paper]
Sample Sam: That's enough music [#music=stop]
```

### `#force_scroll=1`

Prevents the player from skipping the typing animation for that line.

- Used by: `scripts/dialogue/dialogue_ui.gd`
- Presence of the tag is what matters; value is not strongly validated

Example:

```text
Sample Sam: This line must fully type out [#force_scroll=1]
```

## Addon Tag (Only for Dialogue Manager Balloon)

### `#voice=<resource path>`

If you use the Dialogue Manager example balloon, this plays a voice clip for the line.

- Used by: `addons/dialogue_manager/example_balloon/example_balloon.gd`
- Not used by custom `scripts/dialogue/dialogue_ui.gd` unless you add support there

Example:

```text
Sample Sam: Listen to this line [#voice=res://audio/voice/sample_sam_01.ogg]
```

## BBCode vs Tags

These are different systems:

- `[#mood=angry]` is a dialogue tag (game logic)
- `[font_size=20]text[/font_size]` is RichText BBCode (text styling)

You can use both on the same line.

## Where to Update Tag Logic

- Portrait mood + force-scroll behavior: `scripts/dialogue/dialogue_ui.gd`
- Music cue behavior: `scripts/audio/dialogue_music_bridge.gd`
- Balloon voice behavior: `addons/dialogue_manager/example_balloon/example_balloon.gd`
