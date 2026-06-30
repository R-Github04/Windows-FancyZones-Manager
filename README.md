# FancyZones Hotkey Bridge

Monitor-aware hotkeys for Microsoft PowerToys FancyZones on Windows.

This is an independent utility and is not an official Microsoft or Windows application.

Use familiar shortcuts like `Alt+1`, `Alt+2`, `Ctrl+Alt+1`, and `Alt+Shift+Right` to move the active window to the right zone on the right monitor, even when each monitor uses a different FancyZones layout.

> Best for: Windows power users, developers, traders, and AI-heavy multitaskers who work across 2+ monitors and already rely on FancyZones.

## Why this exists

FancyZones is great for layouts, but many people still want direct hotkeys for:

- send this window to zone 1 on the active monitor
- jump to the next monitor while keeping relative placement
- send a window to a named destination such as "main monitor center"

This bridge reads your FancyZones custom layout files, resolves the target zone rectangle, and moves the foreground window there.

## What it does

- Registers global Windows hotkeys.
- Reads FancyZones layouts from `%LocalAppData%\Microsoft\PowerToys\FancyZones`.
- Supports different layouts on different monitors.
- Supports FancyZones custom `grid` and `canvas` layouts.
- Supports `@applied` so a preset can follow the custom layout currently applied to a monitor.
- Supports monitor-aware actions:
  - move to zone `1`, `2`, `3`, and so on
  - move to next or previous monitor
  - move to a specific monitor number
  - map any hotkey to a reusable named target

## Recommended GitHub page layout

For the best first impression on GitHub, add these two assets to a `media/` folder:

- `media/demo.gif`: a 15-30 second GIF showing `Alt+1`, `Alt+2`, and monitor switching
- `media/before-after.png`: one image comparing stock FancyZones behavior vs this bridge

When you have them, place this block right under the intro:

```md
![Demo](media/demo.gif)

![Before and after](media/before-after.png)
```

The GIF should show one clear story:

1. Focus a window on monitor A.
2. Press `Alt+1`, `Alt+2`, `Alt+3`.
3. Press `Alt+Shift+Right`.
4. Show that the hotkeys follow each monitor's applied FancyZones layout.

## Install in 4 steps

1. Install Microsoft PowerToys and set up FancyZones custom layouts for your monitors.
2. Download the latest release ZIP. **Before extracting**, right-click the `.zip` file, select **Properties**, check **Unblock** at the bottom, and click Apply. (This prevents Windows from blocking the scripts inside).
3. Extract the ZIP anywhere, and edit `presets.json` to configure your hotkeys.
4. Run `FancyZonesHotkeys.exe` (or `Run-FancyZonesHotkeys.bat`), then focus a window and press your hotkeys.

> **Note on Windows SmartScreen**: Because this utility is not digitally signed with an expensive certificate, Windows may show a blue "Windows protected your PC" screen on first run. Click **More info** and then **Run anyway**.

If you want to move elevated apps such as Task Manager or an admin terminal, run this bridge as administrator too.

## Release ZIP format

The simplest distribution format for this project is a portable ZIP with these files at the top level:

- `FancyZonesHotkeys.ps1`
- `Run-FancyZonesHotkeys.bat`
- `presets.json`
- `README.md`
- `QUICKSTART.txt`

Recommended asset name:

```text
FancyZonesHotkeyBridge-v0.1.0.zip
```

That gives users a very clear path:

1. Download ZIP
2. Extract ZIP
3. Edit `presets.json`
4. Double-click `Run-FancyZonesHotkeys.bat`

## Example config

`presets.json` has two sections:

- `targets`: reusable named destinations
- `presets`: hotkeys that either define an action directly or point to a target

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
      "id": "center-main",
      "action": "zone",
      "monitor": 1,
      "layout": "@applied",
      "zone": 2
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
      "hotkey": "Alt+2",
      "action": "zone",
      "monitor": "active",
      "layout": "@applied",
      "zone": 2
    },
    {
      "hotkey": "Alt+3",
      "action": "zone",
      "monitor": "active",
      "layout": "@applied",
      "zone": 3
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

## Actions

### Zone action

Use this when you want the active window sent to a FancyZones zone.

- `action`: `zone`
- `monitor`: which monitor should receive the window
- `layout`: `@applied`, a FancyZones layout name, or a FancyZones layout UUID
- `zone`: 1-based zone number inside that layout

### Monitor action

Use this when you only want to move the active window to another monitor.

- `action`: `monitor`
- `monitor`: which monitor should receive the window
- `placement`: how the window should be placed on the target monitor

Supported `placement` values:

- `preserve-relative`
- `preserve-size`
- `center`
- `maximize`
- `top-left`

### Monitor selector

`monitor` can be:

- `active` or `current`
- `primary`
- `next`
- `previous`
- a display number such as `1`, `2`, `3`
- a device name such as `\\.\DISPLAY2`

## Useful commands

Inspect the layouts currently available from FancyZones:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -ListLayouts
```

Inspect the currently detected monitors and their applied custom layouts:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -ListMonitors
```

Validate the config without starting the hotkey loop:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -ValidateConfig
```

Preview where one preset would send the currently focused window:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -PreviewHotkey Alt+1
```

## Suggested workflow

- Give each monitor its own FancyZones custom layout.
- Use `Alt+1`, `Alt+2`, `Alt+3` for zone numbers on the active monitor.
- Use `Alt+Shift+Left` and `Alt+Shift+Right` to move between monitors.
- Use `targets` for absolute destinations like "main monitor center" or "right monitor top-left square".

## Current limitations

- `@applied` currently resolves only custom FancyZones layouts.
- Built-in FancyZones layouts such as `priority-grid` are not resolved yet because PowerToys does not expose ready-to-use zone rectangles for them in the same way.
