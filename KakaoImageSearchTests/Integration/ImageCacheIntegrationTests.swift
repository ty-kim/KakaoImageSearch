//
//  ImageCacheIntegrationTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/18/26.
//

import Testing
import UIKit
import CryptoKit
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

    private func makeSUT(ttl: TimeInterval = 7 * 24 * 60 * 60, maxDiskBytes: Int = 200 * 1024 * 1024) -> ImageCache {
        ImageCache(diskCacheURL: tempDir, ttl: ttl, maxDiskBytes: maxDiskBytes)
    }

    /// cacheKey(for:) private 메서드와 동일한 로직
    private func cacheKey(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
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
        let validData = validImage.pngData()!
        await sut.set(validImage, data: validData, for: imageURL)

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
        let imageData = image.pngData()!
        await sut.set(image, data: imageData, for: imageURL)

        await sut.cleanupExpiredFiles()

        let diskURL = tempDir.appendingPathComponent(cacheKey(for: imageURL))
        #expect(FileManager.default.fileExists(atPath: diskURL.path))
    }

    // MARK: - 디스크 용량 제한

    @Test("총 용량이 maxDiskBytes를 초과하면 오래된 파일부터 삭제된다")
    func cleanupExpiredFiles_exceedingMaxSize_removesOldestFirst() async {
        // maxDiskBytes를 100바이트로 설정해 초과를 유도
        let sut = makeSUT(maxDiskBytes: 100)

        let url1 = URL(string: "https://example.com/old.jpg")!
        let url2 = URL(string: "https://example.com/new.jpg")!

        // old 파일 생성 후 수정 날짜를 과거로 조작
        let oldDisk = tempDir.appendingPathComponent(cacheKey(for: url1))
        try? Data(repeating: 0xAA, count: 60).write(to: oldDisk)
        try? FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -3600)],
            ofItemAtPath: oldDisk.path
        )

        // new 파일 생성 (현재 시각)
        let newDisk = tempDir.appendingPathComponent(cacheKey(for: url2))
        try? Data(repeating: 0xBB, count: 60).write(to: newDisk)

        // 총 120바이트 > maxDiskBytes(100) → old 파일이 먼저 삭제됨
        await sut.cleanupExpiredFiles()

        #expect(!FileManager.default.fileExists(atPath: oldDisk.path))
        #expect(FileManager.default.fileExists(atPath: newDisk.path))
    }

    @Test("총 용량이 maxDiskBytes 이하이면 파일이 유지된다")
    func cleanupExpiredFiles_withinMaxSize_keepsAllFiles() async {
        // maxDiskBytes를 넉넉하게 설정
        let sut = makeSUT(maxDiskBytes: 10_000)

        let url1 = URL(string: "https://example.com/a.jpg")!
        let disk1 = tempDir.appendingPathComponent(cacheKey(for: url1))
        try? Data(repeating: 0xAA, count: 60).write(to: disk1)

        await sut.cleanupExpiredFiles()

        #expect(FileManager.default.fileExists(atPath: disk1.path))
    }
}
