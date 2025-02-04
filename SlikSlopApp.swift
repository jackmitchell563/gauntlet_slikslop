//
//  SlikSlopApp.swift
//  SlikSlop
//
//  Created by Jack Mitchell on 2/3/25.
//

import SwiftUI
import FirebaseCore

@main
struct SlikSlopApp: App {
    init() {
        // Initialize Firebase synchronously
        FirebaseConfig.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
