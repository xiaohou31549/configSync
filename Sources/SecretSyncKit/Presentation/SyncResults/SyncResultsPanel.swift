import SwiftUI

public struct SyncResultsPanel: View {
    let summary: SyncSummary

    public init(summary: SyncSummary) {
        self.summary = summary
    }

    public var body: some View {
        GroupBox("同步结果") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    metric(title: "成功", value: "\(summary.successCount)", color: .green)
                    metric(title: "失败", value: "\(summary.failureCount)", color: .red)
                    metric(title: "总计", value: "\(summary.results.count)", color: .secondary)
                }

                Divider()

                ForEach(summary.results) { result in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(result.repoFullName) · \(result.itemName)")
                                .fontWeight(.medium)
                            Text(result.itemType.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        switch result.status {
                        case .success:
                            Label("成功", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case let .failed(message):
                            VStack(alignment: .trailing, spacing: 4) {
                                Label("失败", systemImage: "xmark.octagon.fill")
                                    .foregroundStyle(.red)
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func metric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
