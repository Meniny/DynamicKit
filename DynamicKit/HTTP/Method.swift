//
//  HTTPMethod.swift
//  SwiftFoundation
//
//  Created by Alsey Coleman Miller on 6/29/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

public extension HTTP {
    
    /// HTTP Method.
    public enum Method: String {
        
        case get = "GET"
        case put = "PUT"
        case delete = "DELETE"
        case post = "POST"
        case options = "OPTIONS"
        case head = "HEAD"
        case trace = "TRACE"
        case connect = "CONNECT"
        case patch = "PATCH"
        
        init() { self = .get }
    }
}
