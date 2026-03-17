//
//  KakaoImageSearchApp.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

/// DI 조립 담당. SceneDelegate에서 MainActor.assumeIsolated 내에 호출됩니다.
@MainActor
enum AppDependencies {

    static func makeMainViewModel() -> MainViewModel {
        if CommandLine.arguments.contains("--resetBookmarks") {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let url = appSupport.appendingPathComponent("KakaoImageSearch/bookmarks.json")
            try? FileManager.default.removeItem(at: url)
        }

        let networkService = NetworkService()
        let bookmarkStorage = BookmarkStorage()

        let imageSearchRepo = DefaultImageSearchRepository(networkService: networkService)
        let bookmarkRepo = DefaultBookmarkRepository(storage: bookmarkStorage)

        let searchUseCase = SearchImageUseCase(
            imageSearchRepository: imageSearchRepo,
            bookmarkRepository: bookmarkRepo
        )
        let bookmarkUseCase = ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)

        return MainViewModel(
            searchImageUseCase: searchUseCase,
            manageBookmarkUseCase: bookmarkUseCase
        )
    }
}
