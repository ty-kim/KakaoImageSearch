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
        let isEnd: Bool

        nonisolated init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            totalCount = try c.decode(Int.self,  forKey: .totalCount)
            isEnd      = try c.decode(Bool.self, forKey: .isEnd)
        }

        private enum CodingKeys: String, CodingKey {
            case totalCount, isEnd
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

struct KakaoErrorResponseDTO: Decodable, Sendable {
    let errorType: String
    let message: String
}

extension KakaoSearchResponseDTO: Decodable {}
extension KakaoSearchResponseDTO.Meta: Decodable {}
extension KakaoSearchResponseDTO.Document: Decodable {}

extension KakaoSearchResponseDTO.Document {

    private static let allowedSchemes: Set<String> = ["http", "https"]

    private static func isSafeURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme) else {
            return false
        }
        return true
    }

    nonisolated(unsafe) private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func toImageItem() -> ImageItem? {
        guard let imageUrl,
              let imageURL = URL(string: imageUrl),
              Self.isSafeURL(imageURL) else {
            return nil
        }

        let thumbnailURL = thumbnailUrl
            .flatMap(URL.init(string:))
            .flatMap { Self.isSafeURL($0) ? $0 : nil }

        let parsedDate = datetime.flatMap { Self.iso8601Formatter.date(from: $0) }

        return ImageItem(
            id: imageUrl,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            width: width,
            height: height,
            displaySitename: displaySitename,
            datetime: parsedDate,
            isBookmarked: false
        )
    }
}
