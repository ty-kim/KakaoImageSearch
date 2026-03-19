//
//  SearchViewModel.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation
import Observation
import OSLog

enum SearchState: Equatable {
    case idle
    case loading
    case loaded(PaginationState)
    case empty
    case error(message: String)
}

enum PaginationState: Equatable {
    case idle
    case loadingMore
    case loadMoreError
    case exhausted
    case apiLimitReached
}

@Observable
@MainActor
final class SearchViewModel {

    private(set) var items: [ImageItem] = []
    private var rawItems: [ImageItem] = []
    private(set) var searchState: SearchState = .idle
    private(set) var toastMessage: String? = nil
    private(set) var inFlightBookmarkIDs: Set<String> = []

    private var currentQuery: String = ""
    private var currentPage: Int = 1
    private var toastTask: Task<Void, Never>? = nil
    private let toastDuration: Duration

    private var searchTask: Task<Void, Never>? = nil
    private var loadMoreTask: Task<Void, Never>? = nil
    private var prefetchTask: Task<Void, Never>? = nil
    private var activeSearchID: UUID? = nil

    private let maxPage = 15
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
        loadMoreTask?.cancel()
        prefetchTask?.cancel()

        let searchID = UUID()
        activeSearchID = searchID

        currentQuery = query
        currentPage = 1
        searchState = .loading

        return searchID
    }

    private func performSearch(query: String, searchID: UUID) async {
        Logger.presentation.debugPrint("Search started: \"\(query)\"")

        defer {
            if activeSearchID == searchID {
                searchTask = nil
            }
        }

        do {
            let result = try await searchImageUseCase.execute(query: query, page: 1)

            guard !Task.isCancelled, activeSearchID == searchID else { return }

            rawItems = result.items
            rebuildItems()

            if result.items.isEmpty {
                searchState = .empty
            } else {
                searchState = .loaded(paginationState(isEnd: result.isEnd, page: 1))
                prefetch(result.items)
            }

            Logger.presentation.debugPrint("Search completed: \(result.items.count) results, isEnd: \(result.isEnd)")
        } catch is CancellationError {
            Logger.presentation.debugPrint("Search cancelled: \"\(query)\"")
        } catch {
            guard activeSearchID == searchID else { return }

            rawItems = []
            items = []
            searchState = .error(message: L10n.Search.error(error.localizedDescription))

            Logger.presentation.errorPrint("Search failed: \(error)")
        }
    }

    @discardableResult
    func retry() -> Task<Void, Never>? {
        guard !currentQuery.isEmpty else { return nil }
        return submitSearch(query: currentQuery)
    }

    // @discardableResult로 반환된 Task를 무시하거나, 테스트에서 .value로 await 가능 (submitSearch와 동일 패턴)
    @discardableResult
    func loadMore() -> Task<Void, Never>? {
        // loaded(.idle) 상태에서만 추가 로드 허용
        guard case .loaded(.idle) = searchState else { return nil }

        let queryAtRequestTime = currentQuery
        let searchIDAtRequestTime = activeSearchID
        let nextPage = currentPage + 1

        searchState = .loaded(.loadingMore)

        Logger.presentation.debugPrint("Loading more: page \(nextPage)")

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoadMore(
                query: queryAtRequestTime,
                searchID: searchIDAtRequestTime,
                page: nextPage
            )
        }
        loadMoreTask = task
        return task
    }

    private func performLoadMore(query: String, searchID: UUID?, page: Int) async {
        do {
            let result = try await searchImageUseCase.execute(query: query, page: page)

            // 검색어가 이미 바뀌었으면 이전 loadMore 결과 무시
            guard !Task.isCancelled,
                  searchID == activeSearchID,
                  query == currentQuery else { return }

            rawItems += result.items
            rebuildItems()
            searchState = .loaded(paginationState(isEnd: result.isEnd, page: page))
            currentPage = page

            Logger.presentation.debugPrint("Loaded \(result.items.count) more, page: \(page)")

            prefetch(result.items)
        } catch is CancellationError {
            Logger.presentation.debugPrint("Load more cancelled: \(query), page \(page)")
        } catch {
            guard searchID == activeSearchID, query == currentQuery else { return }

            searchState = .loaded(.loadMoreError)
            Logger.presentation.errorPrint("Load more failed: \(error)")
        }
    }

    @discardableResult
    func retryLoadMore() -> Task<Void, Never>? {
        searchState = .loaded(.idle)
        return loadMore()
    }

    func toggleBookmark(for item: ImageItem) async {
        guard !inFlightBookmarkIDs.contains(item.id) else { return }
        inFlightBookmarkIDs.insert(item.id)
        defer { inFlightBookmarkIDs.remove(item.id) }

        do {
            _ = try await bookmarkStore.toggle(item)
            rebuildItems()
        } catch {
            showToast(L10n.Bookmark.toggleError)
            Logger.presentation.errorPrint("Bookmark toggle failed: \(error)")
        }
    }

    private func prefetch(_ items: [ImageItem]) {
        let urls = items.compactMap(\.displayURL)
        prefetchTask?.cancel()
        prefetchTask = Task(priority: .background) { [weak self] in
            await self?.imagePrefetcher.prefetch(urls: urls)
        }
    }

    private func paginationState(isEnd: Bool, page: Int) -> PaginationState {
        if !isEnd && page >= maxPage { return .apiLimitReached }
        if isEnd || page >= maxPage { return .exhausted }
        return .idle
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
        loadMoreTask?.cancel()
        loadMoreTask = nil
        prefetchTask?.cancel()
        prefetchTask = nil
        activeSearchID = nil

        rawItems = []
        items = []
        searchState = .idle

        currentQuery = ""
        currentPage = 1

        Logger.presentation.debugPrint("Search cancelled and cleared")
    }

}
