import AppKit
import SwiftUI

/// White pixels that drift while idle and assemble into the current word's letter shapes.
@MainActor
final class PixelField {
    private struct Pixel {
        var x: Double, y: Double
        var tx: Double?, ty: Double?
        var ta: Double = 1
        let seed: Double
    }
    private struct Target { let x: Double, y: Double, alpha: Double }
    private var pixels: [Pixel]
    private let bounds: CGSize
    private var word: String?
    private var equalising = false
    private var peaks: [Double] = []
    private var peakTime: Double?
    private var lastTime: Double?

    init(count: Int, bounds: CGSize) {
        self.bounds = bounds
        pixels = (0..<count).map { _ in
            Pixel(x: Double.random(in: 0...bounds.width), y: Double.random(in: 0...bounds.height), seed: Double.random(in: 0...1))
        }
    }

    func spell(_ newWord: String?) {
        guard newWord != word || equalising else { return }
        word = newWord
        equalising = false
        var targets: [CGPoint] = []
        if let newWord, !newWord.isEmpty {
            var step = 3.0
            repeat {
                targets = Self.rasterise(newWord, in: bounds, step: step)
                step += 1
            } while targets.count > pixels.count && step < 8
        }
        assign(targets.map { Target(x: $0.x, y: $0.y, alpha: 1) })
    }

    /// Bars of bricks rising from a baseline, peak-hold marks above and a faded reflection below.
    /// Every pixel owns a fixed brick slot, so bricks only fade in and out instead of flying between bars.
    private static let barRows = 16, reflectionRows = 5
    private var slotsPerBar: Int { Self.barRows + 1 + Self.reflectionRows }

    func equalise(_ bands: [Float], at time: Double) {
        equalising = true
        word = nil
        let pitch = bounds.width / Double(bands.count)
        let baseline = bounds.height * 0.66
        let brick = (baseline - 2) / Double(Self.barRows)
        if peaks.count != bands.count { peaks = bands.map(Double.init) }
        let dt = min(0.1, max(0, time - (peakTime ?? time)))
        peakTime = time
        var levels: [Int] = []
        var peakRows: [Int] = []
        for (index, band) in bands.enumerated() {
            let level = Double(band)
            // Peak marks hold, then fall slowly, like the detached segments in a 2000s player.
            peaks[index] = level >= peaks[index] ? level : max(level, peaks[index] - dt * 0.4)
            levels.append(Int(level * Double(Self.barRows) + 0.5))
            peakRows.append(Int(peaks[index] * Double(Self.barRows) + 0.5))
        }
        for index in pixels.indices {
            let bar = index % bands.count
            let slot = index / bands.count
            guard slot < slotsPerBar else { pixels[index].tx = nil; pixels[index].ty = nil; pixels[index].ta = 0; continue }
            let x = pitch * (Double(bar) + 0.5)
            pixels[index].tx = x
            if slot < Self.barRows {
                pixels[index].ty = baseline - brick * (Double(slot) + 0.5)
                pixels[index].ta = slot < max(levels[bar], 1) ? 1 : 0
            } else if slot == Self.barRows {
                let row = peakRows[bar]
                pixels[index].ty = baseline - brick * (Double(row) + 0.5)
                pixels[index].ta = row > levels[bar] + 1 ? 0.9 : 0
            } else {
                let row = slot - Self.barRows - 1
                pixels[index].ty = baseline + brick * (Double(row) + 0.5)
                pixels[index].ta = row < levels[bar] ? 0.3 * (1 - Double(row) / Double(Self.reflectionRows)) : 0
            }
        }
    }

    private func assign(_ unsorted: [Target]) {
        var targets = unsorted
        // Pair pixels with targets left to right so the shapes sweep together instead of crossing.
        targets.sort { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        let order = pixels.indices.sorted { pixels[$0].x == pixels[$1].x ? pixels[$0].y < pixels[$1].y : pixels[$0].x < pixels[$1].x }
        for (rank, index) in order.enumerated() {
            if rank < targets.count {
                pixels[index].tx = targets[rank].x
                pixels[index].ty = targets[rank].y
                pixels[index].ta = targets[rank].alpha
            } else {
                pixels[index].tx = nil
                pixels[index].ty = nil
                pixels[index].ta = 1
            }
        }
    }

    func step(to time: Double, level: Double) {
        let dt = min(0.05, max(0, time - (lastTime ?? time)))
        lastTime = time
        let approach = 1 - exp(-dt * 11)
        let jitter = level * 1.4
        for index in pixels.indices {
            var pixel = pixels[index]
            if let tx = pixel.tx, let ty = pixel.ty {
                pixel.x += (tx - pixel.x) * approach + sin(time * 21 + pixel.seed * 40) * jitter
                pixel.y += (ty - pixel.y) * approach + cos(time * 17 + pixel.seed * 30) * jitter
            } else {
                let speed = 7 + pixel.seed * 8 + level * 40
                let angle = pixel.seed * .pi * 2 + sin(time * (0.25 + pixel.seed * 0.5) + pixel.seed * 12) * 1.6
                pixel.x += cos(angle) * speed * dt
                pixel.y += sin(angle) * speed * dt
                if pixel.x < -4 { pixel.x += bounds.width + 8 } else if pixel.x > bounds.width + 4 { pixel.x -= bounds.width + 8 }
                if pixel.y < -4 { pixel.y += bounds.height + 8 } else if pixel.y > bounds.height + 4 { pixel.y -= bounds.height + 8 }
            }
            pixels[index] = pixel
        }
    }

    func draw(in context: inout GraphicsContext) {
        for pixel in pixels {
            let assembled = pixel.tx != nil
            let opacity = assembled ? pixel.ta : 0.3 + 0.25 * (0.5 + 0.5 * sin(pixel.seed * 50 + pixel.x * 0.05))
            if equalising {
                // Green bricks, brighter towards the top of each bar. Spare pixels stay hidden in this mode.
                guard assembled, opacity > 0 else { continue }
                let height = max(0, min(1, 1 - pixel.y / (bounds.height * 0.66)))
                let brickWidth = bounds.width / Double(SystemAudioMonitor.bandCount) - 2
                context.fill(Path(CGRect(x: pixel.x - brickWidth / 2, y: pixel.y - 1.1, width: brickWidth, height: 2.2)),
                             with: .color(Color(hue: 0.36 - 0.06 * height, saturation: 0.85, brightness: 0.55 + 0.45 * height).opacity(opacity)))
            } else {
                context.fill(Path(CGRect(x: pixel.x - 1.3, y: pixel.y - 1.3, width: 2.6, height: 2.6)), with: .color(.white.opacity(opacity)))
            }
        }
    }

    private static func rasterise(_ word: String, in bounds: CGSize, step: Double) -> [CGPoint] {
        let width = Int(bounds.width), height = Int(bounds.height)
        guard let bitmap = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                     space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return [] }
        bitmap.setFillColor(gray: 0, alpha: 1)
        bitmap.fill(CGRect(origin: .zero, size: bounds))
        var pointSize = 44.0
        var text = NSAttributedString(string: word)
        repeat {
            text = NSAttributedString(string: word, attributes: [.font: NSFont.systemFont(ofSize: pointSize, weight: .heavy), .foregroundColor: NSColor.white])
            pointSize -= 2
        } while text.size().width > bounds.width - 6 && pointSize > 10
        let textSize = text.size()
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
        text.draw(at: NSPoint(x: (bounds.width - textSize.width) / 2, y: (bounds.height - textSize.height) / 2))
        NSGraphicsContext.current = previous
        guard let data = bitmap.data else { return [] }
        let buffer = data.assumingMemoryBound(to: UInt8.self)
        var points: [CGPoint] = []
        var y = step / 2
        while y < bounds.height {
            var x = step / 2
            while x < bounds.width {
                // Bitmap rows run top to bottom, matching the canvas.
                if buffer[Int(y) * width + Int(x)] > 110 { points.append(CGPoint(x: x, y: y)) }
                x += step
            }
            y += step
        }
        return points
    }
}
