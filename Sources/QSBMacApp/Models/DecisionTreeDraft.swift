import Foundation
import QSBCore

enum DecisionTreeDraftError: Error, Equatable, CustomStringConvertible {
    case emptyTitle
    case invalidChildIDs(nodeID: Int, value: String)
    case invalidNumber(path: String, value: String)

    var path: String {
        switch self {
        case .emptyTitle: "model.title"
        case .invalidChildIDs(let nodeID, _): "model.nodes.\(nodeID).childIDs"
        case .invalidNumber(let path, _): path
        }
    }

    var description: String {
        switch self {
        case .emptyTitle: "Enter a model title."
        case .invalidChildIDs(let nodeID, let value):
            "Enter comma-separated integer child IDs for node \(nodeID) (received ‘\(value)’)."
        case .invalidNumber(let path, let value):
            "Enter a finite number for \(path) (received ‘\(value)’)."
        }
    }
}

struct DecisionTreeNodeDraft: Equatable, Sendable {
    let id: Int
    var name: String
    var kind: DecisionTreeNodeKind
    var childIDs: String
    var payoff: String
    var probability: String

    init(_ node: DecisionTreeNode) {
        id = node.id
        name = node.name
        kind = node.kind
        childIDs = node.childIDs.map { String($0) }.joined(separator: ", ")
        payoff = node.payoff.map { String($0) } ?? ""
        probability = node.probability.map { String($0) } ?? ""
    }

    init(id: Int, name: String, kind: DecisionTreeNodeKind, childIDs: String = "", payoff: String = "", probability: String = "") {
        self.id = id
        self.name = name
        self.kind = kind
        self.childIDs = childIDs
        self.payoff = payoff
        self.probability = probability
    }
}

struct DecisionTreeDraft: Equatable, Sendable {
    var title: String
    var rootID: Int
    var nodes: [DecisionTreeNodeDraft]

    static func blank() -> Self {
        Self(
            title: "New Decision Tree",
            rootID: 1,
            nodes: [
                DecisionTreeNodeDraft(id: 1, name: "Decision", kind: .decision, childIDs: "2, 3"),
                DecisionTreeNodeDraft(id: 2, name: "Option 1", kind: .terminal, payoff: "1"),
                DecisionTreeNodeDraft(id: 3, name: "Option 2", kind: .terminal, payoff: "0")
            ]
        )
    }

    init(title: String, rootID: Int, nodes: [DecisionTreeNodeDraft]) {
        self.title = title
        self.rootID = rootID
        self.nodes = nodes
    }

    init?(_ envelope: DecisionAnalysisModelEnvelope) {
        guard case .decisionTree(let tree) = envelope else { return nil }
        self.init(title: tree.title, rootID: tree.rootID, nodes: tree.nodes.map(DecisionTreeNodeDraft.init))
    }

    func makeModel() throws -> DecisionAnalysisModelEnvelope {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecisionTreeDraftError.emptyTitle
        }
        let modelNodes = try nodes.map { node in
            let children = try Self.parseChildIDs(node.childIDs, nodeID: node.id)
            let payoff = try Self.optionalNumber(node.payoff, path: "model.nodes.\(node.id).payoff")
            let probability = try Self.optionalNumber(node.probability, path: "model.nodes.\(node.id).probability")
            return DecisionTreeNode(
                id: node.id, name: node.name, kind: node.kind,
                childIDs: children, payoff: payoff, probability: probability
            )
        }
        return .decisionTree(DecisionTree(title: title, rootID: rootID, nodes: modelNodes))
    }

    func draftDiagnostics() -> [ValidationDiagnostic] {
        do {
            return DecisionAnalysisValidator.diagnostics(for: try makeModel())
        } catch let error as DecisionTreeDraftError {
            return [ValidationDiagnostic(
                severity: .error,
                code: "decisionAnalysis.draft.\(error.path.replacingOccurrences(of: ".", with: "_"))",
                message: error.description,
                path: error.path
            )]
        } catch {
            return [ValidationDiagnostic(
                severity: .error, code: "decisionAnalysis.draft.invalid",
                message: error.localizedDescription
            )]
        }
    }

    mutating func addTerminalChild(to parentID: Int) {
        guard canAddTerminalChild(to: parentID),
              let index = nodes.firstIndex(where: { $0.id == parentID }),
              let siblings = try? Self.parseChildIDs(nodes[index].childIDs, nodeID: parentID),
              let highestID = nodes.map(\.id).max(), highestID < Int.max else { return }
        let nextID = highestID + 1
        nodes[index].childIDs = (siblings + [nextID]).map { String($0) }.joined(separator: ", ")
        nodes.append(DecisionTreeNodeDraft(
            id: nextID, name: "Outcome \(nextID)", kind: .terminal,
            payoff: "0", probability: nodes[index].kind == .chance ? "1" : ""
        ))
    }

    mutating func removeLeaf(id: Int) {
        guard canRemoveLeaf(id: id), let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes.remove(at: index)
        for parentIndex in nodes.indices {
            guard let children = try? Self.parseChildIDs(nodes[parentIndex].childIDs, nodeID: nodes[parentIndex].id) else { continue }
            nodes[parentIndex].childIDs = children.filter { $0 != id }.map { String($0) }.joined(separator: ", ")
        }
    }

    func canAddTerminalChild(to parentID: Int) -> Bool {
        guard let parent = nodes.first(where: { $0.id == parentID }),
              parent.kind != .terminal,
              nodes.map(\.id).max() != Int.max else { return false }
        return (try? Self.parseChildIDs(parent.childIDs, nodeID: parentID)) != nil
    }

    func canRemoveLeaf(id: Int) -> Bool {
        guard id != rootID, let node = nodes.first(where: { $0.id == id }) else { return false }
        return (try? Self.parseChildIDs(node.childIDs, nodeID: id))?.isEmpty == true
            && nodes.allSatisfy { (try? Self.parseChildIDs($0.childIDs, nodeID: $0.id)) != nil }
    }

    private static func parseChildIDs(_ text: String, nodeID: Int) throws -> [Int] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
        let ids = parts.compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard ids.count == parts.count else {
            throw DecisionTreeDraftError.invalidChildIDs(nodeID: nodeID, value: text)
        }
        return ids
    }

    private static func optionalNumber(_ text: String, path: String) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), value.isFinite else {
            throw DecisionTreeDraftError.invalidNumber(path: path, value: text)
        }
        return value
    }
}
