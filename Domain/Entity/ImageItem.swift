//
//  ImageItem.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

struct ImageItem: Identifiable, Codable, Sendable, Hashable {
    let id: String          // 이미지 URL을 고유 식별자로 사용
    let imageURL: URL?
    let thumbnailURL: URL?
    let width: Int?
    let height: Int?
    let displaySitename: String?
    let datetime: Date?
    var isBookmarked: Bool

    /// full-width 표시 시 높이 계산에 사용 (height / width)
    var aspectRatio: Double {
        guard let width, let height, width > 0, height > 0 else { return 1 }
        return Double(height) / Double(width)
    }
    
    var displayURL: URL? {
        imageURL ?? thumbnailURL
    }

    nonisolated(unsafe) private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    var relativeTimeString: String? {
        datetime.map { Self.relativeDateFormatter.localizedString(for: $0, relativeTo: Date()) }
    }
    
    func altText(query: String) -> String {
        var altText: String = ""
        
        if !query.isEmpty {
            altText += L10n.Accessibility.searchResultAlt(query: query)
        }
        
        if let sitename = displaySitename, !sitename.isEmpty {
            altText += ", \(sitename)"
        }

        if let time = relativeTimeString {
            altText += ", \(time)"
        }
        return altText
    }
}

extension ImageItem {
    nonisolated init(
        id: String,
        imageURL: URL,
        thumbnailURL: URL,
        width: Int,
        height: Int,
        displaySitename: String? = nil,
        datetime: Date? = nil,
        isBookmarked: Bool
    ) {
        self.id = id
        self.imageURL = imageURL
        self.thumbnailURL = thumbnailURL
        self.width = width
        self.height = height
        self.displaySitename = displaySitename
        self.datetime = datetime
        self.isBookmarked = isBookmarked
    }
}
