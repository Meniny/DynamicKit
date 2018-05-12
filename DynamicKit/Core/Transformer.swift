//
//  Transformer.swift
//
//
//  Created by Meniny on 2018-05-12.
//

import Foundation
#if os(iOS)
import UIKit
#endif

open class Transformer<Car, Robot> {
    
    public init() {}
    
    public func transform(_ original: Car) -> Robot? {
        return original as? Robot
    }
    
    public func transform(_ original: Car, completion: (Robot?) -> Void) {
        completion(transform(original))
    }
}

#if os(iOS)
open class DataToUIImageTransformer: Transformer<Data, UIImage> {
    public override func transform(_ original: Data) -> UIImage? {
        return UIImage.init(data: original)
    }
}
#endif

open class DataToStringTransformer: Transformer<Data, String> {
    public override func transform(_ original: Data) -> String? {
        return String.init(data: original, encoding: .utf8)
    }
}

open class DataToJSONTransformer: Transformer<Data, Any> {
    public override func transform(_ original: Data) -> Any? {
        return try? JSONSerialization.jsonObject(with: original, options: [])
    }
}

open class StringToJSONTransformer: Transformer<String, Any> {
    public override func transform(_ original: String) -> Any? {
        guard let data = original.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [])
    }
}

open class DataToModelTransformer<T: Codable>: Transformer<Data, T> {
    public override func transform(_ original: Data) -> T? {
        return try? JSONDecoder().decode(T.self, from: original)
    }
}

open class StringToModelTransformer<T: Codable>: Transformer<String, T> {
    public override func transform(_ original: String) -> T? {
        guard let data = original.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
