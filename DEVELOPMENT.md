# 개발 방향 및 AI 활용 범위

---

## 개발 방향

### 1. "외부 라이브러리 없음"을 역량 어필의 기회로

과제 조건인 "외부 라이브러리 금지"를 제약이 아닌 어필 포인트로 삼았습니다.
Kingfisher, Alamofire 없이 직접 구현함으로써 각 라이브러리가 내부에서 해결하는 문제들을 직접 다뤘습니다.

| 직접 구현한 것 | 대체되는 라이브러리 |
|---|---|
| URLSession Generic 래퍼 + snake_case 변환 | Alamofire / Moya |
| 메모리 + 디스크 2단계 이미지 캐시 + in-flight dedup | Kingfisher / SDWebImage |
| Composition Root 기반 생성자 주입 (AppAssembler) | Swinject |

### 2. Swift 6 Strict Concurrency 정면 돌파

Swift 6의 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`를 활성화해 컴파일 타임에 데이터 레이스를 차단했습니다.
경고를 억제하는 `@preconcurrency` 우회 대신, `actor` / `nonisolated` / `nonisolated init(from:)` 으로 근본 원인을 해결했습니다.
예를 들어 `NetworkError`의 `@preconcurrency LocalizedError` 우회는 `@MainActor` 제거 + `L10n` 전체를 `nonisolated` 선언하는 방식으로 정공법 해결했습니다.
이 과정에서 발생한 문제들(DTO 런타임 크래시, Logger 격리 문제, DI 팩토리 타입 오류 등)을 하나씩 디버깅하며 Swift Concurrency 모델을 깊이 있게 다뤘습니다.

### 3. 시니어 역량 어필: 다국어 + 테스트 + 상태 설계

단순 기능 구현을 넘어 프로덕션 수준의 코드를 목표로 했습니다.

- **다국어(ko / en / ja)**: `.xcstrings` String Catalog + 타입 세이프 `L10n` 헬퍼
- **유닛 테스트**: Swift Testing Framework, 60개 케이스, Domain + ViewModel 커버리지 100%
- **UI 테스트**: XCUITest, 25개 케이스, 실제 사용자 플로우 검증 (iPhone + iPad)
- **OSLog**: 카테고리별 로거, `OS_ACTIVITY_MODE=disable` 환경 대응
- **BookmarkStore**: 단일 진실 공급원 패턴으로 탭 간 북마크 상태 동기화 보장

### 4. iPad 적응형 레이아웃

과제 조건에 "iPad 레이아웃 변경 가능"으로 명시된 부분을 적극 활용했습니다.

- **분기 기준**: `@Environment(\.horizontalSizeClass)` — iPhone(compact) / iPad(regular) 분리
- **iPhone**: 기존 `TabView` 구조 그대로 유지
- **iPad**: `NavigationSplitView`로 검색 결과(사이드바)와 북마크(디테일)를 동시 표시
  - 단일 화면에서 검색과 북마크를 한눈에 볼 수 있어 콘텐츠 탐색 효율 향상
- **그리드**: `LazyVGrid` 2열, 좌우 패딩 20pt, 컬럼 간격 20pt
  - `itemWidth = (전체 너비 - 패딩 × 2 - 컬럼 간격) / 열 수` 로 정확히 계산
- **iPad UI 테스트**: `setUpWithError` + `XCTSkipIf(!isIPad)`로 클래스 단위에서 iPad 시뮬레이터 전용 실행

### 5. 페이지네이션 & 에러 핸들링 UX

API의 기능을 최대한 활용하고, 사용자에게 명확한 피드백을 제공하는 데 집중했습니다.

- **무한 스크롤**: `LazyVGrid` 마지막 아이템 `.onAppear` 트리거, `isEnd` 플래그로 완료 판별
- **재시도 UX**: 검색 실패 / 추가 로드 실패를 구분하여 각 위치에 맞는 재시도 버튼 제공
- **에러 vs 결과없음 구분**: `hasError` / `errorMessage` 플래그 분리로 UX 분기 명확화
- **Toast 피드백**: 북마크 토글 실패처럼 콘텐츠를 유지해야 하는 일시적 에러는 `toastMessage`로 분리, 하단 Toast로 표시 후 3초 자동 소멸

이 패턴은 웹툰/콘텐츠 앱의 핵심 흐름(작품 목록 무한 스크롤 → 북마크/찜 → 에러 복구)과 구조적으로 동일합니다.

### 6. RxSwift 대신 Swift Concurrency

과제 조건(Zero External Dependency)으로 RxSwift/RxCocoa를 사용하지 않았습니다.
대신 Swift Concurrency로 동일한 반응형 데이터 흐름을 구현했습니다.

| RxSwift 패턴 | 이번 구현 |
|---|---|
| `PublishSubject` + `debounce` | `Task.sleep(1.0)` + `Task.cancel()` |
| `BehaviorRelay` / `Driver` | `@Observable` + `@MainActor` |
| `DisposeBag` | `Task` 명시적 취소 (`searchTask?.cancel()`) |
| `flatMapLatest` | `searchTask` 재생성 + `activeSearchID` stale 결과 무시로 이전 요청 취소 |

Swift Concurrency는 컴파일 타임 데이터 레이스 감지라는 RxSwift에 없는 안전성을 제공합니다.

---

## AI 활용 범위

이 프로젝트는 **Claude(Anthropic)** 를 페어 프로그래머로 활용해 개발했습니다.
AI 활용 자체를 숨기기보다, 어떤 판단을 직접 내렸는지를 투명하게 기술합니다.

### AI가 도운 것

| 영역 | 내용 |
|---|---|
| **보일러플레이트 작성** | DTO `nonisolated init(from:)`, Repository 구현체, Mock 클래스 등 반복적인 코드 |
| **Swift 6 오류 메시지 해석** | 컴파일러 에러 원인 분석 및 수정 방향 제시 |
| **테스트 케이스 초안** | 테스트 구조와 케이스 목록 초안 생성 |
| **커밋 메시지 작성** | Conventional Commits 형식의 메시지 초안 |
| **문서 작성** | README, DEVELOPMENT.md 초안 작성 |

### 직접 판단하고 결정한 것

| 영역 | 내용 |
|---|---|
| **아키텍처 설계** | Clean Architecture + MVVM 레이어 구조 및 의존 방향 결정 |
| **Swift 6 전략** | `@preconcurrency` 우회 거부, `nonisolated` 직접 선언 방식 채택 |
| **기술적 트레이드오프** | `actor` vs `final class`, `UserDefaults` vs `FileManager` 등 |
| **AI 제안 코드 검토** | 생성된 코드를 직접 읽고 이해한 후 채택 여부 결정 / 수정 |
| **디버깅** | 런타임 크래시(DTO 디코딩, Main.storyboard) 원인 파악 및 수정 |
| **테스트 케이스 엣지 케이스 판단** | 커버리지 분석 후 추가 필요한 엣지 케이스 직접 식별 |

### AI 활용에 대한 입장

AI는 빠른 초안 생성과 반복 작업 자동화에 강점이 있습니다.
하지만 "왜 이렇게 설계하는가", "이 트레이드오프가 맞는가"에 대한 판단은 여전히 개발자의 몫입니다.
이 프로젝트에서 AI는 타이핑 속도를 높이는 도구였고, 아키텍처와 품질 기준은 제가 직접 설정하고 검증했습니다.

---

## 아쉬운 점 / 추가하고 싶었던 것

- **검색 히스토리**: 최근 검색어를 `actor` 기반 스토리지로 저장하고 검색창 포커스 시 자동완성 목록으로 표시. `BookmarkStorage`와 동일한 설계 패턴으로 Swift 6 동시성 일관성을 유지하면서 자연스럽게 확장 가능하다.
- **이미지 상세 뷰어**: 목록 셀 탭 시 원본 해상도(`detailDisplayURL`)로 전환해 확대/축소 가능한 뷰어 표시. `ImageItem`에 `detailDisplayURL`(`imageURL ?? thumbnailURL`)이 이미 준비되어 있어 뷰와 네비게이션 연결만 추가하면 된다.
