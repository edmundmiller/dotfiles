import Foundation

struct FixtureInput: Decodable {
    let receiverMatches: Int
    let beforeMuted: Bool
    let writeMode: String
    let readbackMode: String
}

struct FixtureOutput: Encodable {
    let exitCode: Int
    let afterMuted: Bool
    let sounds: [String]
    let events: [String]
    let stdout: [String]
    let stderr: [String]
}

enum FixtureFailure: LocalizedError {
    case missingReceiver
    case ambiguousReceiver
    case setterFailed
    case readbackTimedOut

    var errorDescription: String? {
        switch self {
        case .missingReceiver:
            "Target Wireless Mic Rx UID is not connected"
        case .ambiguousReceiver:
            "Target Wireless Mic Rx UID is ambiguous"
        case .setterFailed:
            "Unable to set receiver input mute"
        case .readbackTimedOut:
            "Timed out reading receiver input mute"
        }
    }
}

final class FixtureEvents {
    var values: [String] = []
}

final class FixtureAudioState {
    var inputMuted: Bool

    init(inputMuted: Bool) {
        self.inputMuted = inputMuted
    }
}

final class FixtureAudio: ReceiverAudio {
    private let input: FixtureInput
    private let events: FixtureEvents
    private let state: FixtureAudioState

    init(input: FixtureInput, events: FixtureEvents, state: FixtureAudioState) {
        self.input = input
        self.events = events
        self.state = state
    }

    func receiver() throws -> ReceiverDeviceID {
        events.values.append("resolve")
        switch input.receiverMatches {
        case 0:
            throw FixtureFailure.missingReceiver
        case 1:
            return 777
        default:
            throw FixtureFailure.ambiguousReceiver
        }
    }

    func readMute(_ device: ReceiverDeviceID) throws -> Bool {
        events.values.append("read:\(state.inputMuted)")
        return state.inputMuted
    }

    func writeMute(_ requested: Bool, to device: ReceiverDeviceID) throws {
        switch input.writeMode {
        case "failure":
            events.values.append("write-failure:\(requested)")
            throw FixtureFailure.setterFailed
        case "no-op":
            events.values.append("write-noop:\(requested)")
        default:
            events.values.append("write:\(requested)")
            state.inputMuted = requested
        }
    }

    func readMuteUntil(
        _ expected: Bool,
        device: ReceiverDeviceID,
        timeoutMilliseconds: Int
    ) throws -> Bool {
        switch input.readbackMode {
        case "timeout":
            events.values.append("readback-timeout:\(timeoutMilliseconds)")
            throw FixtureFailure.readbackTimedOut
        case "mismatch":
            let mismatch = !expected
            events.values.append("readback:\(mismatch):\(timeoutMilliseconds)")
            return mismatch
        default:
            events.values.append("readback:\(state.inputMuted):\(timeoutMilliseconds)")
            return state.inputMuted
        }
    }
}

final class FixtureFeedback: MuteFeedback {
    private let events: FixtureEvents
    private(set) var sounds: [String] = []

    init(events: FixtureEvents) {
        self.events = events
    }

    func play(path: String) throws {
        let sound = URL(fileURLWithPath: path).lastPathComponent
        events.values.append("sound:\(sound)")
        sounds.append(sound)
    }
}

final class FixtureLock: ReceiverMuteLocking {
    private let events: FixtureEvents

    init(events: FixtureEvents) {
        self.events = events
    }

    func lock() throws {
        events.values.append("lock")
    }

    func unlock() {
        events.values.append("unlock")
    }
}

@main
struct ReceiverMuteFixtureMain {
    static func main() throws {
        let environment = ProcessInfo.processInfo.environment
        guard
            let inputPath = environment["DJI_RECEIVER_MUTE_FIXTURE_INPUT"],
            let outputPath = environment["DJI_RECEIVER_MUTE_FIXTURE_OUTPUT"]
        else {
            throw CocoaError(.fileNoSuchFile)
        }

        let input = try JSONDecoder().decode(
            FixtureInput.self,
            from: Data(contentsOf: URL(fileURLWithPath: inputPath))
        )
        let events = FixtureEvents()
        let state = FixtureAudioState(inputMuted: input.beforeMuted)
        let audio = FixtureAudio(input: input, events: events, state: state)
        let feedback = FixtureFeedback(events: events)
        let lock = FixtureLock(events: events)
        var stdout: [String] = []
        var stderr: [String] = []

        let exitCode = runReceiverMuteCLI(
            arguments: CommandLine.arguments,
            audio: audio,
            feedback: feedback,
            lock: lock,
            stdout: { stdout.append($0) },
            stderr: { stderr.append($0) }
        )

        let output = FixtureOutput(
            exitCode: exitCode,
            afterMuted: state.inputMuted,
            sounds: feedback.sounds,
            events: events.values,
            stdout: stdout,
            stderr: stderr
        )
        let encoded = try JSONEncoder().encode(output)
        try encoded.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        exit(Int32(exitCode))
    }
}
