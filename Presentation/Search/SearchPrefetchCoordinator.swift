//
//  SearchPrefetchCoordinator.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/31/26.
//

import Foundation

@MainActor
final class SearchPrefetchCoordinator {
    private let imagePrefetcher: any ImagePrefetcher
    private let networkMonitor: any NetworkMonitoring
    private var prefetchTask: Task<Void, Never>?

    init(imagePrefetcher: any ImagePrefetcher, networkMonitor: any NetworkMonitoring) {
        self.imagePrefetcher = imagePrefetcher
        self.networkMonitor = networkMonitor
    }

    func start(with items: [ImageItem]) {
        guard !networkMonitor.isExpensive else { return }

        let urls = items.compactMap(\.displayURL)
        prefetchTask?.cancel()
        prefetchTask = Task(priority: .background) { [imagePrefetcher] in
            await imagePrefetcher.prefetch(urls: urls)
        }
    }
    
    func cancel() {
        prefetchTask?.cancel()
        prefetchTask = nil
    }
}
