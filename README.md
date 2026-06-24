# FancyZones Hotkey Bridge

This project adds monitor-aware preset hotkeys such as `Alt+1`, `Alt+2`, `Ctrl+Alt+1`, and `Alt+Shift+Right` on top of Microsoft PowerToys FancyZones.

Instead of asking FancyZones itself to move the active window, the script reads your FancyZones layout files and moves the foreground window to the matching zone rectangle.

## What it does

- Registers global hotkeys through Windows.
- Reads FancyZones layouts from `%LocalAppData%\Microsoft\PowerToys\FancyZones`.
- Supports different FancyZones layouts on different monitors.
- Supports FancyZones custom `grid` and `canvas` layouts.
- Supports `@applied` so a hotkey can follow the custom layout currently applied to the target monitor.
- Supports monitor-aware actions such as:
  - move to zone 1/2/3 of the active monitor
  - move to next/previous monitor
  - move to a specific monitor number
  - map any hotkey to a named global target

## Files

- `FancyZonesHotkeys.ps1`: main script.
- `presets.json`: hotkey and target definitions.
- `Run-FancyZonesHotkeys.bat`: simple launcher.

## Config model

The config has two sections:

- `targets`: reusable named destinations
- `presets`: hotkeys that either define an action directly or point to a target

Example:

```json
{
  "targets": [
    {
      "id": "left-main",
      "action": "zone",
      "monitor": 1,
      "layout": "@applied",
      "zone": 1
    },
    {
      "id": "quad-top-left",
      "action": "zone",
      "monitor": 2,
      "layout": "@applied",
      "zone": 1
    }
  ],
  "presets": [
    {
      "hotkey": "Alt+1",
      "action": "zone",
      "monitor": "active",
      "layout": "@applied",
      "zone": 1
    },
    {
      "hotkey": "Alt+Shift+Right",
      "action": "monitor",
      "monitor": "next",
      "placement": "preserve-relative"
    },
    {
      "hotkey": "Ctrl+Alt+1",
      "target": "left-main"
    }
  ]
}
```

## Zone action

Use this when you want the active window sent to a FancyZones zone.

Fields:

- `action`: `zone`
- `monitor`: which monitor should receive the window
- `layout`: `@applied`, a FancyZones layout name, or a FancyZones layout UUID
- `zone`: 1-based zone number inside that layout

## Monitor action

Use this when you only want to move the active window to another monitor.

Fields:

- `action`: `monitor`
- `monitor`: which monitor should receive the window
- `placement`: how the window should be placed on the target monitor

Supported `placement` values:

- `preserve-relative`: scale the current window position and size relative to the target monitor
- `preserve-size`: keep the current size and move with the same offset from the work area
- `center`: keep the size if possible and center it
- `maximize`: fill the target work area
- `top-left`: keep the size and move to the top-left of the target work area

## Monitor selector

`monitor` can be:

- `active` or `current`
- `primary`
- `next`
- `previous`
- a display number such as `1`, `2`, `3`
- a device name such as `\\.\DISPLAY2`

## Usage

1. Keep PowerToys FancyZones installed and configured.
2. Edit `presets.json` to match your monitor setup and preferred hotkeys.
3. Run `Run-FancyZonesHotkeys.bat`.
4. Focus a window and press your hotkey.

To inspect the layouts currently available from FancyZones:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -ListLayouts
```

To inspect the currently detected monitors and their applied custom layouts:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -ListMonitors
```

To validate the preset file without starting the hotkey loop:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -ValidateConfig
```

To preview where one preset would send the currently focused window:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -PreviewHotkey Alt+1
```

## Suggested workflow

- Give each monitor its own FancyZones custom layout.
- Use `Alt+1`, `Alt+2`, `Alt+3` for the active monitor's zone numbers.
- Use `Alt+Shift+Left` and `Alt+Shift+Right` to move between monitors.
- Use `targets` for absolute destinations like "main monitor center" or "right monitor top-left square".

## Elevated windows

If you want to move elevated applications such as Task Manager or admin terminals, run this bridge as administrator too.

This does not bypass Windows secure desktop restrictions, so UAC consent dialogs are still out of scope.

## Current limitations

- `@applied` currently resolves only custom FancyZones layouts.
- Built-in layouts such as `priority-grid` are not resolved yet because PowerToys stores only the type, not a ready-to-use rectangle list, in the same way as custom layouts.
