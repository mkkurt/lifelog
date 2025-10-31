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
            HStack {
                Button(action: { isPresented = false }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Text("Ask LifeLog")
                    .font(.headline)

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
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
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)

                            Button(action: performQuery) {
                                if isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title2)
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
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(querySuggestions, id: \.self) { suggestion in
                Button(action: {
                    query = suggestion
                    performQuery()
                }) {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.orange)
                        Text(suggestion)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top)
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
        VStack(alignment: .leading, spacing: 12) {
            // Response text
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                    Text("Answer")
                        .font(.headline)
                }

                Text(response.response)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)

            // Relevant entries
            if !response.relevantEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Based on \(response.relevantEntries.count) relevant entries")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(response.relevantEntries.prefix(3)) { entry in
                        EntryPreview(entry: entry)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let appName = entry.appName {
                    Text(appName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
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
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

#Preview {
    QueryView(isPresented: .constant(true))
}
