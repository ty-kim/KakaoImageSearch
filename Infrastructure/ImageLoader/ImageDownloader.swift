//
//  ImageDownloader.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import UIKit
import OSLog

enum ImageDownloadError: Error, LocalizedError {
    case invalidResponse
    case invalidData
    case notImageContentType
    case contentLengthExceeded

    var errorDescription: String? {
        switch self {
        case .invalidResponse:       return L10n.ImageDownload.invalidResponse
        case .invalidData:           return L10n.ImageDownload.invalidData
        case .notImageContentType:   return L10n.ImageDownload.notImageContentType
        case .contentLengthExceeded: return L10n.ImageDownload.contentLengthExceeded
        }
    }
}

/// 이미지 선수 다운로드 추상화. 테스트에서 Mock으로 교체 가능합니다.
protocol ImagePrefetcher: Sendable {
    func prefetch(urls: [URL]) async
}

/// 단일 이미지 다운로드 추상화. CachedAsyncImage의 @Environment 주입에 사용됩니다.
protocol ImageDownloading: Sendable {
    func download(from url: URL) async throws -> UIImage
}

/// actor 기반 자체 이미지 다운로더.
/// - 메모리/디스크 캐시 우선 조회
/// - 동일 URL 중복 요청 dedup 처리
/// - Content-Type image/* 검증, 최대 10 MB 제한
actor ImageDownloader: ImagePrefetcher, ImageDownloading {

    static let shared = ImageDownloader()

    /// 썸네일 이미지 최대 허용 크기 (10 MB)
    nonisolated static let maxContentLength: Int64 = 10 * 1024 * 1024

    private let cache = ImageCache()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// prefetch 최대 동시 다운로드 수
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

        // dedup 목적으로 생성하는 unstructured Task.
        // self 전체가 아닌 실제 필요한 session·cache만 명시적으로 캡처한다.
        let task = Task<UIImage, Error>(priority: priority) { [session = self.session, cache = self.cache] in
            let (data, response) = try await session.data(from: secureURL)

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

            // 다운로드된 데이터 크기가 상한을 초과하면 거부
            if data.count > ImageDownloader.maxContentLength {
                Logger.imageLoader.errorPrint("Content length \(data.count) exceeds limit for: \(secureURL.lastPathComponent)")
                throw ImageDownloadError.contentLengthExceeded
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
        // defer는 이 download() 호출의 첫 번째 호출자(Caller A) 컨텍스트가 끝날 때 실행됨.
        // 내부 task는 unstructured이므로 Caller A가 취소되어도 task 자체는 계속 실행되며,
        // 이미 existing.value를 await 중인 다른 호출자(Caller B)는 정상적으로 결과를 받음.
        // 단, Caller A 취소 후 inFlight에서 제거된 상태에서 새 호출자(Caller C)가 들어오면
        // task가 아직 실행 중이더라도 중복 요청이 발생할 수 있음. 이미지 로더 특성상 허용된 트레이드오프.
        defer { inFlight.removeValue(forKey: secureURL) }

        return try await task.value
    }
}
