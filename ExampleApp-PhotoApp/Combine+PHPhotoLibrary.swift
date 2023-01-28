//
//  Combine+PHPhotoLibrary.swift
//  ExampleApp-PhotoApp
//
//  Created by Yuriy Gudimov on 28.01.2023.
//

import Foundation
import Photos
import Combine

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
