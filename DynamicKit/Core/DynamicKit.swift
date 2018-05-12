
import Foundation

public struct CocoaPod: Equatable {
    public let name: String
    public let url: String?
    //    public let version: String
    public init(_ name: String, url: String? = nil) {
        self.name = name
        self.url = url
    }
}

public struct DynamicKit: Equatable {
    
    public let dependency: [CocoaPod] = []
    
    public struct Dependency: Equatable {
        public let subpods: [SubPod]
        public let cocoapods: [CocoaPod]
        
        public init(subpods: [SubPod], cocoapods: [CocoaPod]) {
            self.subpods = subpods
            self.cocoapods = cocoapods
        }
    }
    
    public enum SubPod: String, Equatable {
        case core    = "Core"
        case eval    = "Eval"
        case http    = "HTTP"
        case mirror  = "Mirror"
        case runtime = "Runtime"
        case uikit   = "UIKit"
        case boxing  = "Boxing"
        
        public var dependency: Dependency {
            switch self {
            case .uikit:
                return Dependency.init(subpods: [.eval], cocoapods: [])
            case .http:
                return Dependency.init(subpods: [.core], cocoapods: [])
            default:
                return Dependency.init(subpods: [], cocoapods: [])
            }
        }
    }
    
    public static let subpods: [SubPod] = [
        .core,
        .eval,
        .http,
        .mirror,
        .runtime,
        .uikit,
        .boxing
    ]
    
    public struct Podfile: Equatable {
        
        public struct XcodeTarget: Equatable {
            
            public enum TargetPlatform: Equatable {
                case ios(String)
                case macox(String)
                case watchos(String)
                case tvos(String)
                
                public static func == (lhs: TargetPlatform, rhs: TargetPlatform) -> Bool {
                    switch (lhs, rhs) {
                    case let (.ios(a), .ios(b)):
                        return a == b
                    case let (.macox(a), .macox(b)):
                        return a == b
                    case let (.watchos(a), .watchos(b)):
                        return a == b
                    case let (.tvos(a), .tvos(b)):
                        return a == b
                    default:
                        return false
                    }
                }
                
                public var version: String {
                    switch self {
                    case .ios(let v): return v
                    case .macox(let v): return v
                    case .watchos(let v): return v
                    case .tvos(let v): return v
                    }
                }
                
                public var name: String {
                    switch self {
                    case .ios(_): return "ios"
                    case .macox(_): return "macos"
                    case .watchos(_): return "watchos"
                    case .tvos(_): return "tvos"
                    }
                }
            }
            
            public let name: String
            public let platform: TargetPlatform
            public let dependency: [Dependency]
            
            public init(_ name: String, platform: TargetPlatform, dependency: [Dependency] = []) {
                self.name = name
                self.platform = platform
                self.dependency = dependency
            }
            
            fileprivate var podfile: String {
                let pods = self.dependency.map { (d) -> String in
                    return d.cocoapods.map { "\t\tpod '\($0.name)'" }.joined(separator: "\n")
                    }.joined(separator: "\n")
                return """
                \ttarget '\(self.name)' do
                \t\tplatform :\(self.platform.name), '\(self.platform.version)'
                
                \(pods.isEmpty ? "\t\t# ..." : pods)
                \tend
                """
            }
        }
        
        public static func generate(shared pods: [CocoaPod], targets: [XcodeTarget], project: String) -> String {
            
            
            
            return """
            source 'https://github.com/CocoaPods/Specs.git'
            project './\(project).xcodeproj'
            
            use_frameworks!
            inhibit_all_warnings!
            
            pre_install do |installer|
            
            end
            
            # Abstract ==== ==============================
            
            abstract_target 'All' do
            
            \(pods.map { "\tpod '\($0.name)'" }.joined(separator: "\n"))
            
            \(targets.map { $0.podfile }.joined(separator: "\n\n"))
            
            end
            """
        }
    }
}

