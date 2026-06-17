import CoreAudio
import IOKit

struct AudioDeviceInfo {
    let deviceID: AudioDeviceID
    let name: String
    let transportType: UInt32
    let uid: String
}

enum DeviceClassifier {

    /// Returns true if the device is a headphone/earphone (wired or wireless)
    static func isHeadphoneDevice(_ info: AudioDeviceInfo) -> Bool {
        let headphoneTransports: Set<UInt32> = [
            kAudioDeviceTransportTypeUSB,       // USB DAC / USB-C headphones
            kAudioDeviceTransportTypeBluetooth, // AirPods, BT headphones
            kAudioDeviceTransportTypeBluetoothLE,
            kAudioDeviceTransportTypeBuiltIn,   // 3.5mm on older Macs (with port)
            kAudioDeviceTransportTypeThunderbolt
        ]

        // Exclude virtual/aggregate devices
        if info.transportType == kAudioDeviceTransportTypeVirtual { return false }
        if info.transportType == kAudioDeviceTransportTypeAggregate { return false }

        // Built-in speakers are NOT headphones; built-in headphone jack IS
        if info.transportType == kAudioDeviceTransportTypeBuiltIn {
            return info.name.lowercased().contains("headphone") ||
                   info.uid.lowercased().contains("headphone")
        }

        return headphoneTransports.contains(info.transportType)
    }
}
