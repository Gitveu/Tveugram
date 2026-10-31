import Foundation

public struct NWPath: @unchecked Sendable {
    public enum Status: @unchecked Sendable, Equatable {
        case satisfied
        case unsatisfied
        case requiresConnection
    }
    public var status: Status {
        return .satisfied
    }
    public init() {}
}

public final class NWPathMonitor: @unchecked Sendable {
    public init() {}
    public init(requiredInterfaceType: Any? = nil) {}
    
    public var currentPath: NWPath {
        return NWPath()
    }
    
    public func start(queue: DispatchQueue) {}
    public func cancel() {}
}

public enum NWEndpoint: @unchecked Sendable {
    public enum Host: ExpressibleByStringLiteral, @unchecked Sendable {
        case name(String, Any?)
        public init(stringLiteral value: String) {
            self = .name(value, nil)
        }
    }
    public struct Port: RawRepresentable, @unchecked Sendable {
        public var rawValue: UInt16
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
    }
    case hostPort(host: Host, port: Port)
}

public final class NWParameters: @unchecked Sendable {
    public static var tcp: NWParameters {
        return NWParameters()
    }
    public init() {}
}

public struct NWError: Error, Equatable, @unchecked Sendable {
    public init() {}
}

public final class NWConnection: @unchecked Sendable {
    public enum State: @unchecked Sendable, Equatable {
        case setup
        case waiting(NWError)
        case preparing
        case ready
        case failed(NWError)
        case cancelled
    }
    
    public var state: State = .ready
    public var stateUpdateHandler: ((State) -> Void)? = nil
    
    public init(to: NWEndpoint, using: NWParameters) {}
    
    public func start(queue: DispatchQueue) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.state = .ready
            self.stateUpdateHandler?(.ready)
        }
    }
    
    public func cancel() {
        self.state = .cancelled
        self.stateUpdateHandler?(.cancelled)
    }
}
