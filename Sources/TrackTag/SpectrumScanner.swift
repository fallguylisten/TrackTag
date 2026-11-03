import Foundation
import AVFoundation
import Accelerate
import AppKit

/// Decodes part of a file, runs an FFT, and finds the "sound ceiling": the highest frequency
/// with real content. Also draws the spectrogram shown in the Review Queue.
enum SpectrumScanner {
    static let fftSize = 4096

    struct Result {
        var ceilingKHz: Double
        var image: NSImage?
    }

    /// Analyses up to `seconds` from the middle of the file. Set `wantImage` for the side panel.
    static func analyse(_ url: URL, seconds: Double = 40, wantImage: Bool = false) -> Result? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let sr = format.sampleRate
        let total = AVAudioFrameCount(file.length)
        let want = AVAudioFrameCount(min(Double(total), seconds * sr))
        guard want > AVAudioFrameCount(fftSize) else { return nil }
        file.framePosition = AVAudioFramePosition((total - want) / 2)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: want),
              (try? file.read(into: buf, frameCount: want)) != nil,
              let ch = buf.floatChannelData else { return nil }

        // Mix to mono.
        let n = Int(buf.frameLength)
        var mono = [Float](repeating: 0, count: n)
        let channels = Int(format.channelCount)
        for c in 0..<channels {
            mono = vDSP.add(mono, UnsafeBufferPointer(start: ch[c], count: n))
        }
        mono = vDSP.multiply(1 / Float(max(1, channels)), mono)

        let half = fftSize / 2
        let log2n = vDSP_Length(log2(Double(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        defer { vDSP_destroy_fftsetup(setup) }
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        var avg = [Float](repeating: 0, count: half)
        var columns: [[Float]] = []
        var frames = 0
        var real = [Float](repeating: 0, count: half), imag = [Float](repeating: 0, count: half)
        var segment = [Float](repeating: 0, count: fftSize)
        var power = [Float](repeating: 0, count: half)
        let hop = fftSize
        var start = 0
        while start + fftSize <= n {
            mono.withUnsafeBufferPointer { p in
                vDSP_vmul(p.baseAddress! + start, 1, window, 1, &segment, 1, vDSP_Length(fftSize))
            }
            real.withUnsafeMutableBufferPointer { rp in
                imag.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    segment.withUnsafeBufferPointer { sp in
                        sp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                            vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                        }
                    }
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                    vDSP_zvmags(&split, 1, &power, 1, vDSP_Length(half))
                }
            }
            avg = vDSP.add(avg, power)
            if wantImage { columns.append(power) }
            frames += 1
            start += hop
        }
        guard frames > 0 else { return nil }

        // Average power in dB, lightly smoothed.
        var db = avg.map { 10 * log10(max($0 / Float(frames), 1e-20)) }
        db = smooth(db, radius: 4)
        let binHz = sr / Double(fftSize)
        let refLo = Int(1000 / binHz), refHi = Int(5000 / binHz)
        let ref = db[refLo..<refHi].reduce(0, +) / Float(refHi - refLo)
        let threshold = ref - 60
        var top = refHi
        for k in stride(from: half - 1, through: refHi, by: -1) where db[k] > threshold { top = k; break }
        let ceiling = Double(top) * binHz / 1000

        return Result(ceilingKHz: (ceiling * 10).rounded() / 10,
                      image: wantImage ? draw(columns, binHz: binHz, ref: ref) : nil)
    }

    private static func smooth(_ x: [Float], radius: Int) -> [Float] {
        var out = x
        for i in x.indices {
            let lo = max(0, i - radius), hi = min(x.count - 1, i + radius)
            out[i] = x[lo...hi].reduce(0, +) / Float(hi - lo + 1)
        }
        return out
    }

    /// Spectrogram image: time left→right, 0–22 kHz bottom→top, dark→hot.
    private static func draw(_ cols: [[Float]], binHz: Double, ref: Float) -> NSImage? {
        let width = min(240, cols.count), height = 160
        guard width > 0 else { return nil }
        let maxBin = min(cols[0].count - 1, Int(22_050 / binHz))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for x in 0..<width {
            let col = cols[x * cols.count / width]
            for y in 0..<height {
                let bin = (height - 1 - y) * maxBin / (height - 1)
                let v = 10 * log10(max(col[bin], 1e-20))
                let t = Double(min(1, max(0, (v - (ref - 80)) / 90)))
                let (r, g, b) = heat(t)
                let i = (y * width + x) * 4
                pixels[i] = r; pixels[i + 1] = g; pixels[i + 2] = b; pixels[i + 3] = 255
            }
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                               bytesPerRow: width * 4, space: cs,
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }

    /// Black → purple → orange → yellow.
    private static func heat(_ t: Double) -> (UInt8, UInt8, UInt8) {
        let stops: [(Double, Double, Double)] = [(0.04, 0.04, 0.06), (0.35, 0.08, 0.45), (0.85, 0.3, 0.2), (1.0, 0.75, 0.2), (1.0, 0.98, 0.7)]
        let x = t * Double(stops.count - 1)
        let i = min(stops.count - 2, Int(x)), f = x - Double(i)
        let a = stops[i], b = stops[i + 1]
        func m(_ p: Double, _ q: Double) -> UInt8 { UInt8(max(0, min(255, (p + (q - p) * f) * 255))) }
        return (m(a.0, b.0), m(a.1, b.1), m(a.2, b.2))
    }
}

/// Saved scan results (ceiling per track), so only new or changed files get rescanned.
struct ScanCache: Codable {
    struct Entry: Codable { var ceiling: Double; var fileDate: Date? }
    var entries: [String: Entry] = [:]

    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TrackTag/scan.json")
    }

    static func load() -> ScanCache {
        if let d = try? Data(contentsOf: url), let c = try? JSONDecoder().decode(ScanCache.self, from: d) { return c }
        return ScanCache()
    }

    func save() {
        try? FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(self) { try? d.write(to: Self.url, options: .atomic) }
    }

    /// One-time import of the Nov 2 scan (~/Music/TrackTag/quality-scan.json, keyed by path under ~/Music).
    static func seedPaths() -> [String: Double] {
        let f = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/TrackTag/quality-scan.json")
        guard let d = try? Data(contentsOf: f),
              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        let music = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music").path
        var out: [String: Double] = [:]
        for (k, v) in obj { if let n = v as? Double { out[(music + "/" + k).lowercased()] = n } }
        return out
    }
}
