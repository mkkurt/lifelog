import SwiftUI

struct QueryView: View {
    @Binding var isPresented: Bool
    @StateObject private var aiService = AIService.shared

    @State private var query: String = ""
    @State private var response: QueryResponse?
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Button(action: { isPresented = false }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Text("Ask LifeLog")
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Input area
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What would you like to know?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(alignment: .top, spacing: 8) {
                            TextField("e.g., What was I working on this morning?", text: $query, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(2...5)
                                .padding(10)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                                .onSubmit {
                                    performQuery()
                                }

                            Button(action: performQuery) {
                                if isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(width: 32, height: 32)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(query.isEmpty ? .secondary : .accentColor)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(query.isEmpty || isLoading)
                        }
                    }

                    // Response area
                    if let response = response {
                        ResponseView(response: response)
                    } else {
                        suggestionsView
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Suggestions

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try asking:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            ForEach(querySuggestions, id: \.self) { suggestion in
                Button(action: {
                    query = suggestion
                    performQuery()
                }) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                            .font(.subheadline)

                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    private let querySuggestions = [
        "What was I working on this morning?",
        "What email was I going to write?",
        "What was that command I ran earlier?",
        "What websites did I visit today?"
    ]

    // MARK: - Actions

    private func performQuery() {
        guard !query.isEmpty, !isLoading else { return }

        isLoading = true
        response = nil

        Task {
            let result = await aiService.processQuery(query)

            await MainActor.run {
                response = result
                isLoading = false
            }
        }
    }
}

// MARK: - Response View

struct ResponseView: View {
    let response: QueryResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Response text
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                        .font(.headline)

                    Text("Answer")
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                Text(response.response)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(10)

            // Relevant entries
            if !response.relevantEntries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Based on \(response.relevantEntries.count) relevant \(response.relevantEntries.count == 1 ? "entry" : "entries")")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    ForEach(response.relevantEntries.prefix(3)) { entry in
                        EntryPreview(entry: entry)
                    }

                    if response.relevantEntries.count > 3 {
                        Text("+ \(response.relevantEntries.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
    }
}

// MARK: - Entry Preview

struct EntryPreview: View {
    let entry: TextEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let appName = entry.appName {
                    HStack(spacing: 4) {
                        Image(systemName: "app.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)

                        Text(appName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }

                Spacer()

                Text(entry.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(entry.rawText)
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    QueryView(isPresented: .constant(true))
}
