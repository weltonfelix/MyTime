//
//  String+Similarity.swift
//  MyTime
//
//  Created by Welton Felix on 24/05/26.
//

import Foundation
import Playgrounds

extension String {
    /**
        Calculate the difference between two strings.

        The score is based on the minimum amount of edits required to transform the source string into
        the target

        - Parameter other: The target string
        - Returns: The levenshtein distance between both strings
     */
    private func levenshteinDistance(to other: String) -> Int {
        // Normalize both strings and transform in arrays
        let s = Array(self.normalized)
        let t = Array(other.normalized)

        let m = s.count  // Length of s
        let n = t.count  // Length of t

        // In case m is empty, we need to insert all n characters
        if m == 0 { return n }
        if n == 0 { return m }

        // M x N matrix of zeros
        var matrix = Array(
            repeating: Array(repeating: 0, count: n + 1),
            count: m + 1
        )

        // i operations are needed to transform an i-string into an empty string
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        // matrix[i][j] is the distance between the prefix of s (up to i) and
        // the prefix of t (up to j)
        for i in 1...m {
            for j in 1...n {
                if s[i - 1] == t[j - 1] {
                    // if both chars are the same, the distance is the same as
                    // up to the previous char
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    // otherwise, we need to edit the string with the lowest
                    // cost operation
                    matrix[i][j] =
                        1
                        + Swift
                        .min(
                            matrix[i - 1][j],  // deletion
                            // "MAR" -> "MA" -> remove R:
                            //  1 + the cost to transform MA(i-1) in MA(j)
                            matrix[i][j - 1],  // insertion
                            // "MA" -> "MAR" -> insert R: 1 +
                            //  1 + the cost of transforming MA(i) in MA(j-1)
                            matrix[i - 1][j - 1]  // substitution
                            // "CA" and "CO" A -> O: 1 edit + previous cost
                        )
                }
            }
        }

        return matrix[m][n]
    }

    func similarity(to other: String) -> Double {
        // Converts absolute distance into a normalized ratio, since raw edit
        // count is misleading without considering the strings' total lengths.
        let distance = levenshteinDistance(to: other)
        let maxLength = max(self.count, other.count)
        guard maxLength > 0 else { return 1.0 }
        return 1.0 - Double(distance) / Double(maxLength)
    }
}
