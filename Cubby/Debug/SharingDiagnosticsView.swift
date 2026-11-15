#if DEBUG
import CloudKit
import SwiftUI

/// DEBUG-only screen (Options › Sharing Diagnostics) showing recent CloudKit
/// mirroring events and a field to join a share by pasting its URL.
struct SharingDiagnosticsView: View {
    @ObservedObject private var eventLog = CloudKitEventLog.shared
    @ObservedObject private var acceptance = ShareAcceptanceCoordinator.shared
    @Environment(\.homeSharingService) private var homeSharingService

    @State private var shareURLText = ""
    @State private var joinError: String?

    var body: some View {
        List {
            Section {
                TextField("https://www.icloud.com/share/…", text: $shareURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Button("Join Shared Home") {
                    Task { await join() }
                }
                .disabled(parsedURL == nil || acceptance.isBusy || homeSharingService == nil)
                if let status = acceptanceStatus {
                    Text(status)
                        .font(CubbyDesign.Typography.bodySmall)
                        .foregroundStyle(CubbyDesign.Palette.secondaryText)
                }
                if let joinError {
                    Text(joinError)
                        .font(CubbyDesign.Typography.bodySmall)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Join from Link")
            } footer: {
                Text("Fetches the share's metadata and accepts it through the same path as tapping an invitation.")
            }

            Section("CloudKit Events") {
                if eventLog.entries.isEmpty {
                    Text("No events yet")
                        .foregroundStyle(CubbyDesign.Palette.secondaryText)
                } else {
                    ForEach(eventLog.entries) { entry in
                        EventRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("Sharing Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var parsedURL: URL? {
        let trimmed = shareURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else { return nil }
        return url
    }

    private var acceptanceStatus: String? {
        switch acceptance.state {
        case .idle: nil
        case .joining: "Joining…"
        case .waitingForImport: "Joined. Waiting for iCloud to download the home…"
        case .failed(let message): message
        }
    }

    private func join() async {
        guard let url = parsedURL, let homeSharingService else { return }
        joinError = nil
        do {
            let metadata = try await Self.fetchShareMetadata(
                url: url,
                container: homeSharingService.cloudKitContainer
            )
            await acceptance.accept(
                metadata,
                using: homeSharingService,
                errorHandler: SharingErrorHandler()
            )
        } catch {
            DebugLogger.error("Join from link: metadata fetch failed: \(error)")
            joinError = SharingErrorHandler().handleShareAcceptanceFailure(error).message
                + " (\(error.localizedDescription))"
        }
    }

    static func fetchShareMetadata(url: URL, container: CKContainer) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            operation.shouldFetchRootRecord = false
            var metadataResult: Result<CKShare.Metadata, Error>?
            operation.perShareMetadataResultBlock = { _, result in
                metadataResult = result
            }
            operation.fetchShareMetadataResultBlock = { result in
                switch (result, metadataResult) {
                case (.failure(let error), _):
                    continuation.resume(throwing: error)
                case (.success, .success(let metadata)?):
                    continuation.resume(returning: metadata)
                case (.success, .failure(let error)?):
                    continuation.resume(throwing: error)
                case (.success, nil):
                    continuation.resume(throwing: CKError(.unknownItem))
                }
            }
            container.add(operation)
        }
    }
}

private struct EventRow: View {
    let entry: CloudKitEventLog.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(entry.kind.rawValue) · \(entry.store)")
                    .font(CubbyDesign.Typography.body)
                Spacer()
                Text(status)
                    .font(CubbyDesign.Typography.bodySmall)
                    .foregroundStyle(statusColor)
            }
            Text(entry.startDate.formatted(date: .omitted, time: .standard))
                .font(CubbyDesign.Typography.bodySmall)
                .foregroundStyle(CubbyDesign.Palette.secondaryText)
            if let error = entry.errorDescription {
                Text(error)
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    private var status: String {
        guard entry.isFinished else { return "running" }
        return entry.succeeded ? "ok" : "failed"
    }

    private var statusColor: Color {
        guard entry.isFinished else { return CubbyDesign.Palette.secondaryText }
        return entry.succeeded ? .green : .red
    }
}
#endif
