import Foundation

/// 预览用的样例车况(530Le 插混典型值)。
/// `vehicleImageBase64` 由后端下发,样例不填 → 前端显示占位剪影。
extension VehicleStatus {
    static let sample = VehicleStatus(
        name: "我的 530Le",
        batteryPercent: 82,
        fuelLiters: 38.5,
        rangeElectric: 84,
        rangeFuel: 544,
        rangeTotal: 628,
        mileage: 18560,
        monthKm: 486,
        charging: .notCharging,
        chargerConnected: false,
        lock: .secured,
        windowsOpen: false,
        lidsOpen: false,
        latitude: 31.2304,
        longitude: 121.4737,
        address: "上海市浦东新区世纪大道 100 号",
        chargeKwh: 128,
        chargeSessions: 12,
        monthTrips: 23,
        lastRefresh: Date()
    )

    /// 充电中 + 已解锁 + 车窗开启的「需注意」态,用于预览状态色
    static let chargingSample = VehicleStatus(
        name: "我的 530Le",
        batteryPercent: 58,
        fuelLiters: 30,
        rangeElectric: 61,
        rangeFuel: 430,
        rangeTotal: 491,
        mileage: 18560,
        monthKm: 486,
        charging: .charging,
        chargerConnected: true,
        lock: .unlocked,
        windowsOpen: true,
        lidsOpen: false,
        latitude: 31.2304,
        longitude: 121.4737,
        address: "上海市浦东新区世纪大道 100 号",
        chargeKwh: 128,
        chargeSessions: 12,
        monthTrips: 23,
        lastRefresh: Date()
    )
}
