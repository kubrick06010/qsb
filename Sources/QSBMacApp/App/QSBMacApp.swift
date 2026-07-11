import AppKit
import SwiftUI

@main
struct QSBMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var workspace = QSBWorkspace()

    var body: some Scene {
        WindowGroup("QSB", id: "main") {
            ContentView(workspace: workspace)
                .frame(minWidth: 980, minHeight: 620)
        }
        .commands {
            CommandMenu("Model") {
                Button("Open Model JSON...") {
                    workspace.isImportingModel = true
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Export Model JSON...") {
                    workspace.isExportingModel = true
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button("Export Solution JSON...") {
                    workspace.isExportingSolution = true
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(workspace.solutionJSON.isEmpty)
            }

            CommandMenu("Solve") {
                Button("Solve LP Relaxation") {
                    workspace.solve(.relaxation)
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!workspace.isLinearProgrammingModel)

                Button("Solve ILP") {
                    workspace.solve(.integer)
                }
                .keyboardShortcut("i", modifiers: [.command])
                .disabled(!workspace.isLinearProgrammingModel)

                Button("Solve Network") {
                    workspace.solveNetwork()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(!workspace.isNetworkModel)

                Button("Solve Facilities") {
                    workspace.solveFacilities()
                }
                .disabled(!workspace.isFacilitiesModel)

                Divider()

                Button("Load LP Sample") {
                    workspace.loadSample(.linearProgram)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Load ILP Sample") {
                    workspace.loadSample(.integerProgram)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Load TSP Network Sample") {
                    workspace.loadSample(.travelingSalesperson)
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("Load Facility Layout Sample") {
                    workspace.loadSample(.facilityLayout)
                }
                .keyboardShortcut("4", modifiers: [.command])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
