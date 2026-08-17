import Foundation

enum NetworkStressSamples {
    static func denseShortestPath() -> NetworkDraft {
        let positions: [(Double, Double)] = [
            (0.08, 0.12), (0.25, 0.12), (0.50, 0.10), (0.75, 0.12), (0.92, 0.14),
            (0.12, 0.32), (0.34, 0.30), (0.58, 0.28), (0.82, 0.32), (0.94, 0.38),
            (0.08, 0.54), (0.28, 0.50), (0.50, 0.52), (0.72, 0.50), (0.92, 0.56),
            (0.14, 0.78), (0.38, 0.76), (0.60, 0.80), (0.80, 0.76), (0.92, 0.88)
        ]
        let nodes = positions.enumerated().map { index, position in
            NetworkNodeDraft(id: stableID(index + 1), name: "Node \(index + 1)", position: .init(x: position.0, y: position.1))
        }
        let connections: [(Int, Int, String)] = [
            (1, 2, "3"), (2, 3, "5"), (3, 4, "7.5"), (4, 5, "12"),
            (6, 7, "18"), (7, 8, "2.25"), (8, 9, "9"), (9, 10, "14.5"),
            (11, 12, "21"), (12, 13, "4"), (13, 14, "6.5"), (14, 15, "11"),
            (16, 17, "8"), (17, 18, "13.75"), (18, 19, "16"), (19, 20, "5.5"),
            (1, 6, "10"), (2, 7, "6"), (3, 8, "15"), (4, 9, "3.5"),
            (5, 10, "17"), (6, 11, "4.25"), (7, 12, "12.5"), (8, 13, "8.75"),
            (9, 14, "19"), (10, 15, "7"), (11, 16, "9.5"), (12, 17, "14"),
            (13, 18, "2.5"), (14, 19, "20"), (15, 20, "6.25"),
            (1, 8, "22"), (5, 8, "5.75"), (6, 14, "18.5"), (10, 18, "11.25"),
            (3, 12, "9.75"), (8, 17, "23")
        ]
        let arcs = connections.enumerated().map { index, connection in
            NetworkArcDraft(
                id: stableID(100 + index),
                fromNodeID: nodes[connection.0 - 1].id,
                toNodeID: nodes[connection.1 - 1].id,
                costText: connection.2
            )
        }
        return NetworkDraft(
            kind: .shortestPath,
            title: "Dense Shortest Path Demo",
            nodes: nodes,
            arcs: arcs,
            sourceNodeID: nodes.first?.id,
            sinkNodeID: nodes.last?.id
        )
    }

    private static func stableID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", value)) ?? UUID()
    }
}
