import Foundation
import Testing
@testable import QSBCore

@Suite struct AggregatePlanningParserRobustnessTests {
    @Test func parsesAndSolvesSyntheticPlanningTable() throws {
        let model = try WinQSBAggregatePlanningParser.parse(from: payload())
        #expect(model.demand == [3])
        #expect(model.regularCapacity == [5])
        #expect(try AggregatePlanningJSON.decodeModel(from: AggregatePlanningJSON.encodeModel(model)) == model)
        let solution = try AggregatePlanningSolver.solve(model)
        #expect(abs(solution.totalCost - 6) < 1e-9)
    }

    @Test(arguments: ["Forecast Demand", " Forecast Demand ", "FORECAST DEMAND"])
    func rejectsDuplicateLabels(label: String) throws {
        do {
            _ = try WinQSBAggregatePlanningParser.parse(from: payload(extraRow: "\(label)\t3"))
            Issue.record("Duplicate planning row was accepted")
        } catch AggregatePlanningError.invalidModel(let detail) {
            #expect(detail == "Duplicate row 'forecast demand'")
        }
    }

    @Test(arguments: [2, Int.max])
    func rejectsPeriodCountsExceedingHeader(count: Int) throws {
        do {
            _ = try WinQSBAggregatePlanningParser.parse(from: payload(periodCount: count))
            Issue.record("Invalid period count was accepted")
        } catch AggregatePlanningError.unsupportedFormat {}
    }

    private func payload(extraRow: String? = nil, periodCount: Int = 1) -> Data {
        var rows = [
            "AP\tSynthetic planning\t1",
            "\(periodCount)\tWorkers\tHours\t0",
            "Parameters",
            "Period\tWeek 1",
            "Forecast Demand\t3",
            "Regular Time Capacity\t5",
            "Regular Time Cost\t2",
            "Maximum Subcontracting\t0"
        ]
        if let extraRow { rows.append(extraRow) }
        return Data(rows.joined(separator: "\n").utf8)
    }
}
