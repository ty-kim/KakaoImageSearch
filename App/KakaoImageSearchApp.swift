//
//  KakaoImageSearchApp.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI
import SwiftData

#if DEBUG
// MARK: - UI 테스트용 Stub

private final class FailingImageSearchRepository: ImageSearchRepository, @unchecked Sendable {
    func search(query: String, page: Int) async throws -> SearchResultPage {
        // UI 테스트에서 재시도 시 loading -> error 전이를 안정적으로 관찰할 수 있도록 짧게 지연합니다.
        try? await Task.sleep(for: .seconds(1))
        throw URLError(.notConnectedToInternet)
    }
}

private final class FixtureImageSearchRepository: ImageSearchRepository, @unchecked Sendable {
    func search(query: String, page: Int) async throws -> SearchResultPage {
        let items = (1...3).map { i in
            ImageItem(
                id: "fixture-\(i)",
                imageURL: URL(string: "https://example.com/fixture/\(i)/800x600.jpg")!,
                thumbnailURL: URL(string: "https://example.com/fixture/\(i)/200x150.jpg")!,
                width: 800,
                height: 600,
                isBookmarked: false
            )
        }
        return SearchResultPage(items: items, isEnd: true)
    }
}
#endif

// MARK: - DI 조립

// MARK: - SwiftUI App

@main
struct KakaoImageSearchApp: App {
    @State private var viewModel = AppAssembler.makeMainViewModel()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
        }
    }
}

// MARK: - DI 조립

/// Composition Root. 모든 의존성을 생성자 주입으로 조립하는 단일 진입점.
@MainActor
enum AppAssembler {

    private static let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: BookmarkEntity.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    static func makeMainViewModel() -> MainViewModel {
        #if DEBUG
        if CommandLine.arguments.contains("--resetBookmarks") {
            try? modelContainer.mainContext.delete(model: BookmarkEntity.self)
            try? modelContainer.mainContext.save()
        }

        if CommandLine.arguments.contains("--useFixtureBookmarks") {
            let context = modelContainer.mainContext
            for i in 1...3 {
                let entity = BookmarkEntity(
                    id: "bookmark-\(i)",
                    imageURL: "https://example.com/fixture/bm\(i)/800x600.jpg",
                    thumbnailURL: "https://example.com/fixture/bm\(i)/200x150.jpg",
                    width: 800,
                    height: 600
                )
                context.insert(entity)
            }
            try? context.save()
        }
        #endif

        let networkService = NetworkService()
        let bookmarkStorage = BookmarkStorage(modelContainer: modelContainer)

        let imageSearchRepo: any ImageSearchRepository
        #if DEBUG
        if CommandLine.arguments.contains("--simulateNetworkError") {
            imageSearchRepo = FailingImageSearchRepository()
        } else if CommandLine.arguments.contains("--useFixtureData") {
            imageSearchRepo = FixtureImageSearchRepository()
        } else {
            imageSearchRepo = DefaultImageSearchRepository(networkService: networkService)
        }
        #else
        imageSearchRepo = DefaultImageSearchRepository(networkService: networkService)
        #endif
        let bookmarkRepo = DefaultBookmarkRepository(storage: bookmarkStorage)

        let searchUseCase = SearchImageUseCase(
            imageSearchRepository: imageSearchRepo
        )
        let bookmarkUseCase = ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)

        return MainViewModel(
            searchImageUseCase: searchUseCase,
            manageBookmarkUseCase: bookmarkUseCase,
            imagePrefetcher: ImageDownloader.shared,
            networkMonitor: NetworkMonitor()
        )
    }
}
