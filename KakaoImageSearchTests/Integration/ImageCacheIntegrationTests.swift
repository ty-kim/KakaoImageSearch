//
//  ImageCacheIntegrationTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/18/26.
//

import Testing
import UIKit
@testable import KakaoImageSearch

@Suite("ImageCache 통합 테스트")
struct ImageCacheIntegrationTests {

    private let tempDir: URL
    private let imageURL = URL(string: "https://example.com/image.jpg")!

    init() {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    private func makeSUT(ttl: TimeInterval = 7 * 24 * 60 * 60) -> ImageCache {
        ImageCache(diskCacheURL: tempDir, ttl: ttl)
    }

    /// cacheKey(for:) private 메서드와 동일한 로직
    private func cacheKey(for url: URL) -> String {
        url.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics)
            ?? url.lastPathComponent
    }

    @Test("손상된 디스크 캐시 파일 읽기 시 파일 삭제 후 nil 반환")
    func get_corruptDiskFile_removesFileAndReturnsNil() async {
        let sut = makeSUT()
        let diskURL = tempDir.appendingPathComponent(cacheKey(for: imageURL))
        try? "not an image".data(using: .utf8)?.write(to: diskURL)
        #expect(FileManager.default.fileExists(atPath: diskURL.path))

        let result = await sut.get(for: imageURL)

        #expect(result == nil)
        #expect(!FileManager.default.fileExists(atPath: diskURL.path))
    }

    @Test("손상 파일 삭제 후 정상 이미지 set → 다음 get에서 복구")
    func get_afterCorruptFileRemoved_returnsNewlyCachedImage() async {
        let sut = makeSUT()
        let diskURL = tempDir.appendingPathComponent(cacheKey(for: imageURL))
        try? "not an image".data(using: .utf8)?.write(to: diskURL)

        _ = await sut.get(for: imageURL)  // 손상 파일 삭제 트리거

        let validImage = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
            .image { _ in }
        await sut.set(validImage, for: imageURL)

        let result = await sut.get(for: imageURL)
        #expect(result != nil)
    }

    @Test("TTL 초과 파일은 cleanup 시 삭제됨")
    func cleanupExpiredFiles_removesExpiredFiles() async {
        let sut = makeSUT(ttl: 3600)
        let diskURL = tempDir.appendingPathComponent(cacheKey(for: imageURL))
        try? "fake".data(using: .utf8)?.write(to: diskURL)

        // 수정 날짜를 TTL보다 이전으로 조작
        let pastDate = Date(timeIntervalSinceNow: -7200)
        try? FileManager.default.setAttributes([.modificationDate: pastDate], ofItemAtPath: diskURL.path)

        await sut.cleanupExpiredFiles()

        #expect(!FileManager.default.fileExists(atPath: diskURL.path))
    }

    @Test("TTL 미초과 파일은 cleanup 시 유지됨")
    func cleanupExpiredFiles_keepsValidFiles() async {
        let sut = makeSUT(ttl: 3600)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
        await sut.set(image, for: imageURL)

        await sut.cleanupExpiredFiles()

        let diskURL = tempDir.appendingPathComponent(cacheKey(for: imageURL))
        #expect(FileManager.default.fileExists(atPath: diskURL.path))
    }
}
