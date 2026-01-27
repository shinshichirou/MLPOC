//
//  GGUFChatView.swift
//  MLPOC
//
//  Created by Codex on 11.12.2025.
//

import SwiftUI

struct GGUFChatView: View {
    @State private var selectedModel: GGUFModelType
    @State private var isLoading = false
    private let chatViewModel: ChatViewModel

    init(defaultModel: GGUFModelType = .gemma3Instruction) {
        _selectedModel = State(initialValue: defaultModel)
        let engine = try? GGUFChatEngineFactory.makeEngine(for: defaultModel)
        chatViewModel = ChatViewModel(engine: engine, initialModel: .empty)
    }

    var body: some View {
        ChatView(
            viewModel: chatViewModel,
            navigationTitle: "GGUF",
            showModelPicker: false,
            autoPrepare: false
        ) {
            modelPicker
        }
        .task {
            await loadEngine(for: selectedModel, force: false)
        }
        .onChange(of: selectedModel) { _, newValue in
            Task {
                await loadEngine(for: newValue, force: true)
            }
        }
    }

    // MARK: - Model selection
    @ViewBuilder
    private var modelPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("GGUF Model", selection: $selectedModel) {
                ForEach(GGUFModelType.allCases) { model in
                    Text(model.title).tag(model)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 8) {
                Text(selectedModel.details)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Engine loading
    private func loadEngine(for model: GGUFModelType, force: Bool) async {
        let shouldLoad = await MainActor.run { force || chatViewModel.messages.isEmpty }
        guard shouldLoad else { return }
        await MainActor.run { isLoading = true }

        do {
            let engine = try GGUFChatEngineFactory.makeEngine(for: model)
            await MainActor.run {
                chatViewModel.configure(engine: engine)
                chatViewModel.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                chatViewModel.errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

#Preview {
    GGUFChatView()
}
