# Input Abstraction Probe — Phase 2 Wave 1

## Probes Executed

### 1. Keymap settings access
```bash
grep -rn 'keymap_forward\|get("keymap' engine/archlast-luanti/src/ | head
```
**Result:** `core.settings:get("keymap_forward")` returns a pipe-delimited string like `"SYSTEM_SCANCODE_26|GAMEPAD_AXIS_MINUS_1"`. All keymap_* defaults are defined in `src/defaultsettings.cpp:134-181`. The engine already parses these into `KeyPress` objects via `getKeySetting()` in `src/client/inputhandler.cpp:35-38`. Lua can read raw strings but has no structured query for "is action X currently active" — only raw key state checks.

### 2. Gamepad / joystick API surface
```bash
grep -rn 'gamepad|joystick|SJoystickInfo' engine/archlast-luanti/src/ | head
```
**Result:** IrrlichtMt gamepad support is present and functional:
- `KeyPress::InputType::GAMEPAD_BUTTON`, `GAMEPAD_AXIS_PLUS`, `GAMEPAD_AXIS_MINUS` enums in `src/keycode.h:31-33`
- `SEvent::SGamepadButtonEvent` / `SGamepadAxisEvent` constructors in `src/keycode.cpp:326-337`
- `MyEventReceiver` handles gamepad events in `src/client/inputhandler.cpp:130-198`
- Default keymaps already bind gamepad buttons/axes (e.g., `keymap_jump = "SYSTEM_SCANCODE_44|GAMEPAD_BUTTON_0"`)
- Joystick deadzone settings exist: `joystick_inner_dead_zone`, `joystick_outer_dead_zone` in `src/settings_translation_file.cpp:155-156`
- Touchscreen virtual joystick in `src/gui/touchcontrols.cpp:242-265`

**No SDL2 dependency found.** All gamepad input flows through IrrlichtMt's native event receiver. No `SDL_GameControllerDB` or SDL2 link targets in CMakeLists.txt.

### 3. Existing archlast stub
Read `engine/archlast-luanti/src/archlast/input_action_map.h` — full class declaration exists with:
- `ActionBinding` struct (key_names, gamepad_button_names, pre-resolved KeyPress vectors)
- `AxisBinding` struct (positive/negative actions, gamepad_axis_name, deadzone, pre-resolved KeyPress)
- `InputActionMap` class with all planned methods: `bindAction`, `bindAxis`, `isActionPressed`, `isActionJustPressed`, `isActionJustReleased`, `getAxis`, `getActions`, `loadProfile`, `saveProfile`, `update`
- Private helpers: `resolveKeyName`, `resolveGamepadButtonName`, `resolveGamepadAxisName`, `isKeyPressActive`, `getGamepadAxisValue`
- Global singleton setter: `SetInputActionMap(InputActionMap *map)`

Lua bindings stub (`lua_bindings_input.cpp`) already has `l_bind_action`, `l_bind_axis` implementations parsing Lua tables.

## Gaps Identified

1. **No action abstraction layer.** Current input is raw key/button queries (`IsKeyDown(KeyPress)`). No semantic action name → physical binding mapping accessible to Lua. Mods must hardcode key names and manually check multiple keys for one action.

2. **No axis composition.** Analog axes are consumed directly as float values by the movement system. No named axis abstraction that combines positive/negative actions + gamepad axis + deadzone into a single `-1.0..1.0` value queryable by Lua.

3. **No gamepad button/axis name mapping.** While IrrlichtMt supports gamepads natively, there is no human-readable name → index resolution (e.g., `"a"` → button 0, `"left_stick_x"` → axis 0). The stub implements this via static maps in `resolveGamepadButtonName` / `resolveGamepadAxisName`, but it is not yet wired to live input or exposed to Lua.

4. **No profile load/save.** Key bindings are set once at startup from `minetest.conf`. No runtime rebinding, no JSON profile persistence, no per-game/per-mod binding sets. The `loadProfile`/`saveProfile` methods exist in the stub but have no implementation body.

5. **No configurable deadzone per axis.** Engine-wide `joystick_inner_dead_zone` / `joystick_outer_dead_zone` settings apply globally. No per-axis deadzone in the action map — the stub declares `float deadzone = 0.15f` in `AxisBinding` but does not apply it during `getAxis()`.

6. **No just-pressed / just-released edge detection.** Only continuous `IsKeyDown` queries exist. Frame-delta input state (`m_pressed_prev` vs `m_pressed_curr`) is declared in the stub but `update(dtime)` is unimplemented.

## C++ Approach

**New `InputActionMap` class** in `src/archlast/input_action_map.{h,cpp}` (stub already exists, replace body):

- Wraps IrrlichtMt's `MyEventReceiver` for physical input queries — NO SDL2 dependency required. IrrlichtMt already provides `GAMEPAD_BUTTON_N`, `GAMEPAD_AXIS_PLUS_N`, `GAMEPAD_AXIS_MINUS_N` event types.
- Pre-resolves all string key/button/axis names to `KeyPress` objects at bind time (zero per-frame allocation).
- Maintains previous/current frame pressed sets for edge detection.
- Per-axis deadzone applied in `getAxis()`: `abs(raw) < deadzone ? 0.0 : sign(raw) * (abs(raw) - deadzone) / (1.0 - deadzone)`.
- JSON profile I/O using jsoncpp (already a Luanti dependency) for `loadProfile`/`saveProfile`.
- Default profile loaded from `game/arch_rpg/config/input_default.json` at client init; fallback to hardcoded WASD+gamepad defaults if file missing.

**SDL2 contingency:** If future requirements demand SDL2 GameController DB for cross-platform controller labeling, add SDL2 as optional link dependency and use `SDL_GameControllerAddMappingsFromFile()` as enhancement. For Phase 2, IrrlichtMt native gamepad is sufficient — confirmed working in defaultsettings.cpp with existing `GAMEPAD_*` bindings.

## C++ Signatures

```cpp
// src/archlast/input_action_map.h (already declared, implementation needed)
class InputActionMap {
public:
    void setEventReceiver(MyEventReceiver *receiver);

    void bindAction(const std::string &action, const std::vector<std::string> &keys,
                    const std::vector<std::string> &gamepad_buttons = {});
    void bindAxis(const std::string &axis, const std::string &positive,
                  const std::string &negative, const std::string &gamepad_axis = "");

    bool isActionPressed(const std::string &action) const;
    bool isActionJustPressed(const std::string &action) const;
    bool isActionJustReleased(const std::string &action) const;
    float getAxis(const std::string &axis) const;
    std::vector<std::string> getActions() const;

    bool loadProfile(const std::string &path);
    bool saveProfile(const std::string &path) const;
    void update(float dtime);

private:
    MyEventReceiver *m_receiver = nullptr;
    std::unordered_map<std::string, ActionBinding> m_actions;
    std::unordered_map<std::string, AxisBinding> m_axes;
    std::unordered_set<std::string> m_pressed_prev;
    std::unordered_set<std::string> m_pressed_curr;

    static KeyPress resolveKeyName(const std::string &name);
    static KeyPress resolveGamepadButtonName(const std::string &name);
    static void resolveGamepadAxisName(const std::string &name,
                                       KeyPress &out_plus, KeyPress &out_minus);
    bool isKeyPressActive(const KeyPress &kp) const;
    float getGamepadAxisValue(const KeyPress &plus, const KeyPress &minus) const;
};

void SetInputActionMap(InputActionMap *map);
```

## Lua Binding Signatures (`arch_engine.input.*`)

Registered on both client and server (server returns defaults/nil for hardware queries).

| Function | Signature | Notes |
|---|---|---|
| `bind_action` | `(name: string, keys: string[], gamepad?: string[]) → nil` | Bind action to keyboard keys and optional gamepad buttons |
| `bind_axis` | `(name: string, positive: string, negative: string, gamepad_axis?: string) → nil` | Bind named axis to positive/negative actions + optional gamepad axis |
| `is_action_pressed` | `(name: string) → boolean` | True while any bound key/button is held |
| `is_action_just_pressed` | `(name: string) → boolean` | True only on the frame the action transitions to pressed |
| `is_action_just_released` | `(name: string) → boolean` | True only on the frame the action transitions to released |
| `get_axis` | `(name: string) → number` | Returns -1.0..1.0 with deadzone applied; 0.0 if unbound |
| `get_actions` | `() → string[]` | List all registered action names |
| `load_profile` | `(path: string) → boolean` | Load JSON profile; returns false on parse error |
| `save_profile` | `(path: string) → boolean` | Save current bindings to JSON; returns false on write error |
| `update` | `(dtime: number) → nil` | Called each frame by engine; snapshots input state for edge detection |

## Conflict Risk: MEDIUM

- **IrrlichtMt input coupling:** `InputActionMap` depends on `MyEventReceiver` and `KeyPress` internals. These are stable Luanti APIs but could shift on engine upgrade. Mitigation: isolate all IrrlichtMt calls behind `isKeyPressActive` / `getGamepadAxisValue` private methods.
- **No SDL2 link needed for Phase 2.** IrrlichtMt native gamepad is sufficient. If SDL2 is added later, it is an additive optional dependency — no existing code breaks.
- **Shared files untouched:** This agent creates only `input_action_map.{h,cpp}` and `lua_bindings_input.cpp` in `src/archlast/`. Does NOT modify `modapi_archlast.cpp`, `CMakeLists.txt`, `scripting_client.cpp`, or `scripting_server.cpp` (those are wired in Step 2 before branching).
- **JSON dependency:** jsoncpp is already linked by Luanti core. No new dependency introduction.
- **Default profile path:** `game/arch_rpg/config/input_default.json` lives in parent repo, not engine submodule. No merge conflict with engine work.