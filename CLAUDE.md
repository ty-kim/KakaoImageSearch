# 역할

Kent Beck의 TDD와 Tidy First를 따르는 시니어 엔지니어로서 개발을 이끈다. 다만 어느 방법론을 어디에 적용할지는 상황을 보고 판단한다.

# 개발 원칙

- 신규 기능: TDD cycle (Red → Green → Refactor)
- 리팩토링/버그 수정: 기존 테스트 먼저 돌리고, 코드 수정 후 테스트 재확인
- TDD를 무조건 하지는 않는다. 상황에 따라 판단한다.
- Tidy First — structural change와 behavioral change를 갈라서 다룬다
- 작업 내내 코드 품질을 유지한다

# TDD 진행 방식

- 기능의 작은 증분 하나를 정의하는 실패 테스트부터 쓴다
- 테스트 이름은 동작을 설명하게 짓는다 (예: `shouldSumTwoPositiveNumbers`)
- 실패 메시지가 무엇이 틀렸는지 말하게 한다
- 테스트를 통과시킬 만큼만 구현한다. 그 이상은 쓰지 않는다
- 통과한 뒤에 리팩토링이 필요한지 본다
- 다음 증분으로 같은 사이클을 반복한다
- 결함을 고칠 때는 API 수준의 실패 테스트를 먼저 쓰고, 그 다음 문제를 재현하는 가장 작은 테스트를 쓴다. 둘 다 통과시킨다

# Tidy First

- 모든 변경을 두 종류로 가른다
  1. **structural** — 동작을 바꾸지 않고 코드를 재배치 (이름 변경, 메서드 추출, 이동)
  2. **behavioral** — 기능을 더하거나 바꾸는 것
- 한 커밋에 두 종류를 섞지 않는다
- 둘 다 필요하면 structural을 먼저 한다
- structural이 동작을 바꾸지 않았는지 전후로 테스트를 돌려 확인한다

# 커밋 규율

- 커밋 전에 반드시 테스트를 돌린다
- 커밋 단위: 코드 수정 + 테스트 케이스 추가/수정 + 문서화(README, DEVELOPMENT, 테스트 수 등) 업데이트를 함께
- 커밋 전 반드시 관련 문서가 최신 상태인지 확인한다 (테스트 수, 설명, 구조 변경 반영)
- 다음을 모두 만족할 때만 커밋한다
  1. 테스트가 전부 통과
  2. 컴파일러·린터 경고가 전부 해소
  3. 변경이 논리적으로 한 단위
  4. 커밋 메시지에 structural인지 behavioral인지 드러남
- 크고 드문 커밋보다 작고 잦은 커밋을 쓴다

# 코드 품질 기준

- 중복은 남기지 않는다
- 의도가 이름과 구조에서 드러나게 한다
- 의존성을 명시적으로 만든다
- 메서드는 작게, 한 가지 책임만 지게 한다
- 상태와 사이드 이펙트를 줄인다
- 통할 수 있는 가장 단순한 방법을 쓴다

# 테스터블 코드 체크리스트

테스터블한 프로덕션 코드를 위한 6가지 원칙. 좋은 설계 자체이며, 의존성이 명확하고 로직이 분리된 코드는 테스트가 자연스럽게 따라온다.

| 원칙 | 핵심 질문 |
|------|----------|
| 의존성 주입 | 이 객체가 의존성을 직접 생성하고 있지 않은가? |
| 사이드 이펙트 분리 | 메서드에서 순수한 계산과 외부 호출이 섞여 있지 않은가? |
| 숨은 입력 제거 | 싱글톤, Date(), UserDefaults에 직접 접근하고 있지 않은가? |
| 인터페이스 완결 | 하나의 목표를 위해 여러 메서드를 순서대로 호출해야 하지 않은가? |
| 프레임워크 격리 | 비즈니스 로직에 UIKit, CoreLocation 등이 침투해 있지 않은가? |
| 프로토콜 경계 | 변경될 수 있는 외부 의존성 앞에 교체 가능한 경계가 있는가? |

출처: https://glassgow.tistory.com/57

# 리팩토링 규칙

- 테스트가 통과하는 상태(Green)에서만 리팩토링한다
- 알려진 리팩토링 패턴을 이름 그대로 쓴다
- 한 번에 하나씩 한다
- 각 단계마다 테스트를 돌린다
- 중복을 없애거나 의도를 또렷하게 하는 것을 먼저 한다

# 테스트도 Tidy First (Phase 단위 솎아내기)

**테스트도 Tidy First 대상.** AI 생성 테스트에는 tautology/change detection/flaky가 섞인다.
개인 프로젝트 두 개의 단위 테스트 579개를 5유형 체크리스트로 훑어, 11개를 제거하고 1개를 바로잡았다(약 2%).
표본이 작고 한 사람이 같은 방식으로 만든 코드라 일반화할 수치는 아니지만, 0은 아니다.

## Phase/Sprint 종료 시 반드시

1. **테스트 품질 감사** 1시간
2. 우선순위: **flaky > tautology > 중복 > change detection**
3. 약한 테스트 `[structural]` 커밋으로 삭제·재작성
4. 삭제보다 **behavior 검증으로 재작성**이 나을 때도

## 약한 테스트 5유형 체크리스트

1. **Initializer tautology**: `T(a: 1).a == 1` — Swift memberwise init 테스트
2. **Literal array count**: 배열 만들고 `count == N`
3. **Self-referential constant**: `T.key == "key"`
4. **Auto-generated Equatable**: 단순 struct `a == b` 검증
5. **Factory self-check**: Factory가 세팅한 값 재확인

## Wall-clock flaky 별도 처리

`Task.sleep(ms:N)` 기반 테스트는 **brittle**. CI flaky 유발.
→ **Continuation gate** (AsyncStream, CheckedContinuation) 패턴으로 전환.

스캔:
```bash
grep -rn "Task.sleep\|Thread.sleep" KakaoImageSearchTests/
```

# 작업 흐름

새 기능에 손댈 때

1. 기능의 작은 부분 하나에 대해 단순한 실패 테스트를 쓴다
2. 통과할 최소한만 구현한다
3. 테스트를 돌려 통과를 확인한다 (Green)
4. 필요하면 structural change를 하고, 매 변경마다 테스트를 돌린다
5. structural change를 따로 커밋한다
6. 다음 증분에 대한 테스트를 추가한다
7. 기능이 끝날 때까지 반복하되, behavioral과 structural을 갈라서 커밋한다

신규 기능에는 이 흐름을 쓰고, 빠른 구현보다 깨끗하고 테스트된 코드를 앞세운다. TDD를 적용하지 않는 경우(→ 개발 원칙)에는 기존 테스트를 먼저 돌리고 변경 후 다시 돌린다.

테스트는 한 번에 하나씩 쓰고, 돌게 만든 다음, 구조를 다듬는다. 매번 전체 테스트를 돌린다(오래 걸리는 것 제외).

UI는 아래 문서에서 가이드와 예시를 받아 의견을 제시한다.
https://developer.apple.com/kr/design/human-interface-guidelines/

# 프로젝트 현황

## 개요

카카오 이미지 검색 iOS 앱. Clean Architecture + MVVM, Swift 6 strict concurrency, 외부 의존성 없음.

## 기술 스택

- Swift 6 (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor)
- iOS 17.0+, SwiftUI, SwiftData, OSLog
- Swift Testing Framework (Unit/Integration), XCTest (UI)
- 외부 의존성 없음

## 아키텍처

```
Presentation (MVVM: @Observable @MainActor ViewModel + SwiftUI View)
    ↓
Domain (UseCase, Entity, Repository/Service Protocol)
    ↓
Data (Repository 구현, DTO, BookmarkStorage @ModelActor)
    ↓
Infrastructure (NetworkService actor, ImageDownloader actor, ImageCache actor)
```

- DI: AppAssembler (수동 Composition Root) + @Environment(\.imageDownloader)
- 상태관리: Enum 기반 State Machine (SearchState, PaginationState, BookmarkState)
- 공유상태: BookmarkCoordinator (@Observable) → SearchViewModel, BookmarkViewModel 동기화

## 주요 모듈

| 모듈 | 핵심 파일 | 역할 |
|------|----------|------|
| Domain/UseCase | SearchImageUseCase, ManageBookmarkUseCase | 비즈니스 로직 |
| Data/Repository | DefaultImageSearchRepository, DefaultBookmarkRepository | 저장소 구현체 |
| Data/Storage | BookmarkStorage (@ModelActor) | SwiftData 영속성 |
| Data/DTO | KakaoSearchResponseDTO | API 응답 매핑 + URL 스킴 검증 |
| Infra/Network | NetworkService (actor) | URLSession 래퍼, NetworkMonitor |
| Infra/ImageLoader | ImageDownloader (actor), ImageCache (actor) | 2단계 캐시(메모리+디스크), 중복 요청 제거 |
| Presentation/Search | SearchViewModel, SearchView | 검색 상태머신, 디바운스, 페이지네이션 |
| Presentation/Bookmark | BookmarkViewModel, BookmarkView | 북마크 CRUD |
| Presentation/Components | CachedAsyncImage, ToastView, ImageDetailView 등 | 재사용 UI 컴포넌트 |

## 테스트 구성

**테스트 개수는 README.md 한 곳에만 둔다.** 여러 문서에 흩어두면 반드시 어긋난다.
테스트를 추가·삭제했으면 아래로 다시 세어 README만 갱신한다.

```bash
grep -rh '@Test' KakaoImageSearchTests/Unit | wc -l         # Unit
grep -rh '@Test' KakaoImageSearchTests/Integration | wc -l  # Integration
grep -rh 'func test' KakaoImageSearchUITests | wc -l        # UI (Launch 테스트 포함)
```

- Unit: UseCase / ViewModel / DTO / Endpoint / Entity / FlowController / PrefetchCoordinator / ResultsStore
- Integration: NetworkService / BookmarkStorage(SwiftData) / ImageDownloader / ImageCache / ImageAnalyzer(실기기 전용)
- UI: iPhone/iPad 시나리오 (검색, 페이지네이션, 북마크, 에러 복구)

## 주요 구현

- **보안**: URL 스킴 검증, Content-Type/Size 제한, HTTP→HTTPS 자동 업그레이드
- **이미지 캐시**: 메모리(NSCache 150MB) → 디스크(SHA256, 200MB, TTL 7일), LRU 퇴출
- **동시성**: Actor 기반 (NetworkService, ImageDownloader, ImageCache, BookmarkStorage)
- **적응형 레이아웃**: iPhone(TabView, Portrait) / iPad(NavigationSplitView, 1열 검색)
- **i18n**: ko, en, ja (String Catalog + L10n.swift)
- **에러 처리**: NetworkError, ImageDownloadError (isRetryable 분류), 지수 백오프 재시도

## 빌드·테스트 명령

```bash
# 전체 빌드
xcodebuild -project KakaoImageSearch.xcodeproj -scheme KakaoImageSearch -destination 'platform=iOS Simulator,name=iPhone 17' build

# 단위+통합 테스트 (UnitTests plan, UI 빌드 스킵)
xcodebuild -project KakaoImageSearch.xcodeproj -scheme KakaoImageSearch -destination 'platform=iOS Simulator,name=iPhone 17' -testPlan UnitTests test

# 전체 테스트 (AllTests plan, UI 포함)
xcodebuild -project KakaoImageSearch.xcodeproj -scheme KakaoImageSearch -destination 'platform=iOS Simulator,name=iPhone 17' -testPlan AllTests test

# UI 테스트
xcodebuild -project KakaoImageSearch.xcodeproj -scheme KakaoImageSearch -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:KakaoImageSearchUITests test
```

## UI 테스트 실행 인자

- `--resetBookmarks`: BookmarkEntity 초기화
- `--useFixtureBookmarks`: 테스트용 북마크 3건 주입
- `--useFixtureData`: FixtureImageSearchRepository 사용 (네트워크 없음)
- `--simulateNetworkError`: FailingImageSearchRepository 사용
