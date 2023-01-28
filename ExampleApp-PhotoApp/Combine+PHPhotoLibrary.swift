//
//  Combine+PHPhotoLibrary.swift
//  ExampleApp-PhotoApp
//
//  Created by Yuriy Gudimov on 28.01.2023.
//

import Foundation
import Photos
import Combine
import UIKit

extension PHPhotoLibrary {
    static func authorizationStatusPublisher(for accessLevel: PHAccessLevel) -> AnyPublisher<PHAuthorizationStatus, Never> {
        Deferred {
            Future { promise in
                requestAuthorization(for: accessLevel) { status in
                    promise(.success(status))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

extension PHImageManager {
    func publisher(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?) -> PHImageManagerRequestPublisher {
        PHImageManagerRequestPublisher(asset: asset, targetSize: targetSize, contentMode: contentMode, options: options)
    }
}

struct PHImageManagerRequestPublisher: Publisher {
    typealias Output = UIImage
    typealias Failure = Error
    
    let asset: PHAsset
    let targetSize: CGSize
    let contentMode: PHImageContentMode
    let options: PHImageRequestOptions?
    
    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, UIImage == S.Input {
        let subscription = Subscription(subscriber: subscriber, asset: asset, targetSize: targetSize, contentMode: contentMode, options: options)
        subscriber.receive(subscription: subscription)
    }
}

extension PHImageManagerRequestPublisher {
    final class Subscription<S: Subscriber>: Combine.Subscription where S.Input == Output, S.Failure == Failure {
        let asset: PHAsset
        let targetSize: CGSize
        let contentMode: PHImageContentMode
        let options: PHImageRequestOptions?
        
        var subscriber: S?
        var requestID: PHImageRequestID?
        
        init(subscriber: S, asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, options: PHImageRequestOptions?) {
            self.asset = asset
            self.targetSize = targetSize
            self.contentMode = contentMode
            self.options = options
            self.subscriber = subscriber
        }
        
        func cancel() {
            subscriber = nil
            if let request = requestID {
                PHImageManager.default().cancelImageRequest(request)
            }
        }
        
        func request(_ demand: Subscribers.Demand) {
            
            if let subscriber = subscriber, demand > 0 {
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
                    if let image = image {
                        _ = subscriber.receive(image)
                        subscriber.receive(completion: .finished)
                    } else {
                        if let error = info?[PHImageErrorKey] as? Error {
                            subscriber.receive(completion: .failure(error))
                        } else {
                            subscriber.receive(completion: .finished)
                        }
                    }
                }
            }
        }
    }
}

struct PHFetchResultPublisher<ObjectType: AnyObject>: Publisher {
    typealias Output = ObjectType
    typealias Failure = Never
    
    var fetchResults: PHFetchResult<ObjectType>
    
    init(fetchResult: PHFetchResult<ObjectType>) {
        self.fetchResults = fetchResult
        
    }
    
    func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, ObjectType == S.Input {
        let subscription = Subscription(subscriber: subscriber, fetchResult: fetchResults)
        subscriber.receive(subscription: subscription)
    }
}

extension PHFetchResult where ObjectType == PHAsset {
    var publisher: PHFetchResultPublisher<ObjectType> {
        PHFetchResultPublisher(fetchResult: self)
    }
}

extension PHFetchResultPublisher {
    final class Subscription<S: Subscriber>: Combine.Subscription where S.Input == Output, S.Failure == Failure {
        let fetchResult: PHFetchResult<ObjectType>
        var subscriber: S?
        
        private var index: Int = 0
        private var count: Int {
            fetchResult.count
        }
        
        private var hasMoreResult: Bool {
            index < count - 1
        }
        
        init(subscriber: S, fetchResult: PHFetchResult<ObjectType>) {
            self.subscriber = subscriber
            self.fetchResult = fetchResult
        }
        
        func cancel() {
            subscriber = nil
        }
        
        func request(_ demand: Subscribers.Demand) {
            guard count > 0 else {
                subscriber?.receive(completion: .finished)
                subscriber = nil
                return
            }
            
            var demand = demand
            while hasMoreResult, let subscriber = subscriber, demand > 0 {
                let numberOfObjectsToFetch = demand.max ?? 1
                Swift.print("Requesting up to \(numberOfObjectsToFetch) object(s)...")
                Swift.print("Total: \(count), index: \(index)")
                
                for obj in fetchObjects(upTo: numberOfObjectsToFetch) {
                    let newDemand = subscriber.receive(obj)
                    if self.subscriber == nil {
                        break
                    }
                    demand += newDemand
                }
                if !hasMoreResult {
                    subscriber.receive(completion: .finished)
                    self.subscriber = nil
                }
            }
        }
        
        private func fetchObjects(upTo count: Int) -> [ObjectType] {
            let endIndex = Swift.min(index + count, self.count)
            let range = index..<endIndex
            let set = IndexSet(integersIn: range)
            let objects = fetchResult.objects(at: set)
            index += objects.count
            
            return objects
        }
    }
}
