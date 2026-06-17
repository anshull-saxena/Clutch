import CoreAudio
import Combine
import Foundation

final class AudioDeviceMonitor: ObservableObject {

    static let shared = AudioDeviceMonitor()

    // Publisher that fires with the disconnected device info
    let headphonesDisconnected = PassthroughSubject<AudioDeviceInfo, Never>()
    let headphonesConnected    = PassthroughSubject<AudioDeviceInfo, Never>()

    private var knownDevices: Set<AudioDeviceID> = []
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var cachedDeviceInfo: [AudioDeviceID: AudioDeviceInfo] = [:]

    private init() {}

    func startMonitoring() {
        // Snapshot current devices
        knownDevices = Set(getAllOutputDeviceIDs())
        refreshDeviceCache()

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )

        listenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.handleDeviceListChange()
            }
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.global(qos: .userInteractive),
            listenerBlock!
        )
    }

    func stopMonitoring() {
        guard let block = listenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.global(qos: .userInteractive),
            block
        )
    }

    private func handleDeviceListChange() {
        let current = Set(getAllOutputDeviceIDs())
        let removed = knownDevices.subtracting(current)
        let added   = current.subtracting(knownDevices)

        for deviceID in removed {
            // Device was present, now gone — check if it was headphones
            // We must check against our cached info since the device is gone
            if let info = cachedDeviceInfo[deviceID],
               DeviceClassifier.isHeadphoneDevice(info) {
                headphonesDisconnected.send(info)
            }
        }

        for deviceID in added {
            if let info = getDeviceInfo(deviceID),
               DeviceClassifier.isHeadphoneDevice(info) {
                headphonesConnected.send(info)
            }
        }

        // Update snapshot and cache
        knownDevices = current
        refreshDeviceCache()
    }

    private func refreshDeviceCache() {
        cachedDeviceInfo.removeAll()
        for deviceID in knownDevices {
            if let info = getDeviceInfo(deviceID) {
                cachedDeviceInfo[deviceID] = info
            }
        }
    }

    // MARK: - CoreAudio helpers

    private func getAllOutputDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        )
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs
        )
        return deviceIDs.filter { hasOutputStream($0) }
    }

    private func hasOutputStream(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let err = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        return err == noErr && dataSize > 0
    }

    private func getDeviceInfo(_ deviceID: AudioDeviceID) -> AudioDeviceInfo? {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var nameRef: CFString? = nil
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        
        let nameErr = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &dataSize, &nameRef)
        
        var transportAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transportType: UInt32 = 0
        dataSize = UInt32(MemoryLayout<UInt32>.size)
        
        let transportErr = AudioObjectGetPropertyData(deviceID, &transportAddress, 0, nil, &dataSize, &transportType)
        
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uidRef: CFString? = nil
        dataSize = UInt32(MemoryLayout<CFString?>.size)
        
        let uidErr = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &dataSize, &uidRef)
        
        if nameErr == noErr, transportErr == noErr, uidErr == noErr,
           let name = nameRef as String?, let uid = uidRef as String? {
            return AudioDeviceInfo(deviceID: deviceID, name: name, transportType: transportType, uid: uid)
        }
        
        return nil
    }
}
