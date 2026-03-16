//
//  BookmarkRepository.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

protocol BookmarkRepository: Sendable {
    func save(_ item: ImageItem) async throws
    func delete(id: String) async throws
    func fetchAll() async throws -> [ImageItem]
    func isBookmarked(id: String) async throws -> Bool
}
