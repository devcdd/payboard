import SwiftUI
import Domain
import Data
import DesignSystem

public struct ArchiveView: View {
    @ObservedObject var viewModel: BoardViewModel

    public init(viewModel: BoardViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.archivedSubscriptions.isEmpty {
                    ContentUnavailableView {
                        Label("archive.empty.title", systemImage: "archivebox")
                    } description: {
                        Text("archive.empty.description")
                    }
                } else {
                    List {
                        ForEach(viewModel.archivedSubscriptions) { subscription in
                            HStack(spacing: PayBoardSpacing.sm) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subscription.name)
                                        .font(.headline)
                                    Text(LocalizedStringKey(subscription.category.labelKey))
                                        .font(.caption)
                                        .foregroundStyle(Color.payMuted)
                                }

                                Spacer()

                                Button("archive.action.restore") {
                                    Task { await viewModel.restore(subscription) }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("common.delete", role: .destructive) {
                                    Task { await viewModel.delete(subscription) }
                                }
                            }
                        }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #else
                    .listStyle(.inset)
                    #endif
                }
            }
            .navigationTitle("tab.archive")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                await viewModel.reload()
            }
        }
    }
}
