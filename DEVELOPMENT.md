# 개발 방향 및 AI 활용 범위

---

## 개발 방향

### 1. 외부 라이브러리 없이 필요한 기능 직접 구현

과제 조건인 외부 라이브러리 금지에 맞춰, 네트워크 통신, 이미지 로딩, 의존성 조립을 직접 구현했습니다.
라이브러리로 해결할 수 있는 문제를 직접 다루면서, 각 구성 요소의 역할과 경계를 명확히 두는 데 집중했습니다.

| 직접 구현한 구성 요소 | 일반적으로 많이 사용하는 라이브러리 예시 |
|---|---|
| URLSession Generic 래퍼 + snake_case 변환 | Alamofire / Moya |
| 메모리 + 디스크 2단계 이미지 캐시 + in-flight dedup | Kingfisher / SDWebImage |
| Composition Root 기반 생성자 주입 (AppAssembler) | Swinject |

### 2. Swift 6 Concurrency 제약에 맞춘 구조 정리

Swift 6의 SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor 설정을 기준으로 동시성 관련 경고와 오류를 정리했습니다.
@preconcurrency로 우회하기보다, 필요한 지점에 actor, nonisolated, nonisolated init(from:)를 적용해 격리 규칙을 맞추는 방향을 택했습니다.
이 과정에서 DTO 디코딩, 로거 격리, 지역화 문자열 접근처럼 실제로 충돌이 발생한 부분을 하나씩 수정했습니다.

### 3. 다국어 + 테스트 + 상태 설계

기능 구현 외에도 다국어 지원, 테스트, 상태 관리를 함께 정리했습니다.

- **다국어(ko / en / ja)**: .xcstrings String Catalog와 L10n 헬퍼 사용
- **유닛 테스트**: Swift Testing Framework, 92개 케이스, Domain + ViewModel + BookmarkStore 중심 검증
- **통합 테스트**: Swift Testing Framework, 28개 케이스, NetworkService / BookmarkStorage / ImageDownloader I/O 검증
- **UI 테스트**: XCUITest, 25개 케이스, 주요 사용자 플로우 검증 (iPhone + iPad)
- **OSLog**: 카테고리별 로깅 구성
- **BookmarkStore**: 탭 간 북마크 상태를 한 곳에서 관리

### 4. iPad 적응형 레이아웃

과제 안내에 iPad 레이아웃 변경이 가능하다고 되어 있어, iPhone과 iPad에서 레이아웃을 분리해 구현했습니다.

iPhone에서는 기존 TabView를 유지했고, iPad에서는 NavigationSplitView를 사용해 검색과 북마크를 한 화면에서 볼 수 있도록 했습니다.
이미지 목록은 2열 그리드로 구성했고, 크기 계산은 화면 너비를 기준으로 처리했습니다.

### 5. 페이지네이션 & 에러 핸들링 UX

페이지네이션과 오류 상황에서의 사용자 피드백을 함께 고려했습니다.

- **무한 스크롤**: `LazyVGrid` 마지막 아이템 `.onAppear` 트리거, `isEnd` 플래그로 완료 판별.
- **재시도 UX**: 검색 실패 / 추가 로드 실패를 구분하여 각 위치에 맞는 재시도 버튼 제공.
- **에러 vs 결과없음 구분**: `hasError` / `errorMessage` 플래그 분리로 UX 분기 명확화.
- **Toast 피드백**: 북마크 토글 실패처럼 콘텐츠를 유지해야 하는 일시적 에러는 toastMessage로 분리해 하단 Toast로 표시, 지속 시간은 생성자 주입으로 제어해 테스트에서는 즉시 완료.

무한 스크롤, 북마크, 일시적 오류 복구는 콘텐츠 탐색 화면에서 자주 다뤄지는 흐름이라, 이번 과제에서도 비슷한 관점으로 정리했습니다.

### 6. RxSwift 대신 Swift Concurrency

이번 과제에서는 외부 의존성을 두지 않는 조건에 맞춰, Swift Concurrency로 반응형 흐름을 구성했습니다.

| RxSwift 패턴 | 이번 구현 |
|---|---|
| `PublishSubject` + `debounce` | `Task.sleep(1.0)` + `Task.cancel()` |
| `BehaviorRelay` / `Driver` | `@Observable` + `@MainActor` |
| `DisposeBag` | `Task` 명시적 취소 (`searchTask?.cancel()`) |
| `flatMapLatest` | `searchTask` 재생성 + `activeSearchID` stale 결과 무시로 이전 요청 취소 |

#### API 설계 — 테스트 가능성을 고려한 반환 타입

`submitSearch`는 `@discardableResult Task<Void, Never>`를 반환합니다.
프로덕션 호출 측은 반환값을 무시하고, 테스트에서는 `await task.value`로 완료를 기다려 결정적 타이밍을 보장합니다.
`@discardableResult` 하나로 "프로덕션은 fire-and-forget, 테스트는 await" 두 가지 요구를 동시에 충족합니다.

#### View 수명 관리 — `.task(id:)` 바인딩

`CachedAsyncImage`는 `.task(id: url)`을 사용해 이미지 로드 Task를 뷰 수명에 바인딩합니다.
URL이 변경되면 이전 Task를 자동 취소하고 새 Task를 시작해, `LazyVGrid` 셀 재사용 시 이전 URL의 이미지가 깜빡이거나 덮어쓰이는 문제를 방지합니다.

#### 외부 상태 변화 반영 — `withObservationTracking`

`SearchViewModel.items`는 computed property 대신 stored property로 캐싱합니다.
`BookmarkStore.bookmarkedIDs`가 변경되면 `withObservationTracking onChange`가 트리거되어 `rebuildItems()`를 한 번만 실행합니다.
외부 객체 상태 변화에 반응하도록 구성했습니다.

특히 동시성 관련 제약을 컴파일 단계에서 확인할 수 있다는 점이 장점이라고 봤습니다.

---

## AI 활용 범위

이 프로젝트에서는 **Claude(Anthropic)**를 보조 도구로 활용했습니다.
초안 작성과 반복 작업에는 도움을 받았고, 구조 선택과 채택 여부 판단은 직접 진행했습니다.

AI를 사용한 부분과 직접 판단한 부분을 구분해서 정리했습니다.

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
| **Swift 6 전략** | `@preconcurrency` 대신 명시적 격리 적용, `nonisolated` 직접 선언 방식 채택 |
| **기술적 트레이드오프** | `actor` vs `final class`, `UserDefaults` vs `FileManager` 등 |
| **AI 제안 코드 검토** | 생성된 코드를 직접 읽고 이해한 후 채택 여부 결정 / 수정 |
| **디버깅** | 런타임 크래시(DTO 디코딩, Main.storyboard) 원인 파악 및 수정 |
| **테스트 케이스 엣지 케이스 판단** | 커버리지 분석 후 추가 필요한 엣지 케이스 직접 식별 |

### AI 활용에 대한 입장

AI는 빠른 초안 생성과 반복 작업 자동화에 강점이 있습니다.
하지만 "왜 이렇게 설계하는가", "이 트레이드오프가 맞는가"에 대한 판단은 여전히 개발자의 몫입니다.
이 프로젝트에서 AI는 초안 작성과 반복 작업을 줄이는 데 도움이 됐고, 아키텍처와 품질 기준은 제가 직접 설정하고 검증했습니다.

---

## 아쉬운 점 / 추가하고 싶었던 것

- **검색 히스토리**: 최근 검색어 저장 기능도 추가 후보로 생각했습니다. 현재 북마크 저장 구조와 유사한 방식으로 확장할 수 있다고 봤습니다.
- **이미지 상세 뷰어**: 이미지 상세 뷰어도 고려했지만, 이번 제출에서는 범위를 넓히지 않기 위해 제외했습니다. 필요하다면 현재 모델 구조를 바탕으로 비교적 무리 없이 확장할 수 있습니다.
- **이미지 로드 실패 UX**: 현재 로드 실패 시 `exclamationmark.triangle` placeholder만 표시되며 사용자가 취할 수 있는 액션이 없다. 셀 탭 또는 별도 재시도 버튼으로 `ImageDownloader.download(from:)`를 재호출하는 흐름을 추가하면 검색 결과 재시도 UX와 비슷한 방식으로 정리할 수 있을 것 같습니다.
