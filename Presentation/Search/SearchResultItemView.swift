//
//  SearchResultItemView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

private struct ScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let touchFeedbackDuration = 0.15
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: touchFeedbackDuration), value: configuration.isPressed)
    }
}

struct SearchResultItemView: View {

    let item: ImageItem
    let screenWidth: CGFloat
    var isBookmarkInFlight: Bool = false
    let onBookmarkToggle: () -> Void

    @State private var showDetail = false
    @State private var imageKeywords: [String] = []

    var body: some View {
        Button {
            showDetail = true
        } label: {
            CachedAsyncImage(url: item.displayURL, onKeywordsReady: { keywords in
                imageKeywords = keywords
            })
                .frame(
                    width: screenWidth,
                    height: screenWidth * item.aspectRatio
                )
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(alignment: .bottom) {
                    if item.displaySitename != nil || item.relativeTimeString != nil {
                        metadataOverlay
                    }
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .overlay(alignment: .topTrailing) {
            BookmarkButton(isBookmarked: item.isBookmarked, action: onBookmarkToggle)
                .disabled(isBookmarkInFlight)
                .padding(12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.altText(keywords: imageKeywords))
        .fullScreenCover(isPresented: $showDetail) {
            ImageDetailView(url: item.imageURL ?? item.thumbnailURL)
        }
    }

    private var metadataOverlay: some View {
        HStack(spacing: 4) {
            if let sitename = item.displaySitename, !sitename.isEmpty {
                Text(sitename)
                    .fontWeight(.medium)
            }
            if let sitename = item.displaySitename, !sitename.isEmpty,
               item.relativeTimeString != nil {
                Text("·")
            }
            if let time = item.relativeTimeString {
                Text(time)
            }
        }
        .font(.caption)
        .foregroundStyle(.white)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 15,
                bottomTrailingRadius: 15
            )
        )
    }
}

#if DEBUG
#Preview("With Metadata") {
    SearchResultItemView(
        item: PreviewData.singleItem,
        screenWidth: 350,
        onBookmarkToggle: {}
    )
    .environment(\.imageDownloader, PreviewFactory.imageDownloader)
}

#Preview("Bookmarked") {
    SearchResultItemView(
        item: PreviewData.bookmarkedItem,
        screenWidth: 350,
        onBookmarkToggle: {}
    )
    .environment(\.imageDownloader, PreviewFactory.imageDownloader)
}
#endif
