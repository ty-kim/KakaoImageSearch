//
//  KakaoImageSearchIPadUITests.swift
//  KakaoImageSearchUITests
//
//  Created by tykim on 3/16/26.
//

import XCTest

// MARK: - iPad 일반 (NavigationSplitView 레이아웃)

@MainActor
final class KakaoImageSearchIPadUITests: XCTestCase {

    nonisolated(unsafe) private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        try XCTSkipIf(!isIPad, "iPad 전용 테스트입니다. iPad 시뮬레이터에서 실행하세요.")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--resetBookmarks"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

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

        searchField.tap()
        searchField.typeText("cat")

        // debounce 1.0초 + 네트워크 응답 대기
        let resultsList = app.scrollViews["searchView.resultsList"]
        XCTAssertTrue(resultsList.waitForExistence(timeout: 10))

        // 검색 결과가 표시되는 동안 북마크 패널도 유지
        let bookmarkEmpty = app.descendants(matching: .any)
            .matching(identifier: "bookmarkView.emptyState").firstMatch
        XCTAssertTrue(bookmarkEmpty.waitForExistence(timeout: 3))
    }
}

// MARK: - iPad 에러 / 재시도 UX (네트워크 에러 시뮬레이션)

@MainActor
final class KakaoImageSearchIPadRetryUITests: XCTestCase {

    nonisolated(unsafe) private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        try XCTSkipIf(!isIPad, "iPad 전용 테스트입니다. iPad 시뮬레이터에서 실행하세요.")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--resetBookmarks", "--simulateNetworkError"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - 재시도 버튼 노출

    func test_searchError_retryButtonVisible() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        searchField.tap()
        searchField.typeText("cat")

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

        searchField.tap()
        searchField.typeText("cat")

        let retryButton = app.descendants(matching: .any)
            .matching(identifier: "emptyStateView.retryButton").firstMatch
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))

        retryButton.tap()

        // --simulateNetworkError 이므로 재시도 후에도 에러 → 버튼 다시 노출
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))
    }

    // MARK: - 에러 상태에서도 양쪽 패널 유지

    func test_errorState_bothPanelsStillVisible() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        searchField.tap()
        searchField.typeText("cat")

        let retryButton = app.descendants(matching: .any)
            .matching(identifier: "emptyStateView.retryButton").firstMatch
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))

        // 에러 상태에서도 북마크 패널(디테일)이 동시에 표시되어야 함
        let bookmarkEmpty = app.descendants(matching: .any)
            .matching(identifier: "bookmarkView.emptyState").firstMatch
        XCTAssertTrue(bookmarkEmpty.waitForExistence(timeout: 3))
    }
}
