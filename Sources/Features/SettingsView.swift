import SwiftUI
import Domain
import DesignSystem

public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("알림 권한") {
                    Text(viewModel.permissionGranted ? "허용됨" : "미허용")
                        .foregroundStyle(viewModel.permissionGranted ? Color.green : Color.payDanger)
                    Button("알림 권한 요청") {
                        Task { await viewModel.requestPermission() }
                    }
                }

                Section("리마인드 시점") {
                    ForEach(ReminderOption.allCases, id: \.self) { option in
                        Toggle(option.label, isOn: Binding(
                            get: { viewModel.selectedOptions.contains(option) },
                            set: { isOn in
                                if isOn {
                                    viewModel.selectedOptions.insert(option)
                                } else {
                                    viewModel.selectedOptions.remove(option)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("설정")
        }
    }
}
