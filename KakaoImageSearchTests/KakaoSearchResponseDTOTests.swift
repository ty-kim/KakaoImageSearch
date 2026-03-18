//
//  KakaoSearchResponseDTOTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/16/26.
//

import Testing
import Foundation
@testable import KakaoImageSearch

@MainActor
@Suite("KakaoSearchResponseDTO 디코딩 테스트")
struct KakaoSearchResponseDTOTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - 전체 구조 디코딩

    @Test("전체 필드가 있는 JSON을 올바르게 디코딩한다")
    func decode_fullFields_allValuesCorrect() throws {
        let json = """
        {
            "meta": { "total_count": 422, "pageable_count": 100, "is_end": false },
            "documents": [
                {
                    "collection": "blog",
                    "thumbnail_url": "https://example.com/thumb.jpg",
                    "image_url": "https://example.com/image.jpg",
                    "width": 1280,
                    "height": 720,
                    "display_sitename": "Example Blog",
                    "doc_url": "https://example.com/post",
                    "datetime": "2024-01-01T00:00:00.000+09:00"
                }
            ]
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(KakaoSearchResponseDTO.self, from: json)

        #expect(dto.meta.totalCount == 422)
        #expect(dto.meta.pageableCount == 100)
        #expect(dto.meta.isEnd == false)
        #expect(dto.documents.count == 1)

        let doc = dto.documents[0]
        #expect(doc.collection == "blog")
        #expect(doc.imageUrl == "https://example.com/image.jpg")
        #expect(doc.thumbnailUrl == "https://example.com/thumb.jpg")
        #expect(doc.width == 1280)
        #expect(doc.height == 720)
        #expect(doc.displaySitename == "Example Blog")
        #expect(doc.docUrl == "https://example.com/post")
        #expect(doc.datetime == "2024-01-01T00:00:00.000+09:00")
    }

    @Test("선택 필드가 없는 JSON도 디코딩에 성공한다")
    func decode_missingOptionalFields_decodesSuccessfully() throws {
        let json = """
        {
            "meta": { "total_count": 1, "pageable_count": 1, "is_end": true },
            "documents": [
                { "image_url": "https://example.com/image.jpg" }
            ]
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(KakaoSearchResponseDTO.self, from: json)
        let doc = dto.documents[0]

        #expect(doc.imageUrl == "https://example.com/image.jpg")
        #expect(doc.thumbnailUrl == nil)
        #expect(doc.width == nil)
        #expect(doc.height == nil)
        #expect(doc.collection == nil)
    }

    @Test("documents가 빈 배열인 JSON도 디코딩에 성공한다")
    func decode_emptyDocuments_decodesSuccessfully() throws {
        let json = """
        {
            "meta": { "total_count": 0, "pageable_count": 0, "is_end": true },
            "documents": []
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(KakaoSearchResponseDTO.self, from: json)

        #expect(dto.documents.isEmpty)
        #expect(dto.meta.isEnd == true)
        #expect(dto.meta.totalCount == 0)
    }

    // MARK: - Meta 디코딩

    @Test("meta의 is_end가 true인 경우 올바르게 디코딩된다")
    func decode_metaIsEnd_true() throws {
        let json = """
        {
            "meta": { "total_count": 10, "pageable_count": 10, "is_end": true },
            "documents": []
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(KakaoSearchResponseDTO.self, from: json)
        #expect(dto.meta.isEnd == true)
    }

    // MARK: - toImageItem 변환

    @Test("imageUrl이 있는 Document는 ImageItem으로 변환된다")
    func toImageItem_withImageUrl_returnsItem() throws {
        let json = """
        {
            "meta": { "total_count": 1, "pageable_count": 1, "is_end": false },
            "documents": [{
                "image_url": "https://example.com/image.jpg",
                "thumbnail_url": "https://example.com/thumb.jpg",
                "width": 800,
                "height": 600
            }]
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(KakaoSearchResponseDTO.self, from: json)
        let item = try #require(dto.documents[0].toImageItem())

        #expect(item.id == "https://example.com/image.jpg")
        #expect(item.imageURL == URL(string: "https://example.com/image.jpg"))
        #expect(item.thumbnailURL == URL(string: "https://example.com/thumb.jpg"))
        #expect(item.width == 800)
        #expect(item.height == 600)
        #expect(item.isBookmarked == false)
    }

    @Test("imageUrl이 nil인 Document는 toImageItem이 nil을 반환한다")
    func toImageItem_nilImageUrl_returnsNil() throws {
        let json = """
        {
            "meta": { "total_count": 1, "pageable_count": 1, "is_end": false },
            "documents": [{ "thumbnail_url": "https://example.com/thumb.jpg" }]
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(KakaoSearchResponseDTO.self, from: json)
        #expect(dto.documents[0].toImageItem() == nil)
    }

    @Test("imageUrl이 nil인 documents는 compactMap으로 필터링된다")
    func toImageItem_mixedDocuments_nilsFiltered() throws {
        let json = """
        {
            "meta": { "total_count": 3, "pageable_count": 3, "is_end": false },
            "documents": [
                { "image_url": "https://example.com/1.jpg" },
                { "thumbnail_url": "https://only-thumb.jpg" },
                { "image_url": "https://example.com/2.jpg" }
            ]
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(KakaoSearchResponseDTO.self, from: json)
        let items = dto.documents.compactMap { $0.toImageItem() }

        #expect(items.count == 2)
        #expect(items.map(\.id) == ["https://example.com/1.jpg", "https://example.com/2.jpg"])
    }

    @Test("thumbnailUrl이 빈 문자열인 경우 thumbnailURL은 nil이 된다")
    func toImageItem_emptyThumbnailUrl_returnsNil() throws {
        let json = """
        {
            "meta": { "total_count": 1, "pageable_count": 1, "is_end": false },
            "documents": [{ "image_url": "https://example.com/img.jpg", "thumbnail_url": "" }]
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(KakaoSearchResponseDTO.self, from: json)
        let item = try #require(dto.documents[0].toImageItem())

        #expect(item.thumbnailURL == nil)
    }

    // MARK: - URL 스킴 검증

    @Test("javascript: 스킴의 imageUrl은 toImageItem이 nil을 반환한다")
    func toImageItem_javascriptScheme_returnsNil() throws {
        let json = """
        {
            "meta": { "total_count": 1, "pageable_count": 1, "is_end": false },
            "documents": [{ "image_url": "javascript:alert('xss')" }]
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(KakaoSearchResponseDTO.self, from: json)
        #expect(dto.documents[0].toImageItem() == nil)
    }

    @Test("file: 스킴의 imageUrl은 toImageItem이 nil을 반환한다")
    func toImageItem_fileScheme_returnsNil() throws {
        let json = """
        {
            "meta": { "total_count": 1, "pageable_count": 1, "is_end": false },
            "documents": [{ "image_url": "file:///etc/passwd" }]
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(KakaoSearchResponseDTO.self, from: json)
        #expect(dto.documents[0].toImageItem() == nil)
    }

    @Test("http 스킴의 imageUrl은 유효한 ImageItem을 반환한다")
    func toImageItem_httpScheme_returnsItem() throws {
        let json = """
        {
            "meta": { "total_count": 1, "pageable_count": 1, "is_end": false },
            "documents": [{ "image_url": "http://example.com/image.jpg" }]
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(KakaoSearchResponseDTO.self, from: json)
        let item = dto.documents[0].toImageItem()
        #expect(item != nil)
    }

    @Test("javascript: 스킴의 thumbnailUrl은 nil로 처리된다")
    func toImageItem_javascriptThumbnail_returnsNilThumbnail() throws {
        let json = """
        {
            "meta": { "total_count": 1, "pageable_count": 1, "is_end": false },
            "documents": [{
                "image_url": "https://example.com/image.jpg",
                "thumbnail_url": "javascript:void(0)"
            }]
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(KakaoSearchResponseDTO.self, from: json)
        let item = try #require(dto.documents[0].toImageItem())

        #expect(item.imageURL != nil)
        #expect(item.thumbnailURL == nil)
    }
}
