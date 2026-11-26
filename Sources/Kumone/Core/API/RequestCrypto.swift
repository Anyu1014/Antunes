import Foundation
import CommonCrypto
import CryptoKit
import Security

/// Request encryption (eapi): AES-128-ECB over
/// "url + payload + md5 digest" with a fixed key, hex output.
enum RequestCrypto {
    private static let eapiKey = "e82ckenh8dichen8"

    /// Encrypts a JSON payload for an `/eapi/...` endpoint.
    /// - Parameter apiPath: the internal API path, e.g. "/api/song/enhance/player/url/v1"
    static func eapi(apiPath: String, payload: Data) -> [String: String] {
        let text = String(decoding: payload, as: UTF8.self)
        let message = "nobody\(apiPath)use\(text)md5forencrypt"
        let digest = Insecure.MD5.hash(data: Data(message.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let data = "\(apiPath)-36cd479b6b5-\(text)-36cd479b6b5-\(digest)"
        let encrypted = aes128(Data(data.utf8), key: eapiKey)
        return ["params": encrypted.map { String(format: "%02X", $0) }.joined()]
    }

    /// Browser API envelope for the two playlist cover requests.
    static func weapi(payload: Data) throws -> [String: String] {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let secret = String((0..<16).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
        let iv = Data("0102030405060708".utf8)
        let first = aes128(payload, key: "0CoJUm6Qyw8W8jud", iv: iv).base64EncodedData()
        let params = aes128(first, key: secret, iv: iv).base64EncodedString()
        let pkcs1 = "MIGJAoGBAOC1CfYlnfhkLbw1ZikBR33yJnfsFStf9orOYVu3tyUVKzqxeodq6opap20uQXYp7E7jQfVhNfzPaVKAEE4DEuy9qSVXyThwEUr2ydBcT38MNoW3pGvuJVkyV1zOELQk2BPP5IddPoIEe5fd71J0HVRrjiidxpNbPs4EYtsKIrjnAgMBAAE="
        guard let der = Data(base64Encoded: pkcs1),
              let publicKey = SecKeyCreateWithData(der as CFData, [
                  kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic
              ] as CFDictionary, nil) else { throw CocoaError(.coderInvalidValue) }
        let bytes = Data(repeating: 0, count: SecKeyGetBlockSize(publicKey) - 16) + Data(secret.utf8.reversed())
        guard let encrypted = SecKeyCreateEncryptedData(publicKey, .rsaEncryptionRaw, bytes as CFData, nil) as Data?
        else { throw CocoaError(.coderInvalidValue) }
        return ["params": params, "encSecKey": encrypted.map { String(format: "%02x", $0) }.joined()]
    }

    /// AES-128 with PKCS7 padding: CBC with an IV, ECB for existing EAPI calls.
    private static func aes128(_ data: Data, key: String, iv: Data? = nil) -> Data {
        let keyData = Data(key.utf8)
        var out = Data(count: data.count + kCCBlockSizeAES128)
        var written = 0
        let status = out.withUnsafeMutableBytes { outPtr in
            data.withUnsafeBytes { dataPtr in
                keyData.withUnsafeBytes { keyPtr in
                    (iv ?? Data()).withUnsafeBytes { ivPtr in
                        CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCOptionPKCS7Padding | (iv == nil ? kCCOptionECBMode : 0)),
                                keyPtr.baseAddress, keyData.count, iv == nil ? nil : ivPtr.baseAddress,
                                dataPtr.baseAddress, data.count,
                                outPtr.baseAddress, outPtr.count, &written)
                    }
                }
            }
        }
        precondition(status == kCCSuccess, "AES encryption failed: \(status)")
        return out.prefix(written)
    }
}
