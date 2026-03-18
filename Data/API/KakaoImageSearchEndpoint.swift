//
//  KakaoImageSearchEndpoint.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//
//  ⚠️ API Key 설정 방법:
//  1. KakaoAPIKey.swift 파일을 프로젝트 루트에 생성 (gitignore 대상)
//  2. 아래 형식으로 작성:
//     enum KakaoAPIKey { static let restAPIKey = "YOUR_KAKAO_REST_API_KEY" }

import Foundation

enum KakaoImageSearchEndpoint: APIEndpoint, Sendable {
    /// - page: 결과 페이지 번호 (Kakao API 허용 범위: 1~15)
    /// - size: 한 페이지에 보여질 문서 수 (Kakao API 허용 범위: 1~30, 기본값 15)
    case searchImages(query: String, page: Int, size: Int = 30)

    var baseURL: String { "https://dapi.kakao.com" }

    var path: String { "/v2/search/image" }

    var method: HTTPMethod { .get }

    var headers: [String: String] {
        ["Authorization": "KakaoAK \(KakaoAPIKey.restAPIKey)"]
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case let .searchImages(query, page, size):
            let clampedQuery = String(query.prefix(256))
            let clampedPage = min(max(page, 1), 15)
            let clampedSize = min(max(size, 1), 30)
            return [
                URLQueryItem(name: "query", value: clampedQuery),
                URLQueryItem(name: "page", value: String(clampedPage)),
                URLQueryItem(name: "size", value: String(clampedSize))
            ]
        }
    }
}
