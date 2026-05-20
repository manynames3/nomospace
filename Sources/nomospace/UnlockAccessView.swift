import SwiftUI

struct UnlockAccessView: View {
    @ObservedObject var viewModel: AuditViewModel
    let feature: LockedFeature
    @State private var accessCode = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "key.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(feature.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(feature.message)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Access code")
                    .font(.headline)
                TextField("NOMO-2026-XXXX-XXXX-XXXX", text: $accessCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit(unlock)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(AppTheme.red)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Scan and findings stay available in evaluation mode.", systemImage: "magnifyingglass")
                Label("Full access enables Move to Trash, Save PDF, and cleanup receipts.", systemImage: "lock.open")
                Label("Activation is stored locally on this Mac.", systemImage: "internaldrive")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack {
                Button("Request Code") {
                    viewModel.openAccessCodeRequest()
                }
                Spacer()
                Button("Cancel") {
                    viewModel.dismissUnlockPrompt()
                }
                .keyboardShortcut(.cancelAction)
                Button("Unlock") {
                    unlock()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private func unlock() {
        guard viewModel.activateFullVersion(code: accessCode) else {
            errorMessage = "That code did not unlock nomospace. Check the code or request a new one."
            return
        }
    }
}

struct EvaluationModeBanner: View {
    @ObservedObject var viewModel: AuditViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "lock")
                .font(.title2)
                .foregroundStyle(AppTheme.amber)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.amber.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 5) {
                Text("Evaluation mode")
                    .font(.headline)
                Text("Run audits and inspect findings for free. Enter an access code to enable Trash-first cleanup, PDF reports, and cleanup history.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Request Code") {
                viewModel.openAccessCodeRequest()
            }

            Button("Enter Code") {
                viewModel.requestUnlock()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .panel()
    }
}

struct LockedFeaturePanel: View {
    let title: String
    let message: String
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "lock")
                .font(.title2)
                .foregroundStyle(AppTheme.amber)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.amber.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Request Code", action: secondaryAction)
            Button("Enter Code", action: primaryAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .panel()
    }
}
