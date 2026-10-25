import Foundation
import CryptoKit

/// 请求头生成(移植 src/bimmer/login.py 的 BASE_HEADERS / x_headers,以及
/// bimmer_connected/api/client.py 的 generate_default_header)。
enum AuthHeaders {
    /// 登录/刷新流程用(login.py BASE_HEADERS)。
    static let baseHeaders: [String: String] = [
        "Content-Type": "application/json; charset=utf-8",
        "x-user-agent": "android(29);bmw;5.14.0(58417);cn",
        "Accept-Language": "zh-CN",
        "User-Agent": "Dart/3.3 (dart:io)",
    ]

    static func md5(_ s: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// login.py x_headers:x / x-correlation-id / bmw-correlation-id。
    static func xHeaders() -> [String: String] {
        let u = UUID().uuidString.lowercased()
        let hex0 = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(1))
        let x = String((hex0 + md5(UUID().uuidString.lowercased()) + md5(UUID().uuidString.lowercased())).prefix(64))
        return [
            "x-correlation-id": u,
            "bmw-correlation-id": u,
            "x": x,
        ]
    }

    /// Android 构建号:稳定设备指纹(移植 client.py get_x_user_agent_buildstring)。
    static func xUserAgentBuildString() -> String {
        let key = "x-user-agent-build-string"
        if let s = UserDefaults.standard.string(forKey: key), !s.isEmpty { return s }
        let digits = "0123456789"
        func rand(_ n: Int) -> String { String((0..<n).map { _ in digits.randomElement()! }) }
        let s = "AP2A.\(rand(6)).\(rand(3))"
        UserDefaults.standard.set(s, forKey: key)
        return s
    }

    /// 车况/远程指令等业务接口用(client.py generate_default_header)。
    static func defaultHeader(brand: String = "bmw") -> [String: String] {
        let cid = UUID().uuidString.lowercased()
        return [
            "accept": "application/json",
            "accept-language": "en",
            "x-raw-locale": "en-US",
            "user-agent": "Dart/3.3 (dart:io)",
            "x-user-agent": "android(\(xUserAgentBuildString()));\(brand);4.9.2(36892);cn",
            "x-identity-provider": "gcdm",
            "x-correlation-id": cid,
            "bmw-correlation-id": cid,
            "bmw-units-preferences": "d=KM;v=L;p=B;ec=KWH100KM;fc=L100KM;em=GKM;",
            "24-hour-format": "true",
        ]
    }
}
