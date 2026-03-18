//
//  ImageItemTests.swift
//  KakaoImageSearchTests
//
//  Created by tykim on 3/16/26.
//

import Testing
import Foundation
@testable import KakaoImageSearch

@MainActor
@Suite("ImageItem")
struct ImageItemTests {

    // MARK: - aspectRatio

    @Test("width·height 모두 유효하면 height/width 반환")
    func aspectRatio_validDimensions() {
        let item = ImageItem.fixture(width: 800, height: 600)
        #expect(item.aspectRatio == 600.0 / 800.0)
    }

    @Test("width가 nil이면 1.0 반환")
    func aspectRatio_nilWidth() {
        let item = ImageItem.fixture(width: nil, height: 600)
        #expect(item.aspectRatio == 1.0)
    }

    @Test("height가 nil이면 1.0 반환")
    func aspectRatio_nilHeight() {
        let item = ImageItem.fixture(width: 800, height: nil)
        #expect(item.aspectRatio == 1.0)
    }

    @Test("width가 0이면 1.0 반환 (zero-division 방어)")
    func aspectRatio_zeroWidth() {
        let item = ImageItem.fixture(width: 0, height: 600)
        #expect(item.aspectRatio == 1.0)
    }

    @Test("정사각형 이미지는 1.0 반환")
    func aspectRatio_square() {
        let item = ImageItem.fixture(width: 500, height: 500)
        #expect(item.aspectRatio == 1.0)
    }

    @Test("width·height 모두 nil이면 1.0 반환")
    func aspectRatio_bothNil() {
        let item = ImageItem.fixture(width: nil, height: nil)
        #expect(item.aspectRatio == 1.0)
    }

    // MARK: - Codable

    @Test("Codable 라운드트립: encode → decode 시 모든 필드 보존")
    func codable_roundTrip() throws {
        let original = ImageItem.fixture(
            id: "rt-001",
            imageURL: URL(string: "https://example.com/img.jpg"),
            thumbnailURL: URL(string: "https://example.com/thumb.jpg"),
            width: 1920,
            height: 1080,
            isBookmarked: true
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ImageItem.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.imageURL == original.imageURL)
        #expect(decoded.thumbnailURL == original.thumbnailURL)
        #expect(decoded.width == original.width)
        #expect(decoded.height == original.height)
        #expect(decoded.isBookmarked == original.isBookmarked)
    }

    @Test("Codable 라운드트립: optional 필드 nil 보존")
    func codable_roundTrip_nilFields() throws {
        let original = ImageItem.fixture(imageURL: nil, thumbnailURL: nil, width: nil, height: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageItem.self, from: data)

        #expect(decoded.imageURL == nil)
        #expect(decoded.thumbnailURL == nil)
        #expect(decoded.width == nil)
        #expect(decoded.height == nil)
    }

    // MARK: - listDisplayURL / detailDisplayURL

    @Test("thumbnailURL 있으면 listDisplayURL = thumbnailURL")
    func listDisplayURL_thumbnailPresent() {
        let thumb = URL(string: "https://example.com/thumb.jpg")!
        let item = ImageItem.fixture(thumbnailURL: thumb)
        #expect(item.listDisplayURL == thumb)
    }

    @Test("thumbnailURL nil이면 listDisplayURL = imageURL")
    func listDisplayURL_thumbnailNil_fallsBackToImageURL() {
        let image = URL(string: "https://example.com/image.jpg")!
        let item = ImageItem.fixture(imageURL: image, thumbnailURL: nil)
        #expect(item.listDisplayURL == image)
    }

    @Test("imageURL·thumbnailURL 모두 nil이면 listDisplayURL = nil")
    func listDisplayURL_bothNil() {
        let item = ImageItem.fixture(imageURL: nil, thumbnailURL: nil)
        #expect(item.listDisplayURL == nil)
    }

    @Test("imageURL 있으면 detailDisplayURL = imageURL")
    func detailDisplayURL_imageURLPresent() {
        let image = URL(string: "https://example.com/image.jpg")!
        let item = ImageItem.fixture(imageURL: image)
        #expect(item.detailDisplayURL == image)
    }

    @Test("imageURL nil이면 detailDisplayURL = thumbnailURL")
    func detailDisplayURL_imageURLNil_fallsBackToThumbnailURL() {
        let thumb = URL(string: "https://example.com/thumb.jpg")!
        let item = ImageItem.fixture(imageURL: nil, thumbnailURL: thumb)
        #expect(item.detailDisplayURL == thumb)
    }

    @Test("imageURL·thumbnailURL 모두 nil이면 detailDisplayURL = nil")
    func detailDisplayURL_bothNil() {
        let item = ImageItem.fixture(imageURL: nil, thumbnailURL: nil)
        #expect(item.detailDisplayURL == nil)
    }

    // MARK: - Hashable / Equatable

    @Test("모든 프로퍼티가 동일한 아이템은 같은 해시값")
    func hashable_sameProperties() {
        let a = ImageItem.fixture(id: "same")
        let b = ImageItem.fixture(id: "same")
        #expect(a.hashValue == b.hashValue)
    }

    @Test("모든 프로퍼티가 동일한 아이템은 Set에 중복 추가 불가")
    func hashable_setDedup() {
        let a = ImageItem.fixture(id: "dup")
        let b = ImageItem.fixture(id: "dup")
        let set: Set<ImageItem> = [a, b]
        #expect(set.count == 1)
    }

    @Test("isBookmarked가 다르면 동일 id라도 다른 아이템으로 취급")
    func hashable_differentBookmarkState() {
        let a = ImageItem.fixture(id: "same", isBookmarked: false)
        let b = ImageItem.fixture(id: "same", isBookmarked: true)
        #expect(a != b)
        let set: Set<ImageItem> = [a, b]
        #expect(set.count == 2)
    }
}
