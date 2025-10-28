import Foundation
import Combine

@MainActor
final class QwenChatViewModel: ObservableObject {
    struct Message: Identifiable {
        enum Role {
            case user
            case assistant
        }

        let id = UUID()
        let role: Role
        let text: String
    }

    struct Engine {
        let runner: QwenRunner
        let tokenizer: Tokenizer
        let systemPrompt: String
    }

    @Published private(set) var messages: [Message] = []
    @Published var currentInput: String = ""
    @Published var isGenerating = false
    @Published var errorMessage: String?

    private var engine: Engine?

    init(engine: Engine? = nil) {
        self.engine = engine
        if engine == nil {
            errorMessage = "Configure Qwen models and tokenizer to enable on-device chat."
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

    func loadDefaultEngine(bundle: Bundle = .main) async {
        guard engine == nil else { return }
        errorMessage = nil

        do {
            let engine = try await Task.detached(priority: .userInitiated) {
                try await QwenEngineFactory.makeDefaultEngine(bundle: bundle)
            }.value
            configure(engine: engine)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveReply(for prompt: String) async -> String {
        guard let engine else {
            return "Qwen runner is not configured yet. Add a tokenizer and CoreML models to get live responses."
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
            try await engine.runner.generate(
                system: engine.systemPrompt,
                user: userPrompt,
                tokenizer: engine.tokenizer
            )
        }.value
    }
}
