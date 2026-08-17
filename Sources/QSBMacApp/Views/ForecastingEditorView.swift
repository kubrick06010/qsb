import QSBCore
import SwiftUI

struct ForecastingEditorView: View {
    @Bindable var workspace: QSBWorkspace

    private enum Parameter { case periodsAhead, windowSize, alpha, seasonLength }

    private var methodBinding: Binding<ForecastingMethod> {
        Binding(get: { workspace.forecastingDraft?.method ?? .linearTrend }, set: { method in
            workspace.updateForecastingDraft { $0.switchMethod(to: method) }
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(title: workspace.modelTitle, subtitle: "Native Forecasting editor · \(workspace.modelState.rawValue)")
            if workspace.forecastingDraft == nil {
                ContentUnavailableView("No Forecasting draft", systemImage: "chart.xyaxis.line", description: Text("Choose a Forecasting method from New Model or open a normalized request."))
            } else {
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 18) {
                        controls
                        if workspace.forecastingDraft?.method == .ordinaryLeastSquares {
                            regressionEditor
                        } else {
                            timeSeriesEditor
                        }
                    }
                    .padding(20)
                    .frame(minWidth: 820, alignment: .topLeading)
                }
            }
        }
        .navigationTitle("Forecasting Definition")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Method", selection: methodBinding) {
                    ForEach(ForecastingMethod.allCases, id: \.rawValue) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("forecasting-method")
                Spacer()
                Button("Validate") { workspace.validateCurrentModel() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Button("Run") { workspace.runCurrentModel() }
                    .keyboardShortcut("r", modifiers: [.command])
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("forecasting-run")
                    .disabled(workspace.runState == .solving)
            }
            Text("Switching methods preserves time-series observations; method-specific parameters remain explicit and typed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timeSeriesEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Model identity") {
                HStack {
                    field("Title", value: timeSeriesField(\.title), id: "forecasting-title")
                    field("Time unit", value: timeSeriesField(\.timeUnit), id: "forecasting-time-unit")
                    field("Value name", value: timeSeriesField(\.valueName), id: "forecasting-value-name")
                }
                .padding(8)
            }
            GroupBox("Method parameters") {
                HStack {
                    switch workspace.forecastingDraft?.method {
                    case .linearTrend:
                        Text("Fits a deterministic linear trend to the historical series.")
                    case .movingAverage:
                        field("Window size", value: timeSeriesParameter(.windowSize), id: "forecasting-window-size")
                    case .exponentialSmoothing:
                        field("Alpha", value: timeSeriesParameter(.alpha), id: "forecasting-alpha")
                    case .multiplicativeSeasonalDecomposition:
                        field("Season length", value: timeSeriesParameter(.seasonLength), id: "forecasting-season-length")
                    case .ordinaryLeastSquares, nil:
                        EmptyView()
                    }
                    field("Forecast horizon", value: timeSeriesParameter(.periodsAhead), id: "forecasting-horizon")
                    Spacer()
                }
                .padding(8)
            }
            observationsEditor
        }
    }

    private var observationsEditor: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Historical observations").font(.headline)
                    Text("\(workspace.forecastingDraft?.observationsCount ?? 0)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("forecasting-observation-count")
                    Spacer()
                    Button { workspace.updateForecastingDraft { $0.addObservation() } } label: {
                        Label("Add observation", systemImage: "plus")
                    }
                    .accessibilityIdentifier("forecasting-add-observation")
                }
                HStack(spacing: 8) {
                    Text("Period").frame(width: 180, alignment: .leading)
                    Text("Value").frame(width: 120, alignment: .leading)
                    Spacer()
                }
                .font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(Array(0..<(workspace.forecastingDraft?.observationsCount ?? 0)), id: \.self) { index in
                    HStack(spacing: 8) {
                        TextField("Period", text: timeSeriesObservationField(index, \.label))
                            .textFieldStyle(.roundedBorder).frame(width: 180)
                            .accessibilityLabel("Forecasting period \(index + 1) label")
                        TextField("Value", text: timeSeriesObservationField(index, \.value))
                            .textFieldStyle(.roundedBorder).frame(width: 120)
                            .accessibilityLabel("Forecasting observation \(index + 1) value")
                        Button(role: .destructive) { workspace.updateForecastingDraft { $0.removeObservation(at: index) } } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled((workspace.forecastingDraft?.observationsCount ?? 0) <= 1)
                        .accessibilityLabel("Remove forecasting observation \(index + 1)")
                    }
                }
            }
            .padding(8)
        }
    }

    private var regressionEditor: some View {
        GroupBox("Multiple regression data") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    field("Title", value: regressionField(\.title), id: "forecasting-title")
                    field("Dependent variable", value: regressionField(\.dependentVariable), id: "forecasting-dependent-variable")
                }
                HStack {
                    Text("Predictors").font(.headline)
                    Button { workspace.updateForecastingDraft { draft in guard case .ordinaryLeastSquares(var value) = draft else { return }; value.independentVariables.append("X\(value.independentVariables.count + 1)"); value.observations = value.observations.map { ForecastingRegressionObservationDraft(label: $0.label, dependentValue: $0.dependentValue, independentValues: $0.independentValues + ["0"]) }; draft = .ordinaryLeastSquares(value) } } label: { Label("Add predictor", systemImage: "plus") }
                    Spacer()
                }
                ForEach(Array(0..<(regressionPredictorCount)), id: \.self) { index in
                    TextField("Predictor", text: regressionPredictorField(index))
                        .textFieldStyle(.roundedBorder).frame(width: 180)
                        .accessibilityIdentifier("forecasting-predictor-\(index + 1)")
                }
                Divider()
                HStack { Text("Observation").frame(width: 150, alignment: .leading); Text("Dependent").frame(width: 100, alignment: .leading); ForEach(0..<regressionPredictorCount, id: \.self) { index in Text("X\(index + 1)").frame(width: 90, alignment: .leading) }; Spacer() }
                    .font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(Array(0..<regressionObservationCount), id: \.self) { row in
                    HStack {
                        TextField("Label", text: regressionObservationField(row, \.label)).frame(width: 150)
                        TextField("Value", text: regressionObservationField(row, \.dependentValue)).frame(width: 100)
                        ForEach(0..<regressionPredictorCount, id: \.self) { column in TextField("0", text: regressionIndependentField(row, column)).frame(width: 90) }
                    }
                }
                Button { workspace.updateForecastingDraft { $0.addObservation() } } label: { Label("Add observation", systemImage: "plus") }
                Text("Ordinary least squares uses the existing QSBCore QR-based regression solver. Rank and dimension diagnostics remain core-owned.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(8)
        }
    }

    private var regressionPredictorCount: Int { if case .ordinaryLeastSquares(let draft) = workspace.forecastingDraft { return draft.independentVariables.count }; return 0 }
    private var regressionObservationCount: Int { if case .ordinaryLeastSquares(let draft) = workspace.forecastingDraft { return draft.observations.count }; return 0 }

    private func field(_ title: String, value: Binding<String>, id: String) -> some View { LabeledContent(title) { TextField(title, text: value).textFieldStyle(.roundedBorder).frame(width: 150).accessibilityIdentifier(id) } }

    private func timeSeriesField(_ keyPath: WritableKeyPath<ForecastingTimeSeriesBaseDraft, String>) -> Binding<String> { Binding(get: { baseValue(keyPath) }, set: { value in workspace.updateForecastingDraft { draft in updateBase(&draft, keyPath: keyPath, value: value) } }) }
    private func timeSeriesParameter(_ parameter: Parameter) -> Binding<String> { Binding(get: { parameterValue(parameter) }, set: { value in setParameter(parameter, value: value) }) }
    private func timeSeriesObservationField(_ index: Int, _ keyPath: WritableKeyPath<ForecastingObservationDraft, String>) -> Binding<String> { Binding(get: { observationValue(index, keyPath) }, set: { value in workspace.updateForecastingDraft { draft in updateObservation(&draft, index: index, keyPath: keyPath, value: value) } }) }
    private func regressionField(_ keyPath: WritableKeyPath<ForecastingRegressionDraft, String>) -> Binding<String> { Binding(get: { if case .ordinaryLeastSquares(let draft) = workspace.forecastingDraft { return draft[keyPath: keyPath] }; return "" }, set: { value in workspace.updateForecastingDraft { if case .ordinaryLeastSquares(var draft) = $0 { draft[keyPath: keyPath] = value; $0 = .ordinaryLeastSquares(draft) } } }) }
    private func regressionPredictorField(_ index: Int) -> Binding<String> { Binding(get: { if case .ordinaryLeastSquares(let draft) = workspace.forecastingDraft, draft.independentVariables.indices.contains(index) { return draft.independentVariables[index] }; return "" }, set: { value in workspace.updateForecastingDraft { if case .ordinaryLeastSquares(var draft) = $0, draft.independentVariables.indices.contains(index) { draft.independentVariables[index] = value; $0 = .ordinaryLeastSquares(draft) } } }) }
    private func regressionObservationField(_ row: Int, _ keyPath: WritableKeyPath<ForecastingRegressionObservationDraft, String>) -> Binding<String> { Binding(get: { if case .ordinaryLeastSquares(let draft) = workspace.forecastingDraft, draft.observations.indices.contains(row) { return draft.observations[row][keyPath: keyPath] }; return "" }, set: { value in workspace.updateForecastingDraft { if case .ordinaryLeastSquares(var draft) = $0, draft.observations.indices.contains(row) { draft.observations[row][keyPath: keyPath] = value; $0 = .ordinaryLeastSquares(draft) } } }) }
    private func regressionIndependentField(_ row: Int, _ column: Int) -> Binding<String> { Binding(get: { if case .ordinaryLeastSquares(let draft) = workspace.forecastingDraft, draft.observations.indices.contains(row), draft.observations[row].independentValues.indices.contains(column) { return draft.observations[row].independentValues[column] }; return "" }, set: { value in workspace.updateForecastingDraft { if case .ordinaryLeastSquares(var draft) = $0, draft.observations.indices.contains(row), draft.observations[row].independentValues.indices.contains(column) { draft.observations[row].independentValues[column] = value; $0 = .ordinaryLeastSquares(draft) } } }) }

    private func baseValue(_ keyPath: KeyPath<ForecastingTimeSeriesBaseDraft, String>) -> String { switch workspace.forecastingDraft { case .linearTrend(let base, _), .movingAverage(let base, _, _), .exponentialSmoothing(let base, _, _), .multiplicativeSeasonalDecomposition(let base, _, _): base[keyPath: keyPath]; default: "" } }
    private func updateBase(_ draft: inout ForecastingDraft, keyPath: WritableKeyPath<ForecastingTimeSeriesBaseDraft, String>, value: String) { switch draft { case .linearTrend(var base, let p): base[keyPath: keyPath] = value; draft = .linearTrend(base, periodsAhead: p); case .movingAverage(var base, let w, let p): base[keyPath: keyPath] = value; draft = .movingAverage(base, windowSize: w, periodsAhead: p); case .exponentialSmoothing(var base, let a, let p): base[keyPath: keyPath] = value; draft = .exponentialSmoothing(base, alpha: a, periodsAhead: p); case .multiplicativeSeasonalDecomposition(var base, let s, let p): base[keyPath: keyPath] = value; draft = .multiplicativeSeasonalDecomposition(base, seasonLength: s, periodsAhead: p); default: break } }
    private func observationValue(_ index: Int, _ keyPath: KeyPath<ForecastingObservationDraft, String>) -> String { switch workspace.forecastingDraft { case .linearTrend(let base, _), .movingAverage(let base, _, _), .exponentialSmoothing(let base, _, _), .multiplicativeSeasonalDecomposition(let base, _, _): base.observations.indices.contains(index) ? base.observations[index][keyPath: keyPath] : ""; default: "" } }
    private func updateObservation(_ draft: inout ForecastingDraft, index: Int, keyPath: WritableKeyPath<ForecastingObservationDraft, String>, value: String) { switch draft { case .linearTrend(var base, let periods): if base.observations.indices.contains(index) { base.observations[index][keyPath: keyPath] = value }; draft = .linearTrend(base, periodsAhead: periods); case .movingAverage(var base, let window, let periods): if base.observations.indices.contains(index) { base.observations[index][keyPath: keyPath] = value }; draft = .movingAverage(base, windowSize: window, periodsAhead: periods); case .exponentialSmoothing(var base, let alpha, let periods): if base.observations.indices.contains(index) { base.observations[index][keyPath: keyPath] = value }; draft = .exponentialSmoothing(base, alpha: alpha, periodsAhead: periods); case .multiplicativeSeasonalDecomposition(var base, let season, let periods): if base.observations.indices.contains(index) { base.observations[index][keyPath: keyPath] = value }; draft = .multiplicativeSeasonalDecomposition(base, seasonLength: season, periodsAhead: periods); default: break } }
    private func parameterValue(_ parameter: Parameter) -> String { switch workspace.forecastingDraft { case .linearTrend(_, let p): parameter == .periodsAhead ? p : ""; case .movingAverage(_, let w, let p): parameter == .windowSize ? w : p; case .exponentialSmoothing(_, let a, let p): parameter == .alpha ? a : p; case .multiplicativeSeasonalDecomposition(_, let s, let p): parameter == .seasonLength ? s : p; default: "" } }
    private func setParameter(_ parameter: Parameter, value: String) { workspace.updateForecastingDraft { draft in switch draft { case .linearTrend(let base, let p): draft = .linearTrend(base, periodsAhead: parameter == .periodsAhead ? value : p); case .movingAverage(let base, let w, let p): draft = .movingAverage(base, windowSize: parameter == .windowSize ? value : w, periodsAhead: parameter == .periodsAhead ? value : p); case .exponentialSmoothing(let base, let a, let p): draft = .exponentialSmoothing(base, alpha: parameter == .alpha ? value : a, periodsAhead: parameter == .periodsAhead ? value : p); case .multiplicativeSeasonalDecomposition(let base, let s, let p): draft = .multiplicativeSeasonalDecomposition(base, seasonLength: parameter == .seasonLength ? value : s, periodsAhead: parameter == .periodsAhead ? value : p); default: break } } }
}
