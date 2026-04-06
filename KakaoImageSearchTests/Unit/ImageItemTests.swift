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
            displaySitename: "Example Blog",
            datetime: Date(timeIntervalSince1970: 1704067200),
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
        #expect(decoded.displaySitename == original.displaySitename)
        #expect(decoded.datetime == original.datetime)
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
        #expect(decoded.displaySitename == nil)
        #expect(decoded.datetime == nil)
    }

    // MARK: - displayURL

    @Test("imageURL 있으면 displayURL = imageURL")
    func displayURL_imageURLPresent() {
        let image = URL(string: "https://example.com/image.jpg")!
        let item = ImageItem.fixture(imageURL: image)
        #expect(item.displayURL == image)
    }

    @Test("imageURL nil이면 displayURL = thumbnailURL")
    func displayURL_imageURLNil_fallsBackToThumbnailURL() {
        let thumb = URL(string: "https://example.com/thumb.jpg")!
        let item = ImageItem.fixture(imageURL: nil, thumbnailURL: thumb)
        #expect(item.displayURL == thumb)
    }

    @Test("imageURL·thumbnailURL 모두 nil이면 displayURL = nil")
    func displayURL_bothNil() {
        let item = ImageItem.fixture(imageURL: nil, thumbnailURL: nil)
        #expect(item.displayURL == nil)
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

    // MARK: - displaySitename

    @Test("displaySitename이 설정되면 해당 값을 반환한다")
    func displaySitename_returnsValue() {
        let item = ImageItem.fixture(displaySitename: "Naver Blog")
        #expect(item.displaySitename == "Naver Blog")
    }

    @Test("displaySitename 기본값은 nil이다")
    func displaySitename_defaultNil() {
        let item = ImageItem.fixture()
        #expect(item.displaySitename == nil)
    }

    // MARK: - datetime

    @Test("datetime이 설정되면 해당 값을 반환한다")
    func datetime_returnsValue() {
        let date = Date(timeIntervalSince1970: 1704067200) // 2024-01-01T00:00:00Z
        let item = ImageItem.fixture(datetime: date)
        #expect(item.datetime == date)
    }

    @Test("datetime 기본값은 nil이다")
    func datetime_defaultNil() {
        let item = ImageItem.fixture()
        #expect(item.datetime == nil)
    }

    // MARK: - relativeTimeString

    @Test("datetime이 nil이면 relativeTimeString은 nil")
    func relativeTimeString_nilDatetime() {
        let item = ImageItem.fixture(datetime: nil)
        #expect(item.relativeTimeString == nil)
    }

    @Test("datetime이 있으면 relativeTimeString은 비어있지 않은 문자열")
    func relativeTimeString_withDatetime() {
        let date = Date(timeIntervalSinceNow: -86400) // 1일 전
        let item = ImageItem.fixture(datetime: date)
        let result = item.relativeTimeString
        #expect(result != nil)
        #expect(result!.isEmpty == false)
    }
    
    @Test("altText메서드에 query를 주고 값이 잘 있는지 확인")
    func itemWithQuery_altText() {
        let item = ImageItem.fixture(displaySitename: "티스토리", datetime: Date())
        let altText = item.altText(query: "dog")
        #expect(altText.contains("dog"))
        #expect(altText.contains("티스토리"))
    }
    
    @Test("altText메서드에 빈 query를 주고 값이 잘 있는지 확인")
    func itemWithQuery_altTextWithNullQuery() {
        let item = ImageItem.fixture(displaySitename: "다음", datetime: Date())
        let altText = item.altText(query: "")
        #expect(!altText.contains("dog"))
        #expect(altText.contains("다음"))
    }
}
