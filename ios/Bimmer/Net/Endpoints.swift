import Foundation

/// 宝马中国区互联驾驶 API 端点(移植 bimmer_connected/const.py 与 src/bimmer/login.py)。
enum API {
    static let server = "https://myprofile.bmw.com.cn"

    // 短信登录流程(src/bimmer/login.py / login_sms.py)
    static let createCaptcha = "/eadrax-coas/v2/cop/create-captcha"
    static let verifyCaptcha = "/eadrax-coas/v2/cop/verify-captcha"
    static let sendSms = "/eadrax-coas/v1/cop/message"
    static let loginSms = "/eadrax-coas/v2/login/sms"

    // token 刷新(src/bimmer/app.py _refresh_token_known_good)
    static let refreshToken = "/eadrax-coas/v2/oauth/token"

    // 车况(const.py)
    static let vehicleList = "/eadrax-vcs/v5/vehicle-list"
    static let vehicleProfile = "/eadrax-vcs/v5/vehicle-data/profile"
    static let vehicleState = "/eadrax-vcs/v4/vehicles/state"
    static let chargingStats = "/eadrax-chs/v2/charging-statistics"

    // 远程指令(const.py)
    static let remoteCommand = "/eadrax-vrccs/v4/presentation/remote-commands"
    static let remoteEventStatus = "/eadrax-vrccs/v3/presentation/remote-commands/eventStatus"
}
