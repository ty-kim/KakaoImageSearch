//
//  DebugTestRepositories.swift
//  KakaoImageSearch
//
//  Created by tykim on 4/3/26.
//

#if DEBUG
import Foundation

/// UI 테스트에서 네트워크 에러를 시뮬레이션하는 Stub Repository.
final class FailingImageSearchRepository: ImageSearchRepository, @unchecked Sendable {
    func search(query: String, page: Int) async throws -> SearchResultPage {
        // UI 테스트에서 재시도 시 loading -> error 전이를 안정적으로 관찰할 수 있도록 짧게 지연합니다.
        try? await Task.sleep(for: .seconds(1))
        throw URLError(.notConnectedToInternet)
    }
}

/// UI 테스트에서 고정 데이터를 반환하는 Stub Repository.
final class FixtureImageSearchRepository: ImageSearchRepository, @unchecked Sendable {
    func search(query: String, page: Int) async throws -> SearchResultPage {
        let items = (1...3).map { i in
            // 리터럴이라 실패할 수 없지만, 오타로 깨지면 조용히 넘어가지 않고 즉시 드러나게 한다.
            guard let imageURL = URL(string: "https://example.com/fixture/\(i)/800x600.jpg"),
                  let thumbnailURL = URL(string: "https://example.com/fixture/\(i)/200x150.jpg") else {
                preconditionFailure("fixture URL 구성 실패: \(i)")
            }
            return ImageItem(
                id: "fixture-\(i)",
                imageURL: imageURL,
                thumbnailURL: thumbnailURL,
                width: 800,
                height: 600,
                isBookmarked: false
            )
        }
        return SearchResultPage(items: items, isEnd: true)
    }
}
#endif
