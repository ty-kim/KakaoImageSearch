# 개발 방향 및 AI 활용 범위

---

## 이번 구현에서 우선한 것

이번 구현에서는 기능 확장보다 다음 세 가지를 우선했습니다.

- 검색/북마크 핵심 사용자 흐름의 안정성
- 비동기 상태 전이와 실패 복구의 명확성
- 테스트 가능성과 문서 정합성

반대로 검색 히스토리, 오프라인 감지처럼 확장 가능한 기능은 이번 구현에서 제외했습니다.

## 개발 방향

### 1. 외부 라이브러리 없이 필요한 기능 직접 구현

과제 조건인 외부 라이브러리 금지에 맞춰, 네트워크 통신, 이미지 로딩, 의존성 조립을 직접 구현했습니다.
라이브러리로 해결할 수 있는 문제를 직접 다루면서, 각 구성 요소의 역할과 경계를 분리해두는 데 집중했습니다.

| 직접 구현한 구성 요소 | 일반적으로 많이 사용하는 라이브러리 예시 |
|---|---|
| URLSession Generic 래퍼 + snake_case 변환 | Alamofire / Moya |
| 메모리 + 디스크 2단계 이미지 캐시 + in-flight dedup | Kingfisher / SDWebImage |
| Composition Root 기반 생성자 주입 (AppAssembler) | Swinject |

### 2. Swift 6 Concurrency 제약에 맞춘 구조 정리

Swift 6의 SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor 설정을 기준으로 동시성 관련 경고와 오류를 정리했습니다.
@preconcurrency로 우회하기보다, 필요한 지점에 actor, nonisolated, nonisolated init(from:)를 적용해 현재 과제 범위에서 격리 규칙에 맞추는 방향을 택했습니다.
이 과정에서 DTO 디코딩, 로거 격리, 지역화 문자열 접근처럼 실제로 충돌이 발생한 부분을 하나씩 수정했습니다.

### 3. App Lifecycle 선택
SwiftUI `App` 프로토콜(`@main struct KakaoImageSearchApp: App`)을 사용합니다.
`AppAssembler`에서 ViewModel을 조립하고 `WindowGroup`에 `MainView`를 배치하는 구조로, UIKit 라이프사이클(`AppDelegate`/`SceneDelegate`) 없이 동작합니다.

### 4. 다국어 + 테스트 + 상태 설계

기능 구현 외에도 다국어 지원, 테스트, 상태 관리를 함께 정리했습니다.

- **다국어(ko / en / ja)**: .xcstrings String Catalog와 L10n 헬퍼 사용
- **유닛 테스트**: Swift Testing Framework, 111개 케이스, Domain + ViewModel + BookmarkStore + CachedAsyncImageViewModel 중심 검증 (`Unit/`)
- **통합 테스트**: Swift Testing Framework, 45개 케이스, NetworkService / BookmarkStorage / ImageDownloader / ImageCache I/O 검증 (`Integration/`)
- **UI 테스트**: XCUITest, 25개 + 1개(Launch 테스트) 케이스, 주요 사용자 플로우 검증 (iPhone + iPad)
- **OSLog**: 카테고리별 로깅 구성
- **BookmarkStore**: 탭 간 북마크 상태를 한 곳에서 관리
- **VoiceOver 접근성**: 주요 인터랙티브 컴포넌트에 `accessibilityLabel`/`accessibilityHint` 적용, 접근성 문자열도 ko/en/ja 3개 언어 지원

### 5. iPad 적응형 레이아웃

과제 안내에 iPad 레이아웃 변경이 가능하다고 되어 있어, iPhone과 iPad에서 레이아웃을 분리해 구현했습니다.

iPhone에서는 기존 TabView를 유지했고, iPad에서는 NavigationSplitView를 사용해 검색과 북마크를 한 화면에서 볼 수 있도록 했습니다.
레이아웃 분기는 `UIDevice.current.userInterfaceIdiom`으로 판별합니다. `horizontalSizeClass` 대신 디바이스 idiom을 사용해 대형 iPhone landscape에서 iPad 레이아웃이 표시되는 문제를 방지했습니다.
이미지 목록은 2열 그리드로 구성했고, 크기 계산은 화면 너비를 기준으로 처리했습니다.

### 6. 페이지네이션 & 에러 핸들링 UX

페이지네이션과 오류 상황에서의 사용자 피드백을 함께 고려했습니다.

- **페이지네이션**: `LazyVGrid` 마지막 아이템 `.onAppear` 트리거, 응답의 `isEnd` 값으로 완료 판별. API 페이지 제한(15페이지) 도달 시 실제 결과 소진과 구분해 안내 문구를 다르게 표시.
- **재시도 UX**: 검색 실패 / 추가 로드 실패 / 북마크 로드 실패를 구분하여 각 위치에 맞는 재시도 버튼 제공.
- **에러 vs 결과없음 구분**: 검색(`SearchState.error`/`.empty`)과 북마크(`BookmarkState.error`/`.loaded`) 모두 상태 enum 기반으로 UX 분기를 통일.
- **이미지 에러 분류**: 재시도 가능 에러(일시적 서버 오류)와 불가 에러(포맷·크기)를 구분해, 불가 에러는 즉시 영구 실패 처리.
- **Toast 피드백**: 북마크 토글 실패처럼 콘텐츠를 유지해야 하는 일시적 에러는 toastMessage로 분리해 하단 Toast로 표시, 지속 시간은 생성자 주입으로 제어해 테스트에서는 즉시 완료.

페이지네이션, 북마크, 일시적 오류 복구는 콘텐츠 탐색 화면에서 자주 다뤄지는 흐름이라, 이번 과제에서도 비슷한 관점으로 정리했습니다.

### 7. RxSwift 대신 Swift Concurrency

이번 과제에서는 외부 의존성을 두지 않는 조건에 맞춰, Swift Concurrency로 반응형 흐름을 구성했습니다.

| RxSwift 패턴 | 이번 구현 |
|---|---|
| `PublishSubject` + `debounce` | `Task.sleep(for: .seconds(1.0))` + `Task.cancel()` |
| `BehaviorRelay` / `Driver` | `@Observable` + `@MainActor` |
| `DisposeBag` | `Task` 명시적 취소 (`searchTask?.cancel()`) |
| `flatMapLatest` | `searchTask` 재생성 + `activeSearchID` stale 결과 무시로 이전 요청 취소 |

#### 이미지 상세 뷰어

 이미지 탭 시 `fullScreenCover`로 전체 화면 뷰어를 표시합니다.
 `MagnifyGesture` 핀치 확대/축소(1x~5x), 더블탭 줌 토글, 확대 시 드래그 패닝을 지원하며, 기존 `ImageDownloader` 캐시를 활용해 이미 다운로드된 이미지는 즉시 표시됩니다.

#### API 설계 — 테스트 가능성을 고려한 반환 타입

`submitSearch`는 `@discardableResult Task<Void, Never>`를 반환합니다.
프로덕션 호출 측은 반환값을 무시하고, 테스트에서는 `await task.value`로 완료를 기다려 완료 시점을 기다릴 수 있도록 했습니다.
`@discardableResult` 하나로 "프로덕션은 fire-and-forget, 테스트는 await" 두 가지 요구를 동시에 충족합니다.

#### View 수명 관리 — `.task(id:)` 바인딩

`CachedAsyncImage`는 `.task(id:)`를 사용해 이미지 로드 Task를 뷰 수명에 바인딩합니다.
URL이 변경되면 이전 Task를 자동 취소하고 새 Task를 시작해, `LazyVGrid` 셀 재사용 시 이전 URL의 이미지가 깜빡이거나 덮어쓰이는 문제를 방지합니다.

#### 외부 상태 변화 반영 — `withObservationTracking`

`SearchViewModel.items`는 computed property 대신 stored property로 캐싱합니다.
`BookmarkStore.bookmarkedIDs`가 변경되면 `withObservationTracking onChange`가 트리거되어 `rebuildItems()`를 한 번만 실행합니다.
외부 객체 상태 변화에 반응하도록 구성했습니다.

특히 동시성 관련 제약을 컴파일 단계에서 확인할 수 있다는 점이 이번 구현에서는 장점이라고 판단했습니다.

#### ATS 예외 설정
일부 검색 결과 이미지 CDN이 HTTPS를 지원하지 않고, 실제 이미지 호스트도 여러 서브도메인으로 분산되어 있어 `daum.net`, `naver.net` 계열 도메인에 ATS 예외를 적용했습니다.
이 예외는 검색 결과 이미지 로딩에만 사용하며, API 통신이나 민감 정보 전송에는 적용하지 않습니다. 현재 과제 범위에서는 호스트 구성이 다양해 이 방식이 가장 현실적이었고, 사용 호스트를 더 좁힐 수 있다면 예외 범위도 함께 축소할 수 있습니다.

#### BookmarkStore (공유 상태 관리)
- `Presentation/Store/`에 위치한 Presentation 레이어 공유 상태 객체
- `@Observable @MainActor`로 선언해 북마크 상태를 중앙 관리
- `SearchViewModel` / `BookmarkViewModel` 이 동일 인스턴스를 참조해 양쪽 탭에서 같은 북마크 상태를 참조하도록 구성했습니다.

#### VoiceOver 접근성
- `BookmarkButton`: 북마크 상태에 따라 `accessibilityLabel`과 `accessibilityHint`를 분기 적용
- `SearchBar`: 텍스트필드에 debounce 안내 `accessibilityHint`, 지우기 버튼에 `accessibilityLabel` 적용
- `SearchResultItemView`: 이미지 크기 정보를 포함한 `accessibilityLabel` 적용
- `EmptyStateView`: 메시지 영역에 `accessibilityLabel`, 재시도 버튼에 `accessibilityHint` 적용
- `ToastView`: 등장 시 `AccessibilityNotification.Announcement`로 VoiceOver 자동 안내
- `ProgressView`: 검색/북마크 로딩 상태에 `accessibilityLabel` 적용
- 탭(검색/북마크): `accessibilityHint`로 탭 전환 시 역할 안내
- 추가 로드 재시도 버튼: `accessibilityHint` 적용
- 접근성 문자열은 `L10n.Accessibility`에서 관리하며, 한국어/영어/일본어를 지원합니다.

#### OSLog 기반 로깅
- `Logger.network`, `Logger.imageLoader`, `Logger.bookmark`, `Logger.presentation` 카테고리 분리 (각 카테고리는 사용하는 레이어에 정의)
- `debugPrint` / `errorPrint` 헬퍼로 `OS_ACTIVITY_MODE=disable` 환경에서도 Xcode 콘솔 출력 보장


---

## AI 활용 범위

이 프로젝트에서는 **Claude(Anthropic)**를 보조 도구로 활용했습니다.

구조 선택, 채택 여부 판단, 최종 검증은 직접 수행했습니다.
AI는 초안 작성과 반복 작업에 활용했고, 아키텍처 선택과 품질 판단은 직접 진행했습니다.

### AI가 도운 것: 초안, 반복 작업, 테스트 케이스 아이디어

### 직접 판단한 것: 구조, 트레이드오프, 최종 검증

---

## 아쉬운 점 / 추가하고 싶었던 것

- **검색 히스토리**: 최근 검색어 저장 기능도 추가 후보로 생각했습니다. 현재 북마크 저장 구조와 유사한 방식으로 확장할 수 있다고 봤습니다.
- **네트워크 상태 감지**: 현재는 오프라인 상태를 별도로 감지하지 않고, 요청 실패 시 에러 메시지와 재시도 버튼으로 대응합니다. `NWPathMonitor`를 활용해 오프라인 전환 시 사전 안내하거나, 셀룰러 환경에서 prefetch를 억제하는 등의 개선을 고려할 수 있습니다.
- **Certificate Pinning**: 현재 API 통신(`dapi.kakao.com`)은 HTTPS로 보호되지만, 인증서 검증을 시스템 기본 동작에 위임하고 있습니다. 프로덕션 환경에서는 MITM 방어를 위해 `URLSessionDelegate`에서 서버 공개키를 직접 검증하는 방식을 고려할 수 있습니다. 이미지 CDN(`daum.net`, `naver.net`)은 HTTP 통신이라 pinning 대상이 아니며, CDN이 HTTPS를 지원하게 되면 ATS 예외 제거와 함께 pinning을 고려할 수 있습니다.
