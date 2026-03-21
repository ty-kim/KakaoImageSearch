//
//  BaseUITestCase.swift
//  KakaoImageSearchUITests
//
//  Created by tykim on 3/21/26.
//

import XCTest
import UIKit

class BaseUITestCase: XCTestCase {
    /// 저장 프로퍼티로 들고 있지 않고, 필요할 때마다 핸들을 가져옵니다.
    @MainActor
    var app: XCUIApplication { XCUIApplication() }

    /// 공통 launch helper
    func launchApp(arguments: [String] = []) async throws {
        continueAfterFailure = false

        try await MainActor.run {
            let isIPhone = UIDevice.current.userInterfaceIdiom == .phone
            try XCTSkipIf(!isIPhone, "iPhone 전용 테스트입니다. iPhone 시뮬레이터에서 실행하세요.")
            let app = XCUIApplication()
            app.launchArguments = arguments
            app.launch()
        }
    }

    /// iPad 전용 launch helper
    func launchAppOnIPad(arguments: [String] = []) async throws {
        continueAfterFailure = false

        try await MainActor.run {
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            try XCTSkipIf(!isIPad, "iPad 전용 테스트입니다. iPad 시뮬레이터에서 실행하세요.")

            let app = XCUIApplication()
            app.launchArguments = arguments
            app.launch()
        }
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }
}
