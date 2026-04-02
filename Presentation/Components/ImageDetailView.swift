//
//  ImageDetailView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/20/26.
//

import SwiftUI
import UIKit

/// 전체 화면 이미지 뷰어. 핀치 확대/축소, 드래그 이동, 더블탭 줌을 지원합니다.
struct ImageDetailView: View {

    let url: URL?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.imageDownloader) private var downloader

    @State private var image: UIImage?
    @State private var loadFailed = false
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 5
    private let doubleTapScale: CGFloat = 3

    var body: some View {
        ZStack {
            AppColors.detailBackground.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        magnifyGesture.simultaneously(with: dragGesture)
                    )
                    // 더블탭: 확대↔원본 토글.
                    // 축소 시 offset도 리셋 — 확대 상태에서 패닝한 위치가 원본에서는 무의미.
                    .onTapGesture(count: 2) {
                        let zoomToggleDuration = 0.3
                        withAnimation(.easeInOut(duration: zoomToggleDuration)) {
                            if scale > minScale {
                                scale = minScale
                                lastScale = minScale
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = doubleTapScale
                                lastScale = doubleTapScale
                            }
                        }
                    }
            } else if loadFailed {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(AppColors.detailOverlay)
                    Text(L10n.Search.imageLoadFailed)
                        .font(.callout)
                        .foregroundStyle(AppColors.detailOverlay)
                }
            } else {
                ProgressView()
                    .tint(AppColors.detailCloseButton)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColors.detailCloseButton, AppColors.detailCloseButtonShadow)
            }
            .accessibilityLabel(L10n.Accessibility.detailClose)
            .accessibilityIdentifier("imageDetailView.closeButton")
            .padding(16)
        }
        .task {
            guard let url else {
                loadFailed = true
                return
            }
            do {
                image = try await downloader.download(from: url)
            } catch {
                loadFailed = true
            }
        }
        .statusBarHidden()
    }

    // MARK: - Gestures

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                scale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                // onChanged에서 클램핑하지만, 제스처 관성으로 범위 밖 값이 남을 수 있어 재클램핑.
                // 1배 이하로 복귀하면 패닝 위치도 리셋하여 이미지를 중앙에 정렬.
                let snapBackDuration = 0.2
                withAnimation(.easeOut(duration: snapBackDuration)) {
                    scale = min(max(scale, minScale), maxScale)
                    if scale <= minScale {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
                lastScale = scale
            }
    }

    // 원본 크기(1배)에서는 드래그 무시 — 이미지가 화면 밖으로 벗어나는 것을 방지.
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
}

#if DEBUG
#Preview("Loading") {
    ImageDetailView(url: nil)
        .environment(\.imageDownloader, PreviewFactory.imageDownloader)
}

#Preview("With Image") {
    ImageDetailView(url: URL(string: "https://picsum.photos/800/600"))
        .environment(\.imageDownloader, PreviewFactory.imageDownloader)
}
#endif
