# FancyZones Hotkey Bridge

Windows의 Microsoft PowerToys FancyZones를 위한 모니터 인식 단축키 브리지입니다.

이 유틸리티는 독립적인 도구이며 공식적인 Microsoft 또는 Windows 애플리케이션이 아닙니다.

`Alt+1`, `Alt+2`, `Ctrl+Alt+1`, `Alt+Shift+Right`와 같은 익숙한 단축키를 사용하여 각 모니터가 다른 FancyZones 레이아웃을 사용하고 있더라도 현재 활성 창을 대상 모니터의 올바른 영역으로 이동시킬 수 있습니다.

> 추천 대상: 2대 이상의 모니터를 사용하고 이미 FancyZones를 활용하고 있는 Windows 파워 유저, 개발자, 트레이더 등 멀티태스킹이 잦은 사용자.

## 개발 배경

FancyZones는 레이아웃 설정에 매우 유용하지만, 많은 사용자가 다음과 같은 동작을 위한 직접적인 단축키를 원합니다:

- 현재 창을 활성 모니터의 1번 영역으로 보내기
- 상대적 위치를 유지하면서 창을 다음 모니터로 이동하기
- "메인 모니터 중앙"과 같이 지정된 목적지로 창 보내기

이 브리지는 사용자의 FancyZones 커스텀 레이아웃 파일을 읽어 대상 영역의 좌표를 계산하고 전경(foreground) 창을 해당 위치로 이동시킵니다.

## 주요 기능

- 글로벌 Windows 단축키 등록.
- `%LocalAppData%\Microsoft\PowerToys\FancyZones`에서 FancyZones 레이아웃 읽기.
- 각 모니터별로 다른 레이아웃 지원.
- FancyZones 커스텀 `grid` 및 `canvas` 레이아웃 지원.
- 특정 모니터에 현재 적용된 커스텀 레이아웃을 따르도록 `@applied` 지원.
- 모니터 인식 작업 지원:
  - `1`, `2`, `3` 등 특정 영역으로 이동
  - 다음 또는 이전 모니터로 이동
  - 특정 모니터 번호로 이동
  - 원하는 단축키를 재사용 가능한 지정 목적지에 매핑

## 4단계 설치 방법

1. Microsoft PowerToys를 설치하고 모니터에 맞게 FancyZones 커스텀 레이아웃을 설정합니다.
2. 최신 릴리스 ZIP 파일을 다운로드합니다. **압축을 풀기 전에** `.zip` 파일을 마우스 오른쪽 버튼으로 클릭하고 **속성**을 선택한 뒤, 하단의 **차단 해제(Unblock)**를 선택하고 적용을 클릭합니다. (이렇게 해야 Windows가 내부 스크립트 실행을 차단하지 않습니다).
3. 원하는 곳에 ZIP 압축을 풀고 `presets.yaml`을 편집하여 단축키를 구성합니다.
4. `FancyZonesHotkeys.exe` (또는 `Run-FancyZonesHotkeys_kor.bat`)를 실행한 뒤, 창을 선택하고 단축키를 누릅니다.

> **Windows SmartScreen 참고**: 이 유틸리티는 값비싼 인증서로 디지털 서명되지 않았기 때문에, 처음 실행 시 파란색 "Windows의 PC 보호" 화면이 나타날 수 있습니다. **추가 정보**를 클릭한 후 **실행**을 누르세요.

작업 관리자나 관리자 권한 터미널 등 관리자 권한으로 실행 중인 앱을 이동하려면 이 브리지 역시 관리자 권한으로 실행해야 합니다.

## 릴리스 ZIP 구조

이 프로젝트의 배포 형식은 다음과 같은 파일들이 포함된 포터블 ZIP입니다:

- `FancyZonesHotkeys.exe`
- `FancyZonesHotkeys.ps1`
- `Run-FancyZonesHotkeys_kor.bat`
- `presets.yaml`
- `README_kor.md`
- `QUICKSTART_kor.txt`
- `Register-Startup_kor.bat`
- `Unregister-Startup_kor.bat`

설치 및 사용 흐름:

1. ZIP 다운로드
2. ZIP 압축 해제
3. `presets.yaml` 편집
4. `Run-FancyZonesHotkeys_kor.bat` 더블 클릭

## 설정 예시

`presets.yaml`에는 두 가지 섹션이 있습니다:

- `targets`: 재사용 가능한 목적지 지정
- `presets`: 직접 작업을 정의하거나 대상(target)을 참조하는 단축키 목록

```yaml
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
  - hotkey: "Ctrl+Alt+1"
    target: "left-main"
```

## 액션 가이드

### 영역 (zone) 액션

현재 활성화된 창을 특정 FancyZones 영역으로 보낼 때 사용합니다.

- `action`: `zone`
- `monitor`: 창을 받을 모니터 지정
- `layout`: `@applied`, FancyZones 레이아웃 이름, 또는 FancyZones 레이아웃 UUID
- `zone`: 해당 레이아웃 내의 1부터 시작하는 영역 번호

### 모니터 (monitor) 액션

영역 상관없이 현재 활성 창을 다른 모니터로만 이동시키고자 할 때 사용합니다.

- `action`: `monitor`
- `monitor`: 창을 받을 모니터 지정
- `placement`: 대상 모니터에 창을 배치할 방식

지원되는 `placement` 값:

- `preserve-relative` (상대적 위치 및 비율 유지)
- `preserve-size` (창 크기 유지)
- `center` (중앙)
- `maximize` (최대화)
- `top-left` (좌측 상단)

### 모니터 선택 (monitor)

`monitor` 옵션에 사용할 수 있는 값:

- `active` 또는 `current` (현재 활성 모니터)
- `primary` (주 모니터)
- `next` (다음 모니터)
- `previous` (이전 모니터)
- 디스플레이 번호 (예: `1`, `2`, `3`)
- 장치 이름 (예: `\\.\DISPLAY2`)

## 유용한 명령어

명령 프롬프트나 터미널에서 다음 명령어로 정보를 조회할 수 있습니다.

FancyZones에서 현재 사용 가능한 커스텀 레이아웃 조회:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -Language ko -ListLayouts
```

현재 감지된 모니터 및 각 모니터에 적용된 커스텀 레이아웃 조회:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -Language ko -ListMonitors
```

단축키 루프를 시작하지 않고 설정 파일만 검증:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -Language ko -ValidateConfig
```

특정 프리셋(단축키)이 창을 어디로 보낼지 미리 보기:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\FancyZonesHotkeys.ps1 -Language ko -PreviewHotkey Alt+1
```

## 권장 워크플로우

- 각 모니터에 고유한 FancyZones 커스텀 레이아웃을 할당하세요.
- 활성 모니터 내 영역 이동에는 `Alt+1`, `Alt+2`, `Alt+3`을 사용하세요.
- 모니터 간 이동에는 `Alt+Shift+Left` 및 `Alt+Shift+Right`를 사용하세요.
- "메인 모니터 중앙" 또는 "오른쪽 모니터 좌측 상단 사각형"과 같은 절대 목적지에는 `targets`를 활용하세요.

## 현재의 한계

- `@applied`는 현재 커스텀 FancyZones 레이아웃만 인식합니다.
- `priority-grid`와 같은 기본 내장 레이아웃은 아직 지원되지 않습니다. (PowerToys가 이러한 기본 레이아웃의 영역 정보를 같은 방식으로 노출하지 않기 때문입니다.)
