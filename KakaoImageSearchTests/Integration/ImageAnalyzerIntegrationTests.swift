//
//  ImageAnalyzerIntegrationTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 4/7/26.
//

import Testing
import UIKit
@testable import KakaoImageSearch

// 테스트 번들 접근용
private class BundleToken {}

private enum TestEnvironment {
    static var isSimulator: Bool {
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif
    }
}

// MARK: - Integration Tests
@Suite("ImageAnalyzer 통합 테스트", .enabled(if: !TestEnvironment.isSimulator))
struct ImageAnalyzerIntegrationTests {

    private let sut = ImageAnalyzer()
    
    // MARK: - Helpers

    private func loadTestImage() -> UIImage {
        let bundle = Bundle(for: BundleToken.self) // 또는 테스트 번들 접근 방식
        let url = bundle.url(forResource: "test_cat", withExtension: "jpeg")!
        return UIImage(contentsOfFile: url.path)!
    }
    
    @Test("이미지에서 키워드를 5개 이하로 받는지 확인")
    func get_keywordsFromImage() async throws {
        let image = loadTestImage()
        let keywords = try await sut.classifyImage(image)
        #expect(!keywords.isEmpty)
        #expect(keywords.count <= sut.maxKeywordCount)
    }
    
    @Test("빈이미지에서 실패하는지 확인")
    func get_keywordsFromInvalidImage() async {
        await #expect(throws: ImageAnalyzerError.invalidImage) {
            try await sut.classifyImage(UIImage())
        }
    }
}
