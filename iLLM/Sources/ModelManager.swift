import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import Hub

@MainActor
class ModelManager: ObservableObject {
    @Published var isDownloading = false
    @Published var progress: Double = 0.0
    @Published var loadedContainer: ModelContainer?
    @Published var loadedModelId: String?
    
    private let hub = HubApi()

    func downloadModel(_ modelId: String) {
        isDownloading = true
        progress = 0.0
        
        Task {
            do {
                let configuration = ModelConfiguration(id: modelId)
                let container = try await LLMModelFactory.shared.loadContainer(configuration: configuration) { progress in
                    Task { @MainActor in
                        self.progress = progress.fractionCompleted
                    }
                }
                
                self.loadedContainer = container
                self.loadedModelId = modelId
                self.isDownloading = false
            } catch {
                print("Failed to download/load model: \(error)")
                self.isDownloading = false
            }
        }
    }
}
