//
//  SearchView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct SearchView: View {

    let viewModel: SearchViewModel

    var body: some View {
        GeometryReader { geometry in
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if let message = viewModel.errorMessage {
                    EmptyStateView(message: message)

                } else if !viewModel.hasSearched {
                    EmptyStateView(message: L10n.Search.emptyInitial)

                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.items) { item in
                                SearchResultItemView(
                                    item: item,
                                    screenWidth: geometry.size.width
                                ) {
                                    Task { await viewModel.toggleBookmark(for: item) }
                                }
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}
