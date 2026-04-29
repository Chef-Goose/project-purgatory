# Tier 1 Implementation Guide

## What's Been Built

### Core Scripts (in `scripts/core/`)
- **character_data.gd** — Stores character info, passport data, morality, dialogue references, and fate decisions
- **day_cycle_manager.gd** — Orchestrates the entire day cycle (intro → characters → summary → overworld → lunch → next day)

### UI Scripts (in `scripts/ui/`)
- **fate_decision_ui.gd** — Heaven/Hell button UI (embed in table scene)
- **day_summary_ui.gd** — End-of-day results screen

### Scenes
- `scenes/levels/intro.tscn` — Opening placeholder (starts the game loop)
- `scenes/ui/day_summary.tscn` — Day summary screen
- `scenes/ui/lunch_break.tscn` — Lunch break transition
- `scenes/levels/overworld.tscn` — Placeholder overworld

## Setup Instructions

### 1. Add DayCycleManager as an Autoload
In Godot Editor:
1. Go to **Project → Project Settings → Autoload**
2. Add a new autoload:
   - **Node Path**: Create an empty Node2D scene, save as `scenes/core/game_manager.tscn`
   - **Node Name**: Attach `day_cycle_manager.gd` script to the root node
   - **Autoload Name**: `GameManager`
3. This makes `GameManager` available globally across all scenes

### 2. Update the Table Scene
The existing `scenes/levels/table.tscn` needs:
1. Add the `FateDecisionUI` scene as a CanvasLayer child
2. Wire `set_current_character()` to be called whenever a new character starts their dialogue
3. The fate buttons are now always available via toggle button — player can open/close at any time

### 3. Wire Character Display in Table
When the table scene loads for a new character:
1. Get the current character from `GameManager.get_current_character()`
2. Call `fate_decision_ui.set_current_character(character)` so the UI knows who to judge
3. Display the character portrait and start their dialogue

### 4. Dialogue to Fate Flow (Simplified)
Since fate is always available, the flow is now:
1. Player talks to character via dialogue tree
2. At any point, player can click "Assign Fate" button
3. Player chooses heaven or hell
4. Character is marked as processed, UI hides, next character loads

This means dialogue doesn't need to "trigger" the fate UI anymore — it's player-controlled.

## Testing the Flow

1. Run the game → See the intro scene
2. Click "Start Game" → Should load the first character at the table
3. Complete dialogue with them → Fate buttons appear
4. Choose heaven/hell → Move to next character (or go to summary if done)
5. Summary shows results → Go to overworld
6. Overworld → Go to lunch break → Next day (loops back to step 2)

## What's Next (Tier 2)

Once this is working:
- **Dialogue integration**: Wire real character dialogue into the flow
- **Overworld expansion**: Add player movement, rooms, and exploration
- **Save system**: Integrate GodotSavesAddon for persistence
