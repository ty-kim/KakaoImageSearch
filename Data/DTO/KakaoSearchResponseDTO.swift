//
//  KakaoSearchResponseDTO.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

struct KakaoSearchResponseDTO: @preconcurrency Decodable, Sendable {

    let meta: Meta
    let documents: [Document]

    nonisolated struct Meta: Decodable, Sendable {
        let totalCount: Int
        let pageableCount: Int
        let isEnd: Bool
    }

    nonisolated struct Document: Decodable, Sendable {
        let collection: String?
        let thumbnailUrl: String?
        let imageUrl: String?
        let width: Int?
        let height: Int?
        let displaySitename: String?
        let docUrl: String?
        let datetime: String?
    }
}

extension KakaoSearchResponseDTO.Document {
    func toImageItem() -> ImageItem? {
        // imageUrl이 없으면 식별자를 만들 수 없으므로 제외
        guard let imageUrl else { return nil }

        return ImageItem(
            id: imageUrl,
            imageURL: URL(string: imageUrl),
            thumbnailURL: URL(string: thumbnailUrl ?? ""),
            width: width,
            height: height,
            isBookmarked: false
        )
    }
}
