//
//  HTTPClient.swift
//  SwiftFoundation
//
//  Created by Alsey Coleman Miller on 9/02/15.
//  Copyright © 2015 PureSwift. All rights reserved.
//

import Foundation


// Dot notation syntax for class
public extension HTTP {
    
    public enum RequestError: Error {
        case transformingFailed
        case invaildURL
        case unknown
    }
    
    /// Loads HTTP requests
    public final class Client {
        
        public init(session: URLSession = URLSession.shared) {
            
            self.session = session
        }
        
        /// The backing ```NSURLSession```.
        public let session: URLSession
        
        /// Request the data from a URL synchronically.
        ///
        /// - Parameters:
        ///   - request: a `HTTP.Rerquest` object
        public func send(request: HTTP.Request) throws -> HTTP.Response {
            
            // build request...
            
            let urlRequest = Foundation.URLRequest(request: request)
            
            // execute request
            
            let semaphore = DispatchSemaphore(value: 0);
            
            var error: Swift.Error?
            
            var responseData: Data?
            
            var urlResponse: HTTPURLResponse?
            
            let dataTask = self.session.dataTask(with: urlRequest) { (data: Foundation.Data?, response: Foundation.URLResponse?, responseError: Swift.Error?) -> () in
                
                responseData = data
                
                urlResponse = response as? Foundation.HTTPURLResponse
                
                error = responseError
                
                semaphore.signal()
            }
            
            dataTask.resume()
            
            // wait for task to finish
            
            let _ = semaphore.wait(timeout: DispatchTime.distantFuture);
            
            guard urlResponse != nil else { throw error! }
            
            var response = HTTP.Response()
            
            response.statusCode = urlResponse!.statusCode
            
            if let data = responseData, data.count > 0 {
                
                response.body = data
            }
            
            response.headers = urlResponse!.allHeaderFields as! [String: String]
            
            response.url = urlResponse!.url
            
            return response
        }
        
        /// Request the data from a URL asynchronically.
        ///
        /// - Parameters:
        ///   - request: a `HTTP.Rerquest` object
        ///   - completion: completion handler to run when request finishs.
        ///   - failure: error handler to run when request finishs with error
        public func send(request: HTTP.Request, completion: @escaping (HTTP.Response) -> Void, failure: @escaping (Error) -> Void) {
            
            // build request...
            
            let urlRequest = Foundation.URLRequest(request: request)
            
            // execute request
            
            let dataTask = self.session.dataTask(with: urlRequest) { (data: Foundation.Data?, response: Foundation.URLResponse?, responseError: Swift.Error?) -> () in
                
                if let error = responseError {
                    DispatchQueue.main.async { failure(error) }
                    return
                }
                
                let urlResponse = response as? Foundation.HTTPURLResponse
                var result = HTTP.Response()
                result.url = urlResponse?.url
                if let responseData = data, !responseData.isEmpty {
                    result.body = responseData
                }
                if let code = urlResponse?.statusCode {
                    result.statusCode = code
                }
                if let allHeaders = urlResponse?.allHeaderFields, let headers = allHeaders as? [String: String] {
                    result.headers = headers
                }
                DispatchQueue.main.async { completion(result) }
            }
            
            dataTask.resume()
        }
        
        /// Request the data from a URL asynchronically.
        ///
        /// - Parameters:
        ///   - request: a `HTTP.Rerquest` object
        ///   - transformer: a Transformer
        ///   - completion: completion handler to run when request finishs.
        ///   - failure: error handler to run when request finishs with error.
        public func send<T>(_ request: HTTP.Request, transformer: Transformer<Data, T>, completion: @escaping ((T) -> Void), failure: @escaping (Error) -> Void) {
            send(request: request, completion: { (response) in
                guard let result = transformer.transform(response.body) else {
                    failure(HTTP.RequestError.transformingFailed)
                    return
                }
                completion(result)
            }, failure: failure)
        }
    }
}

public extension Foundation.URLRequest {
    
    init(request: HTTP.Request) {
                
        self.init(url: request.url, timeoutInterval: request.timeoutInterval)
        
        if !request.body.isEmpty {
            self.httpBody = request.body
        }
        
        self.allHTTPHeaderFields = request.headers
        
        self.httpMethod = request.method.rawValue
    }
}
