//
//  SearchResultItemView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct SearchResultItemView: View {

    let item: ImageItem
    let screenWidth: CGFloat
    var isBookmarkInFlight: Bool = false
    let onBookmarkToggle: () -> Void

    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            CachedAsyncImage(url: item.displayURL)
                .frame(
                    width: screenWidth,
                    height: screenWidth * item.aspectRatio
                )
                .clipShape(RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            BookmarkButton(isBookmarked: item.isBookmarked, action: onBookmarkToggle)
                .disabled(isBookmarkInFlight)
                .padding(12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Accessibility.imageItem(width: item.width, height: item.height))
        .fullScreenCover(isPresented: $showDetail) {
            ImageDetailView(url: item.imageURL ?? item.thumbnailURL)
        }
    }
}
