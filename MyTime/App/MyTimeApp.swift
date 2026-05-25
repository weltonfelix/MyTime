//
//  MyTimeApp.swift
//  MyTime
//
//  Created by Welton Felix on 15/05/26.
//

import SwiftData
import SwiftUI

@main
struct MyTimeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().modelContainer(for: Routine.self)
        }
    }
}
