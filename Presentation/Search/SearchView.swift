//
//  SearchView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct SearchView: View {

    let viewModel: SearchViewModel
    var isFocused: FocusState<Bool>.Binding
    var columns: Int = 1

    var body: some View {
        GeometryReader { geometry in
            let toastTransitionDuration = 0.3
            Group {
                switch viewModel.searchState {
                case .loading:
                    let layout = GridLayout(columns: columns, availableWidth: geometry.size.width)

                    ScrollView {
                        LazyVGrid(columns: layout.gridColumns, spacing: 20) {
                            ForEach(0..<6, id: \.self) { _ in
                                SkeletonItemView(width: layout.itemWidth)
                            }
                        }
                        .padding(.horizontal, layout.horizontalPadding)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .accessibilityLabel(L10n.Accessibility.loading)
                    .accessibilityIdentifier("searchView.loadingIndicator")

                case .error(let message):
                    EmptyStateView(
                        message: message,
                        accessibilityID: "searchView.emptyState",
                        retryAction: { viewModel.retry() }
                    )

                case .empty:
                    EmptyStateView(
                        message: L10n.Search.emptyNoResults,
                        accessibilityID: "searchView.emptyState"
                    )

                case .idle:
                    EmptyStateView(message: L10n.Search.emptyInitial, accessibilityID: "searchView.emptyState")

                case .loaded(let paginationState):
                    let layout = GridLayout(columns: columns, availableWidth: geometry.size.width)

                    ScrollView {
                        LazyVGrid(columns: layout.gridColumns, spacing: 20) {
                            ForEach(viewModel.items) { item in
                                SearchResultItemView(
                                    item: item,
                                    screenWidth: layout.itemWidth,
                                    isBookmarkInFlight: viewModel.inFlightBookmarkIDs.contains(item.id)
                                ) {
                                    Task { await viewModel.toggleBookmark(for: item) }
                                }
                                .accessibilityIdentifier("searchResultItem.\(item.id)")
                                .onAppear {
                                    if item.id == viewModel.items.last?.id {
                                        viewModel.loadMore()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, layout.horizontalPadding)

                        switch paginationState {
                        case .loadingMore:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .accessibilityIdentifier("searchView.loadingMore")
                        case .apiLimitReached:
                            Text(L10n.Search.apiLimitReached)
                                .font(.footnote)
                                .foregroundStyle(AppColors.placeholderIcon)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .accessibilityIdentifier("searchView.apiLimitReached")
                        case .loadMoreError:
                            Button {
                                viewModel.retryLoadMore()
                            } label: {
                                Text(L10n.Search.loadMoreRetry)
                                    .font(.callout.weight(.medium))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(AppColors.retryBackground)
                                    .foregroundStyle(AppColors.retryForeground)
                                    .clipShape(Capsule())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .accessibilityHint(L10n.Accessibility.loadMoreRetryHint)
                            .accessibilityIdentifier("searchView.loadMoreRetryButton")
                        case .idle, .exhausted:
                            EmptyView()
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .accessibilityIdentifier("searchView.resultsList")
                }
            }
            .overlay(alignment: .bottom) {
                if let msg = viewModel.toastMessage {
                    ToastView(message: msg)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded {
                isFocused.wrappedValue = false
            })
            .onChange(of: viewModel.searchState) { _, newValue in
                switch newValue {
                case .loaded, .error, .empty:
                    isFocused.wrappedValue = false
                case .idle, .loading:
                    break
                }
            }
            .animation(.easeInOut(duration: toastTransitionDuration), value: viewModel.toastMessage)
        }
    }
}

#if DEBUG
#Preview("Idle") {
    @Previewable @FocusState var focused: Bool
    SearchView(
        viewModel: PreviewFactory.makeSearchViewModel(),
        isFocused: $focused
    )
}
#endif
