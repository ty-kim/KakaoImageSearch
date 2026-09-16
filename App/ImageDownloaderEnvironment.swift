//
//  ImageDownloaderEnvironment.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/20/26.
//

import SwiftUI
import UIKit
import OSLog

/// 주입이 누락된 경우에만 쓰이는 대체 다운로더. 네트워크를 타지 않는다.
/// 프로덕션은 KakaoImageSearchApp에서, 프리뷰는 각 #Preview에서 주입한다.
/// 실제 다운로더를 기본값으로 두면 주입을 빠뜨려도 이미지가 그냥 떠서,
/// 화면과 프리페처가 서로 다른 인스턴스를 쓰는 사고가 조용히 지나간다.
private struct UnconfiguredImageDownloader: ImageDownloading {
    func download(from url: URL) async throws -> UIImage {
        Logger.imageLoader.errorPrint("imageDownloader 미주입: \(url.lastPathComponent)")
        // 재시도 대상이 아닌 케이스를 던져 즉시 permanentFailure로 끝낸다.
        throw ImageDownloadError.notFound
    }
}

private struct ImageDownloaderKey: EnvironmentKey {
    static let defaultValue: any ImageDownloading = UnconfiguredImageDownloader()
}

extension EnvironmentValues {
    var imageDownloader: any ImageDownloading {
        get { self[ImageDownloaderKey.self] }
        set { self[ImageDownloaderKey.self] = newValue }
    }
}
