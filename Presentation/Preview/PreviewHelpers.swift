//
//  PreviewHelpers.swift
//  KakaoImageSearch
//
//  Preview 전용 Mock 및 샘플 데이터.
//

#if DEBUG

import UIKit

// MARK: - Sample Data

enum PreviewData {

    static let sampleItems: [ImageItem] = [
        ImageItem(
            id: "preview-1",
            imageURL: URL(string: "https://picsum.photos/id/10/800/600")!,
            thumbnailURL: URL(string: "https://picsum.photos/id/10/200/150")!,
            width: 800,
            height: 600,
            displaySitename: "Example.com",
            datetime: Date(timeIntervalSinceNow: -3600),
            isBookmarked: false
        ),
        ImageItem(
            id: "preview-2",
            imageURL: URL(string: "https://picsum.photos/id/20/600/800")!,
            thumbnailURL: URL(string: "https://picsum.photos/id/20/150/200")!,
            width: 600,
            height: 800,
            displaySitename: "Photo.kr",
            datetime: Date(timeIntervalSinceNow: -86400),
            isBookmarked: true
        ),
        ImageItem(
            id: "preview-3",
            imageURL: URL(string: "https://picsum.photos/id/30/700/700")!,
            thumbnailURL: URL(string: "https://picsum.photos/id/30/200/200")!,
            width: 700,
            height: 700,
            datetime: Date(timeIntervalSinceNow: -604800),
            isBookmarked: false
        ),
    ]

    static var singleItem: ImageItem { sampleItems[0] }
    static var bookmarkedItem: ImageItem { sampleItems[1] }
}

// MARK: - Mock Repository

private final class PreviewImageSearchRepository: ImageSearchRepository {
    func search(query: String, page: Int) async throws -> SearchResultPage {
        SearchResultPage(items: PreviewData.sampleItems, isEnd: false)
    }
}

private final class PreviewBookmarkRepository: BookmarkRepository {
    private var items: [ImageItem] = []

    func save(_ item: ImageItem) async throws { items.append(item) }
    func delete(id: String) async throws { items.removeAll { $0.id == id } }
    func fetchAll() async throws -> [ImageItem] { items }
    func isBookmarked(id: String) async throws -> Bool { items.contains { $0.id == id } }
}

// MARK: - Mock Services

private final class PreviewImageDownloader: ImageDownloading {
    func download(from url: URL) async throws -> UIImage {
        // 네트워크 없이 컬러 블록 반환
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300))
        return renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
    }
}

private final class PreviewImagePrefetcher: ImagePrefetcher {
    func prefetch(urls: [URL]) async {}
}

private final class PreviewNetworkMonitor: NetworkMonitoring {
    var isConnected: Bool { true }
    var isExpensive: Bool { false }
}

// MARK: - ViewModel Factory

@MainActor
enum PreviewFactory {

    static func makeMainViewModel() -> MainViewModel {
        MainViewModel(
            searchImageUseCase: SearchImageUseCase(
                imageSearchRepository: PreviewImageSearchRepository()
            ),
            manageBookmarkUseCase: ManageBookmarkUseCase(
                bookmarkRepository: PreviewBookmarkRepository()
            ),
            imagePrefetcher: PreviewImagePrefetcher(),
            networkMonitor: PreviewNetworkMonitor()
        )
    }

    static func makeSearchViewModel() -> SearchViewModel {
        let bookmarkStore = BookmarkStore(
            manageBookmarkUseCase: ManageBookmarkUseCase(
                bookmarkRepository: PreviewBookmarkRepository()
            )
        )
        return SearchViewModel(
            searchImageUseCase: SearchImageUseCase(
                imageSearchRepository: PreviewImageSearchRepository()
            ),
            bookmarkStore: bookmarkStore,
            imagePrefetcher: PreviewImagePrefetcher(),
            networkMonitor: PreviewNetworkMonitor()
        )
    }

    static func makeBookmarkViewModel() -> BookmarkViewModel {
        let bookmarkStore = BookmarkStore(
            manageBookmarkUseCase: ManageBookmarkUseCase(
                bookmarkRepository: PreviewBookmarkRepository()
            )
        )
        return BookmarkViewModel(bookmarkStore: bookmarkStore)
    }

    static var imageDownloader: any ImageDownloading {
        PreviewImageDownloader()
    }
}

#endif
