//
//  HTTPRequest.swift
//  SwiftFoundation
//
//  Created by Alsey Coleman Miller on 6/29/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

import struct Foundation.Data
import struct Foundation.URL
import typealias Foundation.TimeInterval

public extension HTTP {
    
    /// HTTP request. 
    public struct Request {
        
        public var url: URL
        
        public var timeoutInterval: TimeInterval
        
        public var body: Data
        
        public var headers: [String: String]
        
        public var method: HTTP.Method
        
        public init(url: URL,
                    timeoutInterval: TimeInterval = 30,
                    body: Data = Data(),
                    headers: [String: String] = [:],
                    method: HTTP.Method = .get) {
            
            self.url = url
            self.timeoutInterval = timeoutInterval
            self.body = body
            self.headers = headers
            self.method = method
        }
    }
}

