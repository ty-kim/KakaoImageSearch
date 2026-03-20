//
//  NetworkMonitor.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/20/26.
//

import Network
import os

/// NWPathMonitor를 래핑한 네트워크 상태 감지기.
/// NetworkMonitoring 프로토콜을 구현해 Presentation 레이어에서 추상에만 의존합니다.
final class NetworkMonitor: NetworkMonitoring, @unchecked Sendable {

    private struct State {
        var isConnected: Bool = true
        var isExpensive: Bool = false
    }

    private let monitor = NWPathMonitor()
    private let lock = OSAllocatedUnfairLock(initialState: State())

    var isConnected: Bool {
        lock.withLock { $0.isConnected }
    }

    var isExpensive: Bool {
        lock.withLock { $0.isExpensive }
    }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.lock.withLock {
                $0.isConnected = path.status == .satisfied
                $0.isExpensive = path.isExpensive
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    deinit {
        monitor.cancel()
    }
}
