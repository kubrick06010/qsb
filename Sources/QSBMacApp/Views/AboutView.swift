import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // App Icon
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            } else {
                Image(systemName: "cube.transparent")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .foregroundStyle(.tint)
            }

            VStack(spacing: 4) {
                Text("QSB")
                    .font(.system(size: 24, weight: .bold))

                Text("Modern Operations Research Workbench")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Versión 1.0 · 2026")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            Divider()
                .padding(.horizontal, 16)

            VStack(spacing: 14) {
                VStack(spacing: 3) {
                    Text("Autor principal")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Humberto A.")
                        .font(.headline.weight(.semibold))
                        .accessibilityIdentifier("about-author")
                }

                VStack(spacing: 4) {
                    Text("Colaboradores")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("Agradecimiento a los colaboradores que aportan soluciones y mejoras a través de pull requests en el repositorio oficial.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            }

            Divider()
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/kubrick06010/qsb")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.caption)
                        Text("github.com/kubrick06010/qsb")
                            .font(.callout.weight(.medium))
                    }
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("about-repo-link")

                Text("Clean-room modernization de WinQSB bajo licencia de código abierto.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 4)

            Button("Cerrar") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 4)
            .accessibilityIdentifier("about-close")
        }
        .padding(24)
        .frame(width: 440, height: 490)
        .accessibilityIdentifier("about-view")
    }
}
