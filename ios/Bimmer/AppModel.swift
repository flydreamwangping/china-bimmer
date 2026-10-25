import Foundation
import Combine

/// 应用状态:登录态、车况、远程指令编排。
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var isLoggedIn = false
    @Published private(set) var isLoading = false
    @Published private(set) var state: VehicleState?
    @Published private(set) var notice: String?

    // 登录面板状态
    @Published private(set) var loginStatus = ""
    @Published private(set) var isSendingCode = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var otpID: String?

    private let service = BMWService()
    private var token: Token?
    private var vin: String?
    private var brand = "bmw"
    private var loopTask: Task<Void, Never>?

    init() {
        if let t = TokenStore.load() {
            token = t
            isLoggedIn = true
        }
    }

    func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetch()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    // MARK: - 登录

    func sendCode(phone: String) async {
        isSendingCode = true
        otpID = nil
        loginStatus = "正在自动解滑块并发送验证码…"
        defer { isSendingCode = false }
        do {
            let id = try await service.sendSmsCode(mobile: phone)
            otpID = id
            loginStatus = "验证码已发送,请输入短信验证码"
        } catch {
            loginStatus = message(for: error)
        }
    }

    func login(phone: String, code: String) async {
        guard let otpID else {
            loginStatus = "请先点「发送验证码」"
            return
        }
        isSubmitting = true
        loginStatus = "正在登录…"
        defer { isSubmitting = false }
        do {
            let t = try await service.smsLogin(mobile: phone, code: code, otpID: otpID)
            token = t
            TokenStore.save(t)
            self.otpID = nil
            loginStatus = ""
            isLoggedIn = true
            notice = "登录成功 ✓"
            await fetch()
        } catch {
            loginStatus = message(for: error)
        }
    }

    func logout() {
        token = nil
        state = nil
        vin = nil
        otpID = nil
        isLoggedIn = false
        TokenStore.delete()
    }

    // MARK: - 车况

    func fetch() async {
        guard var t = token else { return }
        isLoading = true
        defer { isLoading = false }

        if needsRefresh(t) {
            do {
                t = try await service.refreshToken(t)
                token = t
                TokenStore.save(t)
            } catch {
                logout()
                return
            }
        }

        do {
            let info = try await service.vehicleInfo(token: t)
            vin = info.vin
            brand = info.brand
            var s = try await service.vehicleState(token: t, vin: info.vin, brand: info.brand, driveTrain: info.driveTrain)
            s.name = info.name

            let stats = await service.chargingStats(token: t, vin: info.vin)
            s.chargeKwh = stats.kwh
            s.chargeSessions = stats.sessions

            if let lat = s.lat, let lng = s.lng {
                s.address = await GeocodeService.reverse(lat: lat, lng: lng)
            }
            state = s
            notice = nil
        } catch {
            notice = message(for: error)
        }
    }

    // MARK: - 远程指令

    func trigger(_ command: RemoteCommand) async {
        guard let t = token, let vin else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await service.trigger(token: t, vin: vin, command: command)
            notice = "\(command.title): \(Self.stateText(result))"
            if command.refreshesState {
                // 库内 refresh=True:等 2 个轮询周期(7s)让车辆状态落库后再刷新,避免读到旧锁/空调状态。
                try? await Task.sleep(nanoseconds: 7_000_000_000)
            }
            await fetch()
        } catch {
            notice = message(for: error)
        }
    }

    // MARK: - 工具

    private func needsRefresh(_ t: Token) -> Bool {
        guard !t.accessToken.isEmpty, let exp = JWT.expiry(of: t.accessToken) else { return true }
        return Date() > exp.addingTimeInterval(-300)
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    private static func stateText(_ s: String) -> String {
        switch s {
        case "EXECUTED": return "已执行 ✓"
        case "ERROR": return "失败"
        case "TIMEOUT": return "超时"
        case "INITIATED", "PENDING", "DELIVERED": return "执行中…"
        default: return s
        }
    }
}
