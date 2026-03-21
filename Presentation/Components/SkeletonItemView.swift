//
//  SkeletonItemView.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/20/26.
//

import SwiftUI

/// 검색 결과 로딩 중 표시되는 스켈레톤 플레이스홀더.
/// LinearGradient 애니메이션으로 shimmer 효과를 구현합니다.
struct SkeletonItemView: View {

    let width: CGFloat

    @State private var phase: CGFloat = -1

    /// 실제 검색 결과 이미지의 일반적인 비율 범위에서 랜덤 생성
    private let aspectRatio: CGFloat

    init(width: CGFloat, aspectRatio: CGFloat? = nil) {
        self.width = width
        self.aspectRatio = aspectRatio ?? CGFloat.random(in: 0.7...1.3)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(AppColors.placeholderBackground)
            .frame(width: width, height: width * aspectRatio)
            .overlay(
                shimmerGradient
                    .mask(RoundedRectangle(cornerRadius: 15))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }

    private var shimmerGradient: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    .clear,
                    AppColors.skeletonShimmer,
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.6)
            .offset(x: geometry.size.width * phase)
        }
        .clipped()
    }
}
