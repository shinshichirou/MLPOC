import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    struct Message: Identifiable {
        enum Role {
            case user
            case assistant
        }

        let id = UUID()
        let role: Role
        let text: String
    }

    struct Engine: Sendable {
        let runner: any ChatRunning
        let tokenizer: ChatTokenizer
        let systemPrompt: String
    }

    @Published private(set) var messages: [Message] = []
    @Published var currentInput: String = ""
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var selectedModel: ChatModelType {
        didSet {
            guard modelSelectionActive, selectedModel != oldValue else { return }
            Task { [weak self] in
                guard let self else { return }
                await self.loadEngine(for: selectedModel, bundle: modelBundle)
            }
        }
    }

    private var engine: Engine?
    private var modelBundle: Bundle = .main
    private var modelSelectionActive = false

    init(engine: Engine? = nil, initialModel: ChatModelType = .empty) {
        self.engine = engine
        self.selectedModel = initialModel
        if engine == nil {
            errorMessage = "Configure the chat models and tokenizer to enable on-device responses."
        } else {
            errorMessage = nil
        }
    }

    var sendDisabled: Bool {
        currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating
    }

    func configure(engine: Engine) {
        self.engine = engine
        errorMessage = nil
    }

    func send() {
        let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = Message(role: .user, text: trimmed)
        messages.append(userMessage)
        currentInput = ""
        isGenerating = true
        errorMessage = nil

        Task { [weak self] in
            guard let self else { return }
            let reply = await self.resolveReply(for: trimmed)
            if Task.isCancelled { return }

            self.messages.append(Message(role: .assistant, text: reply))
            self.isGenerating = false
        }
    }

    func prepareForUse(bundle: Bundle = .main) async {
        modelBundle = bundle
        modelSelectionActive = true
        await loadEngine(for: selectedModel, bundle: bundle)
    }

    @discardableResult
    func loadEngine(for model: ChatModelType, bundle: Bundle = .main) async -> Bool {
        guard let configuration = model.configuration else {
            engine = nil
            errorMessage = "Select a chat model to enable on-device replies."
            return false
        }

        errorMessage = nil

        do {
            let engine = try await Task.detached(priority: .userInitiated) {
                return try ChatEngineFactory.makeEngine(for: model, bundle: bundle)
            }.value
            configure(engine: engine)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func resolveReply(for prompt: String) async -> String {
        guard let engine else {
            return "Chat runner is not configured yet. Add a tokenizer and CoreML models to get live responses."
        }

        do {
            return try await runInference(using: engine, userPrompt: prompt)
        } catch {
            self.errorMessage = error.localizedDescription
            return "Something went wrong: \(error.localizedDescription)"
        }
    }

    private func runInference(using engine: Engine, userPrompt: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            return try engine.runner.generate(
                system: engine.systemPrompt,
                user: userPrompt,
                tokenizer: engine.tokenizer
            )
        }.value
    }
}
