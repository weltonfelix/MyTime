//
//  String+Normalize.swift
//  MyTime
//
//  Created by Welton Felix on 24/05/26.
//

import Foundation

extension String {
    var normalized: String {
        self.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
    }
}
