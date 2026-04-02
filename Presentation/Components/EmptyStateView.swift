//
//  EmptyStateView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import SwiftUI

struct EmptyStateView: View {

    let message: String
    var accessibilityID: String = ""
    var retryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 52))
                    .foregroundStyle(AppColors.placeholderIcon)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(AppColors.placeholderIcon)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message)
            .accessibilityIdentifier(accessibilityID)

            if let retryAction {
                Button(action: retryAction) {
                    Text(L10n.Search.retry)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(AppColors.retryBackground)
                        .foregroundStyle(AppColors.retryForeground)
                        .clipShape(Capsule())
                }
                .accessibilityHint(L10n.Accessibility.retryHint)
                .accessibilityIdentifier("emptyStateView.retryButton")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview("With Retry") {
    EmptyStateView(
        message: "검색 결과가 없습니다",
        retryAction: {}
    )
}

#Preview("Without Retry") {
    EmptyStateView(message: "검색어를 입력해주세요")
}
#endif
