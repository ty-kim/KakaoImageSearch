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

        typeText("고양이", into: searchField)

        let clearButton = app.buttons["searchBar.clearButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 2))
    }

    func test_searchBar_clearButton_clearsText() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        typeText("고양이", into: searchField)

        let clearButton = app.buttons["searchBar.clearButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 2))
        clearButton.tap()

        XCTAssertTrue(clearButton.waitForNonExistence(timeout: 2))
    }

    func test_searchBar_tapOutsideOnSearchTab_dismissesKeyboard() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        tabBar.buttons.element(boundBy: 0).tap()

        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        searchField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))

        // 검색 탭의 빈 영역 탭
        let emptyState = app.descendants(matching: .any).matching(identifier: "searchView.emptyState").firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 2))
        emptyState.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 2))
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

        typeText("cat", into: searchField)

        // debounce 1.0초 대기 (fixture이므로 네트워크 불필요)
        let resultsList = app.scrollViews["searchView.resultsList"]
        XCTAssertTrue(resultsList.waitForExistence(timeout: 3))

        // fixture는 항상 3개 반환 — 결과 개수까지 단언
        let item1 = app.descendants(matching: .any).matching(identifier: "searchResultItem.fixture-1").firstMatch
        XCTAssertTrue(item1.waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "searchResultItem.fixture-2").firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "searchResultItem.fixture-3").firstMatch.exists)
    }

    func test_search_resultVisible_tabSwitchToBookmark_works() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        typeText("cat", into: searchField)

        // debounce 후 검색 결과 노출 대기
        let item1 = app.descendants(matching: .any).matching(identifier: "searchResultItem.fixture-1").firstMatch
        XCTAssertTrue(item1.waitForExistence(timeout: 3))

        // 검색 결과가 있는 상태에서 북마크 탭으로 전환
        app.tabBars.firstMatch.buttons.element(boundBy: 1).tap()

        let bookmarkEmpty = app.descendants(matching: .any)
            .matching(identifier: "bookmarkView.emptyState").firstMatch
        XCTAssertTrue(bookmarkEmpty.waitForExistence(timeout: 3))
    }

    func test_search_clearQuery_restoresEmptyState() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        typeText("고양이", into: searchField)

        let clearButton = app.buttons["searchBar.clearButton"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 2))
        clearButton.tap()

        let emptyState = app.descendants(matching: .any).matching(identifier: "searchView.emptyState").firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 3))
    }

    // MARK: - 이미지 상세보기

    func test_imageDetail_closeButton_hasAccessibilityLabel() {
        let searchField = app.textFields["searchBar.textField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        typeText("cat", into: searchField)

        let item = app.descendants(matching: .any).matching(identifier: "searchResultItem.fixture-1").firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        item.tap()

        let closeButton = app.buttons["imageDetailView.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        XCTAssertEqual(closeButton.label, "이미지 닫기")
    }

    // MARK: - 퍼포먼스

    func test_launchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

// MARK: - iPhone 북마크 있는 상태 (fixture 북마크)

final class KakaoImageSearchIPhoneBookmarkUITests: BaseUITestCase {
    override func setUp() async throws {
        try await super.setUp()
        try await launchApp(arguments: ["--resetBookmarks", "--useFixtureBookmarks", "--useFixtureData"])
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
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))

        retryButton.tap()

        // --simulateNetworkError 이므로 재시도 후에도 에러 → 버튼 다시 노출
        XCTAssertTrue(retryButton.waitForExistence(timeout: 5))
    }
}
