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
        let networkService = NetworkService()
        let bookmarkStorage = BookmarkStorage()

        let imageSearchRepo = DefaultImageSearchRepository(networkService: networkService)
        let bookmarkRepo = DefaultBookmarkRepository(storage: bookmarkStorage)

        let searchUseCase = SearchImageUseCase(
            imageSearchRepository: imageSearchRepo,
            bookmarkRepository: bookmarkRepo
        )
        let bookmarkUseCase = ManageBookmarkUseCase(bookmarkRepository: bookmarkRepo)

        let searchVM = SearchViewModel(
            searchImageUseCase: searchUseCase,
            manageBookmarkUseCase: bookmarkUseCase
        )
        let bookmarkVM = BookmarkViewModel(manageBookmarkUseCase: bookmarkUseCase)

        return MainViewModel(searchViewModel: searchVM, bookmarkViewModel: bookmarkVM)
    }
}
