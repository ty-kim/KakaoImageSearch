//
//  KakaoImageSearchApp.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

// MARK: - UI 테스트용 Stub

private final class FailingImageSearchRepository: ImageSearchRepository, @unchecked Sendable {
    func search(query: String, page: Int) async throws -> SearchResultPage {
        throw URLError(.notConnectedToInternet)
    }
}

private final class FixtureImageSearchRepository: ImageSearchRepository, @unchecked Sendable {
    func search(query: String, page: Int) async throws -> SearchResultPage {
        let items = (1...3).map { i in
            ImageItem(
                id: "fixture-\(i)",
                imageURL: URL(string: "https://picsum.photos/seed/\(i)/800/600")!,
                thumbnailURL: URL(string: "https://picsum.photos/seed/\(i)/200/150")!,
                width: 800,
                height: 600,
                isBookmarked: false
            )
        }
        return SearchResultPage(items: items, isEnd: true)
    }
}

// MARK: - DI 조립

/// Composition Root. 모든 의존성을 생성자 주입으로 조립하는 단일 진입점.
/// SceneDelegate에서 MainActor.assumeIsolated 내에 호출됩니다.
@MainActor
enum AppAssembler {

    static func makeMainViewModel() -> MainViewModel {
        if CommandLine.arguments.contains("--resetBookmarks") {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let url = appSupport.appendingPathComponent("KakaoImageSearch/bookmarks.json")
            try? FileManager.default.removeItem(at: url)
        }

        let networkService = NetworkService()
        let bookmarkStorage = BookmarkStorage()

        let imageSearchRepo: any ImageSearchRepository
        if CommandLine.arguments.contains("--simulateNetworkError") {
            imageSearchRepo = FailingImageSearchRepository()
        } else if CommandLine.arguments.contains("--useFixtureData") {
            imageSearchRepo = FixtureImageSearchRepository()
        } else {
            imageSearchRepo = DefaultImageSearchRepository(networkService: networkService)
        }
        let bookmarkRepo = DefaultBookmarkRepository(storage: bookmarkStorage)

        let searchUseCase = SearchImageUseCase(
            imageSearchRepository: imageSearchRepo
        )
        let bookmarkUseCase = ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)

        return MainViewModel(
            searchImageUseCase: searchUseCase,
            manageBookmarkUseCase: bookmarkUseCase
        )
    }
}
