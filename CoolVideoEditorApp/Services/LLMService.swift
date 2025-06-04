import Foundation
import CoreML
import NaturalLanguage
import Vision
import PythonKit

class LLMService {
    private let model: MLModel
    private let tokenizer: NLTokenizer
    private let vocab: [String: Int]
    private let systemPrompt = """
    You are an expert video editor AI assistant specializing in music video editing.
    Your role is to analyze video content, audio patterns, and make creative decisions about editing.
    Consider visual flow, narrative structure, musical rhythm, and emotional impact in your decisions.
    Provide specific, actionable editing suggestions that can be parsed into concrete editing commands.
    """
    
    init() throws {
        // Download/convert model if not present
        try Self.ensureModelExists()
        
        // Initialize CoreML model
        let config = MLModelConfiguration()
        config.computeUnits = .all // Use all available compute units
        
        let modelURL = Bundle.main.url(forResource: "VideoEditor", withExtension: "mlmodelc")!
        self.model = try MLModel(contentsOf: modelURL, configuration: config)
        
        // Initialize tokenizer and load vocabulary
        self.tokenizer = NLTokenizer(unit: .word)
        self.vocab = try Self.loadVocabulary(from: model)
    }
    
    private static func loadVocabulary(from model: MLModel) throws -> [String: Int] {
        guard let vocabString = model.modelDescription.metadata[MLModelMetadataKey(rawValue: "tokenizer_vocab")] as? String,
              let vocabData = vocabString.data(using: String.Encoding.utf8) else {
            throw LLMError.invalidVocabulary
        }
        
        // Parse the vocabulary string back into a dictionary
        let vocabDict = try JSONSerialization.jsonObject(with: vocabData) as? [String: Int]
        return vocabDict ?? [:]
    }
    
    private static func ensureModelExists() throws {
        let modelName = "VideoEditor.mlmodelc"
        let modelURL = Bundle.main.bundleURL.appendingPathComponent("Resources/\(modelName)")
        
        if !FileManager.default.fileExists(atPath: modelURL.path) {
            print("🤖 Converting Phi-2 to CoreML format...")
            let scriptURL = Bundle.main.url(forResource: "download_model", withExtension: "sh")!
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path, modelURL.path]
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw LLMError.modelConversionFailed
            }
        }
    }
    
    private func tokenize(_ text: String) -> [Int] {
        tokenizer.string = text
        let tokens = tokenizer.tokens(for: text.startIndex..<text.endIndex)
        return tokens.map { token in
            let word = String(text[token])
            return vocab[word] ?? vocab["<unk>"] ?? 0
        }
    }
    
    private func generateResponse(for prompt: String) async throws -> String {
        let fullPrompt = systemPrompt + "\n\n" + prompt
        let tokens = tokenize(fullPrompt)
        
        // Prepare model input
        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32)
        tokens.enumerated().forEach { i, token in
            inputArray[i] = NSNumber(value: token)
        }
        
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": inputArray
        ])
        
        // Generate response
        let prediction = try model.prediction(from: input)
        
        guard let outputLogits = prediction.featureValue(for: "output_logits")?.multiArrayValue else {
            throw LLMError.invalidResponse
        }
        
        // Convert logits to tokens and then to text
        return try decodeResponse(from: outputLogits)
    }
    
    private func decodeResponse(from logits: MLMultiArray) throws -> String {
        var response = ""
        let vocabSize = vocab.count
        
        // For each position in the sequence
        for i in 0..<logits.shape[1].intValue {
            var maxProb = Float(-1000000)
            var bestToken = 0
            
            // Find the token with highest probability
            for j in 0..<vocabSize {
                let prob = logits[[0, i, j] as [NSNumber]].floatValue
                if prob > maxProb {
                    maxProb = prob
                    bestToken = j
                }
            }
            
            // Convert token ID back to text
            if let word = vocab.first(where: { $0.value == bestToken })?.key {
                response += word + " "
            }
        }
        
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func interpret(_ content: String) async throws -> EditingInterpretation {
        let prompt = """
        [INST]
        Analyze this editing content and provide specific recommendations:
        \(content)
        
        Format your response as JSON with the following structure:
        {
            "moodAnalysis": {
                "currentMood": "energetic|calm|tense|emotional|neutral",
                "suggestedMood": "energetic|calm|tense|emotional|neutral",
                "confidence": 0.0-1.0
            },
            "editingRecommendations": [
                {
                    "type": "pacing|transition|effect|scene",
                    "description": "string",
                    "priority": 1-5,
                    "timing": "start|middle|end|throughout"
                }
            ],
            "narrativeStructure": {
                "suggestedFlow": ["string"],
                "keyMoments": [{"timestamp": "float", "importance": 1-5}]
            }
        }
        [/INST]
        """
        
        let response = try await generateResponse(for: prompt)
        return try parseInterpretation(from: response)
    }
    
    func analyze(_ context: String) async throws -> EditingStrategy {
        let prompt = """
        [INST]
        Create a detailed editing strategy based on this context:
        \(context)
        
        Format your response as JSON with the following structure:
        {
            "strategy": {
                "overallApproach": "string",
                "pacing": {
                    "start": 0.0-1.0,
                    "middle": 0.0-1.0,
                    "end": 0.0-1.0
                },
                "transitions": [
                    {
                        "type": "string",
                        "timing": "float",
                        "duration": "float"
                    }
                ],
                "effects": [
                    {
                        "type": "string",
                        "intensity": 0.0-1.0,
                        "timing": "float"
                    }
                ]
            },
            "reasoning": {
                "pacingChoice": "string",
                "transitionLogic": "string",
                "effectConsiderations": "string"
            }
        }
        [/INST]
        """
        
        let response = try await generateResponse(for: prompt)
        return try parseStrategy(from: response)
    }
    
    func createEditMonitor(_ instructions: String) async throws -> EditMonitor {
        let prompt = """
        [INST]
        Monitor and provide real-time editing adjustments based on these instructions:
        \(instructions)
        
        You will receive progress updates and should respond with JSON-formatted adjustment suggestions:
        {
            "adjustment": {
                "type": "pacing|transition|effect|reorder",
                "value": "float or specific instruction",
                "reason": "string",
                "urgency": 1-5
            }
        }
        [/INST]
        """
        
        // Create a monitoring session
        let monitor = EditMonitor(
            llm: self,
            initialPrompt: prompt,
            context: instructions
        )
        
        return monitor
    }
    
    class EditMonitor {
        private let llm: LLMService
        private let initialPrompt: String
        private let context: String
        private var history: [(progress: Double, scene: Int)] = []
        
        init(llm: LLMService, initialPrompt: String, context: String) {
            self.llm = llm
            self.initialPrompt = initialPrompt
            self.context = context
        }
        
        func checkProgress(progress: Double, currentScene: Int) async throws -> EditAdjustment? {
            history.append((progress: progress, scene: currentScene))
            
            let prompt = """
            [INST]
            Current progress: \(progress)
            Current scene: \(currentScene)
            
            Previous states:
            \(history.map { "Progress: \($0.progress), Scene: \($0.scene)" }.joined(separator: "\n"))
            
            Based on the editing instructions and progress, suggest any necessary adjustments.
            If no adjustments are needed, respond with {"adjustment": null}
            [/INST]
            """
            
            let response = try await llm.generateResponse(for: prompt)
            return try llm.parseAdjustment(from: response)
        }
    }
    
    // MARK: - Response Parsing
    
    private func parseInterpretation(from response: String) throws -> EditingInterpretation {
        guard let jsonStart = response.range(of: "{")?.lowerBound,
              let jsonEnd = response.range(of: "}", options: .backwards)?.upperBound,
              let data = response[jsonStart..<jsonEnd].data(using: .utf8) else {
            throw LLMError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(EditingInterpretation.self, from: data)
    }
    
    private func parseStrategy(from response: String) throws -> EditingStrategy {
        guard let jsonStart = response.range(of: "{")?.lowerBound,
              let jsonEnd = response.range(of: "}", options: .backwards)?.upperBound,
              let data = response[jsonStart..<jsonEnd].data(using: .utf8) else {
            throw LLMError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(EditingStrategy.self, from: data)
    }
    
    private func parseAdjustment(from response: String) throws -> EditAdjustment? {
        guard let jsonStart = response.range(of: "{")?.lowerBound,
              let jsonEnd = response.range(of: "}", options: .backwards)?.upperBound,
              let data = response[jsonStart..<jsonEnd].data(using: .utf8) else {
            throw LLMError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(AdjustmentResponse.self, from: data).adjustment
    }
    
    enum LLMError: Error {
        case invalidResponse
        case processingError(String)
        case modelConversionFailed
        case invalidVocabulary
    }
} 