import Flutter
import AVFoundation

public class OfflineEnginePlugin: NSObject, FlutterPlugin {
    private let worker = DispatchQueue(label: "app.lingoscribe.decode", qos: .userInitiated)
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "lingoscribe/offline_engine", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(OfflineEnginePlugin(), channel: channel)
    }
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "arguments", message: "Invalid arguments", details: nil)); return
        }
        if call.method == "protectDirectory", let path = args["path"] as? String {
            do {
                var url = URL(fileURLWithPath: path)
                var values = URLResourceValues(); values.isExcludedFromBackup = true
                try url.setResourceValues(values)
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: path)
                result(nil)
            } catch { result(FlutterError(code: "protection", message: error.localizedDescription, details: nil)) }
            return
        }
        guard call.method == "normalize", let source = args["source"] as? String, let destination = args["destination"] as? String, source != destination else {
            result(FlutterMethodNotImplemented); return
        }
        worker.async {
            do {
                let duration = try Self.normalize(source, destination)
                DispatchQueue.main.async { result(duration) }
            } catch {
                try? FileManager.default.removeItem(atPath: destination)
                DispatchQueue.main.async { result(FlutterError(code: "decode", message: error.localizedDescription, details: nil)) }
            }
        }
    }
    private static func normalize(_ source: String, _ destination: String) throws -> Int64 {
        let asset = AVURLAsset(url: URL(fileURLWithPath: source))
        let tracks = asset.tracks(withMediaType: .audio)
        guard let track = tracks.first else { throw NSError(domain: "LingoScribe", code: 1, userInfo: [NSLocalizedDescriptionKey: "No supported audio track"]) }
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite && duration > 0 && duration <= 7200 else {
            throw NSError(domain: "LingoScribe", code: 2, userInfo: [NSLocalizedDescriptionKey: "Audio must be shorter than two hours"])
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw NSError(domain: "LingoScribe", code: 3) }
        reader.add(output)
        FileManager.default.createFile(atPath: destination, contents: nil, attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let file = try FileHandle(forWritingTo: URL(fileURLWithPath: destination))
        defer { try? file.close(); reader.cancelReading() }
        try file.write(contentsOf: Data(count: 44))
        guard reader.startReading() else { throw reader.error ?? NSError(domain: "LingoScribe", code: 4) }
        var bytes: UInt32 = 0
        while let sample = output.copyNextSampleBuffer() {
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            guard UInt64(bytes) + UInt64(length) <= 16000 * 2 * 7200 else { throw NSError(domain: "LingoScribe", code: 5) }
            var data = Data(count: length)
            let status = data.withUnsafeMutableBytes { buffer in
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: buffer.baseAddress!)
            }
            guard status == kCMBlockBufferNoErr else { throw NSError(domain: "LingoScribe", code: 6) }
            try file.write(contentsOf: data); bytes += UInt32(length)
        }
        guard reader.status == .completed && bytes > 0 else { throw reader.error ?? NSError(domain: "LingoScribe", code: 7) }
        var header = Data()
        func text(_ s: String) { header.append(s.data(using: .ascii)!) }
        func u16(_ v: UInt16) { var n = v.littleEndian; withUnsafeBytes(of: &n) { header.append(contentsOf: $0) } }
        func u32(_ v: UInt32) { var n = v.littleEndian; withUnsafeBytes(of: &n) { header.append(contentsOf: $0) } }
        text("RIFF"); u32(bytes + 36); text("WAVEfmt "); u32(16); u16(1); u16(1)
        u32(16000); u32(32000); u16(2); u16(16); text("data"); u32(bytes)
        try file.seek(toOffset: 0); try file.write(contentsOf: header)
        return Int64(bytes / 32)
    }
}
