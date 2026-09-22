# Contributing to heat

heat에 기여해 주셔서 감사합니다. 작은 문서 수정부터 기능 PR까지 모두 환영합니다.

## 행동 강령

참여 전에 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)를 읽어 주세요.

## 개발 환경

- macOS 14+
- Xcode Command Line Tools (`xcode-select --install`)
- Git

빌드:

```bash
./scripts/build-app.sh
open dist/Heat.app
```

`dist/`는 git에 올리지 않습니다.

## 이슈

버그·기능 제안은 GitHub Issues에 올려 주세요.

버그 리포트에 가능하면 포함해 주세요:

- macOS 버전 / 칩 (Apple Silicon / Intel)
- heat 버전 또는 커밋
- 재현 단계
- 기대 동작 vs 실제 동작
- (센서 관련) 관리자 sampler 허용 여부

보안 이슈는 공개 이슈 대신 maintainer에게 비공개로 연락해 주세요.

## Pull Request 흐름

`main`에는 **직접 push하지 않습니다.** PR을 통해서만 반영합니다.

1. 최신 `main`에서 브랜치 생성  
   `git checkout -b fix/short-description`
2. 변경 + 로컬 빌드·실행으로 확인
3. PR 열기 (무엇을 / 왜 바꿨는지 짧게)
4. 리뷰 반영 후 merge

### 커밋 메시지

한국어를 권장합니다.

```
prefix: 짧은 제목

- 변경 이유 / 내용 불릿
```

prefix 예: `feat`, `fix`, `update`, `refactor`, `docs`, `chore`, `style`

### PR 체크리스트

- [ ] `./scripts/build-app.sh` 성공
- [ ] 메뉴바·팝오버 기본 동작 확인
- [ ] 권한/LaunchDaemon 관련이면 README 권한 절도 갱신
- [ ] 비밀키·로컬 경로·`dist/` 미포함

## 코드 가이드

- 메뉴바 UX는 단순하게: 한눈에 열·메모리, 클릭하면 원인과 종료
- SwiftUI `List`/`ScrollView` 기본 여백에 의존하지 말고, 목록은 기존 AppKit `TopPinnedScroll` 패턴을 유지
- privileged helper(`heat-sampler`) 변경 시 권한·제거 절차를 README와 맞출 것
- 시스템 보호 프로세스 종료는 계속 막혀 있어야 함 (`ProcessActions`)

## 라이선스

기여분은 프로젝트와 동일한 [MIT License](LICENSE)로 라이선스됩니다.
