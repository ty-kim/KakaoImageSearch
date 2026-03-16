//
//  DIContainer.swift
//  KakaoImageSearch
//
//  Created by tykim on 3/16/26.
//

import Foundation

/// 타입 기반 경량 DI 컨테이너.
/// - register: 팩토리 등록 (lazy, 최초 resolve 시점에 인스턴스 생성)
/// - resolve: 등록된 인스턴스 반환 (싱글턴 스코프)
@MainActor
final class DIContainer {

    static let shared = DIContainer()

    private var factories: [ObjectIdentifier: @MainActor () -> Any] = [:]
    private var instances: [ObjectIdentifier: Any] = [:]

    private init() {}

    @discardableResult
    func register<T>(_ type: T.Type, factory: @MainActor @escaping () -> T) -> Self {
        factories[ObjectIdentifier(type)] = factory
        return self
    }

    func resolve<T>(_ type: T.Type) -> T {
        let key = ObjectIdentifier(type)

        if let existing = instances[key] as? T {
            return existing
        }

        guard let factory = factories[key] else {
            fatalError("[DIContainer] \(T.self) 에 대한 팩토리가 등록되지 않았습니다.")
        }

        // swiftlint:disable:next force_cast
        let instance = factory() as! T
        instances[key] = instance
        return instance
    }
}
