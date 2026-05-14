import CoreGraphics

enum SwiftUIScaleDetector {
    private static let knownPointSizes: [(width: CGFloat, height: CGFloat)] = [
        (320, 568),
        (375, 667),
        (414, 736),
        (375, 812),
        (390, 844),
        (393, 852),
        (402, 874),
        (414, 896),
        (428, 926),
        (430, 932),
        (440, 956),
        (744, 1133),
        (768, 1024),
        (810, 1080),
        (820, 1180),
        (834, 1112),
        (834, 1194),
        (1024, 1366)
    ]

    static func detectedScale(for pixelSize: CGSize) -> Double {
        [3.0, 2.0, 1.0]
            .map { scale in
                (scale: scale, score: score(scale: CGFloat(scale), pixelSize: pixelSize))
            }
            .max { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.scale < rhs.scale
                }

                return lhs.score < rhs.score
            }?
            .scale ?? 1
    }

    private static func score(scale: CGFloat, pixelSize: CGSize) -> CGFloat {
        let pointSize = normalizedSize(
            CGSize(
                width: pixelSize.width / scale,
                height: pixelSize.height / scale
            )
        )
        let integerDistance = fractionalDistance(pointSize.width) + fractionalDistance(pointSize.height)
        let isPixelAligned = integerDistance < 0.02
        var score: CGFloat = isPixelAligned ? 40 : max(0, 16 - integerDistance * 24)

        if knownPointSizes.contains(where: { knownSize in
            abs(pointSize.width - knownSize.width) <= 2
                && abs(pointSize.height - knownSize.height) <= 2
        }) {
            score += 200
        }

        if isPixelAligned && isLikelyPhonePointSize(pointSize) {
            score += scale == 3 ? 72 : 48
        }

        if isPixelAligned && isLikelyTabletPointSize(pointSize) {
            score += scale == 2 ? 72 : 36
        }

        if scale == 1 && max(pixelSize.width, pixelSize.height) <= 1400 {
            score += 20
        }

        return score
    }

    private static func normalizedSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: min(size.width, size.height),
            height: max(size.width, size.height)
        )
    }

    private static func fractionalDistance(_ value: CGFloat) -> CGFloat {
        abs(value.rounded() - value)
    }

    private static func isLikelyPhonePointSize(_ size: CGSize) -> Bool {
        (320...460).contains(size.width) && (560...980).contains(size.height)
    }

    private static func isLikelyTabletPointSize(_ size: CGSize) -> Bool {
        (700...1100).contains(size.width) && (1000...1400).contains(size.height)
    }
}
