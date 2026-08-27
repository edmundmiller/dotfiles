import CoreAudio
import Darwin
import Dispatch
import Foundation

typealias ReceiverDeviceID = AudioDeviceID

let targetUID = "AppleUSBAudioEngine:DJI Technology Co., Ltd.:Wireless Mic Rx:XSP12345678B:3"
let targetName = "Wireless Mic Rx"
let targetManufacturer = "DJI Technology Co., Ltd."
let mutedFeedbackPath = "/System/Library/Sounds/Basso.aiff"
let liveFeedbackPath = "/System/Library/Sounds/Tink.aiff"

enum ReceiverMuteError: LocalizedError {
    case unableToEnumerateDevices
    case unableToReadDeviceList
    case missingReceiver
    case ambiguousReceiver
    case unexpectedReceiverIdentity
    case unableToReadMute
    case unableToSetMute
    case readbackTimedOut
    case transitionMismatch
    case unableToOpenLock
    case unableToAcquireLock
    case usage

    var errorDescription: String? {
        switch self {
        case .unableToEnumerateDevices:
            "Unable to enumerate CoreAudio devices"
        case .unableToReadDeviceList:
            "Unable to read CoreAudio device list"
        case .missingReceiver:
            "Target Wireless Mic Rx UID is not connected"
        case .ambiguousReceiver:
            "Target Wireless Mic Rx UID is ambiguous"
        case .unexpectedReceiverIdentity:
            "Target Wireless Mic Rx identity does not match"
        case .unableToReadMute:
            "Unable to read receiver input mute"
        case .unableToSetMute:
            "Unable to set receiver input mute"
        case .readbackTimedOut:
            "Timed out reading receiver input mute"
        case .transitionMismatch:
            "Receiver input mute did not transition"
        case .unableToOpenLock:
            "Unable to open receiver mute lock"
        case .unableToAcquireLock:
            "Unable to acquire receiver mute lock"
        case .usage:
            "Usage: receiver-mute [status|toggle|on|off]"
        }
    }
}

protocol ReceiverAudio {
    func receiver() throws -> ReceiverDeviceID
    func readMute(_ device: ReceiverDeviceID) throws -> Bool
    func writeMute(_ muted: Bool, to device: ReceiverDeviceID) throws
    func readMuteUntil(
        _ expected: Bool,
        device: ReceiverDeviceID,
        timeoutMilliseconds: Int
    ) throws -> Bool
}

protocol MuteFeedback {
    func play(path: String) throws
}

protocol ReceiverMuteLocking {
    func lock() throws
    func unlock()
}

struct CoreAudioReceiver: ReceiverAudio {
    private func propertyString(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector
    ) -> String? {
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

    private func allAudioDevices() throws -> [AudioDeviceID] {
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
            throw ReceiverMuteError.unableToEnumerateDevices
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
            throw ReceiverMuteError.unableToReadDeviceList
        }
        return devices
    }

    func receiver() throws -> ReceiverDeviceID {
        let matches = try allAudioDevices().filter {
            propertyString($0, kAudioDevicePropertyDeviceUID) == targetUID
        }
        guard !matches.isEmpty else {
            throw ReceiverMuteError.missingReceiver
        }
        guard matches.count == 1, let device = matches.first else {
            throw ReceiverMuteError.ambiguousReceiver
        }
        guard
            propertyString(device, kAudioObjectPropertyName) == targetName,
            propertyString(device, kAudioObjectPropertyManufacturer) == targetManufacturer
        else {
            throw ReceiverMuteError.unexpectedReceiverIdentity
        }
        return device
    }

    private func muteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    func readMute(_ device: ReceiverDeviceID) throws -> Bool {
        var address = muteAddress()
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
            throw ReceiverMuteError.unableToReadMute
        }
        return value != 0
    }

    func writeMute(_ muted: Bool, to device: ReceiverDeviceID) throws {
        var address = muteAddress()
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectSetPropertyData(device, &address, 0, nil, size, &value) == noErr else {
            throw ReceiverMuteError.unableToSetMute
        }
    }

    func readMuteUntil(
        _ expected: Bool,
        device: ReceiverDeviceID,
        timeoutMilliseconds: Int
    ) throws -> Bool {
        let timeoutNanoseconds = UInt64(timeoutMilliseconds) * 1_000_000
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        var current = try readMute(device)

        while current != expected {
            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadline else {
                break
            }
            let remainingNanoseconds = deadline - now
            let sleepMicroseconds = min(10_000, remainingNanoseconds / 1_000)
            if sleepMicroseconds > 0 {
                usleep(useconds_t(sleepMicroseconds))
            }
            current = try readMute(device)
        }

        guard current == expected else {
            throw ReceiverMuteError.readbackTimedOut
        }
        return current
    }
}

final class AdvisoryReceiverMuteLock: ReceiverMuteLocking {
    private let lockPath: String
    private var descriptor: Int32 = -1

    init(lockPath: String = "/tmp/dji-mic-mini-receiver-mute.lock") {
        self.lockPath = lockPath
    }

    func lock() throws {
        let opened = Darwin.open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard opened >= 0 else {
            throw ReceiverMuteError.unableToOpenLock
        }
        guard Darwin.lockf(opened, F_LOCK, 0) == 0 else {
            Darwin.close(opened)
            throw ReceiverMuteError.unableToAcquireLock
        }
        descriptor = opened
    }

    func unlock() {
        guard descriptor >= 0 else {
            return
        }
        Darwin.lockf(descriptor, F_ULOCK, 0)
        Darwin.close(descriptor)
        descriptor = -1
    }

    deinit {
        unlock()
    }
}

struct AfplayMuteFeedback: MuteFeedback {
    func play(path: String) throws {
        let player = Process()
        player.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        player.arguments = [path]
        try player.run()
    }
}

private func verifiedToggle(
    audio: ReceiverAudio,
    feedback: MuteFeedback,
    lock: ReceiverMuteLocking
) throws -> (device: ReceiverDeviceID, muted: Bool) {
    let transition = try { () throws -> (device: ReceiverDeviceID, muted: Bool) in
        try lock.lock()
        defer { lock.unlock() }

        let device = try audio.receiver()
        let before = try audio.readMute(device)
        let expected = !before
        try audio.writeMute(expected, to: device)
        let after = try audio.readMuteUntil(
            expected,
            device: device,
            timeoutMilliseconds: 300
        )
        guard after == expected, after != before else {
            throw ReceiverMuteError.transitionMismatch
        }
        return (device, after)
    }()

    try feedback.play(path: transition.muted ? mutedFeedbackPath : liveFeedbackPath)
    return transition
}

func runReceiverMuteCLI(
    arguments: [String],
    audio: ReceiverAudio,
    feedback: MuteFeedback,
    lock: ReceiverMuteLocking,
    stdout: (String) -> Void,
    stderr: (String) -> Void
) -> Int {
    do {
        let command = arguments.dropFirst().first ?? "status"
        let result: (device: ReceiverDeviceID, muted: Bool)

        if command == "toggle" {
            result = try verifiedToggle(audio: audio, feedback: feedback, lock: lock)
        } else {
            let device = try audio.receiver()
            switch command {
            case "status":
                break
            case "on":
                try audio.writeMute(true, to: device)
            case "off":
                try audio.writeMute(false, to: device)
            default:
                throw ReceiverMuteError.usage
            }

            let after = try audio.readMute(device)
            result = (device, after)
        }

        stdout("device=\(result.device) uid=\(targetUID) mute=\(result.muted ? "on" : "off")")
        return 0
    } catch {
        stderr("receiver-mute: \(error.localizedDescription)")
        return 1
    }
}

#if !DJI_RECEIVER_MUTE_FIXTURE
@main
struct ReceiverMuteMain {
    static func main() {
        let exitCode = runReceiverMuteCLI(
            arguments: CommandLine.arguments,
            audio: CoreAudioReceiver(),
            feedback: AfplayMuteFeedback(),
            lock: AdvisoryReceiverMuteLock(),
            stdout: { print($0) },
            stderr: { fputs("\($0)\n", Darwin.stderr) }
        )
        exit(Int32(exitCode))
    }
}
#endif
