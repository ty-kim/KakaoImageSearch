//
//  BookmarkEntity.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/20/26.
//

import Foundation
import SwiftData

/// SwiftData 북마크 엔티티. ImageItem과 1:1 매핑됩니다.
@Model
final class BookmarkEntity {
    @Attribute(.unique) var id: String
    var imageURL: String?
    var thumbnailURL: String?
    var width: Int?
    var height: Int?
    var displaySitename: String?
    var datetime: Date?
    var createdAt: Date

    init(id: String, imageURL: String?, thumbnailURL: String?, width: Int?, height: Int?, displaySitename: String? = nil, datetime: Date? = nil, createdAt: Date = Date()) {
        self.id = id
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.width = width
        self.height = height
        self.displaySitename = displaySitename
        self.datetime = datetime
        self.createdAt = createdAt
    }

    convenience init(from item: ImageItem) {
        self.init(
            id: item.id,
            imageURL: item.imageURL?.absoluteString,
            thumbnailURL: item.thumbnailURL?.absoluteString,
            width: item.width,
            height: item.height,
            displaySitename: item.displaySitename,
            datetime: item.datetime
        )
    }

    func toImageItem() -> ImageItem {
        ImageItem(
            id: id,
            imageURL: imageURL.flatMap { URL(string: $0) },
            thumbnailURL: thumbnailURL.flatMap { URL(string: $0) },
            width: width,
            height: height,
            displaySitename: displaySitename,
            datetime: datetime,
            isBookmarked: true
        )
    }
}
