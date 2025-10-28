import SwiftUI

struct QwenChatView: View {
    @StateObject private var viewModel = QwenChatViewModel()

    init(viewModel: QwenChatViewModel? = nil) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if viewModel.messages.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "text.bubble")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.secondary)
                                    Text("Ask Qwen something to get started.")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                            } else {
                                ForEach(viewModel.messages) { message in
                                    chatBubble(for: message)
                                        .id(message.id)
                                }
                            }

                            if viewModel.isGenerating {
                                typingIndicator
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .onChange(of: viewModel.messages.last?.id) { _, id in
                        guard let id else { return }
                        withAnimation {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }

                HStack(spacing: 12) {
                    TextField("Ask a question…", text: $viewModel.currentInput)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .onSubmit { viewModel.send() }

                    Button {
                        viewModel.send()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.sendDisabled)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, 4)
            }
            .navigationTitle("Qwen Chat")
        }
        .task {
            await viewModel.loadDefaultEngine()
        }
    }

    @ViewBuilder
    private func chatBubble(for message: QwenChatViewModel.Message) -> some View {
        HStack {
            if message.role == .assistant {
                bubbleText(message.text, isUser: false)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                bubbleText(message.text, isUser: true)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func bubbleText(_ text: String, isUser: Bool) -> some View {
        Text(text)
            .padding(12)
            .foregroundStyle(isUser ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isUser ? Color.accentColor : Color(.secondarySystemBackground))
            )
            .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)
    }

    private var typingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Thinking…")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.trailing, 60)
    }
}

#Preview {
    QwenChatView()
}
