//
//  CachedAsyncImage.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

/// ImageDownloader를 통해 캐시를 지원하는 SwiftUI 이미지 컴포넌트.
struct CachedAsyncImage: View {

    let url: URL?

    @State private var phase: Phase = .idle

    private enum Phase {
        case idle
        case loading
        case success(UIImage)
        case failure
    }

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                placeholder(systemName: "photo")

            case .success(let image):
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)

            case .failure:
                placeholder(systemName: "exclamationmark.triangle")
            }
        }
        .task(id: url) {
            await load()
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
        guard let url else { return }
        phase = .loading

        do {
            let image = try await ImageDownloader.shared.download(from: url)
            phase = .success(image)
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failure
        }
    }
}
