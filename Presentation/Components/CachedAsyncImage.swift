//
//  CachedAsyncImage.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI
import UIKit

// MARK: - ViewModel

/// CachedAsyncImage의 Phase 상태 전이 로직을 분리한 ViewModel.
/// View 수명주기와 독립적으로 테스트 가능합니다.
@Observable
@MainActor
final class CachedAsyncImageViewModel {

    enum Phase: Equatable {
        case idle
        case loading
        case success(UIImage)
        case failure
        case permanentFailure

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.failure, .failure), (.permanentFailure, .permanentFailure):
                return true
            case (.success(let a), .success(let b)):
                return a === b
            default:
                return false
            }
        }
    }

    /// 이미지 로드 최대 재시도 횟수
    static let maxRetryCount = 3

    private(set) var phase: Phase = .idle
    private(set) var retryCount = 0
    private let downloader: any ImageDownloading
    private let backoffBase: Double

    init(downloader: any ImageDownloading, backoffBase: Double = 2.0) {
        self.downloader = downloader
        self.backoffBase = backoffBase
    }

    func load(url: URL?) async {
        guard let url else {
            phase = .idle
            return
        }
        phase = .loading

        do {
            let image = try await downloader.download(from: url)
            phase = .success(image)
        } catch is CancellationError {
            phase = .idle
        } catch let error as ImageDownloadError where !error.isRetryable {
            phase = .permanentFailure
        } catch {
            retryCount += 1
            if retryCount > Self.maxRetryCount {
                phase = .permanentFailure
            } else {
                let delay = pow(backoffBase, Double(retryCount - 1))
                try? await Task.sleep(for: .seconds(delay))
                phase = Task.isCancelled ? .idle : .failure
            }
        }
    }

    func resetRetry() {
        retryCount = 0
    }
}

// MARK: - View

/// ImageDownloader를 통해 캐시를 지원하는 SwiftUI 이미지 컴포넌트.
struct CachedAsyncImage: View {

    let url: URL?

    @Environment(\.imageDownloader) private var downloader
    @State private var viewModel: CachedAsyncImageViewModel?
    /// URL 변경 또는 실패 후 탭 시 값이 바뀌어 .task를 재실행한다.
    @State private var loadTrigger = UUID()

    var body: some View {
        Group {
            switch viewModel?.phase ?? .idle {
            case .idle:
                placeholder(systemName: "photo")

            case .loading:
                placeholder(systemName: "photo")
                    .overlay(ProgressView())

            case .success(let image):
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)

            case .failure:
                placeholder(systemName: "arrow.clockwise")
                    .onTapGesture { loadTrigger = UUID() }
                    .accessibilityHint(L10n.Accessibility.retryHint)

            case .permanentFailure:
                placeholder(systemName: "exclamationmark.triangle")
            }
        }
        .animation(.easeIn(duration: 0.3), value: viewModel?.phase)
        .task(id: loadTrigger) {
            if viewModel == nil {
                viewModel = CachedAsyncImageViewModel(downloader: downloader)
            }
            await viewModel?.load(url: url)
        }
        .onChange(of: url) {
            viewModel?.resetRetry()
            loadTrigger = UUID()
        }
    }

    private func placeholder(systemName: String) -> some View {
        Rectangle()
            .fill(AppColors.placeholderBackground)
            .overlay(
                Image(systemName: systemName)
                    .font(.title)
                    .foregroundStyle(AppColors.placeholderIcon)
            )
    }
}
