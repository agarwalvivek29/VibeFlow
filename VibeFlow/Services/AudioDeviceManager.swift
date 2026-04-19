//
//  AudioDeviceManager.swift
//  VibeFlow
//
//  CoreAudio helper for enumerating and resolving audio input devices.
//

import Foundation
#if os(macOS)
import CoreAudio
#endif

struct AudioInputDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let sampleRate: Float64

    func hash(into hasher: inout Hasher) { hasher.combine(uid) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.uid == rhs.uid }
}

enum AudioDeviceManager {

    #if os(macOS)

    // MARK: - List Input Devices

    static func listInputDevices() -> [AudioInputDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &dataSize
        )
        guard status == noErr, dataSize > 0 else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &dataSize, &deviceIDs
        )
        guard status == noErr else { return [] }

        return deviceIDs.compactMap { deviceID -> AudioInputDevice? in
            guard hasInputStreams(deviceID) else { return nil }
            let uid = getDeviceUID(deviceID)
            let name = getDeviceName(deviceID)
            let rate = getDeviceSampleRate(deviceID)
            guard !uid.isEmpty else { return nil }
            return AudioInputDevice(id: deviceID, uid: uid, name: name, sampleRate: rate)
        }
    }

    // MARK: - Default Input Device

    static func getDefaultInputDevice() -> AudioInputDevice? {
        var deviceID: AudioDeviceID = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != 0 else { return nil }

        let uid = getDeviceUID(deviceID)
        let name = getDeviceName(deviceID)
        let rate = getDeviceSampleRate(deviceID)
        return AudioInputDevice(id: deviceID, uid: uid, name: name, sampleRate: rate)
    }

    // MARK: - Resolve UID → DeviceID

    /// Returns the AudioDeviceID for a given UID, or nil if not found.
    static func resolveDeviceID(uid: String?) -> AudioDeviceID? {
        guard let uid, !uid.isEmpty else { return nil }
        let devices = listInputDevices()
        return devices.first(where: { $0.uid == uid })?.id
    }

    // MARK: - Private Helpers

    private static func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        guard status == noErr, size > 0 else { return false }

        // Allocate the exact size CoreAudio needs (AudioBufferList is variable-length)
        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawPointer.deallocate() }
        let bufferListPointer = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        let getStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, bufferListPointer)
        guard getStatus == noErr else { return false }

        let bufferList = bufferListPointer.pointee
        return bufferList.mNumberBuffers > 0 && bufferList.mBuffers.mNumberChannels > 0
    }

    private static func getDeviceUID(_ deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid)
        return uid as String
    }

    private static func getDeviceName(_ deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        return name as String
    }

    private static func getDeviceSampleRate(_ deviceID: AudioDeviceID) -> Float64 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rate)
        if status != noErr || rate <= 0 {
            // Try global scope as fallback (some devices report rate there)
            address.mScope = kAudioObjectPropertyScopeGlobal
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rate)
        }
        return rate > 0 ? rate : 48000
    }

    #else

    static func listInputDevices() -> [AudioInputDevice] { [] }
    static func getDefaultInputDevice() -> AudioInputDevice? { nil }
    static func resolveDeviceID(uid: String?) -> AudioDeviceID? { nil }

    #endif
}
