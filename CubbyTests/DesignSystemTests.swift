import Testing
@testable import Cubby

struct DesignSystemTests {
    @Test func spacingScaleIsStrictlyIncreasing() {
        let scale = [
            CubbyDesign.Spacing.xSmall,
            CubbyDesign.Spacing.small,
            CubbyDesign.Spacing.medium,
            CubbyDesign.Spacing.standard,
            CubbyDesign.Spacing.large,
            CubbyDesign.Spacing.xLarge,
            CubbyDesign.Spacing.xxLarge,
            CubbyDesign.Spacing.xxxLarge
        ]

        #expect(zip(scale, scale.dropFirst()).allSatisfy { pair in pair.0 < pair.1 })
    }

    @Test func layoutAndShapeMetricsMeetFoundationInvariants() {
        #expect(CubbyDesign.Layout.minimumTapTarget >= 44)
        #expect(CubbyDesign.Layout.compactIcon < CubbyDesign.Layout.rowIcon)
        #expect(CubbyDesign.Radius.small < CubbyDesign.Radius.medium)
        #expect(CubbyDesign.Radius.medium < CubbyDesign.Radius.large)
        #expect(CubbyDesign.Radius.large < CubbyDesign.Radius.xLarge)
        #expect(CubbyDesign.Stroke.hairline < CubbyDesign.Stroke.standard)
        #expect(CubbyDesign.Stroke.standard < CubbyDesign.Stroke.emphasized)
    }

    @Test(arguments: [
        CubbyDesign.Motion.Token.quick,
        CubbyDesign.Motion.Token.standard,
        CubbyDesign.Motion.Token.emphasized
    ])
    func reduceMotionMakesEveryMotionTokenImmediate(token: CubbyDesign.Motion.Token) {
        #expect(
            CubbyDesign.Motion.resolution(for: token, reduceMotion: true) == .immediate
        )
        #expect(
            CubbyDesign.Motion.resolution(for: token, reduceMotion: false) == .animated(token)
        )
    }
}
