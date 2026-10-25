import UIKit

/// 滑块缺口定位(移植 src/bimmer/login.py 的 solve_position)。
///
/// 算法:取拼图块 alpha 轮廓边缘,在背景水平梯度图上滑动,累加轮廓处的梯度,
/// 最大处即缺口左边界,返回 position = x / width。
enum CaptchaSolver {
    struct Pixels {
        let width: Int
        let height: Int
        let data: [UInt8]  // RGBA,每像素 4 字节

        func a(_ x: Int, _ y: Int) -> UInt8 { data[(y * width + x) * 4 + 3] }
        func gray(_ x: Int, _ y: Int) -> UInt8 {
            let i = (y * width + x) * 4
            // 背景图不透明,premultiplied == 原始值
            let r = Int(data[i]), g = Int(data[i + 1]), b = Int(data[i + 2])
            return UInt8((299 * r + 587 * g + 114 * b) / 1000)
        }
    }

    /// 解码图片为 RGBA 字节(左上角为原点,与 PIL 一致)。
    static func pixels(of image: UIImage) -> Pixels? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &bytes, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // 翻转 y,使行 0 = 图片顶部(与 PIL 一致)
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return Pixels(width: w, height: h, data: bytes)
    }

    /// 返回缺口左边界比例(0~1);失败返回 nil。
    static func solve(bgBase64: String, cutBase64: String) -> Double? {
        guard
            let bgData = Data(base64Encoded: bgBase64),
            let cutData = Data(base64Encoded: cutBase64),
            let bgImage = UIImage(data: bgData),
            let cutImage = UIImage(data: cutData),
            let bg = pixels(of: bgImage),
            let cut = pixels(of: cutImage)
        else { return nil }

        let W = bg.width, H = bg.height

        // 拼图块 alpha 的包围盒(alpha > 0)
        var x0 = cut.width, y0 = cut.height, x1 = 0, y1 = 0
        for y in 0..<cut.height {
            for x in 0..<cut.width {
                if cut.a(x, y) > 0 {
                    if x < x0 { x0 = x }
                    if x > x1 { x1 = x }
                    if y < y0 { y0 = y }
                    if y > y1 { y1 = y }
                }
            }
        }
        guard x0 <= x1, y0 <= y1 else { return nil }
        let w = x1 - x0 + 1, h = y1 - y0 + 1

        func opaque(_ x: Int, _ y: Int) -> Bool {
            x >= 0 && x < cut.width && y >= 0 && y < cut.height && cut.a(x, y) > 128
        }

        // 轮廓边缘点(相对 bbox 左上角)
        var edge: [(dx: Int, dy: Int)] = []
        for dy in 0..<h {
            for dx in 0..<w {
                let px = x0 + dx, py = y0 + dy
                guard opaque(px, py) else { continue }
                var allOpaque = true
                outer: for ox in -1...1 {
                    for oy in -1...1 {
                        if !opaque(px + ox, py + oy) { allOpaque = false; break outer }
                    }
                }
                if !allOpaque { edge.append((dx, dy)) }
            }
        }

        // 背景水平梯度幅值
        var gx = [Int](repeating: 0, count: W * H)
        for y in 0..<H {
            for x in 0..<W {
                if x > 0 && x < W - 1 {
                    gx[y * W + x] = abs(Int(bg.gray(x + 1, y)) - Int(bg.gray(x - 1, y)))
                } else {
                    gx[y * W + x] = 0
                }
            }
        }

        var bestX = 0, bestScore = -1
        if W >= w {
            for cx in 0...(W - w) {
                var s = 0
                for (dx, dy) in edge {
                    s += gx[(y0 + dy) * W + (cx + dx)]
                }
                if s > bestScore { bestScore = s; bestX = cx }
            }
        }

        return Double(bestX) / Double(W)
    }
}
