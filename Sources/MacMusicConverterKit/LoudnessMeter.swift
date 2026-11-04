import Foundation

/// Integrated loudness by ITU-R BS.1770-4 / EBU R128 (decision L2), fed
/// one sample at a time: the K-weighting filter, mean squares over 400 ms
/// blocks every 100 ms, then the −70 LUFS absolute gate and the −10 LU
/// relative gate. It's fed the mono mix (the channels averaged, as the
/// WAV is made), since that is what the Plus plays.
public struct LoudnessMeter: Sendable {
    /// −70 LUFS: blocks quieter than this are ignored.
    public static let absoluteGate = -70.0
    /// Blocks more than 10 LU below the ungated mean are ignored.
    public static let relativeGate = -10.0

    /// A second-order section, direct form I.
    struct Biquad: Sendable {
        let b0, b1, b2, a1, a2: Double
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

        init(b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) {
            (self.b0, self.b1, self.b2, self.a1, self.a2) = (b0, b1, b2, a1, a2)
        }

        mutating func run(_ x: Double) -> Double {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            (x2, x1, y2, y1) = (x1, x, y1, y)
            return y
        }
    }

    var shelf: Biquad
    var highPass: Biquad
    /// Samples in a 100 ms step; a block is four steps.
    let step: Int
    /// The current step's sum of squares, and how many samples are in it.
    var stepSum = 0.0
    var stepCount = 0
    /// The last three whole steps' sums, oldest first.
    var recent: [Double] = []
    /// Each whole block's mean square.
    var blocks: [Double] = []

    /// The K-weighting filter for `sampleRate`, designed as the standard's
    /// two stages (a high shelf, then a high-pass) by the bilinear
    /// transform, so any rate gives the standard's 48 kHz response.
    public init(sampleRate: Int) {
        let fs = Double(max(sampleRate, 1))

        // Stage 1: the head's high shelf, about +4 dB above 1.5 kHz.
        var f0 = 1681.974450955533, q = 0.7071752369554196
        let gain = 3.999843853973347
        var k = tan(Double.pi * f0 / fs)
        let vh = pow(10, gain / 20), vb = pow(vh, 0.4996667741545416)
        var a0 = 1 + k / q + k * k
        shelf = Biquad(b0: (vh + vb * k / q + k * k) / a0,
                       b1: 2 * (k * k - vh) / a0,
                       b2: (vh - vb * k / q + k * k) / a0,
                       a1: 2 * (k * k - 1) / a0,
                       a2: (1 - k / q + k * k) / a0)

        // Stage 2: the RLB high-pass, about 38 Hz.
        f0 = 38.13547087602444; q = 0.5003270373238773
        k = tan(Double.pi * f0 / fs)
        a0 = 1 + k / q + k * k
        highPass = Biquad(b0: 1, b1: -2, b2: 1,
                          a1: 2 * (k * k - 1) / a0,
                          a2: (1 - k / q + k * k) / a0)

        step = max(Int((fs / 10).rounded()), 1)
    }

    /// One sample of the mono mix, as a fraction of full scale.
    public mutating func add(_ sample: Double) {
        let y = highPass.run(shelf.run(sample))
        stepSum += y * y
        stepCount += 1
        guard stepCount == step else { return }
        if recent.count == 3 {
            blocks.append((recent.reduce(0, +) + stepSum) / Double(4 * step))
            recent.removeFirst()
        }
        recent.append(stepSum)
        stepSum = 0
        stepCount = 0
    }

    static func lufs(_ meanSquare: Double) -> Double {
        -0.691 + 10 * log10(meanSquare)
    }

    /// The integrated loudness in LUFS, or nil if no block passes the
    /// gates: shorter than 400 ms, or silent.
    public var integrated: Double? {
        let absolute = blocks.filter { $0 > 0 && Self.lufs($0) > Self.absoluteGate }
        guard !absolute.isEmpty else { return nil }
        let threshold = Self.lufs(absolute.reduce(0, +) / Double(absolute.count)) + Self.relativeGate
        let gated = absolute.filter { Self.lufs($0) > threshold }
        guard !gated.isEmpty else { return nil }
        return Self.lufs(gated.reduce(0, +) / Double(gated.count))
    }
}
