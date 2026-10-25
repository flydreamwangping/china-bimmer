import Foundation

/// GCJ-02 → WGS-84(宝马中国区返回 GCJ-02,Apple 地图 / CLGeocoder 用 WGS-84)。
/// 移植 bimmer_connected/coord_convert.py。
enum CoordConvert {
    static let pi = Double.pi
    static let a = 6378245.0
    static let ee = 0.00669342162296594323

    static func outOfChina(_ lng: Double, _ lat: Double) -> Bool {
        !(72.004 <= lng && lng <= 137.8347 && 0.8293 <= lat && lat <= 55.8271)
    }

    static func transformLat(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * pi) + 320.0 * sin(y * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    static func transformLon(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x * pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    static func wgs2gcj(_ lng: Double, _ lat: Double) -> (Double, Double) {
        if outOfChina(lng, lat) { return (lng, lat) }
        let dLat = transformLat(lng - 105.0, lat - 35.0)
        let dLon = transformLon(lng - 105.0, lat - 35.0)
        let radLat = lat / 180.0 * pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        let dLat2 = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi)
        let dLon2 = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi)
        return (lng + dLon2, lat + dLat2)
    }

    static func gcj2wgs(_ lng: Double, _ lat: Double) -> (Double, Double) {
        let g0 = (lng, lat)
        var w0 = g0
        var w1 = g0
        var g1 = wgs2gcj(w0.0, w0.1)
        w1 = (w0.0 - (g1.0 - g0.0), w0.1 - (g1.1 - g0.1))
        var delta = (w1.0 - w0.0, w1.1 - w0.1)
        while abs(delta.0) >= 1e-6 || abs(delta.1) >= 1e-6 {
            w0 = w1
            g1 = wgs2gcj(w0.0, w0.1)
            w1 = (w0.0 - (g1.0 - g0.0), w0.1 - (g1.1 - g0.1))
            delta = (w1.0 - w0.0, w1.1 - w0.1)
        }
        return w1
    }
}
