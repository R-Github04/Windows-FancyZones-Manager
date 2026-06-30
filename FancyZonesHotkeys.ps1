[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$ListLayouts,
    [switch]$ListMonitors,
    [switch]$ValidateConfig,
    [string]$PreviewHotkey
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "Installing powershell-yaml module..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue
    Install-Module -Name powershell-yaml -Scope CurrentUser -Force -AllowClobber
}
Import-Module powershell-yaml

if (-not $ConfigPath) {
    $scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $ConfigPath = Join-Path $scriptRoot 'presets.yaml'
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$interopSource = @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class NativeMethods
{
    public const uint MOD_ALT = 0x0001;
    public const uint MOD_CONTROL = 0x0002;
    public const uint MOD_SHIFT = 0x0004;
    public const uint MOD_WIN = 0x0008;
    public const uint MOD_NOREPEAT = 0x4000;

    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_SHOWWINDOW = 0x0040;

    public const uint MONITOR_DEFAULTTONEAREST = 0x00000002;
    public const int SW_RESTORE = 9;
    public const int WM_HOTKEY = 0x0312;

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct MONITORINFOEX
    {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string szDevice;
    }

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr MonitorFromWindow(IntPtr hwnd, uint dwFlags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFOEX lpmi);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsZoomed(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int X,
        int Y,
        int cx,
        int cy,
        uint uFlags
    );

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
}

public class HotkeyWindow : Form
{
    public event Action<int> HotkeyPressed;

    public HotkeyWindow()
    {
        ShowInTaskbar = false;
        FormBorderStyle = FormBorderStyle.FixedToolWindow;
        WindowState = FormWindowState.Minimized;
        Opacity = 0;
    }

    protected override void SetVisibleCore(bool value)
    {
        base.SetVisibleCore(false);
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == NativeMethods.WM_HOTKEY)
        {
            if (HotkeyPressed != null)
            {
                HotkeyPressed(m.WParam.ToInt32());
            }
        }

        base.WndProc(ref m);
    }
}
'@

Add-Type -TypeDefinition $interopSource -ReferencedAssemblies System.Windows.Forms, System.Drawing

function Get-FancyZonesRoot {
    Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\FancyZones'
}

function Read-JsonFile {
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "JSON file not found: $Path"
    }

    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-FancyZonesData {
    $root = Get-FancyZonesRoot

    [pscustomobject]@{
        Root           = $root
        CustomLayouts  = (Read-JsonFile -Path (Join-Path $root 'custom-layouts.json')).'custom-layouts'
        AppliedLayouts = (Read-JsonFile -Path (Join-Path $root 'applied-layouts.json')).'applied-layouts'
    }
}

function New-SampleConfig {
    param([Parameter(Mandatory)] [string]$Path)

    $sample = @'
targets:
  - id: "left-main"
    action: "zone"
    monitor: 1
    layout: "@applied"
    zone: 1
  - id: "center-main"
    action: "zone"
    monitor: 1
    layout: "@applied"
    zone: 2
  - id: "quad-top-left"
    action: "zone"
    monitor: 2
    layout: "@applied"
    zone: 1

presets:
  - hotkey: "Alt+1"
    action: "zone"
    monitor: "active"
    layout: "@applied"
    zone: 1
  - hotkey: "Alt+2"
    action: "zone"
    monitor: "active"
    layout: "@applied"
    zone: 2
  - hotkey: "Alt+3"
    action: "zone"
    monitor: "active"
    layout: "@applied"
    zone: 3
  - hotkey: "Alt+Shift+Right"
    action: "monitor"
    monitor: "next"
    placement: "preserve-relative"
  - hotkey: "Alt+Shift+Left"
    action: "monitor"
    monitor: "previous"
    placement: "preserve-relative"
  - hotkey: "Ctrl+Alt+1"
    target: "left-main"
  - hotkey: "Ctrl+Alt+2"
    target: "center-main"
  - hotkey: "Ctrl+Alt+Q"
    target: "quad-top-left"
'@

    Set-Content -LiteralPath $Path -Value $sample -Encoding UTF8
}

function Get-HotkeyDefinition {
    param([Parameter(Mandatory)] [string]$Hotkey)

    $parts = $Hotkey.Split('+', [System.StringSplitOptions]::RemoveEmptyEntries) |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }

    if ($parts.Count -lt 2) {
        throw "Hotkey '$Hotkey' must contain at least one modifier and one key."
    }

    $modifierMap = @{
        'ALT'      = [uint32][NativeMethods]::MOD_ALT
        'CTRL'     = [uint32][NativeMethods]::MOD_CONTROL
        'CONTROL'  = [uint32][NativeMethods]::MOD_CONTROL
        'SHIFT'    = [uint32][NativeMethods]::MOD_SHIFT
        'WIN'      = [uint32][NativeMethods]::MOD_WIN
        'WINDOWS'  = [uint32][NativeMethods]::MOD_WIN
    }

    $virtualKeys = @{
        'LEFT'      = [uint32][System.Windows.Forms.Keys]::Left
        'RIGHT'     = [uint32][System.Windows.Forms.Keys]::Right
        'UP'        = [uint32][System.Windows.Forms.Keys]::Up
        'DOWN'      = [uint32][System.Windows.Forms.Keys]::Down
        'HOME'      = [uint32][System.Windows.Forms.Keys]::Home
        'END'       = [uint32][System.Windows.Forms.Keys]::End
        'INSERT'    = [uint32][System.Windows.Forms.Keys]::Insert
        'DELETE'    = [uint32][System.Windows.Forms.Keys]::Delete
        'TAB'       = [uint32][System.Windows.Forms.Keys]::Tab
        'SPACE'     = [uint32][System.Windows.Forms.Keys]::Space
        'ENTER'     = [uint32][System.Windows.Forms.Keys]::Enter
        'ESC'       = [uint32][System.Windows.Forms.Keys]::Escape
        'ESCAPE'    = [uint32][System.Windows.Forms.Keys]::Escape
        'PGUP'      = [uint32][System.Windows.Forms.Keys]::PageUp
        'PAGEUP'    = [uint32][System.Windows.Forms.Keys]::PageUp
        'PGDN'      = [uint32][System.Windows.Forms.Keys]::PageDown
        'PAGEDOWN'  = [uint32][System.Windows.Forms.Keys]::PageDown
    }

    [uint32]$modifiers = [NativeMethods]::MOD_NOREPEAT
    $keyToken = $parts[-1].ToUpperInvariant()

    foreach ($modifier in $parts[0..($parts.Count - 2)]) {
        $token = $modifier.ToUpperInvariant()
        if (-not $modifierMap.ContainsKey($token)) {
            throw "Unknown hotkey modifier '$modifier' in '$Hotkey'."
        }

        $modifiers = $modifiers -bor $modifierMap[$token]
    }

    if ($keyToken -match '^[A-Z]$') {
        $vk = [uint32][byte][char]$keyToken
    }
    elseif ($keyToken -match '^[0-9]$') {
        $vk = [uint32][System.Windows.Forms.Keys]::"D$keyToken"
    }
    elseif ($keyToken -match '^F([1-9]|1[0-9]|2[0-4])$') {
        $vk = [uint32][System.Windows.Forms.Keys]::$keyToken
    }
    elseif ($virtualKeys.ContainsKey($keyToken)) {
        $vk = $virtualKeys[$keyToken]
    }
    else {
        throw "Unsupported hotkey key '$($parts[-1])' in '$Hotkey'."
    }

    [pscustomobject]@{
        Display    = $Hotkey
        Modifiers  = $modifiers
        VirtualKey = $vk
    }
}

function Get-DisplayNumberFromDeviceName {
    param([string]$DeviceName)

    if ($DeviceName -match 'DISPLAY(\d+)$') {
        return [int]$Matches[1]
    }

    $null
}

function Convert-Rectangle {
    param($Rectangle)

    [pscustomobject]@{
        Left   = $Rectangle.Left
        Top    = $Rectangle.Top
        Right  = $Rectangle.Right
        Bottom = $Rectangle.Bottom
        Width  = $Rectangle.Width
        Height = $Rectangle.Height
    }
}

function Get-AllMonitors {
    $screens = [System.Windows.Forms.Screen]::AllScreens
    $monitors = New-Object System.Collections.Generic.List[object]

    foreach ($screen in $screens) {
        $displayNumber = Get-DisplayNumberFromDeviceName -DeviceName $screen.DeviceName
        $monitors.Add([pscustomobject]@{
            DeviceName    = $screen.DeviceName
            DisplayNumber = $displayNumber
            IsPrimary     = $screen.Primary
            Bounds        = Convert-Rectangle -Rectangle $screen.Bounds
            WorkArea      = Convert-Rectangle -Rectangle $screen.WorkingArea
            MonitorLeft   = $screen.Bounds.Left
            MonitorTop    = $screen.Bounds.Top
            MonitorRight  = $screen.Bounds.Right
            MonitorBottom = $screen.Bounds.Bottom
            WorkLeft      = $screen.WorkingArea.Left
            WorkTop       = $screen.WorkingArea.Top
            WorkRight     = $screen.WorkingArea.Right
            WorkBottom    = $screen.WorkingArea.Bottom
            WorkWidth     = $screen.WorkingArea.Width
            WorkHeight    = $screen.WorkingArea.Height
        }) | Out-Null
    }

    $monitors
}

function Get-MonitorInfoForWindow {
    param([Parameter(Mandatory)] [System.IntPtr]$WindowHandle)

    $monitorHandle = [NativeMethods]::MonitorFromWindow($WindowHandle, [NativeMethods]::MONITOR_DEFAULTTONEAREST)
    if ($monitorHandle -eq [System.IntPtr]::Zero) {
        throw 'Could not determine the monitor for the active window.'
    }

    $info = New-Object NativeMethods+MONITORINFOEX
    $info.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type] [NativeMethods+MONITORINFOEX])

    if (-not [NativeMethods]::GetMonitorInfo($monitorHandle, [ref]$info)) {
        throw 'GetMonitorInfo failed.'
    }

    $allMonitors = Get-AllMonitors
    $matchedMonitor = $allMonitors | Where-Object { $_.DeviceName -eq $info.szDevice } | Select-Object -First 1

    if ($matchedMonitor) {
        return $matchedMonitor
    }

    [pscustomobject]@{
        DeviceName    = $info.szDevice
        DisplayNumber = (Get-DisplayNumberFromDeviceName -DeviceName $info.szDevice)
        IsPrimary     = $false
        MonitorLeft   = $info.rcMonitor.Left
        MonitorTop    = $info.rcMonitor.Top
        MonitorRight  = $info.rcMonitor.Right
        MonitorBottom = $info.rcMonitor.Bottom
        WorkLeft      = $info.rcWork.Left
        WorkTop       = $info.rcWork.Top
        WorkRight     = $info.rcWork.Right
        WorkBottom    = $info.rcWork.Bottom
        WorkWidth     = $info.rcWork.Right - $info.rcWork.Left
        WorkHeight    = $info.rcWork.Bottom - $info.rcWork.Top
    }
}

function Get-WindowRectObject {
    param([Parameter(Mandatory)] [System.IntPtr]$WindowHandle)

    $rect = New-Object NativeMethods+RECT
    if (-not [NativeMethods]::GetWindowRect($WindowHandle, [ref]$rect)) {
        throw 'GetWindowRect failed.'
    }

    [pscustomobject]@{
        Left   = $rect.Left
        Top    = $rect.Top
        Right  = $rect.Right
        Bottom = $rect.Bottom
        Width  = $rect.Right - $rect.Left
        Height = $rect.Bottom - $rect.Top
    }
}

function Convert-PercentagesToLengths {
    param(
        [Parameter(Mandatory)] [int]$TotalLength,
        [Parameter(Mandatory)] [object[]]$Percentages
    )

    $result = New-Object System.Collections.Generic.List[int]
    $previousBoundary = 0
    $runningPercent = 0

    for ($i = 0; $i -lt $Percentages.Count; $i++) {
        $runningPercent += [int]$Percentages[$i]
        if ($i -eq $Percentages.Count - 1) {
            $boundary = $TotalLength
        }
        else {
            $boundary = [int][Math]::Round($TotalLength * ($runningPercent / 10000.0))
        }

        $result.Add($boundary - $previousBoundary)
        $previousBoundary = $boundary
    }

    $result
}

function Get-GridZoneRects {
    param(
        [Parameter(Mandatory)] $Layout,
        [Parameter(Mandatory)] $Monitor
    )

    $rows = [int]$Layout.info.rows
    $columns = [int]$Layout.info.columns
    $spacing = if ($Layout.info.'show-spacing') { [int]$Layout.info.spacing } else { 0 }

    $effectiveWidth = $Monitor.WorkWidth - ($spacing * [Math]::Max($columns - 1, 0))
    $effectiveHeight = $Monitor.WorkHeight - ($spacing * [Math]::Max($rows - 1, 0))

    if ($effectiveWidth -le 0 -or $effectiveHeight -le 0) {
        throw "Monitor work area is too small for layout '$($Layout.name)'."
    }

    $columnWidths = Convert-PercentagesToLengths -TotalLength $effectiveWidth -Percentages $Layout.info.'columns-percentage'
    $rowHeights = Convert-PercentagesToLengths -TotalLength $effectiveHeight -Percentages $Layout.info.'rows-percentage'

    $columnStarts = New-Object System.Collections.Generic.List[int]
    $rowStarts = New-Object System.Collections.Generic.List[int]

    $cursor = $Monitor.WorkLeft
    foreach ($width in $columnWidths) {
        $columnStarts.Add($cursor)
        $cursor += $width + $spacing
    }

    $cursor = $Monitor.WorkTop
    foreach ($height in $rowHeights) {
        $rowStarts.Add($cursor)
        $cursor += $height + $spacing
    }

    $zoneCells = @{}
    for ($row = 0; $row -lt $rows; $row++) {
        for ($column = 0; $column -lt $columns; $column++) {
            $zoneId = [int]$Layout.info.'cell-child-map'[$row][$column]

            if (-not $zoneCells.ContainsKey($zoneId)) {
                $zoneCells[$zoneId] = [pscustomobject]@{
                    MinRow    = $row
                    MaxRow    = $row
                    MinColumn = $column
                    MaxColumn = $column
                }
            }
            else {
                $zoneCells[$zoneId].MinRow = [Math]::Min($zoneCells[$zoneId].MinRow, $row)
                $zoneCells[$zoneId].MaxRow = [Math]::Max($zoneCells[$zoneId].MaxRow, $row)
                $zoneCells[$zoneId].MinColumn = [Math]::Min($zoneCells[$zoneId].MinColumn, $column)
                $zoneCells[$zoneId].MaxColumn = [Math]::Max($zoneCells[$zoneId].MaxColumn, $column)
            }
        }
    }

    $rects = New-Object System.Collections.Generic.List[object]
    foreach ($zoneId in ($zoneCells.Keys | Sort-Object)) {
        $cell = $zoneCells[$zoneId]
        $left = $columnStarts[$cell.MinColumn]
        $top = $rowStarts[$cell.MinRow]

        $width = 0
        for ($column = $cell.MinColumn; $column -le $cell.MaxColumn; $column++) {
            $width += $columnWidths[$column]
        }
        $width += $spacing * ($cell.MaxColumn - $cell.MinColumn)

        $height = 0
        for ($row = $cell.MinRow; $row -le $cell.MaxRow; $row++) {
            $height += $rowHeights[$row]
        }
        $height += $spacing * ($cell.MaxRow - $cell.MinRow)

        $rects.Add([pscustomobject]@{
            Zone   = $zoneId + 1
            X      = $left
            Y      = $top
            Width  = $width
            Height = $height
        }) | Out-Null
    }

    $rects
}

function Get-CanvasZoneRects {
    param(
        [Parameter(Mandatory)] $Layout,
        [Parameter(Mandatory)] $Monitor
    )

    $refWidth = [double]$Layout.info.'ref-width'
    $refHeight = [double]$Layout.info.'ref-height'

    if ($refWidth -le 0 -or $refHeight -le 0) {
        throw "Canvas layout '$($Layout.name)' has an invalid reference size."
    }

    $scaleX = $Monitor.WorkWidth / $refWidth
    $scaleY = $Monitor.WorkHeight / $refHeight

    $rects = New-Object System.Collections.Generic.List[object]
    for ($index = 0; $index -lt $Layout.info.zones.Count; $index++) {
        $zone = $Layout.info.zones[$index]
        $rects.Add([pscustomobject]@{
            Zone   = $index + 1
            X      = $Monitor.WorkLeft + [int][Math]::Round([double]$zone.X * $scaleX)
            Y      = $Monitor.WorkTop + [int][Math]::Round([double]$zone.Y * $scaleY)
            Width  = [int][Math]::Round([double]$zone.width * $scaleX)
            Height = [int][Math]::Round([double]$zone.height * $scaleY)
        }) | Out-Null
    }

    $rects
}

function Resolve-CustomLayout {
    param(
        [Parameter(Mandatory)] $FancyZonesData,
        [Parameter(Mandatory)] [string]$LayoutReference,
        [Parameter(Mandatory)] $Monitor
    )

    if ($LayoutReference -eq '@applied') {
        $monitorNumber = $Monitor.DisplayNumber

        if ($null -eq $monitorNumber) {
            throw "Could not derive a monitor number from '$($Monitor.DeviceName)'."
        }

        $appliedEntry = $FancyZonesData.AppliedLayouts |
            Where-Object {
                $_.device.'monitor-number' -eq $monitorNumber -and
                $_.'applied-layout'.type -eq 'custom'
            } |
            Select-Object -Last 1

        if (-not $appliedEntry) {
            throw "No custom applied FancyZones layout found for monitor $monitorNumber."
        }

        $layout = $FancyZonesData.CustomLayouts |
            Where-Object { $_.uuid -eq $appliedEntry.'applied-layout'.uuid } |
            Select-Object -First 1

        if (-not $layout) {
            throw "Applied layout '$($appliedEntry.'applied-layout'.uuid)' was not found in custom-layouts.json."
        }

        return $layout
    }

    $layout = $FancyZonesData.CustomLayouts |
        Where-Object { $_.uuid -eq $LayoutReference -or $_.name -eq $LayoutReference } |
        Select-Object -First 1

    if (-not $layout) {
        throw "Layout '$LayoutReference' was not found in custom-layouts.json."
    }

    $layout
}

function Resolve-MonitorSelector {
    param(
        [Parameter(Mandatory)] $MonitorSelector,
        [Parameter(Mandatory)] $CurrentMonitor,
        [Parameter(Mandatory)] $AllMonitors
    )

    $sortedMonitors = $AllMonitors |
        Sort-Object @{ Expression = { if ($null -ne $_.DisplayNumber) { $_.DisplayNumber } else { 9999 } } }, DeviceName

    if ($null -eq $MonitorSelector -or $MonitorSelector -eq '' -or $MonitorSelector -eq 'active' -or $MonitorSelector -eq 'current') {
        return $CurrentMonitor
    }

    if ($MonitorSelector -is [int] -or $MonitorSelector -is [long]) {
        $monitor = $AllMonitors | Where-Object { $_.DisplayNumber -eq [int]$MonitorSelector } | Select-Object -First 1
        if (-not $monitor) {
            throw "No monitor with display number '$MonitorSelector' was found."
        }

        return $monitor
    }

    $token = [string]$MonitorSelector

    if ($token -match '^\d+$') {
        return Resolve-MonitorSelector -MonitorSelector ([int]$token) -CurrentMonitor $CurrentMonitor -AllMonitors $AllMonitors
    }

    switch -Regex ($token.ToLowerInvariant()) {
        '^primary$' {
            $monitor = $AllMonitors | Where-Object { $_.IsPrimary } | Select-Object -First 1
            if (-not $monitor) {
                throw 'No primary monitor was found.'
            }

            return $monitor
        }
        '^next$' {
            $currentIndex = -1
            for ($i = 0; $i -lt $sortedMonitors.Count; $i++) {
                if ($sortedMonitors[$i].DeviceName -eq $CurrentMonitor.DeviceName) {
                    $currentIndex = $i
                    break
                }
            }

            if ($currentIndex -lt 0) {
                throw "Current monitor '$($CurrentMonitor.DeviceName)' was not found in the monitor list."
            }

            return $sortedMonitors[($currentIndex + 1) % $sortedMonitors.Count]
        }
        '^previous$' {
            $currentIndex = -1
            for ($i = 0; $i -lt $sortedMonitors.Count; $i++) {
                if ($sortedMonitors[$i].DeviceName -eq $CurrentMonitor.DeviceName) {
                    $currentIndex = $i
                    break
                }
            }

            if ($currentIndex -lt 0) {
                throw "Current monitor '$($CurrentMonitor.DeviceName)' was not found in the monitor list."
            }

            $previousIndex = if ($currentIndex -eq 0) { $sortedMonitors.Count - 1 } else { $currentIndex - 1 }
            return $sortedMonitors[$previousIndex]
        }
        default {
            $monitor = $AllMonitors | Where-Object { $_.DeviceName -eq $token } | Select-Object -First 1
            if (-not $monitor) {
                throw "Unknown monitor selector '$MonitorSelector'. Use active, primary, next, previous, a display number, or a device name like \\.\DISPLAY2."
            }

            return $monitor
        }
    }
}

function Get-ZoneRectForAction {
    param(
        [Parameter(Mandatory)] $FancyZonesData,
        [Parameter(Mandatory)] $ActionDefinition,
        [Parameter(Mandatory)] $Monitor
    )

    $layoutReference = if ($ActionDefinition.layout) { [string]$ActionDefinition.layout } else { '@applied' }
    $layout = Resolve-CustomLayout -FancyZonesData $FancyZonesData -LayoutReference $layoutReference -Monitor $Monitor

    $rects = switch ($layout.type) {
        'grid' { Get-GridZoneRects -Layout $layout -Monitor $Monitor }
        'canvas' { Get-CanvasZoneRects -Layout $layout -Monitor $Monitor }
        default { throw "Unsupported FancyZones layout type '$($layout.type)'." }
    }

    $rect = $rects | Where-Object { $_.Zone -eq [int]$ActionDefinition.zone } | Select-Object -First 1
    if (-not $rect) {
        throw "Layout '$($layout.name)' does not contain zone $($ActionDefinition.zone)."
    }

    [pscustomobject]@{
        LayoutName = $layout.name
        LayoutUuid = $layout.uuid
        Rect       = $rect
    }
}

function Clamp-WindowRectToMonitor {
    param(
        [Parameter(Mandatory)] [int]$X,
        [Parameter(Mandatory)] [int]$Y,
        [Parameter(Mandatory)] [int]$Width,
        [Parameter(Mandatory)] [int]$Height,
        [Parameter(Mandatory)] $Monitor
    )

    $safeWidth = [Math]::Min($Width, $Monitor.WorkWidth)
    $safeHeight = [Math]::Min($Height, $Monitor.WorkHeight)

    $maxLeft = $Monitor.WorkRight - $safeWidth
    $maxTop = $Monitor.WorkBottom - $safeHeight

    [pscustomobject]@{
        X      = [Math]::Max($Monitor.WorkLeft, [Math]::Min($X, $maxLeft))
        Y      = [Math]::Max($Monitor.WorkTop, [Math]::Min($Y, $maxTop))
        Width  = $safeWidth
        Height = $safeHeight
    }
}

function Get-MonitorPlacementRect {
    param(
        [Parameter(Mandatory)] $SourceMonitor,
        [Parameter(Mandatory)] $TargetMonitor,
        [Parameter(Mandatory)] $WindowRect,
        [string]$Placement = 'preserve-relative'
    )

    $placementMode = $Placement.ToLowerInvariant()

    switch ($placementMode) {
        'maximize' {
            return [pscustomobject]@{
                X      = $TargetMonitor.WorkLeft
                Y      = $TargetMonitor.WorkTop
                Width  = $TargetMonitor.WorkWidth
                Height = $TargetMonitor.WorkHeight
            }
        }
        'center' {
            $width = [Math]::Min($WindowRect.Width, $TargetMonitor.WorkWidth)
            $height = [Math]::Min($WindowRect.Height, $TargetMonitor.WorkHeight)

            return [pscustomobject]@{
                X      = $TargetMonitor.WorkLeft + [int][Math]::Round(($TargetMonitor.WorkWidth - $width) / 2.0)
                Y      = $TargetMonitor.WorkTop + [int][Math]::Round(($TargetMonitor.WorkHeight - $height) / 2.0)
                Width  = $width
                Height = $height
            }
        }
        'preserve-size' {
            $x = $TargetMonitor.WorkLeft + ($WindowRect.Left - $SourceMonitor.WorkLeft)
            $y = $TargetMonitor.WorkTop + ($WindowRect.Top - $SourceMonitor.WorkTop)

            return Clamp-WindowRectToMonitor -X $x -Y $y -Width $WindowRect.Width -Height $WindowRect.Height -Monitor $TargetMonitor
        }
        'top-left' {
            return Clamp-WindowRectToMonitor -X $TargetMonitor.WorkLeft -Y $TargetMonitor.WorkTop -Width $WindowRect.Width -Height $WindowRect.Height -Monitor $TargetMonitor
        }
        'preserve-relative' {
            $widthRatio = if ($SourceMonitor.WorkWidth -gt 0) { $WindowRect.Width / [double]$SourceMonitor.WorkWidth } else { 1.0 }
            $heightRatio = if ($SourceMonitor.WorkHeight -gt 0) { $WindowRect.Height / [double]$SourceMonitor.WorkHeight } else { 1.0 }
            $xRatio = if ($SourceMonitor.WorkWidth -gt 0) { ($WindowRect.Left - $SourceMonitor.WorkLeft) / [double]$SourceMonitor.WorkWidth } else { 0.0 }
            $yRatio = if ($SourceMonitor.WorkHeight -gt 0) { ($WindowRect.Top - $SourceMonitor.WorkTop) / [double]$SourceMonitor.WorkHeight } else { 0.0 }

            $width = [int][Math]::Round($TargetMonitor.WorkWidth * $widthRatio)
            $height = [int][Math]::Round($TargetMonitor.WorkHeight * $heightRatio)
            $x = $TargetMonitor.WorkLeft + [int][Math]::Round($TargetMonitor.WorkWidth * $xRatio)
            $y = $TargetMonitor.WorkTop + [int][Math]::Round($TargetMonitor.WorkHeight * $yRatio)

            return Clamp-WindowRectToMonitor -X $x -Y $y -Width $width -Height $height -Monitor $TargetMonitor
        }
        default {
            throw "Unsupported monitor placement '$Placement'."
        }
    }
}

function Invoke-WindowMove {
    param(
        [Parameter(Mandatory)] [System.IntPtr]$WindowHandle,
        [Parameter(Mandatory)] [int]$X,
        [Parameter(Mandatory)] [int]$Y,
        [Parameter(Mandatory)] [int]$Width,
        [Parameter(Mandatory)] [int]$Height
    )

    if ([NativeMethods]::IsIconic($WindowHandle) -or [NativeMethods]::IsZoomed($WindowHandle)) {
        [NativeMethods]::ShowWindow($WindowHandle, [NativeMethods]::SW_RESTORE) | Out-Null
    }

    $flags = [NativeMethods]::SWP_NOZORDER -bor [NativeMethods]::SWP_NOACTIVATE -bor [NativeMethods]::SWP_SHOWWINDOW
    $result = [NativeMethods]::SetWindowPos(
        $WindowHandle,
        [System.IntPtr]::Zero,
        $X,
        $Y,
        $Width,
        $Height,
        $flags
    )

    if (-not $result) {
        throw 'SetWindowPos failed.'
    }
}

function Get-TargetMap {
    param($Config)

    $targetMap = @{}
    if ($Config.targets) {
        foreach ($target in $Config.targets) {
            if (-not $target.id) {
                throw 'Each target must define an id.'
            }

            if ($targetMap.ContainsKey([string]$target.id)) {
                throw "Duplicate target id '$($target.id)'."
            }

            $targetMap[[string]$target.id] = $target
        }
    }

    $targetMap
}

function Resolve-ActionDefinition {
    param(
        [Parameter(Mandatory)] $Preset,
        [Parameter(Mandatory)] $TargetMap
    )

    $definition = [ordered]@{}

    $targetProperty = $Preset.PSObject.Properties['target']
    if ($targetProperty -and $null -ne $targetProperty.Value -and [string]$targetProperty.Value -ne '') {
        $targetId = [string]$targetProperty.Value
        if (-not $TargetMap.ContainsKey($targetId)) {
            throw "Preset '$($Preset.hotkey)' references unknown target '$targetId'."
        }

        foreach ($property in $TargetMap[$targetId].PSObject.Properties) {
            $definition[$property.Name] = $property.Value
        }
    }

    foreach ($property in $Preset.PSObject.Properties) {
        if ($property.Name -eq 'target') {
            continue
        }

        $definition[$property.Name] = $property.Value
    }

    if (-not $definition.Contains('action') -or -not $definition.action) {
        $definition.action = if ($definition.Contains('zone') -and $definition.zone) { 'zone' } else { 'monitor' }
    }

    if (-not $definition.Contains('monitor') -or -not $definition.monitor) {
        $definition.monitor = 'active'
    }

    foreach ($name in @('layout', 'zone', 'placement')) {
        if (-not $definition.Contains($name)) {
            $definition[$name] = $null
        }
    }

    [pscustomobject]$definition
}

function Invoke-ActionDefinition {
    param(
        [Parameter(Mandatory)] $ActionDefinition,
        [Parameter(Mandatory)] $FancyZonesData
    )

    $windowHandle = [NativeMethods]::GetForegroundWindow()
    if ($windowHandle -eq [System.IntPtr]::Zero) {
        throw 'No foreground window is available.'
    }

    $allMonitors = Get-AllMonitors
    $sourceMonitor = Get-MonitorInfoForWindow -WindowHandle $windowHandle
    $targetMonitor = Resolve-MonitorSelector -MonitorSelector $ActionDefinition.monitor -CurrentMonitor $sourceMonitor -AllMonitors $allMonitors

    switch ($ActionDefinition.action.ToLowerInvariant()) {
        'zone' {
            if (-not $ActionDefinition.zone) {
                throw "Preset '$($ActionDefinition.hotkey)' is missing zone."
            }

            $target = Get-ZoneRectForAction -FancyZonesData $FancyZonesData -ActionDefinition $ActionDefinition -Monitor $targetMonitor
            Invoke-WindowMove -WindowHandle $windowHandle -X $target.Rect.X -Y $target.Rect.Y -Width $target.Rect.Width -Height $target.Rect.Height

            Write-Host ("[{0}] -> {1} / {2} / zone {3} ({4}, {5}, {6}x{7})" -f
                $ActionDefinition.hotkey,
                $targetMonitor.DeviceName,
                $target.LayoutName,
                $ActionDefinition.zone,
                $target.Rect.X,
                $target.Rect.Y,
                $target.Rect.Width,
                $target.Rect.Height
            )
        }
        'monitor' {
            $windowRect = Get-WindowRectObject -WindowHandle $windowHandle
            $placement = if ($ActionDefinition.placement) { [string]$ActionDefinition.placement } else { 'preserve-relative' }
            $targetRect = Get-MonitorPlacementRect -SourceMonitor $sourceMonitor -TargetMonitor $targetMonitor -WindowRect $windowRect -Placement $placement
            Invoke-WindowMove -WindowHandle $windowHandle -X $targetRect.X -Y $targetRect.Y -Width $targetRect.Width -Height $targetRect.Height

            Write-Host ("[{0}] -> monitor {1} ({2}) using {3} ({4}, {5}, {6}x{7})" -f
                $ActionDefinition.hotkey,
                $targetMonitor.DisplayNumber,
                $targetMonitor.DeviceName,
                $placement,
                $targetRect.X,
                $targetRect.Y,
                $targetRect.Width,
                $targetRect.Height
            )
        }
        default {
            throw "Unsupported action '$($ActionDefinition.action)'."
        }
    }
}

function Show-PresetPreview {
    param(
        [Parameter(Mandatory)] $ActionDefinition,
        [Parameter(Mandatory)] $FancyZonesData
    )

    $windowHandle = [NativeMethods]::GetForegroundWindow()
    if ($windowHandle -eq [System.IntPtr]::Zero) {
        throw 'No foreground window is available for preview.'
    }

    $allMonitors = Get-AllMonitors
    $sourceMonitor = Get-MonitorInfoForWindow -WindowHandle $windowHandle
    $targetMonitor = Resolve-MonitorSelector -MonitorSelector $ActionDefinition.monitor -CurrentMonitor $sourceMonitor -AllMonitors $allMonitors

    Write-Host ("Hotkey: {0}" -f $ActionDefinition.hotkey)
    Write-Host ("Source monitor: {0}" -f $sourceMonitor.DeviceName)
    Write-Host ("Target monitor: {0}" -f $targetMonitor.DeviceName)
    Write-Host ("Action: {0}" -f $ActionDefinition.action)

    switch ($ActionDefinition.action.ToLowerInvariant()) {
        'zone' {
            $target = Get-ZoneRectForAction -FancyZonesData $FancyZonesData -ActionDefinition $ActionDefinition -Monitor $targetMonitor
            Write-Host ("Layout: {0}" -f $target.LayoutName)
            Write-Host ("Zone: {0}" -f $ActionDefinition.zone)
            Write-Host ("Rect: X={0}, Y={1}, Width={2}, Height={3}" -f
                $target.Rect.X,
                $target.Rect.Y,
                $target.Rect.Width,
                $target.Rect.Height
            )
        }
        'monitor' {
            $windowRect = Get-WindowRectObject -WindowHandle $windowHandle
            $placement = if ($ActionDefinition.placement) { [string]$ActionDefinition.placement } else { 'preserve-relative' }
            $targetRect = Get-MonitorPlacementRect -SourceMonitor $sourceMonitor -TargetMonitor $targetMonitor -WindowRect $windowRect -Placement $placement
            Write-Host ("Placement: {0}" -f $placement)
            Write-Host ("Rect: X={0}, Y={1}, Width={2}, Height={3}" -f
                $targetRect.X,
                $targetRect.Y,
                $targetRect.Width,
                $targetRect.Height
            )
        }
        default {
            throw "Unsupported action '$($ActionDefinition.action)'."
        }
    }
}

function Get-Config {
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Warning "Config file not found. Creating a sample at $Path"
        New-SampleConfig -Path $Path
    }

    $rawContent = Get-Content -LiteralPath $Path -Raw
    $config = ConvertFrom-Yaml $rawContent
    
    if (-not $config.presets -or $config.presets.Count -eq 0) {
        throw "No presets were found in $Path"
    }

    $config
}

function Show-Layouts {
    param([Parameter(Mandatory)] $FancyZonesData)

    Write-Host 'Custom FancyZones layouts:'
    foreach ($layout in $FancyZonesData.CustomLayouts) {
        $zoneCount = if ($layout.type -eq 'canvas') {
            $layout.info.zones.Count
        }
        else {
            (($layout.info.'cell-child-map' | ForEach-Object { $_ }) | Measure-Object -Maximum).Maximum + 1
        }

        Write-Host ("- {0} | {1} | {2} zones | {3}" -f $layout.name, $layout.type, $zoneCount, $layout.uuid)
    }

    Write-Host ''
    Write-Host 'Applied custom layouts by monitor-number:'
    foreach ($entry in ($FancyZonesData.AppliedLayouts | Where-Object { $_.'applied-layout'.type -eq 'custom' })) {
        $layout = $FancyZonesData.CustomLayouts | Where-Object { $_.uuid -eq $entry.'applied-layout'.uuid } | Select-Object -First 1
        $layoutName = if ($layout) { $layout.name } else { $entry.'applied-layout'.uuid }
        Write-Host ("- monitor {0} ({1}) -> {2}" -f
            $entry.device.'monitor-number',
            $entry.device.monitor,
            $layoutName
        )
    }
}

function Show-Monitors {
    param([Parameter(Mandatory)] $FancyZonesData)

    $allMonitors = Get-AllMonitors | Sort-Object @{ Expression = { if ($null -ne $_.DisplayNumber) { $_.DisplayNumber } else { 9999 } } }, DeviceName

    Write-Host 'Detected monitors:'
    foreach ($monitor in $allMonitors) {
        $appliedEntry = $FancyZonesData.AppliedLayouts |
            Where-Object {
                $_.device.'monitor-number' -eq $monitor.DisplayNumber -and
                $_.'applied-layout'.type -eq 'custom'
            } |
            Select-Object -Last 1

        $appliedLayoutName = ''
        if ($appliedEntry) {
            $layout = $FancyZonesData.CustomLayouts | Where-Object { $_.uuid -eq $appliedEntry.'applied-layout'.uuid } | Select-Object -First 1
            $appliedLayoutName = if ($layout) { $layout.name } else { $appliedEntry.'applied-layout'.uuid }
        }

        Write-Host ("- display {0} | {1} | primary={2} | workarea=({3}, {4}, {5}x{6}){7}" -f
            $monitor.DisplayNumber,
            $monitor.DeviceName,
            $monitor.IsPrimary,
            $monitor.WorkLeft,
            $monitor.WorkTop,
            $monitor.WorkWidth,
            $monitor.WorkHeight,
            $(if ($appliedLayoutName) { " | applied custom layout=$appliedLayoutName" } else { '' })
        )
    }
}

function Test-Config {
    param(
        [Parameter(Mandatory)] $Config,
        [Parameter(Mandatory)] $TargetMap
    )

    foreach ($preset in $Config.presets) {
        if (-not $preset.hotkey) {
            throw 'Each preset must define hotkey.'
        }

        [void](Get-HotkeyDefinition -Hotkey $preset.hotkey)

        $actionDefinition = Resolve-ActionDefinition -Preset $preset -TargetMap $TargetMap

        switch ($actionDefinition.action.ToLowerInvariant()) {
            'zone' {
                if (-not $actionDefinition.zone) {
                    throw "Preset '$($preset.hotkey)' must define zone for a zone action."
                }
            }
            'monitor' {
                if (-not $actionDefinition.monitor) {
                    throw "Preset '$($preset.hotkey)' must define monitor for a monitor action."
                }
            }
            default {
                throw "Preset '$($preset.hotkey)' uses unsupported action '$($actionDefinition.action)'."
            }
        }
    }
}

$config = Get-Config -Path $ConfigPath
$targetMap = Get-TargetMap -Config $Config
Test-Config -Config $Config -TargetMap $targetMap

if ($ValidateConfig) {
    Write-Host "Config is valid: $ConfigPath"
    exit 0
}

$initialFancyZonesData = Get-FancyZonesData

if ($ListLayouts) {
    Show-Layouts -FancyZonesData $initialFancyZonesData
    exit 0
}

if ($ListMonitors) {
    Show-Monitors -FancyZonesData $initialFancyZonesData
    exit 0
}

if ($PreviewHotkey) {
    $preset = $Config.presets | Where-Object { $_.hotkey -eq $PreviewHotkey } | Select-Object -First 1
    if (-not $preset) {
        throw "No preset found for hotkey '$PreviewHotkey'."
    }

    $actionDefinition = Resolve-ActionDefinition -Preset $preset -TargetMap $targetMap
    Show-PresetPreview -ActionDefinition $actionDefinition -FancyZonesData $initialFancyZonesData
    exit 0
}

$window = New-Object HotkeyWindow
$window.CreateControl()

$script:registeredHotkeys = New-Object System.Collections.Generic.List[int]
$script:presetMap = @{}
$script:targetMap = $targetMap
$script:config = $config

function Register-AllHotkeys {
    # Unregister existing
    foreach ($id in $script:registeredHotkeys) {
        [NativeMethods]::UnregisterHotKey($window.Handle, $id) | Out-Null
    }
    $script:registeredHotkeys.Clear()
    $script:presetMap.Clear()

    $nextId = 1
    foreach ($preset in $script:config.presets) {
        $definition = Get-HotkeyDefinition -Hotkey $preset.hotkey
        $registered = [NativeMethods]::RegisterHotKey(
            $window.Handle,
            $nextId,
            $definition.Modifiers,
            $definition.VirtualKey
        )

        if (-not $registered) {
            Write-Warning "Failed to register hotkey '$($preset.hotkey)'. Another app may already be using it."
        } else {
            $script:registeredHotkeys.Add($nextId) | Out-Null
            $script:presetMap[$nextId] = $preset
        }
        $nextId++
    }
}

function Reload-Settings {
    try {
        $newConfig = Get-Config -Path $ConfigPath
        $newTargetMap = Get-TargetMap -Config $newConfig
        Test-Config -Config $newConfig -TargetMap $newTargetMap
        
        $script:config = $newConfig
        $script:targetMap = $newTargetMap
        
        Register-AllHotkeys
        $notifyIcon.ShowBalloonTip(3000, "FancyZonesHotkeys", "?ㅼ젙???깃났?곸쑝濡?媛깆떊?섏뿀?듬땲??", [System.Windows.Forms.ToolTipIcon]::Info)
    } catch {
        $notifyIcon.ShowBalloonTip(5000, "FancyZonesHotkeys ?ㅻ쪟", "?ㅼ젙 媛깆떊 ?ㅽ뙣: $_", [System.Windows.Forms.ToolTipIcon]::Error)
    }
}

$window.add_HotkeyPressed({
    param($id)

    try {
        $currentFancyZonesData = Get-FancyZonesData
        $actionDefinition = Resolve-ActionDefinition -Preset $script:presetMap[$id] -TargetMap $script:targetMap
        Invoke-ActionDefinition -ActionDefinition $actionDefinition -FancyZonesData $currentFancyZonesData | Out-Null
    }
    catch {
        # Suppress errors to prevent message boxes during background hotkey presses
    }
})

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$notifyIcon.Text = "FancyZonesHotkeys"
$notifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$menuOpen = $contextMenu.Items.Add("?ㅼ젙 ?뚯씪 ?닿린")
$menuOpen.add_Click({
    Start-Process -FilePath $ConfigPath
})

$menuReload = $contextMenu.Items.Add("?ㅼ젙 ?ㅼ떆 遺덈윭?ㅺ린")
$menuReload.add_Click({
    Reload-Settings
})

$contextMenu.Items.Add("-") | Out-Null

$menuExit = $contextMenu.Items.Add("醫낅즺")
$menuExit.add_Click({
    [System.Windows.Forms.Application]::Exit()
})

$notifyIcon.ContextMenuStrip = $contextMenu

$notifyIcon.add_DoubleClick({
    Start-Process -FilePath $ConfigPath
})

try {
    Register-AllHotkeys
    
    Write-Host 'FancyZones hotkey bridge is running with System Tray.'
    Write-Host "Config: $ConfigPath"
    
    [System.Windows.Forms.Application]::Run()
}
finally {
    foreach ($id in $script:registeredHotkeys) {
        [NativeMethods]::UnregisterHotKey($window.Handle, $id) | Out-Null
    }
    
    if ($notifyIcon) {
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
    }
    if ($window) {
        $window.Dispose()
    }
}
