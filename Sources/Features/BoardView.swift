import SwiftUI
import Domain
import Data
import DesignSystem

public struct BoardView: View {
    @ObservedObject var viewModel: BoardViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel

    public init(viewModel: BoardViewModel, settingsViewModel: SettingsViewModel) {
        self.viewModel = viewModel
        self.settingsViewModel = settingsViewModel
    }

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: PayBoardSpacing.md),
        GridItem(.flexible(), spacing: PayBoardSpacing.md)
    ]

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.payBackground.ignoresSafeArea()

                if viewModel.filteredSubscriptions.isEmpty {
                    ContentUnavailableView("구독이 없습니다", systemImage: "tray", description: Text("오른쪽 상단 + 버튼으로 추가하세요."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: PayBoardSpacing.md) {
                            ForEach(viewModel.filteredSubscriptions) { subscription in
                                SubscriptionCardView(
                                    subscription: subscription,
                                    symbolName: iconSymbol(for: subscription.iconKey)
                                )
                                .contextMenu {
                                    Button("수정") {
                                        viewModel.editingTarget = subscription
                                        viewModel.isPresentingEditor = true
                                    }
                                    Button("삭제", role: .destructive) {
                                        Task { await viewModel.delete(subscription) }
                                    }
                                }
                            }
                        }
                        .padding(PayBoardSpacing.lg)
                    }
                }
            }
            .navigationTitle("Pay Board")
            .toolbar {
                ToolbarItem {
                    Picker("Filter", selection: $viewModel.selectedFilter) {
                        ForEach(BoardFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                }

                ToolbarItem {
                    Button {
                        viewModel.editingTarget = nil
                        viewModel.isPresentingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await viewModel.onAppear()
                await viewModel.syncReminderOptions(settingsViewModel.selectedOptions)
            }
            .onChange(of: settingsViewModel.selectedOptions) { _, newValue in
                Task { await viewModel.syncReminderOptions(newValue) }
            }
            .sheet(isPresented: $viewModel.isPresentingEditor) {
                ServiceEditorView(original: viewModel.editingTarget) { payload in
                    viewModel.setReminderOptions(Array(settingsViewModel.selectedOptions))
                    await viewModel.upsert(payload)
                }
            }
            .alert("오류", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { viewModel.errorMessage = nil }
                }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    private func iconSymbol(for iconKey: String) -> String {
        PresetIconCatalog.all().first(where: { $0.key == iconKey })?.systemSymbol ?? "app.badge"
    }
}
