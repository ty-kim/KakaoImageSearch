//
//  ImageLoadingProtocol.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import UIKit

enum ImageDownloadError: Error, LocalizedError {
    case notFound
    case invalidResponse
    case invalidData
    case notImageContentType
    case contentLengthExceeded

    var isRetryable: Bool {
        switch self {
        case .notFound:              return false
        case .invalidResponse:       return true
        case .invalidData:           return true
        case .notImageContentType:   return false
        case .contentLengthExceeded: return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .notFound:              return String(localized: "image_download.error.not_found")
        case .invalidResponse:       return String(localized: "image_download.error.invalid_response")
        case .invalidData:           return String(localized: "image_download.error.invalid_data")
        case .notImageContentType:   return String(localized: "image_download.error.not_image_content_type")
        case .contentLengthExceeded: return String(localized: "image_download.error.content_length_exceeded")
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
