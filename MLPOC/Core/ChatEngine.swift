import Foundation

struct ChatEngine: Sendable {
    let runner: any ChatRunning
    let tokenizer: ChatTokenizer
    let systemPrompt: String
}
