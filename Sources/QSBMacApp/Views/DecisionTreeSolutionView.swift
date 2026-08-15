import Foundation
import QSBCore
import SwiftUI

struct DecisionTreeSolutionView: View {
    let document: DecisionAnalysisSolutionDocument

    private var model: DecisionTree {
        guard case .decisionTree(let model) = document.model else {
            preconditionFailure("DecisionTreeSolutionView requires a decision tree model")
        }
        return model
    }

    private var solution: DecisionTreeSolution {
        guard case .decisionTree(let solution) = document.solution else {
            preconditionFailure("DecisionTreeSolutionView requires a decision tree solution")
        }
        return solution
    }

    private var nodesByID: [Int: DecisionTreeNode] {
        Dictionary(uniqueKeysWithValues: model.nodes.map { ($0.id, $0) })
    }

    private var valuesByID: [Int: DecisionTreeNodeValue] {
        Dictionary(uniqueKeysWithValues: solution.nodeValues.map { ($0.nodeID, $0) })
    }

    private var childrenByID: [Int: [DecisionTreeNode]] {
        Dictionary(uniqueKeysWithValues: model.nodes.map { node in
            (node.id, node.childIDs.compactMap { nodesByID[$0] })
        })
    }

    private var visibleRows: [TreeRow] {
        var rows: [TreeRow] = []

        func append(_ nodeID: Int, depth: Int, branch: String?) {
            guard let node = nodesByID[nodeID] else { return }
            rows.append(TreeRow(node: node, depth: depth, branch: branch))
            for (index, child) in (childrenByID[node.id] ?? []).enumerated() {
                append(child.id, depth: depth + 1, branch: branchLabel(index: index, count: childrenByID[node.id]?.count ?? 0))
            }
        }

        append(model.rootID, depth: 0, branch: nil)
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summary
            Divider()

            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 20) {
                        policyOverview
                        treeTable
                        runContext
                    }
                    .padding(18)
                    .frame(
                        width: max(720, geometry.size.width),
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
            Text(model.title)
                .font(.headline)
                .lineLimit(1)
            Text("Decision tree rollback · \(document.backend.algorithm)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var summaryMetrics: some View {
        HStack(spacing: 24) {
            metric(Self.number(solution.expectedValue), label: "Expected value")
            metric("\(model.nodes.count)", label: "Nodes")
            metric("\(solution.policy.count)", label: "Decisions")
        }
    }

    private func metric(_ value: String, label: String) -> some View {
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

    private var policyOverview: some View {
        section(title: "Recommended policy", subtitle: "Rollback values and selected alternatives at decision nodes.") {
            if solution.policy.isEmpty {
                Text("This tree contains no decision nodes.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .leading)], alignment: .leading, spacing: 10) {
                    ForEach(solution.policy, id: \.nodeID) { decision in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(decision.nodeName, systemImage: "arrow.triangle.branch")
                                .font(.headline)
                            Text("Choose \(decision.selectedChildName)")
                            Text("Expected value \(Self.number(decision.expectedValue))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Decision \(decision.nodeName)")
                        .accessibilityValue("Choose \(decision.selectedChildName), expected value \(Self.number(decision.expectedValue))")
                    }
                }
            }
        }
    }

    private var treeTable: some View {
        section(title: "Tree inspection", subtitle: "Terminal payoffs, chance probabilities, and rollback values.") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Text("Node").frame(width: 280, alignment: .leading)
                    Text("Type").frame(width: 90, alignment: .leading)
                    Text("Probability").frame(width: 100, alignment: .trailing)
                    Text("Payoff").frame(width: 100, alignment: .trailing)
                    Text("Rollback value").frame(width: 120, alignment: .trailing)
                    Text("Selected child").frame(width: 180, alignment: .leading)
                }
                .tableHeaderStyle()

                ForEach(visibleRows) { row in
                    let value = valuesByID[row.node.id]
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Text(row.branch ?? "")
                                .foregroundStyle(.tertiary)
                                .frame(width: CGFloat(row.depth * 22), alignment: .trailing)
                            Image(systemName: row.node.kind.symbol)
                                .foregroundStyle(row.node.kind.color)
                                .accessibilityHidden(true)
                            Text(row.node.name)
                                .lineLimit(1)
                        }
                        .frame(width: 280, alignment: .leading)
                        Text(row.node.kind.label).frame(width: 90, alignment: .leading)
                        Text(row.node.probability.map(Self.number) ?? "—")
                            .frame(width: 100, alignment: .trailing)
                        Text(row.node.payoff.map(Self.number) ?? "—")
                            .frame(width: 100, alignment: .trailing)
                        Text(value.map { Self.number($0.expectedValue) } ?? "—")
                            .frame(width: 120, alignment: .trailing)
                        Text(value?.selectedChildName ?? "—")
                            .frame(width: 180, alignment: .leading)
                            .lineLimit(1)
                    }
                    .tableRowStyle()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(row.node.kind.label) \(row.node.name)")
                    .accessibilityValue("Rollback value \(value.map { Self.number($0.expectedValue) } ?? "not available")")
                }
            }
        }
    }

    private var runContext: some View {
        section(title: "Run context", subtitle: "Solver metadata retained in the normalized solution document.") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Backend: \(document.backend.backendKind.rawValue)")
                Text("Exactness: \(document.backend.exactness.rawValue)")
                ForEach(document.backend.notes, id: \.self) { note in
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func section<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title3.weight(.semibold))
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func branchLabel(index: Int, count: Int) -> String {
        count > 1 ? "\(index + 1)." : "└"
    }

    private static func number(_ value: Double) -> String {
        let rounded = value.rounded()
        return abs(value - rounded) < 1e-8 ? String(Int(rounded)) : String(format: "%.2f", value)
    }
}

private struct TreeRow: Identifiable {
    let node: DecisionTreeNode
    let depth: Int
    let branch: String?

    var id: Int { node.id }
}

private extension DecisionTreeNodeKind {
    var label: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .decision: "arrow.triangle.branch"
        case .chance: "die.face.5"
        case .terminal: "flag.checkered"
        }
    }

    var color: Color {
        switch self {
        case .decision: .blue
        case .chance: .orange
        case .terminal: .green
        }
    }
}

private extension View {
    func tableHeaderStyle() -> some View {
        self
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary)
    }

    func tableRowStyle() -> some View {
        self
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.background)
            .overlay(alignment: .bottom) {
                Divider()
            }
    }
}
