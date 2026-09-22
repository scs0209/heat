# heat

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-black.svg)](#요구-사항)

macOS 메뉴바 앱 — 노트북이 **왜 뜨거운지 / 팬이 왜 도는지**, 메뉴바만 보고도 감이 오고 클릭하면 원인이 보입니다.

> Ad-hoc 서명 OSS입니다. 유료 Apple Developer / notarize 없이 본인 Mac에서 빌드·실행할 수 있습니다.

## 기능

- 메뉴바: 온도(°C) 또는 열 상태, 급증 시 `↑`, SF Symbol 온도계
- 팝오버 상단: **전체 메모리 사용량** (사용 / 전체 · %)
- **CPU / 메모리** 탭, 스크롤 가능한 프로세스 목록
- 프로세스별 CPU% · RSS 메모리 · 전체 대비 점유율
- **종료**로 원인 프로세스 kill (확인 후 SIGTERM)
- 상세 센서(온도·팬): 첫 실행 때 관리자 권한 1회 (거부해도 앱은 동작)

## 요구 사항

- macOS 14+
- Apple Silicon 또는 Intel Mac
- 로컬 빌드: Xcode Command Line Tools (`swiftc`, `xcrun`)

## 설치 (Release zip)

1. [Releases](https://github.com/scs0209/heat/releases)에서 `Heat-macos.zip` 다운로드
2. 압축 해제 후 `Heat.app`을 `/Applications`로 이동
3. Gatekeeper가 막을 수 있습니다:

```bash
xattr -dr com.apple.quarantine /Applications/Heat.app
```

또는 Finder에서 `Heat.app` → 우클릭 → **열기**.

4. (선택) 상세 온도·팬을 쓰려면 첫 실행 시트에서 **Enable** → 관리자 암호 1회

## 로컬 빌드

```bash
git clone https://github.com/scs0209/heat.git
cd heat
./scripts/build-app.sh
open dist/Heat.app
```

산출물:

| 경로 | 설명 |
|------|------|
| `dist/Heat.app` | ad-hoc 서명 앱 |
| `dist/Heat-macos.zip` | 배포용 zip |

## 권한 모델

| 데이터 | 권한 |
|--------|------|
| `ProcessInfo.thermalState` | 불필요 |
| top CPU / 메모리 (`ps`) | 불필요 |
| 시스템 메모리 (`host_statistics64`) | 불필요 |
| CPU 온도 · 팬 RPM (`powermetrics`) | 관리자 1회 → LaunchDaemon |

상세 센서 설치 위치:

- `/usr/local/libexec/heat-sampler`
- `/Library/LaunchDaemons/dev.heat.sampler.plist`
- 샘플: `/Users/Shared/heat/sensors.json`

제거:

```bash
sudo launchctl bootout system/dev.heat.sampler 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/dev.heat.sampler.plist /usr/local/libexec/heat-sampler
rm -rf /Users/Shared/heat
```

## 프로젝트 구조

```
heat/
  Sources/Heat/     # 메뉴바 앱 (AppKit + SwiftUI)
  helper/           # privileged heat-sampler
  Resources/        # Info.plist, LaunchDaemon plist
  scripts/          # build-app.sh (ad-hoc codesign + zip)
```

## 기여

PR과 이슈를 환영합니다. 자세한 내용은 [CONTRIBUTING.md](CONTRIBUTING.md)를 읽어 주세요.

이 프로젝트는 [Contributor Covenant](CODE_OF_CONDUCT.md)를 따릅니다.

## 비범위 (아직)

- Developer ID / notarize
- Homebrew cask 자동화
- GPU 상세, 알림 규칙, 히스토리 차트

## 라이선스

[MIT](LICENSE)
