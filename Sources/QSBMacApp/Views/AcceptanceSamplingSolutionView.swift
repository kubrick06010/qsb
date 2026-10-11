import Charts
import QSBCore
import SwiftUI

struct AcceptanceSamplingSolutionView: View {
    let document: AcceptanceSamplingSolutionDocument

    private var plan: PlanSummary {
        switch document.model {
        case .single(let value):
            PlanSummary(
                kind: "Single sample",
                sampleDescription: "n = \(value.sampleSize), c = \(value.acceptanceNumber)",
                aql: value.acceptableQualityLevel,
                rql: value.rejectableQualityLevel,
                nominalProducerRisk: value.nominalProducerRisk,
                nominalConsumerRisk: value.nominalConsumerRisk,
                economics: value.economics
            )
        case .double(let value):
            PlanSummary(
                kind: "Double sample",
                sampleDescription: "n₁ = \(value.firstSampleSize), c₁ = \(value.firstAcceptanceNumber), r₁ = \(value.firstRejectionNumber); n₂ = \(value.secondSampleSize), c₂ = \(value.cumulativeSecondAcceptanceNumber)",
                aql: value.acceptableQualityLevel,
                rql: value.rejectableQualityLevel,
                nominalProducerRisk: value.nominalProducerRisk,
                nominalConsumerRisk: value.nominalConsumerRisk,
                economics: value.economics
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(
                    title: document.model.title,
                    subtitle: "\(plan.kind) · \(document.backend.algorithmDisplayName)"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 165), spacing: 12)], alignment: .leading, spacing: 12) {
                    metric("Producer risk at AQL", percent(document.solution.producerRiskAtAQL))
                    metric("Consumer risk at RQL", percent(document.solution.consumerRiskAtRQL))
                    metric("Lot size", "\(plan.economics.lotSize)")
                    metric("Exactness", document.backend.exactnessDisplayName)
                }

                operatingCharacteristic
                qualityPoints
                planDetails
                runContext
            }
            .padding(20)
            .frame(maxWidth: 1120, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var operatingCharacteristic: some View {
        GroupBox("Operating characteristic") {
            Chart {
                ForEach(Array(document.solution.operatingCharacteristic.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Fraction defective", point.fractionDefective),
                        y: .value("Acceptance probability", point.acceptanceProbability)
                    )
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }

                RuleMark(x: .value("AQL", plan.aql))
                    .foregroundStyle(Color.green)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .annotation(position: .top) { Text("AQL").font(.caption).foregroundStyle(Color.green) }

                RuleMark(x: .value("RQL", plan.rql))
                    .foregroundStyle(Color.red)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .annotation(position: .top) { Text("RQL").font(.caption).foregroundStyle(Color.red) }

                PointMark(
                    x: .value("AQL", document.solution.atAQL.fractionDefective),
                    y: .value("Acceptance probability", document.solution.atAQL.acceptanceProbability)
                )
                .foregroundStyle(Color.green)
                .symbolSize(55)
                .accessibilityLabel("Acceptance probability at AQL")
                .accessibilityValue(percent(document.solution.atAQL.acceptanceProbability))

                PointMark(
                    x: .value("RQL", document.solution.atRQL.fractionDefective),
                    y: .value("Acceptance probability", document.solution.atRQL.acceptanceProbability)
                )
                .foregroundStyle(Color.red)
                .symbolSize(55)
                .accessibilityLabel("Acceptance probability at RQL")
                .accessibilityValue(percent(document.solution.atRQL.acceptanceProbability))
            }
            .chartXScale(domain: 0...1)
            .chartYScale(domain: 0...1)
            .chartXAxisLabel("Fraction defective")
            .chartYAxisLabel("P(accept)")
            .frame(height: 320)
            .padding(.vertical, 8)
            .accessibilityLabel("Operating characteristic curve")
        }
    }

    private var qualityPoints: some View {
        GroupBox("Quality-level operating measures") {
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 9) {
                    GridRow {
                        heading("Point")
                        heading("Defective")
                        heading("P(accept)")
                        heading("ASN")
                        heading("ATI")
                        heading("AOQ")
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    pointRow("AQL", document.solution.atAQL)
                    pointRow("RQL", document.solution.atRQL)
                }
                .padding(4)
            }
        }
    }

    private var planDetails: some View {
        GroupBox("Plan details") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Decision rule", value: plan.sampleDescription)
                LabeledContent("AQL", value: percent(plan.aql))
                LabeledContent("RQL", value: percent(plan.rql))
                LabeledContent("Nominal producer risk", value: percent(plan.nominalProducerRisk))
                LabeledContent("Nominal consumer risk", value: percent(plan.nominalConsumerRisk))
                LabeledContent("Sampling cost per unit", value: number(plan.economics.unitSamplingCost))
                LabeledContent("Inspection cost per unit", value: number(plan.economics.unitInspectionCost))
            }
            .padding(4)
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

    @ViewBuilder
    private func pointRow(_ label: String, _ point: AcceptanceSamplingPoint) -> some View {
        GridRow {
            Text(label).fontWeight(.semibold)
            tableValue(percent(point.fractionDefective))
            tableValue(percent(point.acceptanceProbability))
            tableValue(number(point.averageSampleNumber))
            tableValue(number(point.averageTotalInspection))
            tableValue(percent(point.averageOutgoingQuality))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Operating measures at \(label)")
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

    private func tableValue(_ text: String) -> some View {
        Text(text).monospacedDigit().frame(minWidth: 72, alignment: .trailing)
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...3)))
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0...2)))
    }
}

private struct PlanSummary {
    let kind: String
    let sampleDescription: String
    let aql: Double
    let rql: Double
    let nominalProducerRisk: Double
    let nominalConsumerRisk: Double
    let economics: AcceptanceSamplingEconomics
}
