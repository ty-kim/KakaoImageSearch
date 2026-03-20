//
//  ImageDownloader.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import UIKit
import OSLog

/// actor 기반 자체 이미지 다운로더.
/// - 메모리/디스크 캐시 우선 조회
/// - 동일 URL 중복 요청 dedup 처리
/// - Content-Type image/* 검증, 최대 20 MB 제한
actor ImageDownloader: ImagePrefetcher, ImageDownloading {

    static let shared = ImageDownloader()

    /// 이미지 최대 허용 크기 (20 MB). 일반 CDN 썸네일/원본 기준 충분하며, 비정상 파일 조기 차단 목적
    nonisolated static let maxContentLength: Int64 = 20 * 1024 * 1024

    private let cache = ImageCache()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// prefetch 최대 동시 다운로드 수. URLSession 기본 호스트당 커넥션 풀(6)에 맞춤
    private nonisolated static let maxConcurrentPrefetches = 6

    /// 다음 페이지 썸네일을 백그라운드에서 병렬 선수 다운로드합니다.
    /// 캐시 히트 URL은 제외하고, 최대 동시 요청 수를 제한합니다.
    func prefetch(urls: [URL]) async {
        // 캐시 히트 제외
        var uncached: [URL] = []
        for url in urls {
            if await cache.get(for: url) == nil {
                uncached.append(url)
            }
        }

        guard !uncached.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            var running = 0

            for url in uncached {
                if running >= Self.maxConcurrentPrefetches {
                    await group.next()
                    running -= 1
                }
                group.addTask(priority: .background) {
                    _ = try? await self.download(from: url, priority: .background)
                }
                running += 1
            }
        }
    }

    /// ImageDownloading 프로토콜 준수 — priority 기본값(.userInitiated)으로 위임.
    func download(from url: URL) async throws -> UIImage {
        try await download(from: url, priority: .userInitiated)
    }

    /// Info.plist의 ATS 예외 도메인 목록을 런타임에 읽어 HTTP 허용 호스트로 사용합니다.
    /// Info.plist가 단일 소스가 되므로, ATS 예외 변경 시 코드 수정이 불필요합니다.
    nonisolated private static let httpExemptHosts: [String] = {
        guard let ats = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any],
              let domains = ats["NSExceptionDomains"] as? [String: Any] else {
            return []
        }
        return domains.keys.filter { domain in
            guard let config = domains[domain] as? [String: Any] else { return false }
            return config["NSExceptionAllowsInsecureHTTPLoads"] as? Bool == true
        }
    }()

    func download(from url: URL, priority: TaskPriority = .userInitiated) async throws -> UIImage {
        // http → https 변환 (ATS 예외 도메인은 HTTP 그대로 유지)
        let secureURL: URL
        if url.scheme == "http",
           let host = url.host,
           !Self.httpExemptHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }),
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

        // dedup 목적으로 생성하는 unstructured Task.
        // self 전체가 아닌 실제 필요한 session·cache만 명시적으로 캡처한다.
        let task = Task<UIImage, Error>(priority: priority) { [session = self.session, cache = self.cache] in
            let (bytes, response) = try await session.bytes(from: secureURL)

            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                Logger.imageLoader.errorPrint("Invalid response for: \(secureURL.absoluteString)")
                throw ImageDownloadError.invalidResponse
            }

            // Content-Type이 image/* 인지 검증 — nil이면 거부
            guard let mimeType = http.mimeType,
                  mimeType.hasPrefix("image/") else {
                let actual = http.mimeType ?? "nil"
                Logger.imageLoader.errorPrint("Non-image Content-Type '\(actual)' for: \(secureURL.lastPathComponent)")
                throw ImageDownloadError.notImageContentType
            }

            // Content-Length 헤더로 사전 검사 — 본문 수신 전 조기 중단
            let maxBytes = Int(ImageDownloader.maxContentLength)
            if http.expectedContentLength > 0,
               http.expectedContentLength > Int64(maxBytes) {
                Logger.imageLoader.errorPrint("Content-Length \(http.expectedContentLength) exceeds limit for: \(secureURL.lastPathComponent)")
                throw ImageDownloadError.contentLengthExceeded
            }

            // 스트리밍 수신 — 누적 크기가 상한을 넘으면 즉시 중단
            var data = Data()
            data.reserveCapacity(min(Int(http.expectedContentLength), maxBytes))
            for try await byte in bytes {
                data.append(byte)
                if data.count > maxBytes {
                    Logger.imageLoader.errorPrint("Download size \(data.count) exceeds limit for: \(secureURL.lastPathComponent)")
                    throw ImageDownloadError.contentLengthExceeded
                }
            }

            guard let image = UIImage(data: data) else {
                Logger.imageLoader.errorPrint("Invalid image data for: \(secureURL.lastPathComponent)")
                throw ImageDownloadError.invalidData
            }

            await cache.set(image, data: data, for: secureURL)
            Logger.imageLoader.debugPrint("Downloaded & cached: \(secureURL.lastPathComponent) (\(data.count) bytes)")
            return image
        }

        inFlight[secureURL] = task

        // 호출자 취소와 무관하게 task가 실제로 완료된 시점에 inFlight에서 제거.
        // actor 격리를 상속하는 unstructured Task로 cleanup을 예약한다.
        Task<Void, Never> {
            _ = await task.result
            inFlight.removeValue(forKey: secureURL)
        }

        return try await task.value
    }
}
