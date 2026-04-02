//
//  BaseUITestCase.swift
//  KakaoImageSearchUITests
//
//  Created by tykim on 3/21/26.
//

import XCTest
import UIKit

class BaseUITestCase: XCTestCase {
    private static let fixedLocalizationLaunchArguments = [
        "-AppleLanguages", "(ko)",
        "-AppleLocale", "ko_KR"
    ]

    /// 저장 프로퍼티로 들고 있지 않고, 필요할 때마다 핸들을 가져옵니다.
    @MainActor
    var app: XCUIApplication { XCUIApplication() }

    /// 공통 launch helper
    func launchApp(arguments: [String] = []) async throws {
        continueAfterFailure = false
        let launchArguments = Self.fixedLocalizationLaunchArguments + arguments

        try await MainActor.run {
            let isIPhone = UIDevice.current.userInterfaceIdiom == .phone
            try XCTSkipIf(!isIPhone, "iPhone 전용 테스트입니다. iPhone 시뮬레이터에서 실행하세요.")
            let app = XCUIApplication()
            // CI/로컬 환경과 무관하게 접근성 문자열을 동일하게 검증하도록 언어/지역을 고정한다.
            app.launchArguments = launchArguments
            app.launch()
        }
    }

    /// iPad 전용 launch helper
    func launchAppOnIPad(arguments: [String] = []) async throws {
        continueAfterFailure = false
        let launchArguments = Self.fixedLocalizationLaunchArguments + arguments

        try await MainActor.run {
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            try XCTSkipIf(!isIPad, "iPad 전용 테스트입니다. iPad 시뮬레이터에서 실행하세요.")

            let app = XCUIApplication()
            // CI/로컬 환경과 무관하게 접근성 문자열을 동일하게 검증하도록 언어/지역을 고정한다.
            app.launchArguments = launchArguments
            app.launch()
        }
    }

    /// 하드웨어 키보드 연결 상태에서도 안정적으로 텍스트를 입력한다.
    /// CI 환경에서 tap()만으로 키보드 포커스가 안 잡히는 문제 대응.
    @MainActor
    func typeText(_ text: String, into element: XCUIElement) {
        for attempt in 1...3 {
            element.tap()
            if element.waitForKeyboardFocus(timeout: 2) { break }
            if attempt == 3 {
                XCTFail("TextField에 키보드 포커스를 획득하지 못했습니다: \(element.identifier)")
                return
            }
        }

        element.typeText(text)
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }
}

extension XCUIElement {
    func waitForKeyboardFocus(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "hasKeyboardFocus == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    func waitForHittable(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
