import Foundation

public enum WinQSBFacilitiesParser {
    public static func parseModelEnvelope(from data: Data) throws -> FacilitiesModelEnvelope {
        let lines = try tabularLines(from: data)
        guard let metadata = lines.first,
              metadata.count >= 3,
              metadata[0] == "FLL"
        else {
            throw FacilitiesModelError.unsupportedFormat
        }

        switch metadata[2].uppercased() {
        case "LINE BALANCING":
            return .lineBalancing(try parseLineBalancing(from: data))
        case "LOCATION":
            return .location(try parseLocation(from: data))
        case "LAYOUT":
            return .layout(try parseLayout(from: data))
        default:
            throw FacilitiesModelError.unsupportedFormat
        }
    }

    public static func parseLayout(from data: Data) throws -> FacilityLayoutProblem {
        let lines = try tabularLines(from: data)
        guard let metadata = lines.first,
              metadata.count >= 7,
              metadata[0] == "FLL",
              metadata[2].uppercased() == "LAYOUT",
              let departmentCount = Int(metadata[3]),
              let rowCount = Int(metadata[4]),
              let columnCount = Int(metadata[5]),
              departmentCount > 0,
              rowCount > 0,
              columnCount > 0,
              lines.count >= departmentCount + 2
        else {
            throw FacilitiesModelError.unsupportedFormat
        }

        let departments = try lines[2..<(2 + departmentCount)].map { row -> FacilityLayoutDepartment in
            guard row.count >= departmentCount + 4,
                  let id = Int(row[0])
            else {
                throw FacilitiesModelError.unsupportedFormat
            }

            return FacilityLayoutDepartment(
                id: id,
                name: row[1],
                fixed: row[2].lowercased().hasPrefix("y"),
                flowUnitCosts: try (0..<departmentCount).map { index in
                    try optionalDouble(row[safe: 3 + index])
                },
                initialLayout: try parseLayoutRects(row[3 + departmentCount])
            )
        }

        return FacilityLayoutProblem(
            title: metadata[1],
            rowCount: rowCount,
            columnCount: columnCount,
            objective: metadata[6].uppercased(),
            departments: departments
        )
    }

    public static func parseLocation(from data: Data) throws -> FacilityLocationProblem {
        let lines = try tabularLines(from: data)
        guard let metadata = lines.first,
              metadata.count >= 7,
              metadata[0] == "FLL",
              metadata[2].uppercased() == "LOCATION",
              let existingCount = Int(metadata[3]),
              let newCount = Int(metadata[4]),
              existingCount > 0,
              newCount > 0,
              lines.count >= existingCount + newCount + 2
        else {
            throw FacilitiesModelError.unsupportedFormat
        }

        let totalFacilityCount = existingCount + newCount
        let distanceMeasure = try parseDistanceMeasure(metadata[5])
        let facilities = try lines[2..<(2 + totalFacilityCount)].enumerated().map { offset, row in
            guard row.count >= 2 + totalFacilityCount else {
                throw FacilitiesModelError.unsupportedFormat
            }

            let marker = row[0].lowercased()
            let isNew = marker.hasPrefix("new")
            let id = try parseTrailingID(row[0], fallback: offset + 1)
            let interactionCosts = try (0..<totalFacilityCount).map { costIndex in
                try optionalDouble(row[safe: 2 + costIndex])
            }

            return FacilityLocationFacility(
                id: id,
                name: row[1],
                isNew: isNew,
                x: try optionalDouble(row[safe: 2 + totalFacilityCount]),
                y: try optionalDouble(row[safe: 3 + totalFacilityCount]),
                interactionCosts: interactionCosts
            )
        }

        guard facilities.filter({ !$0.isNew }).count == existingCount,
              facilities.filter({ $0.isNew }).count == newCount
        else {
            throw FacilitiesModelError.unsupportedFormat
        }

        return FacilityLocationProblem(
            title: metadata[1],
            distanceMeasure: distanceMeasure,
            objective: metadata[6].uppercased(),
            facilities: facilities
        )
    }

    public static func parseLineBalancing(from data: Data) throws -> LineBalancingProblem {
        let lines = try tabularLines(from: data)
        guard let metadata = lines.first,
              metadata.count >= 6,
              metadata[0] == "FLL",
              metadata[2].uppercased() == "LINE BALANCING",
              let taskCount = Int(metadata[3]),
              let cycleTime = Int(metadata[5]),
              taskCount > 0,
              cycleTime > 0,
              lines.count >= taskCount + 2
        else {
            throw FacilitiesModelError.unsupportedFormat
        }

        let tasks = try lines[2..<(2 + taskCount)].map { row -> LineBalancingTask in
            guard row.count >= 5,
                  let id = Int(row[0]),
                  let time = Int(row[2])
            else {
                throw FacilitiesModelError.unsupportedFormat
            }
            return LineBalancingTask(
                id: id,
                name: row[1],
                time: time,
                isolated: row[3].lowercased().hasPrefix("y"),
                successorIDs: try parseSuccessors(row[4])
            )
        }

        return LineBalancingProblem(
            title: metadata[1],
            timeUnit: metadata[4],
            cycleTime: cycleTime,
            tasks: tasks
        )
    }

    private static func parseDistanceMeasure(_ value: String) throws -> FacilityLocationDistanceMeasure {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "rectilinear":
            return .rectilinear
        case "2", "squared euclidean", "squared-euclidean", "squaredeuclidean":
            return .squaredEuclidean
        case "3", "euclidean":
            return .euclidean
        default:
            throw FacilitiesModelError.unsupportedFormat
        }
    }

    private static func parseTrailingID(_ value: String, fallback: Int) throws -> Int {
        guard let last = value.split(separator: " ").last else {
            return fallback
        }
        guard let id = Int(last) else {
            throw FacilitiesModelError.invalidNumericValue(String(last))
        }
        return id
    }

    private static func optionalDouble(_ value: String?) throws -> Double? {
        guard let value else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }
        guard let number = Double(normalized), number.isFinite else {
            throw FacilitiesModelError.invalidNumericValue(value)
        }
        return number
    }

    private static func tabularLines(from data: Data) throws -> [[String]] {
        guard let text = data.legacyLatin1String else {
            throw FacilitiesModelError.unsupportedFormat
        }

        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(clean) }
    }

    private static func parseSuccessors(_ value: String) throws -> [Int] {
        guard !value.isEmpty else {
            return []
        }
        return try value.split(separator: ",").map { piece in
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let id = Int(trimmed) else {
                throw FacilitiesModelError.invalidNumericValue(trimmed)
            }
            return id
        }
    }

    private static func parseLayoutRects(_ value: String) throws -> [FacilityLayoutRect] {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return []
        }

        var rects: [FacilityLayoutRect] = []
        var index = text.startIndex

        func skipWhitespace() {
            while index < text.endIndex, text[index].isWhitespace {
                index = text.index(after: index)
            }
        }

        func consume(_ character: Character) -> Bool {
            skipWhitespace()
            guard index < text.endIndex, text[index] == character else {
                return false
            }
            index = text.index(after: index)
            return true
        }

        func parseInt() -> Int? {
            skipWhitespace()
            let start = index
            while index < text.endIndex, text[index].isNumber {
                index = text.index(after: index)
            }
            guard start != index else {
                return nil
            }
            return Int(text[start..<index])
        }

        func parseCell() throws -> (row: Int, column: Int) {
            guard consume("("),
                  let row = parseInt(),
                  consume(","),
                  let column = parseInt(),
                  consume(")")
            else {
                throw FacilitiesModelError.unsupportedFormat
            }
            return (row: row, column: column)
        }

        while index < text.endIndex {
            let start = try parseCell()
            var end = start
            if consume("-") {
                end = try parseCell()
            }

            rects.append(FacilityLayoutRect(
                startRow: min(start.row, end.row),
                startColumn: min(start.column, end.column),
                endRow: max(start.row, end.row),
                endColumn: max(start.column, end.column)
            ))

            skipWhitespace()
            guard index < text.endIndex else {
                break
            }
            guard consume(",") else {
                throw FacilitiesModelError.unsupportedFormat
            }
        }

        return rects
    }

    private static func clean(_ value: Substring) -> String {
        String(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

