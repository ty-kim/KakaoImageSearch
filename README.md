# KakaoImageSearch

![Build](https://github.com/ty-kim/KakaoImageSearch/actions/workflows/ci.yml/badge.svg)

SwiftUI로 만든 iOS 이미지 검색 앱입니다.
검색 자체보다 검색 취소, 늦은 응답 반영 방지, 페이지네이션, 북마크 동기화처럼
비동기 상태가 복잡해지는 화면을 안정적으로 설계하고 검증하는 데 집중했습니다.

## Highlights

- 1초 debounce + 이전 검색 취소 + 늦은 응답 무시
- 메모리/디스크 캐시 + in-flight 중복제거를 포함한 자체 이미지 로더
- iPhone / iPad 레이아웃 분리, VoiceOver와 Reduce Motion 대응
- Unit / Integration / UI Test로 핵심 사용자 흐름 검증

## Screenshots

<p align="center">
  <img src="Screenshots/01_Screenshot.png" width="250">
  <img src="Screenshots/02_Screenshot.png" width="250">
  <img src="Screenshots/05_Screenshot.png" width="350">
</p>

## Why This Project

이미지 검색 화면은 겉보기엔 단순하지만 실제로는 다음 문제가 함께 얽힙니다.

- 사용자가 검색어를 빠르게 바꿀 때 이전 응답이 뒤늦게 도착하는 문제
- 추가 로드, 재시도, 북마크 반영이 동시에 일어날 때 상태가 꼬이는 문제
- 대량 이미지 로딩에서 캐시, 중복 요청, 실패 복구를 함께 다뤄야 하는 문제

이 프로젝트는 이런 흐름을 SwiftUI와 Swift Concurrency로 어떻게 분리하고,
테스트 가능한 구조로 유지할 수 있는지 보여주기 위한 개인 프로젝트입니다.

## What I Focused On

### 1. 검색 상태 안정성

- `Task.sleep` + `Task.cancel()`로 debounce 구현
- 새 검색 시작 시 이전 검색과 prefetch 작업 취소
- `activeSearchID`로 늦은 응답이 UI를 덮어쓰지 않도록 처리
- 검색 실패, 결과 없음, 추가 로드 실패를 서로 다른 상태로 분리

### 2. 이미지 로딩 파이프라인

- `URLSession` 기반 네트워크 레이어 직접 구현
- 메모리 + 디스크 2단계 캐시
- 동일 URL 동시 요청 중복제거
- Content-Type / Content-Length 검증
- ATS 예외 도메인 외 HTTP URL은 HTTPS로 승격

### 3. 공유 상태와 화면 분리

- `BookmarkCoordinator`로 검색 탭과 북마크 탭의 상태 동기화
- iPhone은 `TabView`, iPad는 `NavigationSplitView`로 분리
- ViewModel과 보조 객체 중심으로 상태 전이를 분리해 테스트 가능하게 유지

### 4. 접근성과 적응형 UI

- ko / en / ja 다국어 지원
- VoiceOver 접근성 라벨 / 힌트 적용
- Reduce Motion 설정 시 애니메이션 축소
- iOS 26+에서는 Foundation Models를 활용해 이미지 설명문 생성

## Quick Start

### 리뷰어용 빠른 확인

실제 Kakao API 호출 없이도 주요 화면을 확인할 수 있습니다.

1. 프로젝트 루트에 `KakaoAPIKey.swift`를 만듭니다
2. 아래 내용을 넣습니다

```swift
enum KakaoAPIKey {
    static let restAPIKey = "dummy-key"
}
```

3. `KakaoImageSearch.xcodeproj`를 엽니다.
4. Scheme Run Arguments에 `--useFixtureData`를 추가하고 실행합니다

### 실제 API로 실행

1. `KakaoAPIKey.swift`에 실제 Kakao REST API 키를 넣습니다
2. `--useFixtureData` 없이 실행합니다
3. iOS 17.0+ 시뮬레이터 또는 실기기에서 빌드합니다

샘플 파일은 `KakaoAPIKey.swift.example`에 있습니다.

## Build & Test

```bash
# Build
xcodebuild -project KakaoImageSearch.xcodeproj -scheme KakaoImageSearch \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Unit + Integration
xcodebuild -project KakaoImageSearch.xcodeproj -scheme KakaoImageSearch \
  -destination 'platform=iOS Simulator,name=iPhone 17' -testPlan UnitTests test

# All Tests
xcodebuild -project KakaoImageSearch.xcodeproj -scheme KakaoImageSearch \
  -destination 'platform=iOS Simulator,name=iPhone 17' -testPlan AllTests test
```

테스트는 검색 취소, 늦은 응답, 페이지네이션, 북마크 동기화,
이미지 캐시와 실패 복구처럼 회귀 위험이 큰 흐름을 중심으로 작성했습니다.

- Unit + Integration: 221개
- UI Test: 28개
- CI: `UnitTests` 플랜 실행

## Architecture

Clean Architecture + MVVM을 기반으로 4개 레이어로 구성했습니다.

```text
KakaoImageSearch
├── Domain
├── Data
├── Infrastructure
├── Presentation
└── App
```

Domain은 외부 구현을 모르고, App이 Composition Root로 전체 의존성을 조립합니다.
검색 흐름, 북마크 공유 상태, 이미지 로딩 파이프라인을 각각 분리해
View에 로직이 몰리지 않도록 구성했습니다.

## Tech Stack

- Swift 6.0
- SwiftUI
- SwiftData
- Swift Testing Framework
- XCUITest
- OSLog
- Zero dependency

## Trade-offs

- 기능 확장보다 상태 안정성과 테스트 가능성을 우선했습니다
- 검색 히스토리 같은 확장 기능은 이번 범위에서 제외했습니다
- 일부 이미지 CDN의 HTTP 응답을 처리하기 위해 제한적인 ATS 예외를 사용했습니다

## Documents

- [DEVELOPMENT.md](DEVELOPMENT.md): 설계 의도, 예외 처리, 트레이드오프
- [KakaoImageSearchTests](KakaoImageSearchTests): 핵심 테스트 케이스

## AI Usage

AI는 초안 작성과 반복 작업에 보조적으로 활용했습니다.
구조 선택, 채택 여부 판단, 최종 검증은 직접 수행했습니다.
