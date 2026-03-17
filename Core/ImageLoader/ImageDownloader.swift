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

/// 이미지 선수 다운로드 추상화. 테스트에서 Mock으로 교체 가능합니다.
protocol ImagePrefetcher: Sendable {
    func prefetch(urls: [URL]) async
}

/// actor 기반 자체 이미지 다운로더.
/// - 메모리/디스크 캐시 우선 조회
/// - 동일 URL 중복 요청 dedup 처리
actor ImageDownloader: ImagePrefetcher {

    static let shared = ImageDownloader()

    private let cache = ImageCache()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    private init() {}

    /// 다음 페이지 썸네일을 백그라운드에서 병렬 선수 다운로드합니다.
    /// 캐시에 이미 있는 URL은 건너뜁니다.
    func prefetch(urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask(priority: .background) {
                    _ = try? await self.download(from: url, priority: .background)
                }
            }
        }
    }

    func download(from url: URL, priority: TaskPriority = .userInitiated) async throws -> UIImage {
        // http → https 변환 (daum.net / naver.net 은 ATS 예외로 처리하므로 제외)
        let secureURL: URL
        let httpExemptHosts = ["daum.net", "naver.net"]
        if url.scheme == "http",
           let host = url.host,
           !httpExemptHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }),
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.scheme = "https"
            secureURL = components.url ?? url
        } else {
            secureURL = url
        }

        // 1. 캐시 히트
        if let cached = await cache.get(for: secureURL) {
            Logger.imageLoader.debugPrint("Cache hit: \(url.lastPathComponent)")
            return cached
        }

        // 2. 동일 URL 진행 중인 요청 재사용
        if let existing = inFlight[secureURL] {
            Logger.imageLoader.debugPrint("Reusing in-flight request: \(secureURL.lastPathComponent)")
            return try await existing.value
        }

        // 3. 신규 요청
        Logger.imageLoader.debugPrint("Downloading: \(secureURL.lastPathComponent)")

        let task = Task<UIImage, Error>(priority: priority) {
            let (data, response) = try await URLSession.shared.data(from: secureURL)

            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                Logger.imageLoader.errorPrint("Invalid response for: \(secureURL.absoluteString)")
                throw ImageDownloadError.invalidResponse
            }

            guard let image = UIImage(data: data) else {
                Logger.imageLoader.errorPrint("Invalid image data for: \(secureURL.lastPathComponent)")
                throw ImageDownloadError.invalidData
            }

            await cache.set(image, for: secureURL)
            Logger.imageLoader.debugPrint("Downloaded & cached: \(secureURL.lastPathComponent) (\(data.count) bytes)")
            return image
        }

        inFlight[secureURL] = task
        defer { inFlight.removeValue(forKey: secureURL) }

        return try await task.value
    }
}
