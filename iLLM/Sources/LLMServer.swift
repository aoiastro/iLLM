import Foundation
import Combine
import FlyingFox
import MLX
import MLXLLM
import MLXLMCommon
import Hub

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

    private var httpServer: HTTPServer?
    var modelContainer: ModelContainer?

    func start() {
        guard let container = modelContainer else {
            print("No model loaded")
            isRunning = false
            return
        }

        Task {
            let server = HTTPServer(port: 8080)
            self.httpServer = server
            
            await server.appendRoute("/v1/chat/completions") { (request: HTTPRequest) in
                let body = try? JSONSerialization.jsonObject(with: await request.bodyData) as? [String: Any]
                let prompt = (body?["messages"] as? [[String: String]])?.last?["content"] ?? "Hello"
                
                do {
                    let result = try await container.perform { context in
                        let promptTokens = context.tokenizer.encode(text: prompt)
                        return try MLXLMCommon.generate(
                            promptTokens: promptTokens,
                            parameters: GenerateParameters(),
                            model: context.model,
                            tokenizer: context.tokenizer
                        ) { _ in
                            return .more
                        }
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
                } catch {
                    return HTTPResponse(statusCode: .internalServerError, body: "Generation failed: \(error)".data(using: .utf8)!)
                }
            }
            
            do {
                try await server.run()
            } catch {
                print("Server error: \(error)")
                self.isRunning = false
            }
        }
    }

    func stop() {
        Task {
            await httpServer?.stop()
            httpServer = nil
        }
    }
}
