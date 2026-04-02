//
//  SearchResultsStore.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/31/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class SearchResultsStore {
    private var rawItems: [ImageItem] = []
    private let bookmarkStore: BookmarkCoordinator

    private(set) var items: [ImageItem] = []
    
    init(bookmarkStore: BookmarkCoordinator) {
        self.bookmarkStore = bookmarkStore
        observeBookmarkCoordinator()
    }

    func replace(with items: [ImageItem]) {
        rawItems = items
        rebuild()
    }

    func append(_ items: [ImageItem]) {
        rawItems += items
        rebuild()
    }

    func clear() {
        rawItems = []
        items = []
    }

    // toggle 직후 테스트가 즉시 반영되도록 수동 refresh 진입점 유지
    func refresh() {
        rebuild()
    }

    // bookmarkedIDs 변경 시에만 재계산 — withObservationTracking으로 단일 의존성 추적.
    // onChange는 1회성이므로 재등록을 반복하는 것이 @Observable의 공식 패턴 (WWDC23).
    // self가 해제되면 재등록하지 않아 관찰이 중단되며, 이는 ViewModel 수명 = 관찰 수명을 의미하는 의도된 동작이다.
    private func observeBookmarkCoordinator() {
        withObservationTracking {
            _ = bookmarkStore.bookmarkedIDs
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rebuild()
                self.observeBookmarkCoordinator()
            }
        }
    }

    private func rebuild() {
        let ids = bookmarkStore.bookmarkedIDs
        items = rawItems.map { item in
            var updated = item
            updated.isBookmarked = ids.contains(item.id)
            return updated
        }
    }
}
