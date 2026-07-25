import CoreGraphics
import Testing
@testable import Cubby

struct WrappingHStackLayoutTests {
    @Test("Items wrap before exceeding the available width")
    func wrapsItemsAcrossRows() {
        let metrics = WrappingLayoutMetrics.calculate(
            itemSizes: [
                CGSize(width: 60, height: 20),
                CGSize(width: 60, height: 20),
                CGSize(width: 60, height: 20)
            ],
            maximumWidth: 130,
            horizontalSpacing: 8,
            verticalSpacing: 8
        )

        #expect(metrics.placements.map(\.origin) == [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 68, y: 0),
            CGPoint(x: 0, y: 28)
        ])
        #expect(metrics.size == CGSize(width: 128, height: 48))
    }

    @Test("A new row starts below the tallest item in the previous row")
    func usesTallestItemForRowHeight() {
        let metrics = WrappingLayoutMetrics.calculate(
            itemSizes: [
                CGSize(width: 70, height: 18),
                CGSize(width: 50, height: 32),
                CGSize(width: 80, height: 20)
            ],
            maximumWidth: 130,
            horizontalSpacing: 6,
            verticalSpacing: 10
        )

        #expect(metrics.placements.last?.origin == CGPoint(x: 0, y: 42))
        #expect(metrics.size == CGSize(width: 126, height: 62))
    }

    @Test("An oversized item remains intact on its own row")
    func preservesOversizedItems() {
        let metrics = WrappingLayoutMetrics.calculate(
            itemSizes: [
                CGSize(width: 160, height: 24),
                CGSize(width: 40, height: 18)
            ],
            maximumWidth: 120,
            horizontalSpacing: 8,
            verticalSpacing: 8
        )

        #expect(metrics.placements.map(\.origin) == [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 32)
        ])
        #expect(metrics.size == CGSize(width: 160, height: 50))
    }
}
