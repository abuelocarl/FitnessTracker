//
//  Fitness_Hydration_TrackerApp.swift
//  Fitness Hydration Tracker
//
//  Created by Carlos Calegari on 3/6/26.
//

import SwiftUI
import UIKit

@main
struct Fitness_Hydration_TrackerApp: App {

    init() {
        // Suppress any system-generated UITabBar (prevents question-mark icons
        // that iOS can inject even when no SwiftUI TabView is present).
        UITabBar.appearance().isHidden = true
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
