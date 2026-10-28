import Foundation

public final class LocalPremium {
    private static let key = "TelegramLegacy_LocalPremiumEnabled"
    
    public static var isEnabled: Bool {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: key) == nil {
                return true
            }
            return defaults.bool(forKey: key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
    
    public static func override(_ value: Bool) -> Bool {
        if isEnabled {
            return true
        }
        return value
    }
}
