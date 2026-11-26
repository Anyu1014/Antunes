import CryptoKit
import Foundation

/// 无损档（flac）要交给 `AVAudioFile` 做帧精确解码，只有本地文件能这样读。
/// 这里按「歌曲 id + 地址指纹」缓存在 Caches/FLAC 下，重复播放不再下载。
enum FLACFileStore {
    private static var directory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FLAC", isDirectory: true)
    }

    static func localCopy(of remote: URL, trackID: Int) async throws -> URL {
        let dir = directory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fingerprint = Insecure.MD5
            .hash(data: Data(remote.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let destination = dir
            .appendingPathComponent("\(trackID)-\(fingerprint)")
            .appendingPathExtension("flac")
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }
        let (temp, response) = try await URLSession.shared.download(from: remote)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        try FileManager.default.moveItem(at: temp, to: destination)
        return destination
    }
}
