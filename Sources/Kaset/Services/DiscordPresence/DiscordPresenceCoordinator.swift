import Darwin
import Foundation

private struct PresenceTrack: Sendable, Equatable {
    let title: String
    let artist: String
    let album: String?
    let artworkURL: String?
    let videoID: String
    let duration: TimeInterval
    let isPlaying: Bool
    let positionMs: Int
    let sampledAt: Int64
}

private actor LocalDiscordBridge {
    private var fileDescriptor: Int32 = -1
    private var connectedApplicationID: String?

    func push(_ track: PresenceTrack, applicationID: String) -> Bool {
        guard self.ensureConnection(applicationID: applicationID) else { return false }
        guard let body = self.activityBody(for: track) else { return false }
        guard self.sendFrame(opcode: 1, body: body) else {
            self.closeSocket()
            return false
        }
        return self.readAcknowledgement()
    }

    func clear(applicationID: String) {
        guard self.ensureConnection(applicationID: applicationID) else { return }
        let command: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "args": [
                "pid": Int(getpid()),
                "activity": NSNull(),
            ],
            "nonce": UUID().uuidString,
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: command) else { return }
        _ = self.sendFrame(opcode: 1, body: body)
        _ = self.readAcknowledgement()
    }

    func disconnect() {
        self.closeSocket()
    }

    private func ensureConnection(applicationID: String) -> Bool {
        if self.fileDescriptor >= 0, self.connectedApplicationID == applicationID {
            return true
        }

        self.closeSocket()

        for path in self.candidateSocketPaths() {
            guard let descriptor = self.openSocket(path: path) else { continue }
            self.fileDescriptor = descriptor
            self.connectedApplicationID = applicationID

            let handshake: [String: Any] = [
                "v": 1,
                "client_id": applicationID,
            ]

            guard let data = try? JSONSerialization.data(withJSONObject: handshake),
                  self.sendFrame(opcode: 0, body: data),
                  self.waitForReady()
            else {
                self.closeSocket()
                continue
            }

            return true
        }

        return false
    }

    private func activityBody(for track: PresenceTrack) -> Data? {
        var activity: [String: Any] = [
            "details": track.title,
            "state": "by \(track.artist)",
            "buttons": [[
                "label": "Listen on YouTube Music",
                "url": "https://music.youtube.com/watch?v=\(track.videoID)",
            ]],
        ]

        if let artworkURL = track.artworkURL {
            activity["assets"] = [
                "large_image": artworkURL,
                "large_text": track.album ?? track.title,
            ]
        }

        if track.isPlaying {
            let elapsed = Int64(max(0, track.positionMs) / 1000)
            let start = track.sampledAt - elapsed
            var timestamps: [String: Int64] = ["start": start]
            if track.duration.isFinite, track.duration > 0 {
                timestamps["end"] = start + Int64(track.duration)
            }
            activity["timestamps"] = timestamps
        }

        let command: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "args": [
                "pid": Int(getpid()),
                "activity": activity,
            ],
            "nonce": UUID().uuidString,
        ]

        return try? JSONSerialization.data(withJSONObject: command)
    }

    private func waitForReady() -> Bool {
        for _ in 0 ..< 4 {
            guard let frame = self.readFrame() else { return false }
            if frame.opcode == 3 {
                _ = self.sendFrame(opcode: 4, body: frame.body)
                continue
            }
            guard frame.opcode == 1,
                  let object = try? JSONSerialization.jsonObject(with: frame.body) as? [String: Any]
            else {
                continue
            }
            if object["evt"] as? String == "READY" {
                return true
            }
            if object["evt"] as? String == "ERROR" {
                return false
            }
        }
        return false
    }

    private func readAcknowledgement() -> Bool {
        for _ in 0 ..< 4 {
            guard let frame = self.readFrame() else {
                self.closeSocket()
                return false
            }
            if frame.opcode == 3 {
                _ = self.sendFrame(opcode: 4, body: frame.body)
                continue
            }
            if frame.opcode == 2 {
                self.closeSocket()
                return false
            }
            guard frame.opcode == 1 else { continue }
            if let object = try? JSONSerialization.jsonObject(with: frame.body) as? [String: Any],
               object["evt"] as? String == "ERROR"
            {
                return false
            }
            return true
        }
        return false
    }

    private func candidateSocketPaths() -> [String] {
        let names = (0 ... 9).map { "discord-ipc-\($0)" }
        var directories: [String] = []

        if let environmentRoot = ProcessInfo.processInfo.environment["TMPDIR"], !environmentRoot.isEmpty {
            directories.append(environmentRoot)
        }
        directories.append(NSTemporaryDirectory())

        let requiredLength = confstr(_CS_DARWIN_USER_TEMP_DIR, nil, 0)
        if requiredLength > 0 {
            var buffer = [CChar](repeating: 0, count: requiredLength)
            let written = buffer.withUnsafeMutableBufferPointer { pointer in
                confstr(_CS_DARWIN_USER_TEMP_DIR, pointer.baseAddress, requiredLength)
            }
            if written > 0 {
                let resolved = buffer.withUnsafeBufferPointer { pointer in
                    String(cString: pointer.baseAddress!)
                }
                directories.append(resolved)
            }
        }

        directories.append(contentsOf: ["/tmp", "/private/tmp"])

        let fileManager = FileManager.default
        for root in ["/private/var/folders", "/var/folders"] {
            guard let buckets = try? fileManager.contentsOfDirectory(atPath: root) else { continue }
            for bucket in buckets {
                let bucketPath = "\(root)/\(bucket)"
                guard let sessions = try? fileManager.contentsOfDirectory(atPath: bucketPath) else { continue }
                for session in sessions {
                    let tempPath = "\(bucketPath)/\(session)/T"
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: tempPath, isDirectory: &isDirectory), isDirectory.boolValue {
                        directories.append(tempPath)
                    }
                }
            }
        }

        var seen = Set<String>()
        var paths: [String] = []
        for directory in directories {
            let base = directory.hasSuffix("/") ? String(directory.dropLast()) : directory
            for name in names {
                let candidate = URL(fileURLWithPath: "\(base)/\(name)").resolvingSymlinksInPath().path
                if seen.insert(candidate).inserted {
                    paths.append(candidate)
                }
            }
        }
        return paths
    }

    private func openSocket(path: String) -> Int32? {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return nil }

        var noSigPipe: Int32 = 1
        _ = setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &noSigPipe,
            socklen_t(MemoryLayout<Int32>.size)
        )

        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        _ = setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_RCVTIMEO,
            &timeout,
            socklen_t(MemoryLayout<timeval>.size)
        )
        _ = setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_SNDTIMEO,
            &timeout,
            socklen_t(MemoryLayout<timeval>.size)
        )

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < capacity else {
            Darwin.close(descriptor)
            return nil
        }

        _ = path.withCString { source in
            withUnsafeMutablePointer(to: &address.sun_path) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: capacity) { destination in
                    strncpy(destination, source, capacity - 1)
                }
            }
        }

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.connect(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else {
            Darwin.close(descriptor)
            return nil
        }

        return descriptor
    }

    private func sendFrame(opcode: UInt32, body: Data) -> Bool {
        guard self.fileDescriptor >= 0 else { return false }
        guard body.count <= Int(UInt32.max) else { return false }

        var wireOpcode = opcode.littleEndian
        var wireLength = UInt32(body.count).littleEndian
        var packet = Data()
        withUnsafeBytes(of: &wireOpcode) { packet.append(contentsOf: $0) }
        withUnsafeBytes(of: &wireLength) { packet.append(contentsOf: $0) }
        packet.append(body)

        var offset = 0
        while offset < packet.count {
            let sent = packet.withUnsafeBytes { pointer -> Int in
                guard let base = pointer.baseAddress else { return -1 }
                return Darwin.send(
                    self.fileDescriptor,
                    base.advanced(by: offset),
                    packet.count - offset,
                    0
                )
            }

            if sent < 0, errno == EINTR {
                continue
            }
            guard sent > 0 else { return false }
            offset += sent
        }

        return true
    }

    private func readFrame() -> (opcode: UInt32, body: Data)? {
        guard let header = self.readExactly(8) else { return nil }
        let bytes = [UInt8](header)
        let opcode = UInt32(bytes[0])
            | (UInt32(bytes[1]) << 8)
            | (UInt32(bytes[2]) << 16)
            | (UInt32(bytes[3]) << 24)
        let length = UInt32(bytes[4])
            | (UInt32(bytes[5]) << 8)
            | (UInt32(bytes[6]) << 16)
            | (UInt32(bytes[7]) << 24)

        guard length <= 1_048_576 else { return nil }
        guard let body = self.readExactly(Int(length)) else { return nil }
        return (opcode, body)
    }

    private func readExactly(_ count: Int) -> Data? {
        guard count >= 0 else { return nil }
        if count == 0 { return Data() }

        var result = Data()
        result.reserveCapacity(count)

        while result.count < count {
            let chunkSize = min(4096, count - result.count)
            var buffer = [UInt8](repeating: 0, count: chunkSize)
            let received = buffer.withUnsafeMutableBytes { pointer -> Int in
                Darwin.recv(self.fileDescriptor, pointer.baseAddress, chunkSize, 0)
            }

            if received < 0, errno == EINTR {
                continue
            }
            guard received > 0 else { return nil }
            result.append(contentsOf: buffer.prefix(received))
        }

        return result
    }

    private func closeSocket() {
        if self.fileDescriptor >= 0 {
            Darwin.close(self.fileDescriptor)
        }
        self.fileDescriptor = -1
        self.connectedApplicationID = nil
    }
}

@MainActor
final class DiscordPresenceCoordinator {
    private static let applicationID = "1542195962129416305"

    private let bridge = LocalDiscordBridge()
    private var refreshTask: Task<Void, Never>?
    private var hasPublishedPresence = false

    func update(
        song: Song?,
        isPlaying: Bool,
        currentTimeMs: Int,
        duration: TimeInterval,
        enabled: Bool
    ) {
        guard enabled, let song else {
            self.stop()
            return
        }

        let artworkURL = song.thumbnailURL?.absoluteString ?? song.fallbackThumbnailURL?.absoluteString
        let track = PresenceTrack(
            title: song.title,
            artist: song.artistsDisplay.isEmpty ? "Unknown Artist" : song.artistsDisplay,
            album: song.album?.title,
            artworkURL: artworkURL,
            videoID: song.videoId,
            duration: duration,
            isPlaying: isPlaying,
            positionMs: max(0, currentTimeMs),
            sampledAt: Int64(Date().timeIntervalSince1970)
        )

        self.hasPublishedPresence = true
        self.refreshTask?.cancel()
        self.refreshTask = Task { [bridge] in
            while !Task.isCancelled {
                let success = await bridge.push(track, applicationID: Self.applicationID)
                if Task.isCancelled { return }
                try? await Task.sleep(for: .seconds(success ? 15 : 5))
            }
        }
    }

    func stop() {
        self.refreshTask?.cancel()
        self.refreshTask = nil
        guard self.hasPublishedPresence else { return }
        self.hasPublishedPresence = false
        Task { [bridge] in
            await bridge.clear(applicationID: Self.applicationID)
            await bridge.disconnect()
        }
    }
}
