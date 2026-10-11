import Charts
import QSBCore
import SwiftUI

struct AggregatePlanningSolutionView: View {
    let document: AggregatePlanningSolutionDocument

    private var rows: [PeriodRow] {
        document.solution.periods.enumerated().map { index, solution in
            PeriodRow(
                index: index,
                demand: document.model.demand.indices.contains(index) ? document.model.demand[index] : 0,
                solution: solution
            )
        }
    }

    private var summaryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .leading)]
    }

    private var chartWidth: CGFloat {
        max(620, CGFloat(rows.count) * 88)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: document.model.title,
                    subtitle: "Aggregate planning · \(document.backend.algorithmDisplayName)"
                )

                LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 12) {
                    metric("Total cost", currency(document.solution.totalCost))
                    metric("Periods", "\(rows.count)")
                    metric("Total demand", quantity(document.model.demand.reduce(0, +)))
                    metric("Exactness", document.backend.exactnessDisplayName)
                }

                productionPlan
                inventoryPlan
                periodTable
                runContext
            }
            .padding(20)
            .frame(maxWidth: 1180, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var productionPlan: some View {
        GroupBox("Production and demand") {
            ScrollView(.horizontal) {
                Chart {
                    ForEach(rows) { row in
                        BarMark(
                            x: .value("Period", row.solution.period),
                            yStart: .value("Production", 0),
                            yEnd: .value("Production", row.solution.regularProduction)
                        )
                        .foregroundStyle(by: .value("Source", "Regular"))
                        .accessibilityLabel("Regular production, \(row.solution.period)")
                        .accessibilityValue(quantity(row.solution.regularProduction))

                        BarMark(
                            x: .value("Period", row.solution.period),
                            yStart: .value("Production", row.solution.regularProduction),
                            yEnd: .value("Production", row.solution.regularProduction + row.solution.overtimeProduction)
                        )
                        .foregroundStyle(by: .value("Source", "Overtime"))
                        .accessibilityLabel("Overtime production, \(row.solution.period)")
                        .accessibilityValue(quantity(row.solution.overtimeProduction))

                        BarMark(
                            x: .value("Period", row.solution.period),
                            yStart: .value("Production", row.solution.regularProduction + row.solution.overtimeProduction),
                            yEnd: .value("Production", row.totalProduction)
                        )
                        .foregroundStyle(by: .value("Source", "Subcontracted"))
                        .accessibilityLabel("Subcontracted production, \(row.solution.period)")
                        .accessibilityValue(quantity(row.solution.subcontracted))

                        LineMark(
                            x: .value("Period", row.solution.period),
                            y: .value("Demand", row.demand),
                            series: .value("Series", "Demand")
                        )
                        .foregroundStyle(Color.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))

                        PointMark(
                            x: .value("Period", row.solution.period),
                            y: .value("Demand", row.demand)
                        )
                        .foregroundStyle(Color.primary)
                        .symbolSize(34)
                        .accessibilityLabel("Demand, \(row.solution.period)")
                        .accessibilityValue(quantity(row.demand))
                    }
                }
                .chartYAxisLabel("Quantity")
                .frame(width: chartWidth, height: 285)
                .padding(.vertical, 8)
            }
            .accessibilityLabel("Production and demand by period")
        }
    }

    private var inventoryPlan: some View {
        GroupBox("Ending inventory and backorder") {
            ScrollView(.horizontal) {
                Chart {
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(.secondary)

                    ForEach(rows) { row in
                        BarMark(
                            x: .value("Period", row.solution.period),
                            y: .value("Ending balance", row.solution.endingInventory)
                        )
                        .foregroundStyle(by: .value("Balance", "Inventory"))
                        .accessibilityLabel("Ending inventory, \(row.solution.period)")
                        .accessibilityValue(quantity(row.solution.endingInventory))

                        BarMark(
                            x: .value("Period", row.solution.period),
                            y: .value("Ending balance", -row.solution.endingBackorder)
                        )
                        .foregroundStyle(by: .value("Balance", "Backorder"))
                        .accessibilityLabel("Ending backorder, \(row.solution.period)")
                        .accessibilityValue(quantity(row.solution.endingBackorder))
                    }
                }
                .chartYAxisLabel("Quantity")
                .frame(width: chartWidth, height: 220)
                .padding(.vertical, 8)
            }
            .accessibilityLabel("Ending inventory and backorder by period; backorders appear below zero")
        }
    }

    private var periodTable: some View {
        GroupBox("Period plan") {
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow {
                        heading("Period")
                        heading("Demand")
                        if document.model.capacityIsPerWorker {
                            heading("Workforce")
                            heading("Hired")
                            heading("Dismissed")
                        }
                        heading("Regular")
                        heading("Overtime")
                        heading("Subcontracted")
                        heading("Inventory")
                        heading("Backorder")
                        heading("Unused capacity")
                    }

                    Divider().gridCellUnsizedAxes(.horizontal)

                    ForEach(rows) { row in
                        GridRow {
                            Text(row.solution.period).fontWeight(.semibold)
                            value(row.demand)
                            if document.model.capacityIsPerWorker {
                                value(row.solution.workforce)
                                value(row.solution.hired)
                                value(row.solution.dismissed)
                            }
                            value(row.solution.regularProduction)
                            value(row.solution.overtimeProduction)
                            value(row.solution.subcontracted)
                            value(row.solution.endingInventory)
                            value(row.solution.endingBackorder)
                            value(row.solution.unusedRegularCapacity)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Plan for \(row.solution.period)")
                    }
                }
                .padding(4)
            }
        }
    }

    private var runContext: some View {
        GroupBox("Run context") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Planning method", value: methodLabel)
                LabeledContent("Backend", value: document.backend.backendDisplayName)
                LabeledContent("Algorithm", value: document.backend.algorithmDisplayName)
                LabeledContent("Exactness", value: document.backend.exactnessDisplayName)
                LabeledContent("Quantity domain", value: "Continuous")
                ForEach(Array(document.backend.notes.enumerated()), id: \.offset) { _, note in
                    Label(note, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(4)
        }
    }

    private var methodLabel: String {
        switch document.model.method {
        case .simple: "Simple"
        case .transportation: "Transportation"
        case .linearProgramming: "Linear programming"
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func value(_ number: Double?) -> some View {
        Text(number.map(quantity) ?? "—")
            .monospacedDigit()
            .frame(minWidth: 64, alignment: .trailing)
    }

    private func quantity(_ value: Double) -> String {
        let displayValue = abs(value) < 1e-9 ? 0 : value
        return displayValue.formatted(.number.precision(.fractionLength(0...3)))
    }

    private func currency(_ value: Double) -> String {
        let displayValue = abs(value) < 1e-9 ? 0 : value
        return displayValue.formatted(.number.precision(.fractionLength(2)))
    }
}

private struct PeriodRow: Identifiable {
    let index: Int
    let demand: Double
    let solution: AggregatePlanningPeriodSolution

    var id: Int { index }

    var totalProduction: Double {
        solution.regularProduction + solution.overtimeProduction + solution.subcontracted
    }
}
