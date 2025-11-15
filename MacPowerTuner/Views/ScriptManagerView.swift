import SwiftUI

struct SavedScript: Identifiable, Codable {
    let id: UUID
    var name: String
    var content: String

    init(id: UUID = UUID(), name: String, content: String) {
        self.id = id
        self.name = name
        self.content = content
    }
}

struct ScriptManagerView: View {
    @EnvironmentObject var activityLog: ActivityLog
    @EnvironmentObject var notificationManager: NotificationManager

    @State private var savedScripts: [SavedScript] = []
    @State private var selectedScript: SavedScript?
    @State private var scriptName = ""
    @State private var scriptContent = ""
    @State private var executionOutput = ""
    @State private var isExecuting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionCard(title: "Script Editor", icon: "doc.text") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("Script name", text: $scriptName)
                            .textFieldStyle(.roundedBorder)

                        Button(action: saveScript) {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .disabled(scriptName.isEmpty || scriptContent.isEmpty)

                        Button(action: newScript) {
                            Label("New", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(.bordered)
                    }

                    TextEditor(text: $scriptContent)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 200)
                        .border(Color.secondary.opacity(0.3))

                    HStack {
                        Button(action: executeScript) {
                            Label(isExecuting ? "Executing..." : "Execute Script", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(scriptContent.isEmpty || isExecuting)

                        if isExecuting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }

                        Spacer()

                        Text("Tip: Scripts run in /bin/sh")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            SectionCard(title: "Saved Scripts", icon: "folder") {
                VStack(alignment: .leading, spacing: 12) {
                    if savedScripts.isEmpty {
                        Text("No saved scripts yet")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(savedScripts) { script in
                                    HStack {
                                        Button(action: {
                                            loadScript(script)
                                        }) {
                                            HStack {
                                                Image(systemName: "doc.text")
                                                Text(script.name)
                                                Spacer()
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .padding(8)
                                        .background(selectedScript?.id == script.id ? Color.accentColor.opacity(0.2) : Color.clear)
                                        .cornerRadius(6)

                                        Button(action: {
                                            deleteScript(script)
                                        }) {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                        .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        .frame(height: 150)
                    }
                }
            }

            SectionCard(title: "Execution Output", icon: "terminal") {
                VStack(alignment: .leading, spacing: 12) {
                    if executionOutput.isEmpty {
                        Text("No output yet")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ScrollView {
                            Text(executionOutput)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 150)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)

                        Button(action: {
                            executionOutput = ""
                        }) {
                            Label("Clear Output", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Spacer()
        }
        .onAppear(perform: loadSavedScripts)
    }

    private func newScript() {
        scriptName = ""
        scriptContent = ""
        selectedScript = nil
        executionOutput = ""
    }

    private func saveScript() {
        let script = SavedScript(name: scriptName, content: scriptContent)

        if let index = savedScripts.firstIndex(where: { $0.id == selectedScript?.id }) {
            // Update existing
            savedScripts[index] = script
        } else {
            // Add new
            savedScripts.append(script)
        }

        selectedScript = script
        saveToDisk()
        activityLog.log("Script '\(scriptName)' saved", type: .success)
        notificationManager.showSuccess(message: "Script saved successfully")
    }

    private func loadScript(_ script: SavedScript) {
        selectedScript = script
        scriptName = script.name
        scriptContent = script.content
    }

    private func deleteScript(_ script: SavedScript) {
        savedScripts.removeAll { $0.id == script.id }
        if selectedScript?.id == script.id {
            newScript()
        }
        saveToDisk()
        activityLog.log("Script '\(script.name)' deleted", type: .info)
    }

    private func executeScript() {
        isExecuting = true
        executionOutput = "Executing...\n"

        Task {
            do {
                let output = try await CommandExecutor.shared.execute("/bin/sh", arguments: ["-c", scriptContent])
                DispatchQueue.main.async {
                    executionOutput = output.isEmpty ? "Script executed successfully (no output)" : output
                    isExecuting = false
                }
                activityLog.log("Script executed successfully", type: .success)
            } catch {
                DispatchQueue.main.async {
                    executionOutput = "Error: \(error.localizedDescription)"
                    isExecuting = false
                }
                activityLog.log("Script execution failed: \(error.localizedDescription)", type: .error)
                notificationManager.showError(message: "Script execution failed")
            }
        }
    }

    private func loadSavedScripts() {
        if let data = UserDefaults.standard.data(forKey: "SavedScripts"),
           let scripts = try? JSONDecoder().decode([SavedScript].self, from: data) {
            savedScripts = scripts
        }
    }

    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(savedScripts) {
            UserDefaults.standard.set(data, forKey: "SavedScripts")
        }
    }
}

#Preview {
    ScriptManagerView()
        .environmentObject(ActivityLog())
        .environmentObject(NotificationManager())
        .frame(width: 700)
}
