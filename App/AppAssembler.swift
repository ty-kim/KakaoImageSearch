//
//  AppAssembler.swift
//  KakaoImageSearch
//
//  Created by tykim on 4/3/26.
//

import SwiftData

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
