//
//  KakaoImageSearchIPhoneUITests.swift
//  KakaoImageSearchIPhoneUITests
//
//  Created by tykim on 3/16/26.
//

import XCTest

// MARK: - iPhone 일반 (TabView 레이아웃)

final class KakaoImageSearchIPhoneUITests: BaseUITestCase {
    override func setUp() async throws {
        try await super.setUp()
        try await launchApp(arguments: ["--resetBookmarks", "--useFixtureData"])
    }
}

@MainActor
extension KakaoImageSearchIPhoneUITests {

    // MARK: - 앱 실행

    func test_launch_searchBarVisible() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
    }

    func test_launch_tabBarVisible() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
    }

    func test_launch_initialEmptyStateVisible() {
        let emptyState = app.descendants(matching: .any).matching(identifier: "searchView.emptyState").firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 3))
    }

    // MARK: - 검색창 인터랙션

    func test_searchBar_clearButton_appearsAfterInput() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        searchField.tap()
        searchField.typeText("고양이")

        let clearButton = app.buttons["searchBar.clearButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 2))
    }

    func test_searchBar_clearButton_clearsText() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        searchField.tap()
        searchField.typeText("고양이")

        let clearButton = app.buttons["searchBar.clearButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 2))
        clearButton.tap()

        XCTAssertTrue(clearButton.waitForNonExistence(timeout: 2))
    }

    func test_searchBar_clearButton_notVisibleOnLaunch() {
        let clearButton = app.buttons["searchBar.clearButton"]
        XCTAssertFalse(clearButton.exists)
    }

    // MARK: - 탭 전환

    func test_tabSwitch_toBookmark_showsEmptyState() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))

        tabBar.buttons.element(boundBy: 1).tap()

        let emptyState = app.descendants(matching: .any).matching(identifier: "bookmarkView.emptyState").firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 3))
    }

    func test_tabSwitch_backToSearch_showsEmptyState() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))

        tabBar.buttons.element(boundBy: 1).tap()
        tabBar.buttons.element(boundBy: 0).tap()

        let emptyState = app.descendants(matching: .any).matching(identifier: "searchView.emptyState").firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 3))
    }

    // MARK: - 검색 결과 (네트워크 필요)

    func test_search_showsResultsAfterDebounce() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        searchField.tap()
        searchField.typeText("cat")

        // debounce 1.0초 대기 (fixture이므로 네트워크 불필요)
        let resultsList = app.scrollViews["searchView.resultsList"]
        XCTAssertTrue(resultsList.waitForExistence(timeout: 3))

        // fixture는 항상 3개 반환 — 결과 개수까지 단언
        let item1 = app.descendants(matching: .any).matching(identifier: "searchResultItem.fixture-1").firstMatch
        XCTAssertTrue(item1.waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "searchResultItem.fixture-2").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "searchResultItem.fixture-3").firstMatch.exists)
    }

    func test_search_clearQuery_restoresEmptyState() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        searchField.tap()
        searchField.typeText("고양이")

        let clearButton = app.buttons["searchBar.clearButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 2))
        clearButton.tap()

        let emptyState = app.descendants(matching: .any).matching(identifier: "searchView.emptyState").firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 3))
    }

    // MARK: - 퍼포먼스

    func test_launchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

// MARK: - iPhone 에러 / 재시도 UX (네트워크 에러 시뮬레이션)

final class KakaoImageSearchIPhoneRetryUITests: BaseUITestCase {
    override func setUp() async throws {
        try await super.setUp()
        try await launchApp(arguments: ["--resetBookmarks", "--simulateNetworkError"])
    }
}

@MainActor
extension KakaoImageSearchIPhoneRetryUITests {

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

    // MARK: - 에러 상태에서도 탭 전환 정상 동작

    func test_errorState_tabSwitch_toBookmark_works() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("cat")

        let retryButton = app.descendants(matching: .any)
            .matching(identifier: "emptyStateView.retryButton").firstMatch
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))

        // Search 키로 키보드 닫기 (탭바가 키보드 뒤에 가려지므로)
        searchField.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 2))

        app.tabBars.firstMatch.buttons.element(boundBy: 1).tap()

        let bookmarkEmpty = app.descendants(matching: .any)
            .matching(identifier: "bookmarkView.emptyState").firstMatch
        XCTAssertTrue(bookmarkEmpty.waitForExistence(timeout: 3))
    }
}
