import SwiftUI

struct AddInstallationView: View {
    @Bindable var store: MonitorStore
    @Environment(\.dismiss) private var dismiss
    private var editingInstallation: ScrutinyInstallation?

    @State private var name = ""
    @State private var urlString = ""
    @State private var apiToken = ""
    @State private var validationMessage: String?
    @State private var isShowingHelp = false

    private enum Field: Hashable {
        case name
        case url
        case apiToken
    }
    @FocusState private var focusedField: Field?

    init(store: MonitorStore, editingInstallation: ScrutinyInstallation? = nil) {
        self.store = store
        self.editingInstallation = editingInstallation

        _name = State(initialValue: editingInstallation?.name ?? "")
        _urlString = State(initialValue: editingInstallation?.baseURL.absoluteString ?? "")

        var tokenString = ""
        if let tokenData = editingInstallation?.apiToken, let parsedString = String(data: tokenData, encoding: .utf8) {
            tokenString = parsedString
        }
        _apiToken = State(initialValue: tokenString)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(title)
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    isShowingHelp.toggle()
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Help")
                .help("Where to find these values")
                .popover(isPresented: $isShowingHelp, arrowEdge: .bottom) {
                    AddServerHelpView()
                }
            }

            Form {
                LabeledContent("Name *") {
                    TextField("Name *", text: $name, prompt: Text("e.g. Basement NAS"))
                        .focused($focusedField, equals: .name)
                        .labelsHidden()
                        .onChange(of: name) { _, newValue in
                            validationMessage = nil
                            if newValue.count > 100 { name = String(newValue.prefix(100)) }
                        }
                }

                LabeledContent("URL *") {
                    TextField("URL *", text: $urlString, prompt: Text("e.g. http://nas.local:8080"))
                        .focused($focusedField, equals: .url)
                        .textContentType(.URL)
                        .labelsHidden()
                        .onChange(of: urlString) { _, newValue in
                            validationMessage = nil
                            if newValue.count > 1024 { urlString = String(newValue.prefix(1024)) }
                        }
                }

                LabeledContent("API token (optional)") {
                    SecureField("API token (optional)", text: $apiToken, prompt: Text("Leave blank for most setups"))
                        .focused($focusedField, equals: .apiToken)
                        .labelsHidden()
                        .onChange(of: apiToken) { _, newValue in
                            validationMessage = nil
                            let filtered = String(newValue.prefix(4096)).removingControlCharacters()
                            if apiToken != filtered { apiToken = filtered }
                        }
                }
            }
            .formStyle(.grouped)
            .onSubmit {
                switch focusedField {
                case .name:
                    focusedField = .url
                case .url:
                    focusedField = .apiToken
                case .apiToken:
                    focusedField = nil
                    if isFormValid {
                        save()
                    }
                case nil:
                    break
                }
            }

            if let validationMessage {
                ErrorPanel(message: validationMessage)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(primaryButtonTitle) {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
                .help(!isFormValid ? "Name and URL are required" : "Save installation")
            }
        }
        .animation(.default, value: validationMessage)
        .padding(24)
        .frame(width: 460)
        .onAppear {
            focusedField = .name
        }
        .onAppear { self.didAppear?(self) }
    }

    internal var didAppear: ((Self) -> Void)?

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var title: String {
        editingInstallation == nil ? "Add Scrutiny Installation" : "Edit Scrutiny Installation"
    }

    private var primaryButtonTitle: String {
        editingInstallation == nil ? "Add" : "Save"
    }

    @MainActor private func save() {
        do {
            if let editingInstallation {
                try store.updateInstallation(
                    id: editingInstallation.id,
                    name: name,
                    baseURLString: urlString,
                    apiToken: apiToken
                )
            } else {
                try store.addInstallation(name: name, baseURLString: urlString, apiToken: apiToken)
            }

            dismiss()
            Task { await store.refreshSelected() }
        } catch {
            validationMessage = error.secureDescription
        }
    }
}
