import Charts
import Foundation
import QSBCore
import SwiftUI

struct InventorySolutionView: View {
    let document: InventorySolutionDocument

    private var presentation: InventorySolutionPresentation {
        InventorySolutionPresentation(document: document)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary
            Divider()

            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 24) {
                        analysis
                        assumptions
                    }
                    .padding(18)
                    .frame(
                        width: max(presentation.minimumContentWidth, geometry.size.width),
                        alignment: .topLeading
                    )
                    .frame(minHeight: geometry.size.height, alignment: .topLeading)
                }
            }
        }
    }

    private var summary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) {
                summaryTitle
                Spacer(minLength: 16)
                summaryMetrics
            }

            VStack(alignment: .leading, spacing: 10) {
                summaryTitle
                summaryMetrics
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var summaryTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(document.title)
                .font(.headline)
                .lineLimit(1)
            Text("\(presentation.kindLabel) - \(document.backend.algorithm)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var summaryMetrics: some View {
        HStack(spacing: 24) {
            ForEach(presentation.summaryMetrics) { item in
                metric(value: item.value, label: item.label)
            }
        }
    }

    @ViewBuilder
    private var analysis: some View {
        switch document.solution {
        case .eoq(let solution):
            eoqAnalysis(solution)
        case .quantityDiscountEOQ(let solution):
            quantityDiscountAnalysis(solution)
        case .newsboy(let solution):
            newsboyAnalysis(solution)
        case .lotSizing(let solution):
            lotSizingAnalysis(solution)
        case .stochasticReview(let solution):
            stochasticAnalysis(solution)
        }
    }

    private func eoqAnalysis(_ solution: EOQSolution) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            section(
                title: "Policy",
                subtitle: "Order timing and replenishment values from the closed-form solution."
            ) {
                detailGrid([
                    detail("Economic order quantity", solution.economicOrderQuantity),
                    detail("Cycles per \(document.timeUnit)", solution.cycleCount),
                    detail("Cycle length", solution.cycleLength),
                    solution.reorderPoint.map { detail("Reorder point", $0) }
                ].compactMap(\.self))
            }

            section(
                title: "Cost breakdown",
                subtitle: "Recurring cost components for the optimum and supplied comparison quantity."
            ) {
                costBreakdownChart(eoqCostItems(solution))
                    .frame(height: 230)

                eoqCostTable(
                    optimum: solution.optimum,
                    known: solution.knownQuantity
                )
            }
        }
    }

    private func quantityDiscountAnalysis(_ solution: QuantityDiscountEOQSolution) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            section(
                title: "Discount candidates",
                subtitle: "Total cost at the feasible quantity evaluated for every all-units tier."
            ) {
                Chart(Array(solution.candidates.enumerated()), id: \.offset) { _, candidate in
                    BarMark(
                        x: .value("Tier", tierLabel(candidate)),
                        y: .value("Total cost", candidate.cost.totalCost)
                    )
                    .foregroundStyle(
                        candidate == solution.optimum ? Color.green : Color.blue
                    )
                    .accessibilityLabel(tierLabel(candidate))
                    .accessibilityValue(InventorySolutionPresentation.number(candidate.cost.totalCost))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .frame(height: 245)

                discountCandidateTable(solution)
            }

            section(
                title: "Selected cost breakdown",
                subtitle: "Setup, holding, and acquisition cost for the selected tier."
            ) {
                costBreakdownChart(
                    costItems(for: solution.optimum.cost, series: "Optimum")
                )
                .frame(height: 210)

                detailGrid([
                    detail("Unconstrained EOQ", solution.unconstrainedEOQ),
                    detail("Selected quantity", solution.optimum.cost.orderQuantity),
                    detail("Discount", percent: solution.optimum.discountPercent / 100),
                    detail("Unit acquisition cost", solution.optimum.unitAcquisitionCost)
                ])
            }
        }
    }

    private func newsboyAnalysis(_ solution: NewsboySolution) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            section(
                title: "Demand outcome",
                subtitle: "Expected sales, leftover stock, and shortage at the optimum quantity."
            ) {
                let outcomes = newsboyOutcomes(solution.optimum)
                Chart(outcomes) { outcome in
                    BarMark(
                        x: .value("Quantity", outcome.value),
                        y: .value("Outcome", outcome.label)
                    )
                    .foregroundStyle(outcome.color)
                    .accessibilityLabel(outcome.label)
                    .accessibilityValue(InventorySolutionPresentation.number(outcome.value))
                }
                .chartXAxis {
                    AxisMarks {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .frame(height: 190)

                detailGrid([
                    detail("Critical ratio", percent: solution.criticalRatio),
                    detail("Order quantity", solution.optimum.orderQuantity),
                    detail("Inventory position", solution.optimum.inventoryPosition),
                    detail("Service level", percent: solution.optimum.serviceLevel),
                    detail("Expected profit", solution.optimum.expectedProfit),
                    solution.desiredServiceLevelQuantity.map {
                        detail("Desired-service quantity", $0)
                    }
                ].compactMap(\.self))
            }

            if let known = solution.knownQuantity {
                section(
                    title: "Quantity comparison",
                    subtitle: "Optimum and supplied quantities evaluated by the same newsvendor model."
                ) {
                    newsboyComparisonTable(optimum: solution.optimum, known: known)
                }
            }
        }
    }

    private func lotSizingAnalysis(_ solution: LotSizingSolution) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            section(
                title: "Production plan",
                subtitle: "Demand, production, and ending inventory or backlog by period."
            ) {
                Chart {
                    ForEach(Array(solution.decisions.enumerated()), id: \.offset) { _, decision in
                        BarMark(
                            x: .value("Period", decision.period),
                            y: .value("Quantity", decision.demand)
                        )
                        .foregroundStyle(by: .value("Series", "Demand"))
                        .position(by: .value("Series", "Demand"))

                        BarMark(
                            x: .value("Period", decision.period),
                            y: .value("Quantity", decision.productionQuantity)
                        )
                        .foregroundStyle(by: .value("Series", "Production"))
                        .position(by: .value("Series", "Production"))

                        LineMark(
                            x: .value("Period", decision.period),
                            y: .value("Ending inventory", decision.endingInventory),
                            series: .value("Series", "Ending inventory")
                        )
                        .foregroundStyle(by: .value("Series", "Ending inventory"))
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Period", decision.period),
                            y: .value("Ending inventory", decision.endingInventory)
                        )
                        .foregroundStyle(by: .value("Series", "Ending inventory"))
                        .symbolSize(30)
                        .accessibilityLabel("\(decision.period) ending inventory")
                        .accessibilityValue("\(decision.endingInventory)")
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .frame(height: 270)
            }

            section(
                title: "Period costs",
                subtitle: "Stacked setup, variable, holding, and backorder contributions."
            ) {
                Chart(lotSizingCostItems(solution)) { item in
                    BarMark(
                        x: .value("Period", item.period),
                        y: .value("Cost", item.value)
                    )
                    .foregroundStyle(by: .value("Component", item.component))
                    .accessibilityLabel("\(item.period), \(item.component)")
                    .accessibilityValue(InventorySolutionPresentation.number(item.value))
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .frame(height: 240)

                lotSizingTable(solution)
            }
        }
    }

    private func stochasticAnalysis(_ solution: StochasticInventorySolution) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            section(
                title: "Policy levels",
                subtitle: "Recommended replenishment and protection-period values."
            ) {
                detailGrid([
                    detail("Order quantity", solution.orderQuantity),
                    solution.reorderPoint.map { detail("Reorder point", $0) },
                    solution.orderUpToLevel.map { detail("Order-up-to level", $0) },
                    solution.reviewInterval.map { detail("Review interval", $0) },
                    detail("Protection period", solution.protectionPeriod),
                    detail("Protection demand", solution.protectionDemandMean),
                    detail("Safety stock", solution.safetyStock),
                    detail("Service level", percent: solution.serviceLevel),
                    detail("Expected shortage per cycle", solution.expectedShortagePerCycle),
                    detail("Cycles per \(document.timeUnit)", solution.expectedCyclesPerTimeUnit)
                ].compactMap(\.self))
            }

            section(
                title: "Cost breakdown",
                subtitle: "Expected recurring policy costs per \(document.timeUnit)."
            ) {
                costBreakdownChart(stochasticCostItems(solution.costs))
                    .frame(height: 240)

                detailGrid([
                    detail("Total relevant cost", solution.costs.totalRelevantCost),
                    detail("Total cost", solution.costs.totalCost),
                    detail("Demand deviation", solution.protectionDemandStandardDeviation),
                    detail("Policy", text: policyLabel(solution.policy))
                ])
            }
        }
    }

    private var assumptions: some View {
        section(
            title: "Run context",
            subtitle: "\(presentation.exactnessLabel) - \(document.timeUnit)"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(document.assumptions.enumerated()), id: \.offset) { _, assumption in
                    Label(assumption, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func costBreakdownChart(_ items: [InventoryCostItem]) -> some View {
        Chart(items) { item in
            BarMark(
                x: .value("Cost", item.value),
                y: .value("Component", item.component)
            )
            .foregroundStyle(by: .value("Series", item.series))
            .position(by: .value("Series", item.series))
            .accessibilityLabel("\(item.series), \(item.component)")
            .accessibilityValue(InventorySolutionPresentation.number(item.value))
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXAxis {
            AxisMarks {
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
    }

    private func eoqCostTable(
        optimum: EOQCostBreakdown,
        known: EOQCostBreakdown?
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            costTableHeader
            costTableRow("Optimum", cost: optimum)
            if let known {
                costTableRow("Known quantity", cost: known)
            }
        }
    }

    private var costTableHeader: some View {
        HStack(spacing: 12) {
            Text("Plan")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Quantity")
                .frame(width: 90, alignment: .trailing)
            Text("Relevant")
                .frame(width: 100, alignment: .trailing)
            Text("Total")
                .frame(width: 100, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.35))
    }

    private func costTableRow(_ label: String, cost: EOQCostBreakdown) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(InventorySolutionPresentation.number(cost.orderQuantity))
                .frame(width: 90, alignment: .trailing)
            Text(InventorySolutionPresentation.number(cost.totalRelevantCost))
                .frame(width: 100, alignment: .trailing)
            Text(InventorySolutionPresentation.number(cost.totalCost))
                .frame(width: 100, alignment: .trailing)
        }
        .font(.callout.monospacedDigit())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func discountCandidateTable(_ solution: QuantityDiscountEOQSolution) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("Tier")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Quantity")
                    .frame(width: 90, alignment: .trailing)
                Text("Unit cost")
                    .frame(width: 90, alignment: .trailing)
                Text("Total")
                    .frame(width: 110, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(0.35))

            ForEach(Array(solution.candidates.enumerated()), id: \.offset) { _, candidate in
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        if candidate == solution.optimum {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        Text(tierLabel(candidate))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(InventorySolutionPresentation.number(candidate.cost.orderQuantity))
                        .frame(width: 90, alignment: .trailing)
                    Text(InventorySolutionPresentation.number(candidate.unitAcquisitionCost))
                        .frame(width: 90, alignment: .trailing)
                    Text(InventorySolutionPresentation.number(candidate.cost.totalCost))
                        .frame(width: 110, alignment: .trailing)
                }
                .font(.callout.monospacedDigit())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Divider()
                }
            }
        }
    }

    private func newsboyComparisonTable(
        optimum: NewsboyEvaluation,
        known: NewsboyEvaluation
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("Plan")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Quantity")
                    .frame(width: 90, alignment: .trailing)
                Text("Service")
                    .frame(width: 80, alignment: .trailing)
                Text("Shortage")
                    .frame(width: 90, alignment: .trailing)
                Text("Profit")
                    .frame(width: 110, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(0.35))

            newsboyComparisonRow("Optimum", evaluation: optimum)
            newsboyComparisonRow("Known quantity", evaluation: known)
        }
    }

    private func newsboyComparisonRow(
        _ label: String,
        evaluation: NewsboyEvaluation
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(InventorySolutionPresentation.number(evaluation.orderQuantity))
                .frame(width: 90, alignment: .trailing)
            Text(InventorySolutionPresentation.percent(evaluation.serviceLevel))
                .frame(width: 80, alignment: .trailing)
            Text(InventorySolutionPresentation.number(evaluation.expectedShortage))
                .frame(width: 90, alignment: .trailing)
            Text(InventorySolutionPresentation.number(evaluation.expectedProfit))
                .frame(width: 110, alignment: .trailing)
        }
        .font(.callout.monospacedDigit())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func lotSizingTable(_ solution: LotSizingSolution) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("Period")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Demand")
                    .frame(width: 70, alignment: .trailing)
                Text("Produce")
                    .frame(width: 70, alignment: .trailing)
                Text("Ending")
                    .frame(width: 70, alignment: .trailing)
                Text("Setup")
                    .frame(width: 80, alignment: .trailing)
                Text("Variable")
                    .frame(width: 85, alignment: .trailing)
                Text("Holding")
                    .frame(width: 80, alignment: .trailing)
                Text("Backorder")
                    .frame(width: 90, alignment: .trailing)
                Text("Total")
                    .frame(width: 90, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(0.35))

            ForEach(Array(solution.decisions.enumerated()), id: \.offset) { _, decision in
                HStack(spacing: 10) {
                    Text(decision.period)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(decision.demand)")
                        .frame(width: 70, alignment: .trailing)
                    Text("\(decision.productionQuantity)")
                        .frame(width: 70, alignment: .trailing)
                    Text("\(decision.endingInventory)")
                        .foregroundStyle(decision.endingInventory < 0 ? .red : .secondary)
                        .frame(width: 70, alignment: .trailing)
                    Text(InventorySolutionPresentation.number(decision.setupCost))
                        .frame(width: 80, alignment: .trailing)
                    Text(InventorySolutionPresentation.number(decision.variableCost))
                        .frame(width: 85, alignment: .trailing)
                    Text(InventorySolutionPresentation.number(decision.holdingCost))
                        .frame(width: 80, alignment: .trailing)
                    Text(InventorySolutionPresentation.number(decision.backorderCost))
                        .frame(width: 90, alignment: .trailing)
                    Text(InventorySolutionPresentation.number(decision.totalCost))
                        .fontWeight(.semibold)
                        .frame(width: 90, alignment: .trailing)
                }
                .font(.callout.monospacedDigit())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Divider()
                }
            }
        }
    }

    private func detailGrid(_ items: [InventoryDetailItem]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)],
            alignment: .leading,
            spacing: 14
        ) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.value)
                        .font(.body.weight(.medium).monospacedDigit())
                        .lineLimit(1)
                    Text(item.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func section<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func detail(_ label: String, _ value: Double) -> InventoryDetailItem {
        InventoryDetailItem(
            label: label,
            value: InventorySolutionPresentation.number(value)
        )
    }

    private func detail(_ label: String, percent value: Double) -> InventoryDetailItem {
        InventoryDetailItem(
            label: label,
            value: InventorySolutionPresentation.percent(value)
        )
    }

    private func detail(_ label: String, text: String) -> InventoryDetailItem {
        InventoryDetailItem(label: label, value: text)
    }

    private func eoqCostItems(_ solution: EOQSolution) -> [InventoryCostItem] {
        costItems(for: solution.optimum, series: "Optimum")
            + (solution.knownQuantity.map {
                costItems(for: $0, series: "Known quantity")
            } ?? [])
    }

    private func costItems(
        for cost: EOQCostBreakdown,
        series: String
    ) -> [InventoryCostItem] {
        [
            InventoryCostItem(series: series, component: "Setup", value: cost.setupCost),
            InventoryCostItem(series: series, component: "Holding", value: cost.holdingCost),
            InventoryCostItem(series: series, component: "Acquisition", value: cost.acquisitionCost)
        ]
        .filter { abs($0.value) > 1e-10 }
    }

    private func stochasticCostItems(
        _ cost: StochasticInventoryCostBreakdown
    ) -> [InventoryCostItem] {
        [
            InventoryCostItem(series: "Policy", component: "Ordering", value: cost.orderingCost),
            InventoryCostItem(series: "Policy", component: "Review", value: cost.reviewCost),
            InventoryCostItem(series: "Policy", component: "Holding", value: cost.holdingCost),
            InventoryCostItem(series: "Policy", component: "Shortage", value: cost.expectedShortageCost),
            InventoryCostItem(series: "Policy", component: "Acquisition", value: cost.acquisitionCost)
        ]
        .filter { abs($0.value) > 1e-10 }
    }

    private func lotSizingCostItems(_ solution: LotSizingSolution) -> [LotSizingCostItem] {
        solution.decisions.flatMap { decision in
            [
                LotSizingCostItem(period: decision.period, component: "Setup", value: decision.setupCost),
                LotSizingCostItem(period: decision.period, component: "Variable", value: decision.variableCost),
                LotSizingCostItem(period: decision.period, component: "Holding", value: decision.holdingCost),
                LotSizingCostItem(period: decision.period, component: "Backorder", value: decision.backorderCost)
            ]
            .filter { abs($0.value) > 1e-10 }
        }
    }

    private func newsboyOutcomes(_ evaluation: NewsboyEvaluation) -> [NewsboyOutcome] {
        [
            NewsboyOutcome(label: "Expected sales", value: evaluation.expectedSales, color: .blue),
            NewsboyOutcome(label: "Expected leftover", value: evaluation.expectedLeftover, color: .orange),
            NewsboyOutcome(label: "Expected shortage", value: evaluation.expectedShortage, color: .red)
        ]
    }

    private func tierLabel(_ candidate: QuantityDiscountCandidate) -> String {
        if candidate.discountPercent == 0 {
            return "Base"
        }
        return "\(InventorySolutionPresentation.number(candidate.discountPercent))% at \(InventorySolutionPresentation.number(candidate.minimumQuantity))+"
    }

    private func policyLabel(_ policy: StochasticInventoryPolicy) -> String {
        switch policy {
        case .continuousFixedOrderQuantity:
            "Continuous (Q, r)"
        case .continuousOrderUpTo:
            "Continuous order-up-to"
        case .periodicFixedOrderInterval:
            "Periodic fixed interval"
        case .periodicOptionalReplenishment:
            "Periodic optional replenishment"
        }
    }
}

private struct InventorySolutionPresentation {
    let document: InventorySolutionDocument

    var kindLabel: String {
        switch document.kind {
        case .eoq: "Economic Order Quantity"
        case .quantityDiscountEOQ: "Quantity Discount EOQ"
        case .newsboy: "Newsboy"
        case .lotSizing: "Lot Sizing"
        case .stochasticReview: "Stochastic Review"
        }
    }

    var exactnessLabel: String {
        switch document.backend.exactness {
        case .exact: "Exact"
        case .closedForm: "Closed form"
        case .fixtureScale: "Fixture scale"
        case .heuristic: "Heuristic"
        case .approximate: "Approximate"
        }
    }

    var summaryMetrics: [InventorySummaryMetric] {
        switch document.solution {
        case .eoq(let solution):
            [
                metric("Order quantity", solution.economicOrderQuantity),
                metric("Relevant cost", solution.optimum.totalRelevantCost),
                metric("Cycle length", solution.cycleLength)
            ]
        case .quantityDiscountEOQ(let solution):
            [
                metric("Order quantity", solution.optimum.cost.orderQuantity),
                metric("Total cost", solution.optimum.cost.totalCost),
                InventorySummaryMetric(
                    label: "Discount",
                    value: Self.percent(solution.optimum.discountPercent / 100)
                )
            ]
        case .newsboy(let solution):
            [
                metric("Order quantity", solution.optimum.orderQuantity),
                metric("Expected profit", solution.optimum.expectedProfit),
                InventorySummaryMetric(
                    label: "Service level",
                    value: Self.percent(solution.optimum.serviceLevel)
                )
            ]
        case .lotSizing(let solution):
            [
                metric("Total cost", solution.totalCost),
                InventorySummaryMetric(
                    label: "Periods",
                    value: "\(solution.decisions.count)"
                ),
                InventorySummaryMetric(
                    label: "Production",
                    value: "\(solution.decisions.reduce(0) { $0 + $1.productionQuantity })"
                )
            ]
        case .stochasticReview(let solution):
            [
                metric("Order quantity", solution.orderQuantity),
                metric("Relevant cost", solution.costs.totalRelevantCost),
                InventorySummaryMetric(
                    label: "Service level",
                    value: Self.percent(solution.serviceLevel)
                )
            ]
        }
    }

    var minimumContentWidth: CGFloat {
        switch document.solution {
        case .lotSizing(let solution):
            max(860, CGFloat(solution.decisions.count) * 115)
        default:
            720
        }
    }

    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func percent(_ value: Double) -> String {
        (value * 100).formatted(.number.precision(.fractionLength(0...1))) + "%"
    }

    private func metric(_ label: String, _ value: Double) -> InventorySummaryMetric {
        InventorySummaryMetric(label: label, value: Self.number(value))
    }
}

private struct InventorySummaryMetric: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

private struct InventoryDetailItem: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

private struct InventoryCostItem: Identifiable {
    let series: String
    let component: String
    let value: Double
    var id: String { "\(series)-\(component)" }
}

private struct LotSizingCostItem: Identifiable {
    let period: String
    let component: String
    let value: Double
    var id: String { "\(period)-\(component)" }
}

private struct NewsboyOutcome: Identifiable {
    let label: String
    let value: Double
    let color: Color
    var id: String { label }
}
