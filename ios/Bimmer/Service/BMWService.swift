import Foundation

enum BMWError: LocalizedError {
    case captchaFailed
    case noOtpID
    case noVehicle
    case loginFailed(String)
    case remoteFailed(String)
    case parse(String)

    var errorDescription: String? {
        switch self {
        case .captchaFailed: return "滑块验证未通过,请重试"
        case .noOtpID: return "未获取到验证码 ID"
        case .noVehicle: return "账号下没有车辆"
        case .loginFailed(let m): return m
        case .remoteFailed(let m): return m
        case .parse(let m): return "解析失败: \(m)"
        }
    }
}

/// 宝马中国区互联驾驶接口封装(移植 src/bimmer/login.py、login_sms.py、app.py 与
/// bimmer_connected 的 account / client / remote_services)。
final class BMWService {
    private let client = APIClient(baseURL: URL(string: API.server)!)

    struct VehicleInfo {
        var vin: String
        var name: String
        var brand: String
        var driveTrain: String
    }

    // MARK: - 通用工具

    static func normalizeMobile(_ m: String) -> String {
        let digits = m.filter { $0.isNumber }
        if digits.hasPrefix("86") && digits.count == 13 { return digits }
        if digits.count == 11 && digits.hasPrefix("1") { return "86" + digits }
        return m
    }

    /// 品牌归一化(移植 CarBrands._missing_):profile 返回 "BMW"/"BMW_I" 等,统一成小写 "bmw"。
    static func normalizeBrand(_ b: String) -> String {
        let first = b.split(separator: "_").first.map { $0.lowercased() } ?? b.lowercased()
        if first == "drittkunde" { return "toyota" }
        switch first {
        case "bmw": return "bmw"
        case "mini": return "mini"
        case "toyota": return "toyota"
        default: return "bmw"
        }
    }

    private static func json(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func isOK(_ j: [String: Any]) -> Bool {
        switch j["code"] {
        case let c as Int: return c == 200
        case let c as String: return c == "200"
        default: return true
        }
    }

    private static func num(_ v: Any?) -> Double? {
        switch v {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let s as String: return Double(s)
        case let n as NSNumber: return n.doubleValue
        default: return nil
        }
    }

    private static func intVal(_ v: Any?) -> Int? {
        switch v {
        case let i as Int: return i
        case let d as Double: return Int(d)
        case let s as String: return Int(s)
        case let n as NSNumber: return n.intValue
        default: return nil
        }
    }

    private static func str(_ v: Any?) -> String? {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return nil
    }

    /// 业务接口头:defaultHeader + Authorization + bmw-session-id。
    private func businessHeaders(token: Token, brand: String = "bmw", extra: [String: String] = [:]) -> [String: String] {
        var h = AuthHeaders.defaultHeader(brand: brand)
        h["authorization"] = "Bearer \(token.accessToken)"
        h["bmw-session-id"] = token.sessionId
        for (k, v) in extra { h[k] = v }
        return h
    }

    // MARK: - 滑块验证码

    private func createCaptcha(mobile: String) async -> [String: Any]? {
        do {
            let headers = AuthHeaders.baseHeaders.merging(AuthHeaders.xHeaders()) { _, new in new }
            let (data, status) = try await client.request(
                "POST", API.createCaptcha,
                headers: headers,
                json: ["mobile": mobile, "brand": "BMW"]
            )
            guard status < 300 else { return nil }
            let j = Self.json(data)
            guard Self.isOK(j), let d = j["data"] as? [String: Any] else { return nil }
            return d
        } catch {
            return nil
        }
    }

    private func verifyCaptcha(mobile: String, verifyID: String, position: Double) async -> (status: Int, ok: Bool) {
        do {
            let headers = AuthHeaders.baseHeaders.merging(AuthHeaders.xHeaders()) { _, new in new }
            let (data, status) = try await client.request(
                "POST", API.verifyCaptcha,
                headers: headers,
                json: ["position": position, "verifyId": verifyID, "mobile": mobile]
            )
            let j = Self.json(data)
            return (status, status < 300 && Self.isOK(j))
        } catch {
            return (0, false)
        }
    }

    /// 解滑块,成功返回 verifyId(移植 login_sms.solve_captcha)。
    private func solveCaptcha(mobile: String) async -> String? {
        for _ in 1...5 {
            guard let cap = await createCaptcha(mobile: mobile),
                  let verifyID = cap["verifyId"] as? String,
                  let bg = cap["backGroundImg"] as? String,
                  let cut = cap["cutImg"] as? String else { continue }
            guard let pos = CaptchaSolver.solve(bgBase64: bg, cutBase64: cut) else { continue }

            var result = await verifyCaptcha(mobile: mobile, verifyID: verifyID, position: pos)
            if result.status >= 300 {
                let rounded = (pos * 100).rounded() / 100
                result = await verifyCaptcha(mobile: mobile, verifyID: verifyID, position: rounded)
            }
            if result.ok { return verifyID }
        }
        return nil
    }

    // MARK: - 登录

    /// 解滑块 + 发送短信,返回 otpID。
    func sendSmsCode(mobile: String) async throws -> String {
        let normalized = Self.normalizeMobile(mobile)
        guard let verifyID = await solveCaptcha(mobile: normalized) else {
            throw BMWError.captchaFailed
        }
        let deviceID = AuthHeaders.md5(normalized)
        let headers = AuthHeaders.baseHeaders.merging(AuthHeaders.xHeaders()) { _, new in new }
        let (data, status) = try await client.request(
            "POST", API.sendSms,
            headers: headers,
            json: ["mobile": normalized, "deviceId": deviceID, "verifyId": verifyID]
        )
        let j = Self.json(data)
        guard status < 300, Self.isOK(j) else {
            let msg = Self.str(j["message"]) ?? Self.str(j["msg"]) ?? "发送短信失败"
            throw BMWError.loginFailed(msg)
        }
        let d = j["data"] as? [String: Any] ?? [:]
        let otpRaw = d["otpID"] ?? d["otpId"]
        guard let otpID = Self.str(otpRaw) else { throw BMWError.noOtpID }
        return otpID
    }

    /// 短信验证码登录,返回 token。
    func smsLogin(mobile: String, code: String, otpID: String) async throws -> Token {
        let normalized = Self.normalizeMobile(mobile)
        let deviceID = AuthHeaders.md5(normalized)
        var headers = AuthHeaders.baseHeaders.merging(AuthHeaders.xHeaders()) { _, new in new }
        headers["x-login-nonce"] = CNNonce.generate(username: normalized)
        let (data, status) = try await client.request(
            "POST", API.loginSms,
            headers: headers,
            json: ["mobile": normalized, "otpId": otpID, "otpMsg": code, "deviceId": deviceID]
        )
        let j = Self.json(data)
        guard status < 300 else {
            throw BMWError.loginFailed("登录失败 (HTTP \(status))")
        }
        let d = j["data"] as? [String: Any] ?? [:]
        guard let refresh = Self.str(d["refresh_token"]) else {
            throw BMWError.loginFailed("验证码错误或已过期,请重新点「发送验证码」")
        }
        let access = Self.str(d["access_token"]) ?? ""
        let gcid = Self.str(d["gcid"]) ?? ""
        return Token(mobile: normalized, gcid: gcid, refreshToken: refresh, accessToken: access)
    }

    /// 刷新 token(移植 app.py _refresh_token_known_good)。
    func refreshToken(_ token: Token) async throws -> Token {
        guard !token.refreshToken.isEmpty else {
            throw BMWError.loginFailed("无 refresh_token,请重新登录")
        }
        var headers = AuthHeaders.baseHeaders.merging(AuthHeaders.xHeaders()) { _, new in new }
        headers["x-login-nonce"] = CNNonce.generate(username: token.gcid)
        let (data, status) = try await client.request(
            "POST", API.refreshToken,
            headers: headers,
            form: ["refresh_token": token.refreshToken, "grant_type": "refresh_token"]
        )
        let j = Self.json(data)
        guard status < 300, let access = Self.str(j["access_token"]) else {
            throw BMWError.loginFailed("token 刷新失败,请重新登录")
        }
        var newToken = token
        newToken.accessToken = access
        newToken.refreshToken = Self.str(j["refresh_token"]) ?? token.refreshToken
        newToken.gcid = Self.str(j["gcid"]) ?? token.gcid
        return newToken
    }

    // MARK: - 车况

    func vehicleInfo(token: Token) async throws -> VehicleInfo {
        let (listData, listStatus) = try await client.request(
            "POST", API.vehicleList,
            headers: businessHeaders(token: token)
        )
        guard listStatus < 300 else { throw BMWError.parse("车辆列表 HTTP \(listStatus)") }
        let listJson = Self.json(listData)
        guard let infos = listJson["mappingInfos"] as? [[String: Any]],
              let first = infos.first,
              let vin = Self.str(first["vin"]) else {
            throw BMWError.noVehicle
        }

        let (profData, _) = try await client.request(
            "GET", API.vehicleProfile,
            query: [URLQueryItem(name: "vin", value: vin)],
            headers: businessHeaders(token: token, extra: ["bmw-vin": vin])
        )
        let prof = Self.json(profData)
        let name = Self.str(prof["model"]) ?? "BMW"
        let brand = Self.normalizeBrand(Self.str(prof["brand"]) ?? "bmw")
        let driveTrain = Self.str(prof["driveTrain"]) ?? "UNKNOWN"
        return VehicleInfo(vin: vin, name: name, brand: brand, driveTrain: driveTrain)
    }

    func vehicleState(token: Token, vin: String, brand: String, driveTrain: String) async throws -> VehicleState {
        let appDateTime = Int(Date().timeIntervalSince1970 * 1000)
        let (data, status) = try await client.request(
            "GET", API.vehicleState,
            query: [
                URLQueryItem(name: "apptimezone", value: "0"),
                URLQueryItem(name: "appDateTime", value: String(appDateTime)),
            ],
            headers: businessHeaders(token: token, brand: brand, extra: ["bmw-vin": vin])
        )
        guard status < 300 else { throw BMWError.parse("车况 HTTP \(status)") }
        let j = Self.json(data)
        let state = j["state"] as? [String: Any] ?? [:]
        return Self.parseVehicleState(state: state, driveTrain: driveTrain)
    }

    private static func parseVehicleState(state: [String: Any], driveTrain: String) -> VehicleState {
        var v = VehicleState()

        let combustionTrains = ["COMBUSTION", "ELECTRIC_WITH_RANGE_EXTENDER", "PLUGIN_HYBRID", "HYBRID", "MILD_HYBRID"]
        let hvTrains = ["PLUGIN_HYBRID", "ELECTRIC", "ELECTRIC_WITH_RANGE_EXTENDER"]
        let combustion = combustionTrains.contains(driveTrain)
        let hv = hvTrains.contains(driveTrain)

        let fuelLevel = state["combustionFuelLevel"] as? [String: Any] ?? [:]
        let electric = state["electricChargingState"] as? [String: Any] ?? [:]

        var fuelLiters: Double?
        var fuelRange: Double?
        var elecRange: Double?
        var batteryPercent: Int?

        if combustion {
            fuelLiters = num(fuelLevel["remainingFuelLiters"])
            fuelRange = num(fuelLevel["range"])
        }
        if hv {
            batteryPercent = intVal(electric["chargingLevelPercent"])
            elecRange = num(electric["range"])
            v.chargerConnected = (electric["isChargerConnected"] as? Bool) ?? false
            v.charging = VehicleFormat.chargingStates[str(electric["chargingStatus"]) ?? ""] ?? "未知"
        }

        var total: Double?
        if combustion && hv {
            if driveTrain == "ELECTRIC_WITH_RANGE_EXTENDER" {
                total = (fuelRange ?? 0) + (elecRange ?? 0)
            } else {
                total = fuelRange
                if let fr = fuelRange, let er = elecRange { fuelRange = fr - er }
            }
        } else if combustion {
            total = fuelRange
        } else if hv {
            total = elecRange
        }

        v.battery = batteryPercent.map { "\($0)%" } ?? "—"
        v.fuel = VehicleFormat.liters(fuelLiters)
        v.rangeElec = VehicleFormat.km(elecRange)
        v.rangeFuel = VehicleFormat.km(fuelRange)
        v.rangeTotal = VehicleFormat.km(total)

        if let mileage = num(state["currentMileage"]) {
            v.mileage = VehicleFormat.km(mileage)
            v.monthKm = StatsStore.recordMileage(mileage)
        }

        let doors = state["doorsState"] as? [String: Any] ?? [:]
        v.lock = VehicleFormat.lockStates[str(doors["combinedSecurityState"]) ?? ""] ?? "未知"
        v.lidsOpen = hasOpen(doors)

        let windows = state["windowsState"] as? [String: Any] ?? [:]
        v.windowsOpen = hasOpen(windows)

        // 位置:宝马中国区返回 GCJ-02,转 WGS-84 给 CLGeocoder / Apple 地图。
        if let loc = state["location"] as? [String: Any],
           let coords = loc["coordinates"] as? [String: Any],
           let lat = num(coords["latitude"]), let lng = num(coords["longitude"]) {
            let w = CoordConvert.gcj2wgs(lng, lat)
            v.lng = w.0
            v.lat = w.1
        }

        // 充电会话本地累计
        v.chargeSessionsLocal = StatsStore.trackCharging(
            status: str(electric["chargingStatus"]) ?? "",
            soc: batteryPercent.map { Double($0) }
        )

        return v
    }

    /// 是否存在打开的车门/车窗(state != CLOSED,排除 combined/invalid/unknown)。
    private static func hasOpen(_ dict: [String: Any]) -> Bool {
        for (k, val) in dict {
            if k == "combinedState" || k == "combinedSecurityState" { continue }
            if let s = val as? String, s != "CLOSED", s != "INVALID", s != "UNKNOWN" {
                return true
            }
        }
        return false
    }

    /// 本月官方充电统计(失败返回 nil,不影响主流程)。
    func chargingStats(token: Token, vin: String) async -> (kwh: Double?, sessions: Int?) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let dateStr = f.string(from: Date())
        do {
            let (data, status) = try await client.request(
                "GET", API.chargingStats,
                query: [URLQueryItem(name: "currentDate", value: dateStr)],
                headers: businessHeaders(token: token, extra: ["bmw-vin": vin])
            )
            guard status < 300 else { return (nil, nil) }
            let j = Self.json(data)
            let st = j["statistics"] as? [String: Any] ?? [:]
            return (Self.num(st["totalEnergyCharged"]), Self.intVal(st["numberOfChargingSessions"]))
        } catch {
            return (nil, nil)
        }
    }

    // MARK: - 远程指令

    /// 触发远程指令并轮询结果,返回最终状态(如 EXECUTED / ERROR / TIMEOUT)。
    func trigger(token: Token, vin: String, command: RemoteCommand) async throws -> String {
        var headers = businessHeaders(token: token, extra: ["bmw-vin": vin])
        headers["content-type"] = "application/json"
        var query: [URLQueryItem] = []
        if let action = command.action {
            query.append(URLQueryItem(name: "action", value: action))
        }
        let path = "\(API.remoteCommand)/\(command.serviceType)"
        let (data, status) = try await client.request("POST", path, query: query, headers: headers, json: [:])
        guard status < 300 else {
            throw BMWError.remoteFailed("指令失败 (HTTP \(status))")
        }
        let j = Self.json(data)
        guard let eventID = Self.str(j["eventId"]) else {
            return "EXECUTED"  // 无 eventId,按成功处理(与 remote_services.py 一致)
        }
        return await pollEventStatus(token: token, eventID: eventID)
    }

    private func pollEventStatus(token: Token, eventID: String) async -> String {
        let headers = businessHeaders(token: token)
        let deadline = Date().addingTimeInterval(240)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            do {
                let (data, status) = try await client.request(
                    "POST", API.remoteEventStatus,
                    query: [URLQueryItem(name: "eventId", value: eventID)],
                    headers: headers
                )
                guard status < 300 else { continue }
                let j = Self.json(data)
                let st = Self.str(j["eventStatus"]) ?? "UNKNOWN"
                if st == "ERROR" { return "ERROR" }
                if !["UNKNOWN", "PENDING", "DELIVERED"].contains(st) { return st }
            } catch {
                continue
            }
        }
        return "TIMEOUT"
    }
}
