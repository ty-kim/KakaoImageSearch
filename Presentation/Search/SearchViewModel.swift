//
//  SearchViewModel.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class SearchViewModel {

    private(set) var items: [ImageItem] = []
    private var rawItems: [ImageItem] = []
    private(set) var isLoading: Bool = false
    private(set) var isLoadingMore: Bool = false
    private(set) var isEnd: Bool = false
    private(set) var hasError: Bool = false
    private(set) var hasLoadMoreError: Bool = false
    private(set) var errorMessage: String? = nil
    private(set) var hasSearched: Bool = false
    private(set) var toastMessage: String? = nil

    private var currentQuery: String = ""
    private var currentPage: Int = 1
    private var toastTask: Task<Void, Never>? = nil
    private let toastDuration: Duration

    private var searchTask: Task<Void, Never>? = nil
    private var activeSearchID: UUID? = nil

    private let searchImageUseCase: SearchImageUseCase
    private let bookmarkStore: BookmarkStore
    private let imagePrefetcher: any ImagePrefetcher

    init(
        searchImageUseCase: SearchImageUseCase,
        bookmarkStore: BookmarkStore,
        imagePrefetcher: any ImagePrefetcher = ImageDownloader.shared,
        toastDuration: Duration = .seconds(3)
    ) {
        self.searchImageUseCase = searchImageUseCase
        self.bookmarkStore = bookmarkStore
        self.imagePrefetcher = imagePrefetcher
        self.toastDuration = toastDuration
        observeBookmarkStore()
    }

    // bookmarkedIDs 변경 시에만 재계산 — withObservationTracking으로 단일 의존성 추적.
    // onChange는 1회성이므로 재등록을 반복하는 것이 @Observable의 공식 패턴 (WWDC23).
    // self가 해제되면 재등록하지 않아 관찰이 중단되며, 이는 ViewModel 수명 = 관찰 수명을 의미하는 의도된 동작이다.
    private func observeBookmarkStore() {
        withObservationTracking {
            _ = bookmarkStore.bookmarkedIDs
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rebuildItems()
                self.observeBookmarkStore()
            }
        }
    }

    private func rebuildItems() {
        let ids = bookmarkStore.bookmarkedIDs
        items = rawItems.map { item in
            var updated = item
            updated.isBookmarked = ids.contains(item.id)
            return updated
        }
    }

    // MainViewModel에서 debounce 후 호출. retry()도 이 경로를 사용
    // @discardableResult로 반환된 Task를 무시하거나, 테스트에서 .value로 await 가능
    @discardableResult
    func submitSearch(query: String) -> Task<Void, Never> {
        let searchID = beginSearch(query: query)
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performSearch(query: query, searchID: searchID)
        }
        searchTask = task
        return task
    }

    private func beginSearch(query: String) -> UUID {
        searchTask?.cancel()

        let searchID = UUID()
        activeSearchID = searchID

        currentQuery = query
        currentPage = 1
        isEnd = false

        isLoading = true
        errorMessage = nil
        hasError = false
        hasLoadMoreError = false
        hasSearched = true

        return searchID
    }

    private func performSearch(query: String, searchID: UUID) async {
        Logger.presentation.debugPrint("Search started: \"\(query)\"")

        defer {
            if activeSearchID == searchID {
                isLoading = false
                searchTask = nil
            }
        }

        do {
            let result = try await searchImageUseCase.execute(query: query, page: 1)

            guard !Task.isCancelled, activeSearchID == searchID else { return }

            rawItems = result.items
            rebuildItems()
            isEnd = result.isEnd

            Logger.presentation.debugPrint("Search completed: \(result.items.count) results, isEnd: \(isEnd)")

            if result.items.isEmpty {
                errorMessage = L10n.Search.emptyNoResults
            } else {
                prefetch(result.items)
            }
        } catch is CancellationError {
            Logger.presentation.debugPrint("Search cancelled: \"\(query)\"")
        } catch {
            guard activeSearchID == searchID else { return }

            rawItems = []
            items = []
            errorMessage = L10n.Search.error(error.localizedDescription)
            hasError = true

            Logger.presentation.errorPrint("Search failed: \(error)")
        }
    }

    @discardableResult
    func retry() -> Task<Void, Never>? {
        guard !currentQuery.isEmpty else { return nil }
        return submitSearch(query: currentQuery)
    }

    func loadMore() async {
        // loadMore 실패 후에는 자동 재시도 루프를 막고 버튼으로만 재시도
        guard !isEnd, !isLoading, !isLoadingMore, !hasLoadMoreError else { return }

        let queryAtRequestTime = currentQuery
        let searchIDAtRequestTime = activeSearchID
        let nextPage = currentPage + 1

        hasLoadMoreError = false
        isLoadingMore = true

        Logger.presentation.debugPrint("Loading more: page \(nextPage)")

        defer {
            if searchIDAtRequestTime == activeSearchID,
               queryAtRequestTime == currentQuery {
                isLoadingMore = false
            }
        }

        do {
            let result = try await searchImageUseCase.execute(
                query: queryAtRequestTime,
                page: nextPage
            )

            // 검색어가 이미 바뀌었으면 이전 loadMore 결과 무시
            guard !Task.isCancelled,
                  searchIDAtRequestTime == activeSearchID,
                  queryAtRequestTime == currentQuery else { return }

            rawItems += result.items
            rebuildItems()
            isEnd = result.isEnd
            currentPage = nextPage

            Logger.presentation.debugPrint("Loaded \(result.items.count) more, isEnd: \(isEnd)")

            prefetch(result.items)
        } catch is CancellationError {
            Logger.presentation.debugPrint("Load more cancelled: \(queryAtRequestTime), page \(nextPage)")
        } catch {
            guard searchIDAtRequestTime == activeSearchID,
                  queryAtRequestTime == currentQuery else { return }

            hasLoadMoreError = true
            Logger.presentation.errorPrint("Load more failed: \(error)")
        }
    }

    func retryLoadMore() async {
        hasLoadMoreError = false
        await loadMore()
    }

    func toggleBookmark(for item: ImageItem) async {
        do {
            _ = try await bookmarkStore.toggle(item)
            rebuildItems()
        } catch {
            showToast(L10n.Bookmark.toggleError)
            Logger.presentation.errorPrint("Bookmark toggle failed: \(error)")
        }
    }

    private func prefetch(_ items: [ImageItem]) {
        let urls = items.compactMap(\.listDisplayURL)
        Task(priority: .background) {
            await imagePrefetcher.prefetch(urls: urls)
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message

        toastTask = Task {
            try? await Task.sleep(for: toastDuration)
            guard !Task.isCancelled else { return }
            toastMessage = nil
        }
    }

    func cancelSearchAndClear() {
        searchTask?.cancel()
        searchTask = nil
        activeSearchID = nil

        rawItems = []
        items = []
        errorMessage = nil
        hasError = false
        hasLoadMoreError = false
        hasSearched = false
        isLoading = false
        isLoadingMore = false
        isEnd = false

        currentQuery = ""
        currentPage = 1

        Logger.presentation.debugPrint("Search cancelled and cleared")
    }

}
