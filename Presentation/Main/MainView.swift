//
//  MainView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct MainView: View {

    @State var viewModel: MainViewModel
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
    
    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            SearchBar(text: $viewModel.searchText, isFocused: $isSearchFieldFocused) {
                    viewModel.selectedTab = .search
                }
                .onChange(of: viewModel.searchText) { _, newValue in
                    viewModel.onSearchTextChanged(newValue)
                }
                .onChange(of: viewModel.searchViewModel.items) {
                    if !viewModel.searchViewModel.items.isEmpty {
                        isSearchFieldFocused = false
                        viewModel.selectedTab = .search
                    }
                }
                .onTapGesture {
                }

            TabView(selection: $viewModel.selectedTab) {
                SearchView(viewModel: viewModel.searchViewModel, isFocused: $isSearchFieldFocused)
                    // 검색 탭 영역 탭 시 키보드 dismiss
                    .tabItem {
                        Label(L10n.Tab.search, systemImage: "magnifyingglass")
                    }
                    .tag(MainViewModel.Tab.search)
                    .accessibilityHint(L10n.Accessibility.tabSearchHint)

                BookmarkView(viewModel: viewModel.bookmarkViewModel, isFocused: $isSearchFieldFocused)
                    // 북마크 탭 영역 탭 시 키보드 dismiss
                    .tabItem {
                        Label(L10n.Tab.bookmark, systemImage: "bookmark.fill")
                    }
                    .tag(MainViewModel.Tab.bookmark)
                    .accessibilityHint(L10n.Accessibility.tabBookmarkHint)
            }
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SearchBar(text: $viewModel.searchText, isFocused: $isSearchFieldFocused)
                    .onChange(of: viewModel.searchText) { _, newValue in
                        viewModel.onSearchTextChanged(newValue)
                    }
                SearchView(viewModel: viewModel.searchViewModel, isFocused: $isSearchFieldFocused, columns: 1)
            }
            .navigationTitle(L10n.Tab.search)
            .navigationBarTitleDisplayMode(.inline)
        } detail: {
            BookmarkView(viewModel: viewModel.bookmarkViewModel, isFocused: $isSearchFieldFocused, columns: 2)
                .navigationTitle(L10n.Tab.bookmark)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
