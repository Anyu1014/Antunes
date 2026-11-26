import CoreGraphics
import SwiftUI

enum CollectionGradientStyle: String {
    case soft = "gradient"
    case dimmed = "gradientDimmed"
    case flow = "gradientFlow"
}

/// Dominant-color extraction for artwork-driven backgrounds
/// (kaset's ColorExtractor approach: tiny bitmap, saturation-weighted averages).
struct ArtworkColors: Equatable {
    var primary: Color
    var secondary: Color
    var isLight = false
    var flowEdges: [[SIMD3<Double>]] = []
    var heroAccent: Color? = nil

    static let collectionFallback = ArtworkColors(
        primary: Color(red: 43 / 255, green: 39 / 255, blue: 47 / 255),
        secondary: Color(red: 245 / 255, green: 225 / 255, blue: 251 / 255)
    )

    static let fallback = ArtworkColors(
        primary: Color(red: 0.16, green: 0.16, blue: 0.20),
        secondary: Color(red: 0.09, green: 0.09, blue: 0.12)
    )
}

enum ArtworkPalette {
    private static var cache: [String: ArtworkColors] = [:]

    @MainActor
    static func extract(from image: PlatformImage, cacheKey: String) -> ArtworkColors {
        if let cached = cache[cacheKey] {
            return cached
        }
        let colors = compute(from: image)
        if cache.count > 200 { cache.removeAll() }
        cache[cacheKey] = colors
        return colors
    }

    @MainActor
    static func collection(from image: PlatformImage, cacheKey: String, aspect: Int, style: CollectionGradientStyle) -> ArtworkColors {
        let key = "collection|\(aspect)|\(style.rawValue)|" + cacheKey
        if let cached = cache[key] { return cached }
        let colors = compute(from: image, collectionAspect: CGFloat(aspect) / 100, style: style)
        if cache.count > 200 { cache.removeAll() }
        cache[key] = colors
        return colors
    }

    private static func compute(from image: PlatformImage, collectionAspect: CGFloat? = nil, style: CollectionGradientStyle = .soft) -> ArtworkColors {
        let fallback: ArtworkColors = collectionAspect == nil ? .fallback : .collectionFallback
        guard let original = image.cgImageRef else { return fallback }
        let imageBounds = CGRect(x: 0, y: 0, width: original.width, height: original.height)
        var visibleBounds = imageBounds
        var cgImage = original
        if let collectionAspect, collectionAspect > 0 {
            // Match the center crop used by the displayed cover.
            let w = CGFloat(original.width), h = CGFloat(original.height)
            let visibleWidth = min(w, h * collectionAspect)
            let visibleHeight = min(h, w / collectionAspect)
            let x = (w - visibleWidth) / 2, y = (h - visibleHeight) / 2
            let lowerBand = CGRect(x: x, y: y + visibleHeight * 0.78, width: visibleWidth, height: visibleHeight * 0.22)
            cgImage = original.cropping(to: lowerBand.integral.intersection(imageBounds)) ?? original
            visibleBounds = CGRect(x: x, y: y, width: visibleWidth, height: visibleHeight)
                .integral.intersection(imageBounds)
        }
        let size = 10
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * size
        let bitsPerComponent = 8
        var rawData = [UInt8](repeating: 0, count: size * size * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: &rawData,
            width: size,
            height: size,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return fallback }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        if collectionAspect != nil {
            let edgeSamples = rawData.withUnsafeBufferPointer { Array($0) }
            let cover = original.cropping(to: visibleBounds)
            let sampleRect = CGRect(x: 0, y: 0, width: size, height: size)
            context.clear(sampleRect)
            context.draw(cover ?? original, in: sampleRect)
            var colors = collectionEdgeColors(edgeSamples, dimmed: style == .dimmed, heroSamples: rawData)
            if style == .flow, let cover {
                let edges = flowEdges(from: cover)
                if !edges.isEmpty {
                    let samples: [UInt8] = edges.joined().flatMap { [UInt8($0.x.rounded()), UInt8($0.y.rounded()), UInt8($0.z.rounded()), 255] }
                    colors = collectionEdgeColors(samples, dimmed: false, heroSamples: rawData)
                    colors.flowEdges = edges
                }
            }
            return colors
        }

        var samples: [(h: CGFloat, s: CGFloat, b: CGFloat, weight: CGFloat)] = []
        for y in 0..<size {
            for x in 0..<size {
                let offset = (y * size + x) * bytesPerPixel
                let r = CGFloat(rawData[offset]) / 255.0
                let g = CGFloat(rawData[offset + 1]) / 255.0
                let b_val = CGFloat(rawData[offset + 2]) / 255.0
                let a = CGFloat(rawData[offset + 3]) / 255.0
                guard a > 0.1 else { continue }

                // Convert RGB to HSB
                let maxC = max(r, max(g, b_val))
                let minC = min(r, min(g, b_val))
                let delta = maxC - minC

                var h: CGFloat = 0
                let s: CGFloat = maxC == 0 ? 0 : delta / maxC
                let b: CGFloat = maxC

                if delta > 0.00001 {
                    if r == maxC {
                        h = (g - b_val) / delta
                    } else if g == maxC {
                        h = 2 + (b_val - r) / delta
                    } else {
                        h = 4 + (r - g) / delta
                    }
                    h /= 6.0
                    if h < 0 { h += 1.0 }
                }

                // Weight vivid mid-brightness pixels highest.
                let weight = s * (1 - abs(b - 0.55))
                samples.append((h, s, b, max(weight, 0.01)))
            }
        }
        guard !samples.isEmpty else { return fallback }

        // Dominant hue = weighted circular mean.
        var sinSum: CGFloat = 0, cosSum: CGFloat = 0, weightSum: CGFloat = 0
        var satSum: CGFloat = 0, brightSum: CGFloat = 0
        for sample in samples {
            let angle = sample.h * 2 * .pi
            sinSum += sin(angle) * sample.weight
            cosSum += cos(angle) * sample.weight
            satSum += sample.s * sample.weight
            brightSum += sample.b * sample.weight
            weightSum += sample.weight
        }
        var hue = atan2(sinSum, cosSum) / (2 * .pi)
        if hue < 0 { hue += 1 }
        let saturation = min(satSum / weightSum * 1.15, 0.72)
        let brightness = brightSum / weightSum

        let primary = Color(hue: hue, saturation: saturation,
                            brightness: min(max(brightness, 0.32), 0.5))
        let secondary = Color(hue: (hue + 0.06).truncatingRemainder(dividingBy: 1),
                              saturation: min(saturation * 1.1, 0.8),
                              brightness: min(max(brightness * 0.5, 0.12), 0.26))
        return ArtworkColors(primary: primary, secondary: secondary)
    }

    private static func flowEdges(from image: CGImage) -> [[SIMD3<Double>]] {
        let size = 32
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }
        guard drawn else { return [] }
        let fallback = SIMD3<Double>(43, 39, 47)
        // Top/right/bottom/left; each edge reads in screen order.
        return (0..<4).map { edge in
            (0..<8).map { part in
                var sum = SIMD3<Double>.zero
                var alpha = 0.0
                for i in (part * size / 8)..<((part + 1) * size / 8) {
                    for j in 0..<(size / 16) {
                        let x = edge == 1 ? size - 1 - j : edge == 3 ? j : i
                        let y = edge == 0 ? j : edge == 2 ? size - 1 - j : i
                        let k = (y * size + x) * 4
                        guard pixels[k + 3] > 25 else { continue }
                        sum += SIMD3(Double(pixels[k]), Double(pixels[k + 1]), Double(pixels[k + 2]))
                        alpha += Double(pixels[k + 3])
                    }
                }
                return alpha > 0 ? sum * (255 / alpha) : fallback
            }
        }
    }

    // The same curved field is used on Android. Projection keeps each edge's color order.
    private static func flowColor(_ edges: [[SIMD3<Double>]], u: Double, v: Double, isLight: Bool) -> SIMD3<Double> {
        func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
        let outward = [-v, u - 1, v - 1, -u]
        let outside = outward.contains { $0 > 0 }
        var rgb = SIMD3<Double>.zero
        var total = 0.0
        for edge in 0..<4 {
            // Beyond the artwork only the facing edges supply color.
            let d = outward[edge]
            let weight = outside ? max(0, d) : 1 / pow(0.035 - d, 3)
            guard weight > 0 else { continue }
            let along = edge.isMultiple(of: 2) ? u : v
            let drift = along > 0 && along < 1 ? 1 - exp(-max(0, d) * 0.85) : 0
            let bend = 0.21 * sin(7.5 * drift + along * 2.4) + (edge.isMultiple(of: 2) ? -0.08 : 0.08)
            let t = clamp(along + drift * bend)
            let count = edges[edge].count
            let index = max(0, min(Double(count - 1), t * Double(count) - 0.5))
            let a = Int(index), b = min(a + 1, count - 1)
            let fraction = index - Double(a), blend = fraction * fraction * (3 - 2 * fraction)
            rgb += (edges[edge][a] * (1 - blend) + edges[edge][b] * blend) * weight
            total += weight
        }
        func linear(_ value: Double) -> Double {
            let s = value / (total * 255)
            return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        let red = linear(rgb.x), green = linear(rgb.y), blue = linear(rgb.z)
        let light = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        let lift = isLight && light < 0.37 ? (0.37 - light) / (1 - light) : 0
        let scale = !isLight && light > 0.14 ? 0.14 / light : 1
        func srgb(_ value: Double) -> Double {
            let t = value * scale * (1 - lift) + lift
            return clamp(t <= 0.0031308 ? 12.92 * t : 1.055 * pow(t, 1.0 / 2.4) - 0.055)
        }
        return SIMD3(srgb(red), srgb(green), srgb(blue))
    }

    static func flowTexture(_ edges: [[SIMD3<Double>]], viewport: CGSize, cover: CGRect,
                            isLight: Bool) -> CGImage? {
        guard edges.count == 4, cover.width > 0, cover.height > 0,
              viewport.width > 0, viewport.height > 0 else { return nil }
        let width = 84, height = 96
        var data = [UInt8](repeating: 255, count: width * height * 4)
        for row in 0..<height {
            let v = Double((CGFloat(row) / CGFloat(height - 1) * viewport.height - cover.minY) / cover.height)
            for col in 0..<width {
                let x = CGFloat(col) / CGFloat(width - 1)
                let u = Double((x * viewport.width - cover.minX) / cover.width)
                let color = flowColor(edges, u: u, v: v, isLight: isLight)
                let k = (row * width + col) * 4
                data[k] = UInt8((color.x * 255).rounded())
                data[k + 1] = UInt8((color.y * 255).rounded())
                data[k + 2] = UInt8((color.z * 255).rounded())
            }
        }
        guard let provider = CGDataProvider(data: Data(data) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return image
    }

    private static func collectionLuminance(_ rgb: [Double]) -> Double {
        let channels = rgb.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    private static func collectionHeroAccent(_ data: [UInt8], background: [Double]) -> [Double]? {
        // Match the Android cover tint, compensating for premultiplied bitmap channels.
        var sums = [0.0, 0.0, 0.0], weight = 0.0
        for i in stride(from: 0, to: data.count, by: 4) where data[i + 3] > 25 {
            let alpha = Double(data[i + 3])
            let rgb = (0..<3).map { Double(data[i + $0]) / alpha }
            let chroma = max(rgb[0], rgb[1], rgb[2]) - min(rgb[0], rgb[1], rgb[2])
            guard chroma >= 0.08 else { continue }
            let w = alpha / 255 * chroma * chroma
            for c in 0..<3 { sums[c] += rgb[c] * w }
            weight += w
        }
        guard weight > 0 else { return nil }
        let seed = sums.map { $0 / weight }
        let base = collectionLuminance(background)
        let ink = base > 0.179 ? 0.0 : 1.0
        func tint(_ t: Double) -> [Double] {
            seed.map { ((ink * (1 - t) + $0 * t) * 255).rounded() / 255 }
        }
        var low = 0.0, high = 0.85
        for _ in 0..<10 {
            let mid = (low + high) / 2
            let light = collectionLuminance(tint(mid))
            if (max(base, light) + 0.05) / (min(base, light) + 0.05) >= 3.65 { low = mid }
            else { high = mid }
        }
        return tint(low)
    }

    private static func collectionEdgeColors(_ data: [UInt8], dimmed: Bool, heroSamples: [UInt8]) -> ArtworkColors {
        var red = 0.0, green = 0.0, blue = 0.0, weight = 0.0
        for i in stride(from: 0, to: data.count, by: 4) where data[i + 3] > 25 {
            // Bitmap RGB is already premultiplied by alpha.
            red += Double(data[i])
            green += Double(data[i + 1])
            blue += Double(data[i + 2])
            weight += Double(data[i + 3])
        }
        guard weight > 0 else { return .collectionFallback }
        let edge = [red / weight, green / weight, blue / weight]
        func heroColor(_ base: [Double]) -> Color? {
            collectionHeroAccent(heroSamples, background: base).map {
                Color(red: $0[0], green: $0[1], blue: $0[2])
            }
        }
        if dimmed {
            let peak = edge.max() ?? 0
            let scale = peak > 0.40 ? 0.40 / peak : 1
            let lift = max(0, 0.12 - peak)
            let base = edge.map { $0 * scale + lift }
            let accent = edge.map { 0.68 + $0 * 0.32 }
            return ArtworkColors(
                primary: Color(red: base[0], green: base[1], blue: base[2]),
                secondary: Color(red: accent[0], green: accent[1], blue: accent[2]),
                heroAccent: heroColor(base)
            )
        }
        let base = collectionLuminance(edge)
        let isLight = base > 0.179
        let ink = isLight ? 0.0 : 1.0
        let tint = edge.map { $0 * 0.18 + ink * 0.82 }
        let tintLight = collectionLuminance(tint)
        let contrast = (max(base, tintLight) + 0.05) / (min(base, tintLight) + 0.05)
        let accent = contrast >= 4.55 ? tint : [ink, ink, ink]
        return ArtworkColors(
            primary: Color(red: edge[0], green: edge[1], blue: edge[2]),
            secondary: Color(red: accent[0], green: accent[1], blue: accent[2]),
            isLight: isLight,
            heroAccent: heroColor(edge)
        )
    }
}
