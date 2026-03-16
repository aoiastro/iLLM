import Foundation
import FlyingFox
import MLX
import MLXLLM

@MainActor
class LLMServer: ObservableObject {
    @Published var isRunning = false {
        didSet {
            if isRunning {
                start()
            } else {
                stop()
            }
        }
    }

    private var server: HTTPServer?
    var modelContainer: ModelContainer?

    func start() {
        guard let container = modelContainer else {
            print("No model loaded")
            isRunning = false
            return
        }

        Task {
            let server = HTTPServer(port: 8080)
            self.server = server
            
            await server.appendRoute("/v1/chat/completions") { request in
                // Extremely simple mock-like but calling MLX
                let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any]
                let prompt = (body?["messages"] as? [[String: String]])?.last?["content"] ?? "Hello"
                
                let result = try await LLMModelFactory.shared.generate(
                    container: container,
                    configuration: container.configuration,
                    prompt: prompt
                ) { _ in 
                    // progress callback
                }
                
                let response: [String: Any] = [
                    "choices": [
                        [
                            "message": [
                                "role": "assistant",
                                "content": result.output
                            ]
                        ]
                    ]
                ]
                
                let data = try! JSONSerialization.data(withJSONObject: response)
                return HTTPResponse(statusCode: .ok, body: data)
            }
            
            do {
                try await server.start()
            } catch {
                print("Server error: \(error)")
                self.isRunning = false
            }
        }
    }

    func stop() {
        Task {
            await server?.stop()
            server = nil
        }
    }
}
