import SwiftUI

struct ContentView: View {
    @StateObject private var modelManager = ModelManager()
    @StateObject private var server = LLMServer()
    @State private var modelId = "mlx-community/Llama-3.2-1B-Instruct-4bit"

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Model Management")) {
                    HStack {
                        TextField("Hugging Face ID", text: $modelId)
                        Button("Download") {
                            modelManager.downloadModel(modelId)
                        }
                    }
                    if modelManager.isDownloading {
                        ProgressView("Downloading...", value: modelManager.progress)
                    }
                    if let container = modelManager.loadedContainer {
                        Text("Loaded: \(container.configuration.id)")
                            .font(.caption)
                    }
                }

                Section(header: Text("Server Status")) {
                    Toggle("Server Running", isOn: $server.isRunning)
                        .disabled(modelManager.loadedContainer == nil)
                    if server.isRunning {
                        Text("API reachable at http://localhost:8080")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if modelManager.loadedContainer == nil {
                        Text("Please load a model first")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("iLLM Server")
            .onChange(of: modelManager.loadedContainer) { newContainer in
                server.modelContainer = newContainer
            }
        }
    }
}
