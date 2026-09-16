//
//  ImageDownloadError+Message.swift
//  KakaoImageSearch
//
//  Created by tykim
//

import Foundation

/// 사용자 대면 문구는 Presentation 책임이다.
/// Domain의 ImageDownloadError는 재시도 가능 여부(도메인 정책)만 안다.
extension ImageDownloadError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFound:              return String(localized: "image_download.error.not_found")
        case .invalidResponse:       return String(localized: "image_download.error.invalid_response")
        case .invalidData:           return String(localized: "image_download.error.invalid_data")
        case .notImageContentType:   return String(localized: "image_download.error.not_image_content_type")
        case .contentLengthExceeded: return String(localized: "image_download.error.content_length_exceeded")
        }
    }
}
