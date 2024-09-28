//
//  MiscExtensions.swift
//  AndroidRestore
//
//  Created by Lrdsnow on 9/26/24.
//

import SwiftUI

extension String {
    func replacingFirstOccurrence(of target: String, with replacement: String) -> String {
        var newString = self
        if let range = newString.range(of: target) {
            newString.replaceSubrange(range, with: replacement)
        }
        return newString
    }
}
