import Foundation
import CoreLocation
import MapKit

/// 逆地理编码(Apple 原生,免 key)+ 打开地图。
/// 移植 src/bimmer/geocode.py 的 Apple 兜底(_format_placemark)。
enum GeocodeService {
    static func reverse(lat: Double, lng: Double) async -> String? {
        await withCheckedContinuation { cont in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lng)) { placemarks, error in
                guard error == nil, let pm = placemarks?.first else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: format(pm))
            }
        }
    }

    /// 把 CLPlacemark 拼成中文地址:省/市/区/街道,直辖市不重复省。
    static func format(_ pm: CLPlacemark) -> String {
        let admin = pm.administrativeArea ?? ""
        let city = pm.locality ?? ""
        let district = pm.subLocality ?? ""
        let street = pm.thoroughfare ?? ""
        let name = pm.name ?? ""

        var parts: [String] = []
        if !admin.isEmpty && admin != city {
            parts.append(admin)
        }
        if !city.isEmpty {
            parts.append(city)
        }
        if !district.isEmpty {
            parts.append(district)
        }
        if !street.isEmpty {
            parts.append(street)
        } else if !name.isEmpty {
            parts.append(name)
        }
        return parts.joined()
    }

    static func openMaps(lat: Double, lng: Double, name: String = "我的车") {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        item.openInMaps(launchOptions: nil)
    }
}
