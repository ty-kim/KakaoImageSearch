//
//  KakaoSearchResponseDTO.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

struct KakaoSearchResponseDTO: Sendable {

    let meta: Meta
    let documents: [Document]

    // SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor 환경에서
    // 합성된 init(from:)이 @MainActor가 되어 NetworkService actor에서 크래시 발생.
    // nonisolated init(from:)을 직접 구현해 어느 actor에서도 디코딩 가능하게 합니다.
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meta      = try container.decode(Meta.self,       forKey: .meta)
        documents = try container.decode([Document].self, forKey: .documents)
    }

    private enum CodingKeys: String, CodingKey {
        case meta, documents
    }

    struct Meta: Sendable {
        let totalCount: Int
        let pageableCount: Int
        let isEnd: Bool

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            totalCount    = try c.decode(Int.self,  forKey: .totalCount)
            pageableCount = try c.decode(Int.self,  forKey: .pageableCount)
            isEnd         = try c.decode(Bool.self, forKey: .isEnd)
        }

        private enum CodingKeys: String, CodingKey {
            case totalCount, pageableCount, isEnd
        }
    }

    struct Document: Sendable {
        let collection: String?
        let thumbnailUrl: String?
        let imageUrl: String?
        let width: Int?
        let height: Int?
        let displaySitename: String?
        let docUrl: String?
        let datetime: String?

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            collection      = try c.decodeIfPresent(String.self, forKey: .collection)
            thumbnailUrl    = try c.decodeIfPresent(String.self, forKey: .thumbnailUrl)
            imageUrl        = try c.decodeIfPresent(String.self, forKey: .imageUrl)
            width           = try c.decodeIfPresent(Int.self,    forKey: .width)
            height          = try c.decodeIfPresent(Int.self,    forKey: .height)
            displaySitename = try c.decodeIfPresent(String.self, forKey: .displaySitename)
            docUrl          = try c.decodeIfPresent(String.self, forKey: .docUrl)
            datetime        = try c.decodeIfPresent(String.self, forKey: .datetime)
        }

        private enum CodingKeys: String, CodingKey {
            case collection, thumbnailUrl, imageUrl, width, height
            case displaySitename, docUrl, datetime
        }
    }
}

extension KakaoSearchResponseDTO: Decodable {}
extension KakaoSearchResponseDTO.Meta: Decodable {}
extension KakaoSearchResponseDTO.Document: Decodable {}

extension KakaoSearchResponseDTO.Document {
    func toImageItem() -> ImageItem? {
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
