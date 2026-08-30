//
//  devcomApp.swift
//  devcom
//
//  Created by Maxim Kabaev on 30/08/2026.
//

import SwiftUI

@main
struct devcomApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
