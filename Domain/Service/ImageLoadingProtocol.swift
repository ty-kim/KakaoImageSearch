//
//  ImageLoadingProtocol.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

// Domain은 UI 프레임워크를 모르는 것이 원칙이나, UIImage 하나만 예외로 통과시킨다.
// 디코딩된 비트맵을 메모리 캐시에 담는 것이 ImageDownloader의 존재 이유라
// Data로 낮추면 캐시가 매 호출 디코딩을 다시 하게 된다. 심볼 단위로 좁혀 경계를 드러낸다.
import Foundation
import class UIKit.UIImage

enum ImageDownloadError: Error {
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
}

/// 이미지 선수 다운로드 추상화. 테스트에서 Mock으로 교체 가능합니다.
protocol ImagePrefetcher: Sendable {
    func prefetch(urls: [URL]) async
}

/// 단일 이미지 다운로드 추상화. CachedAsyncImage의 @Environment 주입에 사용됩니다.
protocol ImageDownloading: Sendable {
    func download(from url: URL) async throws -> UIImage
}
