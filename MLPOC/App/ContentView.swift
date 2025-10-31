//
//  ContentView.swift
//  MLPOC
//
//  Created by Igor Tudoran on 21.10.2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .objectRecognition

    var body: some View {
        TabView(selection: $selectedTab) {
            ObjectRecognitionRootView()
                .tabItem {
                    Label("Recognize", systemImage: "camera.viewfinder")
                }
                .tag(AppTab.objectRecognition)

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "ellipsis.bubble")
                }
                .tag(AppTab.chat)
        }
    }
}

#Preview {
    ContentView()
}
