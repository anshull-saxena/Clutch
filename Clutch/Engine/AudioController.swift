import CoreAudio
import AudioToolbox

final class AudioController {

    static let shared = AudioController()
    private let audioQueue = DispatchQueue(label: "com.clutch.audio")
    private init() {}

    private var prePlugVolume: Float = 0.5
    private var wasMuted: Bool = false

    private var isMonitoringPlayback = false
    private var playbackListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var currentMonitoredDevice: AudioDeviceID?

    // MARK: - Public interface

    func muteOnUnplug() {
        audioQueue.sync {
            let defaultDevice = getDefaultOutputDevice()
            wasMuted = getMuted(for: defaultDevice)

            guard !wasMuted else { return }

            setMuted(true, for: defaultDevice)
        }
    }

    func muteInput() {
        audioQueue.sync {
            let inputDevice = getDefaultInputDevice()
            var val: UInt32 = 1
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope:    kAudioDevicePropertyScopeInput,
                mElement:  kAudioObjectPropertyElementMain
            )
            AudioObjectSetPropertyData(
                inputDevice, &address, 0, nil,
                UInt32(MemoryLayout<UInt32>.size), &val
            )
        }
    }

    func restoreOnPlug() {
        let autoRestore = UserDefaults.standard.object(forKey: UDKeys.autoRestoreAudio) as? Bool ?? true
        guard autoRestore else { return }

        audioQueue.sync {
            guard !wasMuted else { return }

            let defaultDevice = getDefaultOutputDevice()
            setMuted(false, for: defaultDevice)
        }
    }

    func currentVolume() -> Float {
        audioQueue.sync {
            getVolume(for: getDefaultOutputDevice())
        }
    }

    // MARK: - CoreAudio primitives

    private func getDefaultOutputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID
        )
        return deviceID
    }

    private func getDefaultInputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceID
        )
        return deviceID
    }

    private func getVolume(for deviceID: AudioDeviceID) -> Float {
        var volume: Float32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &volume)
        return volume
    }

    private func setVolume(_ volume: Float, for deviceID: AudioDeviceID) {
        var vol = Float32(volume)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            deviceID, &address, 0, nil,
            UInt32(MemoryLayout<Float32>.size), &vol
        )
    }

    private func getMuted(for deviceID: AudioDeviceID) -> Bool {
        var muted: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &muted)
        return muted != 0
    }

    private func setMuted(_ muted: Bool, for deviceID: AudioDeviceID) {
        var val = UInt32(muted ? 1 : 0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            deviceID, &address, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &val
        )
    }

    // MARK: - Playback Monitoring for Parent Zone

    func updatePlaybackMonitoring(mode: Mode? = nil) {
        guard let mode else { return }
        let needsMonitoring = (mode == .parentZone)

        audioQueue.async { [weak self] in
            guard let self else { return }
            if needsMonitoring {
                if !self.isMonitoringPlayback {
                    self.setupPlaybackListener()
                }
            } else if self.isMonitoringPlayback {
                self.removePlaybackListener()
            }
        }
    }

    private func setupPlaybackListener() {
        let device = getDefaultOutputDevice()
        if device == kAudioObjectUnknown { return }

        currentMonitoredDevice = device
        isMonitoringPlayback = true

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )

        playbackListenerBlock = { [weak self] _, _ in
            self?.audioQueue.async {
                self?.handlePlaybackStateChange()
            }
        }

        let status = AudioObjectAddPropertyListenerBlock(
            device,
            &address,
            audioQueue,
            playbackListenerBlock!
        )
        if status != noErr {
            print("Error registering playback listener: \(status)")
        }

        if defaultDeviceListenerBlock == nil {
            setupDefaultDeviceListener()
        }
    }

    private func removePlaybackListener(onlyDevice: Bool = false) {
        guard let device = currentMonitoredDevice, let block = playbackListenerBlock else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListenerBlock(
            device,
            &address,
            audioQueue,
            block
        )

        currentMonitoredDevice = nil
        playbackListenerBlock = nil

        if !onlyDevice {
            isMonitoringPlayback = false
            removeDefaultDeviceListener()
        }
    }

    private func setupDefaultDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )

        defaultDeviceListenerBlock = { [weak self] _, _ in
            self?.audioQueue.async {
                self?.handleDefaultDeviceChange()
            }
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            audioQueue,
            defaultDeviceListenerBlock!
        )
    }

    private func removeDefaultDeviceListener() {
        guard let block = defaultDeviceListenerBlock else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            audioQueue,
            block
        )
        defaultDeviceListenerBlock = nil
    }

    private func handleDefaultDeviceChange() {
        guard isMonitoringPlayback else { return }
        removePlaybackListener(onlyDevice: true)
        setupPlaybackListener()
    }

    private func handlePlaybackStateChange() {
        guard let device = currentMonitoredDevice else { return }
        var isRunning: UInt32 = 0
        var isRunningSize = UInt32(MemoryLayout<UInt32>.size)
        var isRunningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            device,
            &isRunningAddress,
            0,
            nil,
            &isRunningSize,
            &isRunning
        )

        if status == noErr && isRunning == 1 {
            DispatchQueue.main.async {
                ModeManager.shared.triggerParentZoneHeadsUpIfNeeded()
            }
        }
    }
}
