//
//  MDBApp.swift
//  MDB
//
//  Created by Akhil Maddali on 25/07/25.
//

import SwiftUI

@main
struct MDBApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    // Set up any app-wide configurations here
                    setupAppearance()
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            // Add custom menu commands
            CommandGroup(replacing: .newItem) {
                Button("New Metadata Bridge") {
                    // This would reset the ContentView state in a real app
                    // For now, it's just a placeholder
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandMenu("Export") {
                Button("Export as DaVinci Resolve XML") {
                    // This would trigger export in a real app
                    // For now, it's just a placeholder
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                
                Button("Export as CSV") {
                    // This would trigger export in a real app
                    // For now, it's just a placeholder
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
    }
    
    private func setupAppearance() {
        // Set up the app's appearance
        let appearance = NSAppearance(named: .vibrantDark)
        NSApp.appearance = appearance
    }
}
