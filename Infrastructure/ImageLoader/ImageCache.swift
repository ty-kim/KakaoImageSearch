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
    // init/deinit에서만 접근 — init은 actor 노출 전 단일 스레드, deinit은 마지막 참조.
    // 실제 데이터 레이스 없으므로 nonisolated(unsafe) 선언.
    nonisolated(unsafe) private var memoryWarningTask: Task<Void, Never>?

    init(diskCacheURL: URL? = nil) {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.diskCacheURL = diskCacheURL ?? caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: self.diskCacheURL, withIntermediateDirectories: true)

        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50 MB

        // [weak self] 캡처로 순환 참조 방지. ImageCache 해제 시 deinit에서 Task를 취소해
        // for-await 루프를 종료하고 NotificationCenter 구독을 정리한다.
        memoryWarningTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didReceiveMemoryWarningNotification) {
                guard let self else { return }
                await self.clearMemoryCache()
            }
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
                memoryCache.setObject(image, forKey: key as NSString)
                return image
            } else {
                // 데이터는 읽혔지만 이미지 디코딩 실패 → 손상된 파일 삭제해 반복 미스 방지
                try? fileManager.removeItem(at: diskURL)
                Logger.imageLoader.errorPrint("Corrupt disk cache removed: \(diskURL.lastPathComponent)")
            }
        }

        return nil
    }

    func set(_ image: UIImage, for url: URL) {
        let key = cacheKey(for: url)
        memoryCache.setObject(image, forKey: key as NSString)

        let diskURL = diskCacheURL.appendingPathComponent(key)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: diskURL, options: .atomic)
        }
    }

    private func cacheKey(for url: URL) -> String {
        url.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics)
            ?? url.lastPathComponent
    }
}
