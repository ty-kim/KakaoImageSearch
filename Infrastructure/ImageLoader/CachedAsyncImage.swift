//
//  CachedAsyncImage.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

private struct ImageDownloaderKey: EnvironmentKey {
    static let defaultValue: any ImageDownloading = ImageDownloader.shared
}

extension EnvironmentValues {
    var imageDownloader: any ImageDownloading {
        get { self[ImageDownloaderKey.self] }
        set { self[ImageDownloaderKey.self] = newValue }
    }
}

/// ImageDownloader를 통해 캐시를 지원하는 SwiftUI 이미지 컴포넌트.
struct CachedAsyncImage: View {

    let url: URL?

    @Environment(\.imageDownloader) private var downloader
    @State private var phase: Phase = .idle
    /// URL 변경 또는 실패 후 탭 시 값이 바뀌어 .task를 재실행한다.
    @State private var loadTrigger = UUID()
    @State private var retryCount = 0

    /// 이미지 로드 최대 재시도 횟수
    private static let maxRetryCount = 3

    private enum Phase {
        case idle
        case loading
        case success(UIImage)
        case failure
        case permanentFailure
    }

    var body: some View {
        Group {
            switch phase {
            case .idle:
                placeholder(systemName: "photo")

            case .loading:
                placeholder(systemName: "photo")
                    .overlay(ProgressView())

            case .success(let image):
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)

            case .failure:
                placeholder(systemName: "arrow.clockwise")
                    .onTapGesture { loadTrigger = UUID() }
                    .accessibilityHint(L10n.Accessibility.retryHint)

            case .permanentFailure:
                placeholder(systemName: "exclamationmark.triangle")
            }
        }
        .task(id: loadTrigger) {
            await load()
        }
        .onChange(of: url) {
            retryCount = 0
            loadTrigger = UUID()
        }
    }

    private func placeholder(systemName: String) -> some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay(
                Image(systemName: systemName)
                    .font(.title)
                    .foregroundStyle(.secondary)
            )
    }

    private func load() async {
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
        } catch {
            retryCount += 1
            phase = retryCount > Self.maxRetryCount ? .permanentFailure : .failure
        }
    }
}
