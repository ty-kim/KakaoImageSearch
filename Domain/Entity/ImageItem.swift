//
//  ImageItem.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

struct ImageItem: Identifiable, Hashable, Codable, Sendable {
    let id: String          // 이미지 URL을 고유 식별자로 사용
    let imageURL: URL?
    let thumbnailURL: URL?
    let width: Int?
    let height: Int?
    var isBookmarked: Bool

    /// full-width 표시 시 높이 계산에 사용 (height / width)
    var aspectRatio: Double {
        guard let width, let height, width > 0 else { return 1 }
        return Double(height) / Double(width)
    }
}
