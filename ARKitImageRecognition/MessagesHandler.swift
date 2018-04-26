//
//  MessagesHandler.swift
//  ARKitImageRecognition
//
//  Created by Eran Heres on 25/04/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation

class NetworkApplicationLayer {
    func message(str : String) {
        let dict = convertToDictionary(text: str)
    }

    func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }

}
