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
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        Group {
            if isIPad {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }

    /// 탭 내부 콘텐츠를 탭하면 키보드를 내리는 제스처.
    /// simultaneousGesture로 붙여 내부 버튼·스크롤과 충돌 없이 동시 인식한다.
    private var dismissKeyboardGesture: some Gesture {
        TapGesture().onEnded { isSearchFieldFocused = false }
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

            TabView(selection: $viewModel.selectedTab) {
                SearchView(viewModel: viewModel.searchViewModel)
                    // 검색 탭 영역 탭 시 키보드 dismiss
                    .simultaneousGesture(dismissKeyboardGesture)
                    .tabItem {
                        Label(L10n.Tab.search, systemImage: "magnifyingglass")
                    }
                    .tag(MainViewModel.Tab.search)
                    .accessibilityHint(L10n.Accessibility.tabSearchHint)

                BookmarkView(viewModel: viewModel.bookmarkViewModel)
                    // 북마크 탭 영역 탭 시 키보드 dismiss
                    .simultaneousGesture(dismissKeyboardGesture)
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
                SearchView(viewModel: viewModel.searchViewModel, columns: 2)
            }
            .navigationTitle(L10n.Tab.search)
            .navigationBarTitleDisplayMode(.inline)
        } detail: {
            BookmarkView(viewModel: viewModel.bookmarkViewModel, columns: 2)
                .navigationTitle(L10n.Tab.bookmark)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
