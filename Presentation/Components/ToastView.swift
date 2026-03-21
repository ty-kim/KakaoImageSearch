//
//  ToastView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/17/26.
//

import SwiftUI

struct ToastView: View {

    let message: String

    var body: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(AppColors.toastForeground)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.toastBackground)
            .clipShape(Capsule())
            .padding(.horizontal, 24)
            .accessibilityLabel(message)
            .onAppear {
                AccessibilityNotification.Announcement(message).post()
            }
    }
}
