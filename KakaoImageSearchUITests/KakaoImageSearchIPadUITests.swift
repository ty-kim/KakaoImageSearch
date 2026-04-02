//
//  KakaoImageSearchIPadUITests.swift
//  KakaoImageSearchUITests
//
//  Created by tykim on 3/16/26.
//

import XCTest

// MARK: - iPad 일반 (NavigationSplitView 레이아웃)

final class KakaoImageSearchIPadUITests: BaseUITestCase {
    override func setUp() async throws {
        try await super.setUp()
        try await launchAppOnIPad(arguments: ["--resetBookmarks", "--useFixtureData"])
    }
}

@MainActor
extension KakaoImageSearchIPadUITests {

    // MARK: - 앱 실행

    func test_launch_searchBarVisible() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
    }

    func test_launch_noTabBar() {
        // iPad는 NavigationSplitView이므로 탭바 없음
        XCTAssertFalse(app.tabBars.firstMatch.waitForExistence(timeout: 3))
    }

    func test_launch_searchEmptyStateVisible() {
        let emptyState = app.descendants(matching: .any)
            .matching(identifier: "searchView.emptyState").firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 3))
    }

    func test_launch_bookmarkEmptyStateVisible() {
        // iPad SplitView에서는 검색과 북마크가 동시에 표시됨
        let emptyState = app.descendants(matching: .any)
            .matching(identifier: "bookmarkView.emptyState").firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 3))
    }

    // MARK: - 양쪽 패널 동시 표시

    func test_bothPanels_visibleSimultaneously() {
        let searchEmpty = app.descendants(matching: .any)
            .matching(identifier: "searchView.emptyState").firstMatch
        let bookmarkEmpty = app.descendants(matching: .any)
            .matching(identifier: "bookmarkView.emptyState").firstMatch

        XCTAssertTrue(searchEmpty.waitForExistence(timeout: 3))
        XCTAssertTrue(bookmarkEmpty.waitForExistence(timeout: 3))
    }

    // MARK: - 검색 결과 (네트워크 필요)

    func test_search_showsResultsAfterDebounce() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        typeText("cat", into: searchField)

        // debounce 1.0초 대기 (fixture이므로 네트워크 불필요)
        let resultsList = app.scrollViews["searchView.resultsList"]
        XCTAssertTrue(resultsList.waitForExistence(timeout: 3))

        // fixture는 항상 3개 반환 — 결과 개수까지 단언
        let item1 = app.descendants(matching: .any).matching(identifier: "searchResultItem.fixture-1").firstMatch
        XCTAssertTrue(item1.waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "searchResultItem.fixture-2").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "searchResultItem.fixture-3").firstMatch.exists)

        // 검색 결과가 표시되는 동안 북마크 패널도 유지
        let bookmarkEmpty = app.descendants(matching: .any)
            .matching(identifier: "bookmarkView.emptyState").firstMatch
        XCTAssertTrue(bookmarkEmpty.waitForExistence(timeout: 3))
    }
}

// MARK: - iPad 에러 / 재시도 UX (네트워크 에러 시뮬레이션)

final class KakaoImageSearchIPadRetryUITests: BaseUITestCase {
    override func setUp() async throws {
        try await super.setUp()
        try await launchAppOnIPad(arguments: ["--resetBookmarks", "--simulateNetworkError"])
    }
}

@MainActor
extension KakaoImageSearchIPadRetryUITests {

    // MARK: - 재시도 버튼 노출

    func test_searchError_retryButtonVisible() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        typeText("cat", into: searchField)

        let retryButton = app.descendants(matching: .any)
            .matching(identifier: "emptyStateView.retryButton").firstMatch
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))
    }

    // MARK: - 초기 상태에서는 재시도 버튼 없음

    func test_initialState_noRetryButton() {
        let retryButton = app.descendants(matching: .any)
            .matching(identifier: "emptyStateView.retryButton").firstMatch
        XCTAssertFalse(retryButton.waitForExistence(timeout: 2))
    }

    // MARK: - 재시도 버튼 탭 → 에러 재발생

    func test_retryButton_tap_triggersReSearch() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        typeText("cat", into: searchField)

        let retryButton = app.descendants(matching: .any)
            .matching(identifier: "emptyStateView.retryButton").firstMatch
        XCTAssertTrue(retryButton.waitForExistence(timeout: 8))
        // 키보드가 retryButton을 덮어 hittable이 안 될 수 있으므로 dismiss 대기
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))

        retryButton.tap()

        // --simulateNetworkError 이므로 재시도 후에도 에러 → 버튼 다시 노출
        let retriedRetryButton = app.descendants(matching: .any)
            .matching(identifier: "emptyStateView.retryButton").firstMatch
        XCTAssertTrue(retriedRetryButton.waitForExistence(timeout: 8))
    }

    // MARK: - 에러 상태에서도 양쪽 패널 유지

    func test_errorState_bothPanelsStillVisible() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        typeText("cat", into: searchField)

        let retryButton = app.descendants(matching: .any)
            .matching(identifier: "emptyStateView.retryButton").firstMatch
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))

        // 에러 상태에서도 북마크 패널(디테일)이 동시에 표시되어야 함
        let bookmarkEmpty = app.descendants(matching: .any)
            .matching(identifier: "bookmarkView.emptyState").firstMatch
        XCTAssertTrue(bookmarkEmpty.waitForExistence(timeout: 3))
    }
}
