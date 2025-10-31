import Foundation

/// Generates behavioral hypotheses from extracted features using rule-based detection
actor HypothesisGenerator {
    static let shared = HypothesisGenerator()

    private var isRunning = false
    private var generationTimer: Task<Void, Never>?

    // Active hypotheses tracking
    private var activeHypotheses: [Int64: Hypothesis] = [:]

    private init() {}

    // MARK: - Public Interface

    func startGeneration() {
        guard !isRunning else { return }
        isRunning = true

        generationTimer = Task {
            while !Task.isCancelled {
                await generateHypotheses()

                // Run every 5 minutes
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 300 seconds
            }
        }

        Logger.log("HypothesisGenerator started", log: Logger.storage)
    }

    func stopGeneration() {
        isRunning = false
        generationTimer?.cancel()
        generationTimer = nil

        Logger.log("HypothesisGenerator stopped", log: Logger.storage)
    }

    // MARK: - Hypothesis Generation

    private func generateHypotheses() async {
        // Look back at recent features (last 60 minutes for pattern detection)
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-3600) // 60 minutes

        let features = await getRecentFeatures(from: startTime, to: endTime)

        guard !features.isEmpty else {
            Logger.log("No features available for hypothesis generation", log: Logger.storage, type: .debug)
            return
        }

        // Run all detection rules
        await detectDeepWork(features: features)
        await detectStuck(features: features)
        await detectExplorationVsDrift(features: features)
        await detectScatter(features: features)
        await detectComplexityBuildup(features: features)
        await detectLooping(features: features)
        await detectFlowState(features: features)
        await detectGrinding(features: features)

        // Close expired hypotheses
        await closeExpiredHypotheses()
    }

    private func getRecentFeatures(from startTime: Date, to endTime: Date) async -> [Feature] {
        // This would query features table
        // For now, placeholder
        // TODO: Implement StorageService.getFeatures(from:to:)
        return []
    }

    // MARK: - Detection Rules

    /// Deep Work: 45+ min, single topic, ≤2 switches, flow > 0.6
    private func detectDeepWork(features: [Feature]) async {
        guard features.count >= 3 else { return } // Need at least 45 min of data (3 × 15min windows)

        // Check for sustained focus
        let recentFeatures = Array(features.suffix(3))

        // Calculate metrics
        let avgBlockLength = recentFeatures.map { $0.blockLength }.reduce(0, +) / Double(recentFeatures.count)
        let avgSwitchRate = recentFeatures.map { $0.taskSwitchRate }.reduce(0, +) / Double(recentFeatures.count)
        let avgFlow = recentFeatures.map { $0.flowIndicator }.reduce(0, +) / Double(recentFeatures.count)

        // Check topic continuity
        let topics = recentFeatures.compactMap { $0.topicLabel }
        let topicSet = Set(topics)

        // Rule conditions
        let longBlocks = avgBlockLength >= 600 // 10+ min average blocks
        let lowSwitches = avgSwitchRate <= 4 // ≤4 switches per hour
        let highFlow = avgFlow > 0.6
        let singleTopic = topicSet.count <= 2

        guard longBlocks && lowSwitches && highFlow && singleTopic else {
            // Close any active deep work hypothesis
            await closeHypothesisIfActive(type: .deepWork)
            return
        }

        // Calculate confidence
        let blockScore = min(avgBlockLength / 1800, 1.0) // 30 min = 1.0
        let switchScore = max(0, 1.0 - (avgSwitchRate / 12))
        let flowScore = avgFlow
        let topicScore = topicSet.count == 1 ? 1.0 : 0.7

        let confidence = (blockScore * 0.3) + (switchScore * 0.2) + (flowScore * 0.3) + (topicScore * 0.2)

        // Create or update hypothesis
        let evidence = [
            "Long focus blocks: \(Int(avgBlockLength / 60)) min average",
            "Low interruptions: \(String(format: "%.1f", avgSwitchRate)) switches/hr",
            "High flow indicator: \(String(format: "%.2f", avgFlow))",
            "Topic continuity: \(topicSet.count) topic(s)"
        ]

        await createOrUpdateHypothesis(
            type: .deepWork,
            confidence: confidence,
            evidence: evidence,
            features: recentFeatures
        )
    }

    /// Stuck: repetition > 0.7, same topic, output < 0.3, 30+ min
    private func detectStuck(features: [Feature]) async {
        guard features.count >= 2 else { return }

        let recentFeatures = Array(features.suffix(2))

        // Calculate metrics
        let avgRepetition = recentFeatures.map { $0.repetitionScore }.reduce(0, +) / Double(recentFeatures.count)
        let avgOutput = recentFeatures.map { $0.outputDensity }.reduce(0, +) / Double(recentFeatures.count)

        // Check topic consistency
        let topics = recentFeatures.compactMap { $0.topicLabel }
        let sameTopic = topics.count >= 2 && topics.allSatisfy { $0 == topics.first }

        // Rule conditions
        let highRepetition = avgRepetition > 0.7
        let lowOutput = avgOutput < 0.3
        let duration = recentFeatures.count * 5 // 5 min per window

        guard highRepetition && sameTopic && lowOutput && duration >= 30 else {
            await closeHypothesisIfActive(type: .stuck)
            return
        }

        // Calculate confidence
        let repetitionScore = avgRepetition
        let outputScore = max(0, 1.0 - (avgOutput / 0.3))
        let durationScore = min(Double(duration) / 60, 1.0) // 60 min = 1.0
        let topicScore = sameTopic ? 1.0 : 0.0

        let confidence = (repetitionScore * 0.4) + (outputScore * 0.3) + (durationScore * 0.2) + (topicScore * 0.1)

        let evidence = [
            "High repetition: \(String(format: "%.2f", avgRepetition))",
            "Low output: \(String(format: "%.1f", avgOutput)) artifacts/hr",
            "Same topic: \(topics.first ?? "unknown")",
            "Duration: \(duration) min"
        ]

        await createOrUpdateHypothesis(
            type: .stuck,
            confidence: confidence,
            evidence: evidence,
            features: recentFeatures
        )
    }

    /// Exploration vs Drift: consumption time + topic similarity threshold (0.6)
    private func detectExplorationVsDrift(features: [Feature]) async {
        guard let latestFeature = features.last else { return }

        let consumptionTime = latestFeature.passiveConsumption + latestFeature.activeConsumption
        let totalTime = latestFeature.windowDuration

        guard consumptionTime > totalTime * 0.5 else {
            // Not enough consumption to classify
            await closeHypothesisIfActive(type: .exploration)
            await closeHypothesisIfActive(type: .drift)
            return
        }

        // Check topic continuity to distinguish exploration from drift
        let topicContinuity = latestFeature.topicContinuity

        if topicContinuity > 0.6 {
            // Exploration: consumption with topic continuity
            let confidence = min(consumptionTime / totalTime, 1.0)
            let evidence = [
                "Active consumption: \(Int(latestFeature.activeConsumption / 60)) min",
                "Passive consumption: \(Int(latestFeature.passiveConsumption / 60)) min",
                "Topic continuity: \(String(format: "%.2f", topicContinuity))",
                "Relevant to current work"
            ]

            await createOrUpdateHypothesis(
                type: .exploration,
                confidence: confidence,
                evidence: evidence,
                features: [latestFeature]
            )
            await closeHypothesisIfActive(type: .drift)

        } else {
            // Drift: consumption without topic continuity
            let confidence = min(consumptionTime / totalTime, 1.0) * (1.0 - topicContinuity)
            let evidence = [
                "Passive consumption: \(Int(latestFeature.passiveConsumption / 60)) min",
                "Low topic continuity: \(String(format: "%.2f", topicContinuity))",
                "Unrelated to current work"
            ]

            await createOrUpdateHypothesis(
                type: .drift,
                confidence: confidence,
                evidence: evidence,
                features: [latestFeature]
            )
            await closeHypothesisIfActive(type: .exploration)
        }
    }

    /// Scatter: ≥12 switches/hr, blocks < 5 min
    private func detectScatter(features: [Feature]) async {
        guard let latestFeature = features.last else { return }

        let switchRate = latestFeature.taskSwitchRate
        let blockLength = latestFeature.blockLength
        let microDistractions = latestFeature.microDistractionCount

        // Rule conditions
        let highSwitches = switchRate >= 12
        let shortBlocks = blockLength < 300 // 5 minutes
        let hasDistractions = microDistractions > 3

        guard highSwitches || (shortBlocks && hasDistractions) else {
            await closeHypothesisIfActive(type: .scatter)
            return
        }

        // Calculate confidence
        let switchScore = min(switchRate / 24, 1.0) // 24 switches/hr = max
        let blockScore = max(0, 1.0 - (blockLength / 300))
        let distractionScore = min(Double(microDistractions) / 10, 1.0)

        let confidence = (switchScore * 0.4) + (blockScore * 0.3) + (distractionScore * 0.3)

        let evidence = [
            "High switch rate: \(String(format: "%.1f", switchRate)) switches/hr",
            "Short blocks: \(Int(blockLength / 60)) min average",
            "Micro-distractions: \(microDistractions)"
        ]

        await createOrUpdateHypothesis(
            type: .scatter,
            confidence: confidence,
            evidence: evidence,
            features: [latestFeature]
        )
    }

    /// Complexity Build-up: Rising tool/source diversity
    private func detectComplexityBuildup(features: [Feature]) async {
        guard features.count >= 4 else { return }

        let recentFeatures = Array(features.suffix(4))

        // Track increasing switches and decreasing flow
        let switchRates = recentFeatures.map { $0.taskSwitchRate }
        let flowIndicators = recentFeatures.map { $0.flowIndicator }

        // Check for upward trend in switches
        let switchTrend = isTrendIncreasing(values: switchRates)
        let flowTrend = isTrendDecreasing(values: flowIndicators)

        guard switchTrend && flowTrend else {
            await closeHypothesisIfActive(type: .complexityBuildup)
            return
        }

        // Calculate confidence based on trend strength
        let avgSwitchRate = switchRates.reduce(0, +) / Double(switchRates.count)
        let avgFlow = flowIndicators.reduce(0, +) / Double(flowIndicators.count)

        let switchScore = min(avgSwitchRate / 12, 1.0)
        let flowScore = max(0, 1.0 - avgFlow)

        let confidence = (switchScore * 0.5) + (flowScore * 0.5)

        let evidence = [
            "Increasing task switches: \(String(format: "%.1f", avgSwitchRate)) switches/hr",
            "Decreasing flow: \(String(format: "%.2f", avgFlow))",
            "Rising complexity over \(recentFeatures.count * 5) min"
        ]

        await createOrUpdateHypothesis(
            type: .complexityBuildup,
            confidence: confidence,
            evidence: evidence,
            features: recentFeatures
        )
    }

    /// Looping: Repetitive return to same sources
    private func detectLooping(features: [Feature]) async {
        guard features.count >= 3 else { return }

        let recentFeatures = Array(features.suffix(3))

        // Check for high repetition with topic churning
        let avgRepetition = recentFeatures.map { $0.repetitionScore }.reduce(0, +) / Double(recentFeatures.count)
        let avgChurn = recentFeatures.map { $0.topicChurn }.reduce(0, +) / Double(recentFeatures.count)

        // Looping = high repetition + high churn (returning to same things)
        let highRepetition = avgRepetition > 0.6
        let moderateChurn = avgChurn > 3 && avgChurn < 10

        guard highRepetition && moderateChurn else {
            await closeHypothesisIfActive(type: .looping)
            return
        }

        let confidence = (avgRepetition * 0.6) + (min(avgChurn / 10, 1.0) * 0.4)

        let evidence = [
            "High repetition: \(String(format: "%.2f", avgRepetition))",
            "Topic churn: \(String(format: "%.1f", avgChurn)) switches/hr",
            "Returning to same content"
        ]

        await createOrUpdateHypothesis(
            type: .looping,
            confidence: confidence,
            evidence: evidence,
            features: recentFeatures
        )
    }

    /// Flow State: Deep engagement with high productivity
    private func detectFlowState(features: [Feature]) async {
        guard features.count >= 2 else { return }

        let recentFeatures = Array(features.suffix(2))

        let avgFlow = recentFeatures.map { $0.flowIndicator }.reduce(0, +) / Double(recentFeatures.count)
        let avgOutput = recentFeatures.map { $0.outputDensity }.reduce(0, +) / Double(recentFeatures.count)

        // Flow = high flow indicator + output
        let highFlow = avgFlow > 0.7
        let hasOutput = avgOutput > 0.5

        guard highFlow && hasOutput else {
            await closeHypothesisIfActive(type: .flow)
            return
        }

        let confidence = (avgFlow * 0.6) + (min(avgOutput, 1.0) * 0.4)

        let evidence = [
            "High flow indicator: \(String(format: "%.2f", avgFlow))",
            "Productive output: \(String(format: "%.1f", avgOutput)) artifacts/hr",
            "Deep engagement"
        ]

        await createOrUpdateHypothesis(
            type: .flow,
            confidence: confidence,
            evidence: evidence,
            features: recentFeatures
        )
    }

    /// Grinding: High effort with slow progress
    private func detectGrinding(features: [Feature]) async {
        guard let latestFeature = features.last else { return }

        let grindIndicator = latestFeature.grindIndicator
        let outputDensity = latestFeature.outputDensity

        // Grind = high grind indicator + low output
        let highGrind = grindIndicator > 0.6
        let lowOutput = outputDensity < 0.5

        guard highGrind && lowOutput else {
            await closeHypothesisIfActive(type: .grind)
            return
        }

        let confidence = grindIndicator

        let evidence = [
            "High grind indicator: \(String(format: "%.2f", grindIndicator))",
            "Low output: \(String(format: "%.1f", outputDensity)) artifacts/hr",
            "High effort, slow progress"
        ]

        await createOrUpdateHypothesis(
            type: .grind,
            confidence: confidence,
            evidence: evidence,
            features: [latestFeature]
        )
    }

    // MARK: - Hypothesis Management

    private func createOrUpdateHypothesis(
        type: HypothesisType,
        confidence: Double,
        evidence: [String],
        features: [Feature]
    ) async {
        // Check if hypothesis already active
        if let existingId = activeHypotheses.first(where: { $0.value.type == type })?.key {
            // Update confidence and evidence
            var existing = activeHypotheses[existingId]!
            if abs(existing.confidence - confidence) > 0.1 {
                // Significant change, log it
                Logger.log("Updated \(type.displayName) confidence: \(String(format: "%.2f", existing.confidence)) → \(String(format: "%.2f", confidence))", log: Logger.storage, type: .debug)
            }
            return
        }

        // Create new hypothesis
        let hypothesis = Hypothesis(
            timestamp: Date(),
            type: type,
            confidence: confidence,
            evidence: evidence,
            startTime: features.first?.windowStart ?? Date(),
            endTime: nil,
            metadata: nil
        )

        let hypothesisId = await StorageService.shared.saveHypothesis(hypothesis)
        activeHypotheses[hypothesisId] = hypothesis

        // Save evidence links
        for feature in features {
            let evidenceEntry = Evidence(
                hypothesisId: hypothesisId,
                featureId: feature.id,
                weight: 1.0 / Double(features.count),
                reason: "Contributing feature window"
            )
            _ = await StorageService.shared.saveEvidence(evidenceEntry)
        }

        Logger.log("Created hypothesis: \(type.displayName) (confidence: \(String(format: "%.2f", confidence)))", log: Logger.storage)
    }

    private func closeHypothesisIfActive(type: HypothesisType) async {
        guard let (id, _) = activeHypotheses.first(where: { $0.value.type == type }) else {
            return
        }

        await StorageService.shared.endHypothesis(id, endTime: Date())
        activeHypotheses.removeValue(forKey: id)

        Logger.log("Closed hypothesis: \(type.displayName)", log: Logger.storage, type: .debug)
    }

    private func closeExpiredHypotheses() async {
        let now = Date()

        for (id, hypothesis) in activeHypotheses {
            // Close hypotheses older than 30 minutes without updates
            let age = now.timeIntervalSince(hypothesis.timestamp)
            if age > 1800 { // 30 minutes
                await StorageService.shared.endHypothesis(id, endTime: now)
                activeHypotheses.removeValue(forKey: id)
                Logger.log("Expired hypothesis: \(hypothesis.type.displayName)", log: Logger.storage, type: .debug)
            }
        }
    }

    // MARK: - Utilities

    private func isTrendIncreasing(values: [Double]) -> Bool {
        guard values.count >= 2 else { return false }

        var increasingCount = 0
        for i in 1..<values.count {
            if values[i] > values[i - 1] {
                increasingCount += 1
            }
        }

        return Double(increasingCount) / Double(values.count - 1) >= 0.6
    }

    private func isTrendDecreasing(values: [Double]) -> Bool {
        guard values.count >= 2 else { return false }

        var decreasingCount = 0
        for i in 1..<values.count {
            if values[i] < values[i - 1] {
                decreasingCount += 1
            }
        }

        return Double(decreasingCount) / Double(values.count - 1) >= 0.6
    }
}
