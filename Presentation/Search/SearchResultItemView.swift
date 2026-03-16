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
    let onBookmarkToggle: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CachedAsyncImage(url: item.imageURL)
                .frame(
                    width: screenWidth,
                    height: screenWidth * item.aspectRatio
                )
                .clipped()

            BookmarkButton(isBookmarked: item.isBookmarked, action: onBookmarkToggle)
                .padding(12)
        }
    }
}
