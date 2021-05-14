
import UIKit

struct SettingsTemperatureViewModel {
    let temperatureMode: TemperatureMode
    
    var labelText: String {
        return temperatureMode == .celsius ? "Celsius" : "Fahrenhait"
    }
    
    var accessory: UITableViewCellAccessoryType {
        if UserDefaults.temperatureMode() == temperatureMode {
            return .checkmark
        }
        else {
            return .none
        }
    }
}

