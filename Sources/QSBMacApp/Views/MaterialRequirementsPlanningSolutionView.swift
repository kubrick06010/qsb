import Charts
import QSBCore
import SwiftUI

struct MaterialRequirementsPlanningSolutionView: View {
    let document: MaterialRequirementsPlanningSolutionDocument
    @State private var selectedItemID: String?

    private var selection: Binding<String?> {
        Binding(
            get: { selectedItemID ?? document.model.items.first?.identifier },
            set: { selectedItemID = $0 }
        )
    }

    private var selectedItem: MRPItem? {
        let identifier = selection.wrappedValue
        return document.model.items.first { $0.identifier == identifier }
    }

    private var selectedSchedule: MRPItemSchedule? {
        let identifier = selection.wrappedValue
        return document.solution.schedules.first { $0.itemIdentifier == identifier }
    }

    private var points: [MRPPeriodPoint] {
        guard let schedule = selectedSchedule else { return [] }
        return document.solution.bucketNames.indices.map { index in
            MRPPeriodPoint(
                index: index,
                bucket: document.solution.bucketNames[index],
                gross: schedule.grossRequirements[index],
                scheduled: schedule.scheduledReceipts[index],
                projected: schedule.projectedOnHand[index],
                net: schedule.netRequirements[index],
                receipt: schedule.plannedOrderReceipts[index],
                release: schedule.plannedOrderReleases[index],
                capacityExcess: schedule.capacityExcess[index]
            )
        }
    }

    private var chartWidth: CGFloat {
        max(650, CGFloat(points.count) * 82)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: document.model.title,
                    subtitle: "Material requirements planning · \(document.backend.algorithmDisplayName)"
                )

                summary
                itemSelection

                if selectedSchedule != nil {
                    requirementsChart
                    ordersChart
                    scheduleTable
                    itemContext
                }

                billOfMaterials
                runContext
            }
            .padding(20)
            .frame(maxWidth: 1220, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var summary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 12) {
            metric("Items", "\(document.model.items.count)")
            metric("Buckets", "\(document.solution.bucketNames.count)")
            metric("BOM parents", "\(document.model.billsOfMaterial.count)")
            metric("Capacity excess", quantity(document.solution.schedules.flatMap(\.capacityExcess).reduce(0, +)))
        }
    }

    private var itemSelection: some View {
        GroupBox("Item schedule") {
            Picker("Item", selection: selection) {
                ForEach(document.model.items, id: \.identifier) { item in
                    Text("\(item.identifier) · \(item.description)")
                        .tag(Optional(item.identifier))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 430, alignment: .leading)
            .accessibilityLabel("Item schedule")
            .padding(4)
        }
    }

    private var requirementsChart: some View {
        GroupBox("Requirements and projected inventory") {
            ScrollView(.horizontal) {
                Chart {
                    RuleMark(y: .value("Zero", 0)).foregroundStyle(.secondary)
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Bucket", point.bucket),
                            y: .value("Gross requirements", point.gross),
                            series: .value("Series", "Gross requirements")
                        )
                        .foregroundStyle(by: .value("Series", "Gross requirements"))
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(x: .value("Bucket", point.bucket), y: .value("Gross requirements", point.gross))
                            .foregroundStyle(by: .value("Series", "Gross requirements"))
                            .accessibilityLabel("Gross requirements, \(point.bucket)")
                            .accessibilityValue(quantity(point.gross))

                        LineMark(
                            x: .value("Bucket", point.bucket),
                            y: .value("Projected on hand", point.projected),
                            series: .value("Series", "Projected on hand")
                        )
                        .foregroundStyle(by: .value("Series", "Projected on hand"))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))

                        PointMark(x: .value("Bucket", point.bucket), y: .value("Projected on hand", point.projected))
                            .foregroundStyle(by: .value("Series", "Projected on hand"))
                            .accessibilityLabel("Projected on hand, \(point.bucket)")
                            .accessibilityValue(quantity(point.projected))
                    }
                }
                .chartYAxisLabel("Quantity")
                .frame(width: chartWidth, height: 255)
                .padding(.vertical, 8)
            }
        }
    }

    private var ordersChart: some View {
        GroupBox("Planned orders") {
            ScrollView(.horizontal) {
                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Bucket", point.bucket),
                            y: .value("Quantity", point.receipt)
                        )
                        .position(by: .value("Plan", "Receipts"))
                        .foregroundStyle(by: .value("Plan", "Receipts"))
                        .accessibilityLabel("Planned receipt, \(point.bucket)")
                        .accessibilityValue(quantity(point.receipt))

                        BarMark(
                            x: .value("Bucket", point.bucket),
                            y: .value("Quantity", point.release)
                        )
                        .position(by: .value("Plan", "Releases"))
                        .foregroundStyle(by: .value("Plan", "Releases"))
                        .accessibilityLabel("Planned release, \(point.bucket)")
                        .accessibilityValue(quantity(point.release))
                    }
                }
                .chartYAxisLabel("Quantity")
                .frame(width: chartWidth, height: 220)
                .padding(.vertical, 8)
            }
        }
    }

    private var scheduleTable: some View {
        GroupBox("Time-phased schedule") {
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow {
                        heading("Bucket")
                        heading("Gross")
                        heading("Scheduled")
                        heading("Projected")
                        heading("Net")
                        heading("Planned receipt")
                        heading("Planned release")
                        heading("Capacity excess")
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    ForEach(points) { point in
                        GridRow {
                            Text(point.bucket).fontWeight(.semibold)
                            value(point.gross)
                            value(point.scheduled)
                            value(point.projected)
                            value(point.net)
                            value(point.receipt)
                            value(point.release)
                            value(point.capacityExcess)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Schedule for \(point.bucket)")
                    }
                }
                .padding(4)
            }
        }
    }

    @ViewBuilder
    private var itemContext: some View {
        if let item = selectedItem {
            GroupBox("Item details") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], alignment: .leading, spacing: 8) {
                    LabeledContent("Identifier", value: item.identifier)
                    LabeledContent("Description", value: item.description)
                    LabeledContent("Level", value: item.levelCode)
                    LabeledContent("Lead time", value: "\(item.leadTime) \(document.model.timeUnit.lowercased())")
                    LabeledContent("Lot rule", value: item.lotSizingRule.rawValue)
                    LabeledContent("Initial on hand", value: quantity(item.initialOnHand))
                    LabeledContent("Safety stock", value: quantity(item.safetyStock))
                    LabeledContent("Unit", value: item.unit)
                }
                .padding(4)
            }
        }
    }

    private var billOfMaterials: some View {
        GroupBox("Bill of materials") {
            if document.model.billsOfMaterial.isEmpty {
                Text("No component relationships")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(document.model.billsOfMaterial, id: \.parentIdentifier) { bill in
                        LabeledContent(bill.parentIdentifier) {
                            Text(bill.components.map { "\($0.itemIdentifier) × \(quantity($0.quantityPerParent))" }.joined(separator: ", "))
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(4)
            }
        }
    }

    private var runContext: some View {
        GroupBox("Run context") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Backend", value: document.backend.backendDisplayName)
                LabeledContent("Algorithm", value: document.backend.algorithmDisplayName)
                LabeledContent("Exactness", value: document.backend.exactnessDisplayName)
                ForEach(Array(document.backend.notes.enumerated()), id: \.offset) { _, note in
                    Label(note, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(4)
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

    private func value(_ number: Double) -> some View {
        Text(quantity(number)).monospacedDigit().frame(minWidth: 64, alignment: .trailing)
    }

    private func quantity(_ value: Double) -> String {
        let displayValue = abs(value) < 1e-9 ? 0 : value
        return displayValue.formatted(.number.precision(.fractionLength(0...3)))
    }
}

private struct MRPPeriodPoint: Identifiable {
    let index: Int
    let bucket: String
    let gross: Double
    let scheduled: Double
    let projected: Double
    let net: Double
    let receipt: Double
    let release: Double
    let capacityExcess: Double

    var id: Int { index }
}
