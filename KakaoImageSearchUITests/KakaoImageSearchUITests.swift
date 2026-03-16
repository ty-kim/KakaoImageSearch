//
//  KakaoImageSearchUITests.swift
//  KakaoImageSearchUITests
//
//  Created by tykim on 3/16/26.
//

import XCTest

@MainActor
final class KakaoImageSearchUITests: XCTestCase {

    nonisolated(unsafe) private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
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

        // debounce 1.0초 + 네트워크 응답 대기
        let resultsList = app.scrollViews["searchView.resultsList"]
        XCTAssertTrue(resultsList.waitForExistence(timeout: 10))
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
