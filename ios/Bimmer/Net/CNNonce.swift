import Foundation
import CryptoKit
import Security

/// 生成 x-login-nonce(登录用 mobile,刷新用 gcid)。
/// 移植 src/bimmer/login.py 的 generate_cn_nonce:SHA256 + AES-128-CBC。
enum CNNonce {
    /// 返回 size 个随机十六进制字符(移植 login.py _random_hex)。
    static func randomHex(_ size: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: (size + 1) / 2)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(size))
    }

    static func sha256Hex(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 生成 Python `%a, %d %b %Y %H:%M:%S GMT` 格式的 UTC 时间。
    static func gmtNow() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return f.string(from: Date())
    }

    static func generate(username: String?) -> String {
        let uname = username ?? ""
        let key = randomHex(16)
        let iv = randomHex(16)

        let keyChars = Array(key)  // 16 个字符
        let ivChars = Array(iv)    // 16 个字符
        let k1 = String(keyChars[0..<8])
        let k2 = String(keyChars[8..<16])
        let i1 = String(ivChars[0..<8])
        let i2 = String(ivChars[8..<16])

        let shaInput = k2 + i1 + "u3.6.1" + String(uname.suffix(4)) + k1 + i2
        let shaHex = sha256Hex(shaInput)
        let shaA = String(shaHex.prefix(32))
        let shaB = String(shaHex.suffix(32))

        let timeStr = gmtNow()
        let plaintext = "\(uname)&\(timeStr)&\(k1)"

        let chars = Array("01234abcdefghijklmnopqrstuvwxyz56789")  // 36 个字符
        let k1Chars = Array(k1)
        let k2Chars = Array(k2)
        let k1r = chars[36 - (chars.firstIndex(of: k1Chars[4]) ?? 0) - 1]
        let k2r = chars[36 - (chars.firstIndex(of: k2Chars[4]) ?? 0) - 1]

        // key[:4] + k1r + key[5:12] + k2r + key[13:]
        let aesKey = String(keyChars[0..<4]) + String(k1r) + String(keyChars[5..<12]) + String(k2r) + String(keyChars[13..<16])

        let aesHex = aesCBCEncrypt(plaintext: plaintext, key: aesKey, iv: iv)

        return k2 + i1 + shaA + aesHex + k1 + i2 + shaB
    }

    /// AES-128-CBC 加密,手动 PKCS7 填充(与 Python pad() 一致),返回小写 hex。
    static func aesCBCEncrypt(plaintext: String, key: String, iv: String) -> String {
        let pt = Array(plaintext.utf8)
        let keyBytes = Array(key.utf8)   // 16 字节
        let ivBytes = Array(iv.utf8)     // 16 字节

        let blockSize = 16
        let padLen = blockSize - (pt.count % blockSize)
        var padded = pt
        padded.append(contentsOf: [UInt8](repeating: UInt8(padLen), count: padLen))

        var outLen = 0
        var out = [UInt8](repeating: 0, count: padded.count + blockSize)

        let status = padded.withUnsafeBytes { ptBuf -> CCCryptorStatus in
            keyBytes.withUnsafeBytes { keyBuf -> CCCryptorStatus in
                ivBytes.withUnsafeBytes { ivBuf -> CCCryptorStatus in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(0),  // CBC,无内建填充(手动填充,与 Python 一致)
                        keyBuf.baseAddress, keyBuf.count,
                        ivBuf.baseAddress,
                        ptBuf.baseAddress, ptBuf.count,
                        &out, out.count,
                        &outLen
                    )
                }
            }
        }

        guard status == kCCSuccess else { return "" }
        return out.prefix(outLen).map { String(format: "%02x", $0) }.joined()
    }
}
