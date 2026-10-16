import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var status: MonitorStatus

    @ObservedObject var form: SettingsFormState

    private var trimmedDraft: String {
        form.draftWord.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var draftIsSaved: Bool {
        trimmedDraft == preferences.triggerWord
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Group {
                        if form.revealWord {
                            TextField("Trigger word", text: $form.draftWord)
                        } else {
                            SecureField("Trigger word", text: $form.draftWord)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)

                    Button {
                        form.revealWord.toggle()
                    } label: {
                        Image(systemName: form.revealWord ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(form.revealWord ? "Hide" : "Show")

                    Button("Save", action: save)
                        .disabled(draftIsSaved || trimmedDraft.isEmpty)
                        .keyboardShortcut(.defaultAction)
                }

                if !trimmedDraft.isEmpty && trimmedDraft.count < 4 {
                    Label("Short words are easy to type by accident. Pick something you'd never type normally.",
                          systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                } else if !draftIsSaved && !trimmedDraft.isEmpty {
                    Text("Press Save (or Return) to apply.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Toggle("Case sensitive", isOn: $preferences.caseSensitive)
            } header: {
                Text("Trigger")
            } footer: {
                Text("Your Mac locks the moment this word is typed in any app. Typing in password fields is never seen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Enabled", isOn: $preferences.isEnabled)
                Toggle("Test mode (beep instead of locking)", isOn: $preferences.testMode)
                Toggle("Launch at login", isOn: Binding(
                    get: { preferences.launchAtLogin },
                    set: { newValue in
                        do {
                            try preferences.setLaunchAtLogin(newValue)
                            form.launchAtLoginError = nil
                        } catch {
                            form.launchAtLoginError = error.localizedDescription
                        }
                    }
                ))
                if let launchAtLoginError = form.launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            Section("Permission") {
                HStack {
                    Image(systemName: status.hasPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(status.hasPermission ? .green : .red)
                    Text(status.hasPermission ? "Input Monitoring allowed" : "Input Monitoring required")
                    Spacer()
                    if !status.hasPermission {
                        Button("Open System Settings…") {
                            KeyMonitor.requestPermission()
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                        }
                    }
                }
                if !status.hasPermission {
                    Text("Turn on WordLock under Privacy & Security → Input Monitoring. If it still shows as required afterwards, quit and reopen WordLock.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { form.draftWord = preferences.triggerWord }
    }

    private func save() {
        guard !trimmedDraft.isEmpty else { return }
        preferences.triggerWord = trimmedDraft
        form.draftWord = trimmedDraft
    }
}

/// Editing state for the settings window. (SwiftUI's `@State` is a macro that the Command Line
/// Tools can't expand, so view-local state lives here instead.)
final class SettingsFormState: ObservableObject {
    @Published var draftWord = ""
    @Published var revealWord = false
    @Published var launchAtLoginError: String?
}

/// Live state the settings window and menu display.
final class MonitorStatus: ObservableObject {
    @Published var hasPermission = KeyMonitor.hasPermission
    @Published var isListening = false
}
