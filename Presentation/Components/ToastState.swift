//
//  ToastState.swift
//  KakaoImageSearch
//
//  Created by tykim on 4/3/26.
//

import Foundation

/// ViewModel에서 토스트 메시지 표시/자동 해제를 관리하는 공용 헬퍼.
@Observable
@MainActor
final class ToastState {

    private(set) var message: String?
    private var task: Task<Void, Never>?
    private let duration: Duration

    init(duration: Duration = ToastView.defaultDuration) {
        self.duration = duration
    }

    func show(_ message: String) {
        task?.cancel()
        self.message = message
        task = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self.message = nil
        }
    }
}
