import Foundation

struct ClutchEvent: Identifiable, Codable {
    let id:           UUID
    let timestamp:    Date
    let deviceName:   String
    let volumeAtSave: Float       // 0.0 – 1.0
    let frontmostApp: String      // "Spotify", "Discord", etc.
    let mode:         Mode
    let riskScore:    Int         // 0–100

    var riskLabel: String {
        switch riskScore {
        case 80...100: return "crisis"
        case 50...79:  return "awkward"
        default:       return "mild"
        }
    }

    var volumePercent: Int {
        Int(volumeAtSave * 100)
    }
}

enum RiskCalculator {

    /// Computes a 0–100 cringe score based on context
    static func score(volume: Float, hour: Int) -> Int {
        var score = Int(volume * 60)  // volume contributes up to 60 pts

        // Late night multiplier
        let lateNight = (hour >= 23 || hour <= 4)
        if lateNight { score += 25 }

        // Morning silence window
        let earlyMorning = (hour >= 5 && hour <= 7)
        if earlyMorning { score += 15 }

        return min(score, 100)
    }
}
