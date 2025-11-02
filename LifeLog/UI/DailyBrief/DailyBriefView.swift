import SwiftUI

struct DailyBriefView: View {
    @Binding var isPresented: Bool
    @StateObject private var meaningEngine = MeaningEngine.shared
    @State private var dailyBrief: DailyBrief?
    @State private var isLoading = true

    init(isPresented: Binding<Bool> = .constant(true)) {
        self._isPresented = isPresented
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        loadingView
                            .frame(maxHeight: .infinity)
                    } else if let brief = dailyBrief {
                        briefContentView(brief: brief)
                    } else {
                        emptyStateView
                            .frame(maxHeight: .infinity)
                    }
                }
                .padding()
            }
        }
        .task {
            await loadDailyBrief()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Button(action: { isPresented = false }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Brief")
                    .font(.headline)
                    .fontWeight(.bold)

                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { Task { await loadDailyBrief() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Calculating daily metrics...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Activity Yet")
                .font(.headline)

            Text("Start using your computer and LifeLog will build your daily brief.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Brief Content

    private func briefContentView(brief: DailyBrief) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Quality Score Card
            qualityScoreCard(metrics: brief.metrics)

            // Key Metrics
            keyMetricsCard(metrics: brief.metrics)

            // Insights
            if !brief.insights.isEmpty {
                insightsCard(insights: brief.insights)
            }

            // Active Patterns
            if !brief.hypotheses.isEmpty {
                patternsCard(hypotheses: brief.hypotheses)
            }
        }
    }

    // MARK: - Quality Score Card

    private func qualityScoreCard(metrics: DailyMetrics) -> some View {
        VStack(spacing: 16) {
            // Score circle
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: metrics.qualityScore / 100)
                    .stroke(
                        qualityColor(score: metrics.qualityScore),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: metrics.qualityScore)

                VStack(spacing: 4) {
                    Text("\(Int(metrics.qualityScore))")
                        .font(.system(size: 36, weight: .bold))

                    Text("Quality")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(qualityMessage(score: metrics.qualityScore))
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Key Metrics Card

    private func keyMetricsCard(metrics: DailyMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Metrics")
                .font(.headline)

            VStack(spacing: 12) {
                MetricRow(
                    icon: "target",
                    label: "Focus Ratio",
                    value: String(format: "%.0f%%", metrics.focusRatio * 100),
                    color: .blue
                )

                MetricRow(
                    icon: "bolt.fill",
                    label: "Deep Blocks",
                    value: "\(metrics.deepBlocksCount)",
                    color: .purple
                )

                MetricRow(
                    icon: "arrow.triangle.swap",
                    label: "Switches/Hour",
                    value: String(format: "%.1f", metrics.switchesPerHour),
                    color: .orange
                )

                MetricRow(
                    icon: "clock.fill",
                    label: "Active Time",
                    value: String(format: "%.1fh", metrics.totalActiveTime / 3600),
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Insights Card

    private func insightsCard(insights: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)

            ForEach(insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.secondary)

                    Text(insight)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Patterns Card

    private func patternsCard(hypotheses: [Hypothesis]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Patterns")
                .font(.headline)

            ForEach(hypotheses) { hypothesis in
                HStack(spacing: 12) {
                    Image(systemName: hypothesisIcon(type: hypothesis.type))
                        .foregroundColor(hypothesisColor(type: hypothesis.type))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(hypothesis.type.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Confidence: \(Int(hypothesis.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func loadDailyBrief() async {
        isLoading = true

        // Calculate metrics for today
        _ = await meaningEngine.calculateDailyMetrics()

        // Get daily brief
        dailyBrief = await meaningEngine.generateDailyBrief()

        isLoading = false
    }

    private func qualityColor(score: Double) -> Color {
        if score >= 70 {
            return .green
        } else if score >= 50 {
            return .orange
        } else {
            return .red
        }
    }

    private func qualityMessage(score: Double) -> String {
        if score >= 70 {
            return "Excellent Day!"
        } else if score >= 50 {
            return "Good Progress"
        } else {
            return "Room for Improvement"
        }
    }

    private func hypothesisIcon(type: HypothesisType) -> String {
        switch type {
        case .deepWork:
            return "brain.head.profile"
        case .stuck:
            return "exclamationmark.triangle"
        case .exploration:
            return "safari"
        case .drift:
            return "wind"
        case .scatter:
            return "sparkles"
        case .complexityBuildup:
            return "chart.line.uptrend.xyaxis"
        case .looping:
            return "arrow.triangle.2.circlepath"
        case .flow:
            return "drop.fill"
        case .grind:
            return "gearshape.2"
        }
    }

    private func hypothesisColor(type: HypothesisType) -> Color {
        switch type {
        case .deepWork, .flow:
            return .green
        case .exploration:
            return .blue
        case .stuck, .drift, .scatter:
            return .orange
        case .complexityBuildup, .looping, .grind:
            return .purple
        }
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

#Preview {
    DailyBriefView()
}
