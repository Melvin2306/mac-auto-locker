import AppKit

/// Plain AppKit settings window. Created when opened and released when closed, so it costs
/// nothing while WordLock sits in the menu bar.
final class SettingsWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    /// Called after any setting changes.
    var onChange: (() -> Void)?
    var onClose: (() -> Void)?

    private let preferences = Preferences.shared
    private var words: [String] = []

    private let table = NSTableView()
    private let input = NSTextField()
    private let removeButton = NSButton(title: "Remove", target: nil, action: nil)
    private let warning = NSTextField(labelWithString: "")
    private let caseBox = NSButton(checkboxWithTitle: "Case sensitive", target: nil, action: nil)
    private let enabledBox = NSButton(checkboxWithTitle: "Enabled", target: nil, action: nil)
    private let testBox = NSButton(checkboxWithTitle: "Test mode (beep instead of locking)", target: nil, action: nil)
    private let loginBox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionButton = NSButton(title: "Open System Settings…", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true
        )
        window.title = "WordLock Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent(in: window)
        refresh()
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Re-reads all settings and permission state into the controls.
    func refresh() {
        words = preferences.triggerWords
        table.reloadData()
        removeButton.isEnabled = table.selectedRow >= 0
        caseBox.state = preferences.caseSensitive ? .on : .off
        enabledBox.state = preferences.isEnabled ? .on : .off
        testBox.state = preferences.testMode ? .on : .off
        loginBox.state = preferences.launchAtLogin ? .on : .off

        let allowed = KeyMonitor.hasPermission
        permissionLabel.stringValue = allowed
            ? "✅  Input Monitoring allowed"
            : "⚠️  Input Monitoring required. Turn on WordLock under Privacy & Security → Input Monitoring."
        permissionButton.isHidden = allowed
    }

    // MARK: - Layout

    private func buildContent(in window: NSWindow) {
        let title = NSTextField(labelWithString: "Trigger words")
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        table.addTableColumn(NSTableColumn(identifier: .init("word")))
        table.headerView = nil
        table.usesAlternatingRowBackgroundColors = true
        table.dataSource = self
        table.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        input.placeholderString = "Add a word, then press Return"
        input.target = self
        input.action = #selector(addWord)
        input.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let addButton = NSButton(title: "Add", target: self, action: #selector(addWord))
        removeButton.target = self
        removeButton.action = #selector(removeWord)
        let inputRow = NSStackView(views: [input, addButton, removeButton])

        warning.textColor = .systemOrange
        warning.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        warning.isHidden = true

        let hint = NSTextField(wrappingLabelWithString:
            "Typing any of these words in any app locks your Mac. Pick words you'd never type by accident. Typing in password fields is never seen.")
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor

        for box in [caseBox, enabledBox, testBox, loginBox] {
            box.target = self
            box.action = #selector(toggleChanged(_:))
        }

        permissionLabel.lineBreakMode = .byWordWrapping
        permissionLabel.maximumNumberOfLines = 0
        permissionButton.target = self
        permissionButton.action = #selector(openPermissionSettings)

        let stack = NSStackView(views: [
            title, scroll, inputRow, warning, hint, caseBox,
            separator(), enabledBox, testBox, loginBox,
            separator(), permissionLabel, permissionButton,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.setCustomSpacing(6, after: title)
        stack.setCustomSpacing(4, after: warning)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        window.contentView = content

        var constraints = [
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: 440),
            scroll.heightAnchor.constraint(equalToConstant: 140),
        ]
        for view in [scroll, inputRow, hint, permissionLabel] {
            constraints.append(view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40))
        }
        NSLayoutConstraint.activate(constraints)
        window.setContentSize(stack.fittingSize)
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { words.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let label = tableView.makeView(withIdentifier: id, owner: nil) as? NSTextField
            ?? NSTextField(labelWithString: "")
        label.identifier = id
        label.stringValue = words[row]
        return label
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        removeButton.isEnabled = table.selectedRow >= 0
    }

    // MARK: - Actions

    @objc private func addWord() {
        let word = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        input.stringValue = ""

        if words.contains(word) {
            showWarning("“\(word)” is already in the list.")
            return
        }
        showWarning(word.count < 4 ? "“\(word)” is short, so it's easy to type by accident." : nil)
        preferences.triggerWords = words + [word]
        refresh()
        onChange?()
    }

    @objc private func removeWord() {
        let row = table.selectedRow
        guard words.indices.contains(row) else { return }
        var updated = words
        updated.remove(at: row)
        preferences.triggerWords = updated
        showWarning(nil)
        refresh()
        onChange?()
    }

    @objc private func toggleChanged(_ sender: NSButton) {
        let on = sender.state == .on
        switch sender {
        case caseBox: preferences.caseSensitive = on
        case enabledBox: preferences.isEnabled = on
        case testBox: preferences.testMode = on
        case loginBox:
            do {
                try preferences.setLaunchAtLogin(on)
            } catch {
                NSAlert(error: error).runModal()
            }
        default: break
        }
        refresh()
        onChange?()
    }

    @objc private func openPermissionSettings() {
        KeyMonitor.requestPermission()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    private func showWarning(_ text: String?) {
        warning.stringValue = text ?? ""
        warning.isHidden = text == nil
        window?.setContentSize(window?.contentView?.fittingSize ?? .zero)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
