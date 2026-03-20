//
//  ImageCache.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import UIKit
import OSLog

/// 메모리(NSCache) + 디스크 2단계 이미지 캐시.
/// actor로 선언해 Swift 6 기본 MainActor 격리 충돌을 방지하고 스레드 안전성을 보장합니다.
actor ImageCache {

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let diskCacheURL: URL
    private let ttl: TimeInterval
    private let maxDiskBytes: Int
    // init/deinit에서만 접근 — init은 actor 노출 전 단일 스레드, deinit은 마지막 참조.
    // 실제 데이터 레이스 없으므로 nonisolated(unsafe) 선언.
    nonisolated(unsafe) private var memoryWarningTask: Task<Void, Never>?

    /// - maxDiskBytes: 디스크 캐시 최대 용량 (기본 200 MB)
    init(diskCacheURL: URL? = nil, ttl: TimeInterval = 7 * 24 * 60 * 60, maxDiskBytes: Int = 200 * 1024 * 1024) {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.diskCacheURL = diskCacheURL ?? caches.appendingPathComponent("ImageCache", isDirectory: true)
        self.ttl = ttl
        self.maxDiskBytes = maxDiskBytes
        do {
            try fileManager.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)
        } catch {
            Logger.imageLoader.errorPrint("Failed to create image cache directory: \(error)")
        }

        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 150 * 1024 * 1024 // 150 MB

        // [weak self] 캡처로 순환 참조 방지. ImageCache 해제 시 deinit에서 Task를 취소해
        // for-await 루프를 종료하고 NotificationCenter 구독을 정리한다.
        memoryWarningTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didReceiveMemoryWarningNotification) {
                guard let self else { return }
                await self.clearMemoryCache()
            }
        }

        // 앱 시작 시 만료된 디스크 캐시 파일을 백그라운드에서 정리
        Task(priority: .background) { [weak self] in
            await self?.cleanupExpiredFiles()
        }
    }

    deinit {
        memoryWarningTask?.cancel()
    }

    /// 메모리 경고 수신 시 NSCache를 비워 RAM을 즉시 확보합니다.
    /// 디스크 캐시는 유지해 재접근 시 네트워크 없이 복구할 수 있도록 합니다.
    private func clearMemoryCache() {
        memoryCache.removeAllObjects()
        Logger.imageLoader.debugPrint("Memory cache cleared (memory warning)")
    }

    func get(for url: URL) -> UIImage? {
        let key = cacheKey(for: url)

        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }

        let diskURL = diskCacheURL.appendingPathComponent(key)
        if let data = try? Data(contentsOf: diskURL) {
            if let image = UIImage(data: data) {
                memoryCache.setObject(image, forKey: key as NSString, cost: estimatedCost(of: image))
                return image
            } else {
                // 데이터는 읽혔지만 이미지 디코딩 실패 → 손상된 파일 삭제해 반복 미스 방지
                do {
                    try fileManager.removeItem(at: diskURL)
                    Logger.imageLoader.errorPrint("Corrupt disk cache removed: \(diskURL.lastPathComponent)")
                } catch {
                    Logger.imageLoader.errorPrint("Failed to remove corrupt cache: \(error)")
                }
            }
        }

        return nil
    }

    func set(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        memoryCache.setObject(image, forKey: key as NSString, cost: estimatedCost(of: image))

        let diskURL = diskCacheURL.appendingPathComponent(key)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: diskURL, options: [.atomic, .completeFileProtection])
        }
    }

    /// TTL이 지난 파일을 삭제한 뒤, 총 용량이 상한을 넘으면 오래된 파일부터 추가 삭제합니다.
    /// 앱 시작 시 자동으로 background 우선순위로 실행되며, 테스트에서 직접 호출도 가능합니다.
    func cleanupExpiredFiles() {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]

        guard let contents = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: Array(keys),
            options: .skipsHiddenFiles
        ) else { return }

        // 1단계: TTL 초과 파일 삭제
        let expiredBefore = Date().addingTimeInterval(-ttl)
        var surviving: [(url: URL, date: Date, size: Int)] = []
        var removedCount = 0

        for fileURL in contents {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  let modDate = values.contentModificationDate,
                  let size = values.fileSize else { continue }

            if modDate < expiredBefore {
                do {
                    try fileManager.removeItem(at: fileURL)
                    removedCount += 1
                } catch {
                    Logger.imageLoader.errorPrint("Failed to remove expired cache: \(error)")
                }
            } else {
                surviving.append((fileURL, modDate, size))
            }
        }

        // 2단계: 총 용량이 상한을 넘으면 오래된 파일부터 삭제 (LRU)
        var totalSize = surviving.reduce(0) { $0 + $1.size }
        if totalSize > maxDiskBytes {
            surviving.sort { $0.date < $1.date }
            for file in surviving {
                guard totalSize > maxDiskBytes else { break }
                do {
                    try fileManager.removeItem(at: file.url)
                    totalSize -= file.size
                    removedCount += 1
                } catch {
                    Logger.imageLoader.errorPrint("Failed to remove LRU cache: \(error)")
                }
            }
        }

        if removedCount > 0 {
            Logger.imageLoader.debugPrint("Disk cache cleanup: \(removedCount) files removed, \(totalSize) bytes remaining")
        }
    }

    /// 비트맵 기준 메모리 바이트 수를 추정합니다. NSCache의 totalCostLimit 적용에 사용됩니다.
    private nonisolated func estimatedCost(of image: UIImage) -> Int {
        Int(image.size.width * image.size.height * image.scale * image.scale * 4)
    }

    private func cacheKey(for url: URL) -> String {
        url.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics)
            ?? url.lastPathComponent
    }
}
