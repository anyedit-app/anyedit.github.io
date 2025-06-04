import Foundation

struct EditingInterpretation: Codable {
    let moodAnalysis: MoodAnalysis
    let editingRecommendations: [EditingRecommendation]
    let narrativeStructure: NarrativeStructure
    
    struct MoodAnalysis: Codable {
        let currentMood: VideoMood
        let suggestedMood: VideoMood
        let confidence: Double
    }
    
    struct EditingRecommendation: Codable {
        let type: RecommendationType
        let description: String
        let priority: Int
        let timing: TimingType
        
        enum RecommendationType: String, Codable {
            case pacing, transition, effect, scene
        }
        
        enum TimingType: String, Codable {
            case start, middle, end, throughout
        }
    }
    
    struct NarrativeStructure: Codable {
        let suggestedFlow: [String]
        let keyMoments: [KeyMoment]
        
        struct KeyMoment: Codable {
            let timestamp: Double
            let importance: Int
        }
    }
}

struct EditingStrategy: Codable {
    let strategy: Strategy
    let reasoning: Reasoning
    
    struct Strategy: Codable {
        let overallApproach: String
        let pacing: PacingStrategy
        let transitions: [TransitionStrategy]
        let effects: [EffectStrategy]
        
        struct PacingStrategy: Codable {
            let start: Double
            let middle: Double
            let end: Double
        }
        
        struct TransitionStrategy: Codable {
            let type: String
            let timing: Double
            let duration: Double
        }
        
        struct EffectStrategy: Codable {
            let type: String
            let intensity: Double
            let timing: Double
        }
    }
    
    struct Reasoning: Codable {
        let pacingChoice: String
        let transitionLogic: String
        let effectConsiderations: String
    }
}

struct EditAdjustment: Codable {
    let type: AdjustmentType
    let value: String
    let reason: String
    let urgency: Int
    
    enum AdjustmentType: String, Codable {
        case pacing, transition, effect, reorder
    }
}

struct AdjustmentResponse: Codable {
    let adjustment: EditAdjustment?
}

enum VideoMood: String, Codable {
    case energetic
    case calm
    case tense
    case emotional
    case neutral
}

struct Scene: Codable {
    let timeRange: TimeRange
    let dominantColors: [Color]
    let sceneType: String
    let objects: [String]
    let movement: Double
    let emotionalScore: Double
    
    struct TimeRange: Codable {
        let start: Double
        let duration: Double
    }
    
    struct Color: Codable {
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
    }
}

struct Transition: Codable {
    let type: TransitionType
    let duration: Double
    let parameters: [String: Double]
    
    enum TransitionType: String, Codable {
        case crossDissolve
        case fade
        case wipe
        case push
        case custom
    }
}

struct Effect: Codable {
    let type: EffectType
    let startTime: Double
    let duration: Double
    let parameters: [String: Double]
    
    enum EffectType: String, Codable {
        case colorGrade
        case blur
        case zoom
        case speed
        case custom
    }
} 