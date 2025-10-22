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
            ObjectRecognitionView()
                .tabItem {
                    Label("Recognize", systemImage: "camera.viewfinder")
                }
                .tag(AppTab.objectRecognition)

            PlaceholderFeatureView()
                .tabItem {
                    Label("Upcoming", systemImage: "sparkles")
                }
                .tag(AppTab.placeholder)
        }
    }
}

#Preview {
    ContentView()
}
