//
//  SearchBar.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct SearchBar: View {

    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.searchBarIcon)

            TextField(L10n.Search.placeholder, text: $text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused(isFocused)
                .onSubmit { onSubmit?() }
                .accessibilityHint(L10n.Accessibility.searchFieldHint)
                .accessibilityIdentifier("searchBar.textField")

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.searchBarIcon)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Accessibility.searchClear)
                .accessibilityIdentifier("searchBar.clearButton")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.searchBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#if DEBUG
#Preview {
    @Previewable @FocusState var focused: Bool
    @Previewable @State var text = ""
    SearchBar(text: $text, isFocused: $focused)
}
#endif
