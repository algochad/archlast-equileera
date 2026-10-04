# Input Profile Schema — arch_engine.input

This document defines the JSON schema for input profiles consumed by `arch_engine.input.load_profile()` and `arch_engine.input.save_profile()`.

## File Location

The default profile ships at:

```
game/arch_rpg/config/input_default.json
```

Mods may load additional or override profiles from any readable path via `arch_engine.input.load_profile(path)`.

## Top-Level Structure

```json
{
  "actions": { ... },
  "axes": { ... }
}
```

Both top-level keys are required. Empty objects are valid (no bindings).

## Actions Object

Each key is an action name (string). The value describes what physical inputs trigger that action.

```json
{
  "actions": {
    "<action_name>": {
      "keys": ["<keycode>", ...],
      "gamepad": ["<button_name>", ...]
    }
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `keys` | `string[]` | Yes | Array of IrrlichtMt key code strings (e.g., `"KEY_KEY_W"`, `"KEY_SPACE"`, `"KEY_LSHIFT"`). May be empty if gamepad-only. |
| `gamepad` | `string[]` | Yes | Array of gamepad button names (e.g., `"a"`, `"b"`, `"leftstick"`, `"dpad_up"`). May be empty if keyboard-only. |

An action is considered **pressed** when ANY bound key OR gamepad button is currently held down.

### Key Code Format

Key codes follow IrrlichtMt naming conventions as defined in `keycode.cpp`:

- Keyboard: `KEY_KEY_<letter>`, `KEY_KEY_<digit>`, `KEY_F<num>`, `KEY_LSHIFT`, `KEY_RSHIFT`, `KEY_LCONTROL`, `KEY_RCONTROL`, `KEY_SPACE`, `KEY_RETURN`, `KEY_ESCAPE`, etc.
- Mouse: `MOUSE_BUTTON_<1-3>` (not typically used in action maps, but supported).
- System scancodes: `SYSTEM_SCANCODE_<N>` (engine internal; prefer named keys for readability).

### Gamepad Button Names

Button names map to `GamepadButton` enum values in `keycode.h`:

| Name | Enum | Description |
|------|------|-------------|
| `a` | `SOUTH` | South face button (Xbox A / PS Cross) |
| `b` | `EAST` | East face button (Xbox B / PS Circle) |
| `x` | `WEST` | West face button (Xbox X / PS Square) |
| `y` | `NORTH` | North face button (Xbox Y / PS Triangle) |
| `leftshoulder` | `LEFT_SHOULDER` | Left bumper |
| `rightshoulder` | `RIGHT_SHOULDER` | Right bumper |
| `lefttrigger` | `LEFT_TRIGGER` | Left trigger (as button) |
| `righttrigger` | `RIGHT_TRIGGER` | Right trigger (as button) |
| `back` | `BACK` | Back/Select button |
| `start` | `START` | Start/Menu button |
| `leftstick` | `LEFT_STICK` | Left stick click |
| `rightstick` | `RIGHT_STICK` | Right stick click |
| `dpad_up` | `DPAD_UP` | D-pad up |
| `dpad_down` | `DPAD_DOWN` | D-pad down |
| `dpad_left` | `DPAD_LEFT` | D-pad left |
| `dpad_right` | `DPAD_RIGHT` | D-pad right |

## Axes Object

Each key is an axis name (string). The value describes how the axis value is computed.

```json
{
  "axes": {
    "<axis_name>": {
      "positive": "<action_name>",
      "negative": "<action_name>",
      "gamepad_axis": "<axis_name>",
      "deadzone": 0.15
    }
  }
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `positive` | `string` | Yes | — | Action name contributing positive (+1) direction |
| `negative` | `string` | Yes | — | Action name contributing negative (-1) direction |
| `gamepad_axis` | `string` | No | `""` | Gamepad analog axis name (overrides key-based value when non-zero) |
| `deadzone` | `number` | No | `0.15` | Deadzone threshold [0, 1). Values below this magnitude are clamped to 0. |

### Axis Value Computation

1. If `gamepad_axis` is set and its absolute value exceeds `deadzone`, return the gamepad axis value (remapped from deadzone..1 to 0..1 range).
2. Otherwise, compute from actions: `result = (isActionPressed(positive) ? 1 : 0) - (isActionPressed(negative) ? 1 : 0)`.
3. Final value is clamped to [-1, 1].

### Gamepad Axis Names

Axis names map to `GamepadAxis` enum values in `keycode.h`:

| Name | Enum | Range |
|------|------|-------|
| `left_stick_x` | `LEFTX` | [-1, 1] |
| `left_stick_y` | `LEFTY` | [-1, 1] |
| `right_stick_x` | `RIGHTX` | [-1, 1] |
| `right_stick_y` | `RIGHTY` | [-1, 1] |
| `left_trigger` | `LEFT_TRIGGER` | [0, 1] |
| `right_trigger` | `RIGHT_TRIGGER` | [0, 1] |

## Complete Default Profile Example

```json
{
  "actions": {
    "move_forward": { "keys": ["KEY_KEY_W"], "gamepad": [] },
    "move_back":    { "keys": ["KEY_KEY_S"], "gamepad": [] },
    "move_left":    { "keys": ["KEY_KEY_A"], "gamepad": [] },
    "move_right":   { "keys": ["KEY_KEY_D"], "gamepad": [] },
    "jump":         { "keys": ["KEY_SPACE"], "gamepad": ["a"] },
    "sprint":       { "keys": ["KEY_LSHIFT"], "gamepad": ["leftstick"] },
    "dodge":        { "keys": ["KEY_LCONTROL"], "gamepad": ["b"] }
  },
  "axes": {
    "move_x": {
      "positive": "move_right",
      "negative": "move_left",
      "gamepad_axis": "left_stick_x",
      "deadzone": 0.15
    },
    "move_y": {
      "positive": "move_forward",
      "negative": "move_back",
      "gamepad_axis": "left_stick_y",
      "deadzone": 0.15
    }
  }
}
```

## Error Handling

- Missing `actions` or `axes` top-level key → `load_profile` returns `false`, logs `[ARCH-ENGINE:INPUT] profile missing required key`.
- Unknown action name referenced in `axes.positive`/`axes.negative` → axis returns 0, warning logged.
- Invalid keycode string → ignored with warning; action still binds valid keys.
- File not found or unreadable → `load_profile` returns `false`, logs error. Existing bindings are NOT cleared on failed load.
- Malformed JSON → `load_profile` returns `false`, logs parse error.

## Notes

- Profiles are **additive** when loaded programmatically: `load_profile` merges into existing bindings. To fully replace, call a hypothetical `clear_bindings()` first (not in Phase 2 API; rebind individually instead).
- `save_profile` writes the complete current binding state, including any runtime modifications made via `bind_action`/`bind_axis`.
- The `arch_engine.input` namespace handles all profile I/O; mods should never parse input JSON directly.