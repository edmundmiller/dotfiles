import CoreAudio
import Foundation

let targetUID = "AppleUSBAudioEngine:DJI Technology Co., Ltd.:Wireless Mic Rx:XSP12345678B:3"

func propertyString(_ objectID: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var value: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    let status = withUnsafeMutablePointer(to: &value) {
        AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, $0)
    }
    return status == noErr ? value as String : nil
}

func allAudioDevices() throws -> [AudioDeviceID] {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &size
    ) == noErr else {
        throw NSError(domain: "ReceiverMute", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Unable to enumerate CoreAudio devices"
        ])
    }

    var devices = [AudioDeviceID](
        repeating: 0,
        count: Int(size) / MemoryLayout<AudioDeviceID>.size
    )
    guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &size,
        &devices
    ) == noErr else {
        throw NSError(domain: "ReceiverMute", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Unable to read CoreAudio device list"
        ])
    }
    return devices
}

func receiver() throws -> AudioDeviceID {
    guard let device = try allAudioDevices().first(where: {
        propertyString($0, kAudioDevicePropertyDeviceUID) == targetUID
    }) else {
        throw NSError(domain: "ReceiverMute", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Target Wireless Mic Rx UID is not connected"
        ])
    }
    return device
}

func muteAddress() -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioObjectPropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )
}

func readMute(_ device: AudioDeviceID) throws -> Bool {
    var address = muteAddress()
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
        throw NSError(domain: "ReceiverMute", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "Unable to read receiver input mute"
        ])
    }
    return value != 0
}

func writeMute(_ muted: Bool, to device: AudioDeviceID) throws {
    var address = muteAddress()
    var value: UInt32 = muted ? 1 : 0
    let size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr else {
        throw NSError(domain: "ReceiverMute", code: 5, userInfo: [
            NSLocalizedDescriptionKey: "Unable to set receiver input mute"
        ])
    }
}

do {
    let device = try receiver()
    let command = CommandLine.arguments.dropFirst().first ?? "status"
    let before = try readMute(device)

    switch command {
    case "status":
        break
    case "toggle":
        try writeMute(!before, to: device)
    case "on":
        try writeMute(true, to: device)
    case "off":
        try writeMute(false, to: device)
    default:
        throw NSError(domain: "ReceiverMute", code: 6, userInfo: [
            NSLocalizedDescriptionKey: "Usage: receiver-mute [status|toggle|on|off]"
        ])
    }

    let after = try readMute(device)
    print("device=\(device) uid=\(targetUID) mute=\(after ? "on" : "off")")
} catch {
    fputs("receiver-mute: \(error.localizedDescription)\n", stderr)
    exit(1)
}
