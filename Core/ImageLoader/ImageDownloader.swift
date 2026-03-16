//
//  ImageDownloader.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import UIKit
import OSLog

enum ImageDownloadError: Error {
    case invalidResponse
    case invalidData
}

/// actor 기반 자체 이미지 다운로더.
/// - 메모리/디스크 캐시 우선 조회
/// - 동일 URL 중복 요청 dedup 처리
actor ImageDownloader {

    static let shared = ImageDownloader()

    private let cache = ImageCache()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    private init() {}

    func download(from url: URL) async throws -> UIImage {
        // 1. 캐시 히트
        if let cached = await cache.get(for: url) {
            Logger.imageLoader.debugPrint("Cache hit: \(url.lastPathComponent)")
            return cached
        }

        // 2. 동일 URL 진행 중인 요청 재사용
        if let existing = inFlight[url] {
            Logger.imageLoader.debugPrint("Reusing in-flight request: \(url.lastPathComponent)")
            return try await existing.value
        }

        // 3. 신규 요청
        Logger.imageLoader.debugPrint("Downloading: \(url.lastPathComponent)")

        let task = Task<UIImage, Error> {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                Logger.imageLoader.errorPrint("Invalid response for: \(url.lastPathComponent)")
                throw ImageDownloadError.invalidResponse
            }

            guard let image = UIImage(data: data) else {
                Logger.imageLoader.errorPrint("Invalid image data for: \(url.lastPathComponent)")
                throw ImageDownloadError.invalidData
            }

            await cache.set(image, for: url)
            Logger.imageLoader.debugPrint("Downloaded & cached: \(url.lastPathComponent) (\(data.count) bytes)")
            return image
        }

        inFlight[url] = task
        defer { inFlight.removeValue(forKey: url) }

        return try await task.value
    }
}
