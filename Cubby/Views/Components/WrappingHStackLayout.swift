import SwiftUI

struct WrappingHStackLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    init(spacing: CGFloat) {
        horizontalSpacing = spacing
        verticalSpacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        metrics(for: subviews, maximumWidth: proposal.width).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let itemSizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let layout = WrappingLayoutMetrics.calculate(
            itemSizes: itemSizes,
            maximumWidth: bounds.width,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )

        for (subview, placement) in zip(subviews, layout.placements) {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + placement.origin.x,
                    y: bounds.minY + placement.origin.y
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(placement.size)
            )
        }
    }

    private func metrics(for subviews: Subviews, maximumWidth: CGFloat?) -> WrappingLayoutMetrics {
        WrappingLayoutMetrics.calculate(
            itemSizes: subviews.map { $0.sizeThatFits(.unspecified) },
            maximumWidth: maximumWidth,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        )
    }
}

struct WrappingLayoutMetrics: Equatable {
    struct Placement: Equatable {
        let origin: CGPoint
        let size: CGSize
    }

    let size: CGSize
    let placements: [Placement]

    static func calculate(
        itemSizes: [CGSize],
        maximumWidth: CGFloat?,
        horizontalSpacing: CGFloat,
        verticalSpacing: CGFloat
    ) -> WrappingLayoutMetrics {
        guard !itemSizes.isEmpty else {
            return WrappingLayoutMetrics(size: .zero, placements: [])
        }

        let availableWidth = maximumWidth.flatMap { width in
            width.isFinite ? max(0, width) : nil
        } ?? .infinity

        var placements: [Placement] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0

        for itemSize in itemSizes {
            let proposedX = currentX == 0 ? 0 : currentX + horizontalSpacing
            if currentX > 0, proposedX + itemSize.width > availableWidth {
                currentX = 0
                currentY += currentRowHeight + verticalSpacing
                currentRowHeight = 0
            } else {
                currentX = proposedX
            }

            placements.append(Placement(origin: CGPoint(x: currentX, y: currentY), size: itemSize))
            currentX += itemSize.width
            currentRowHeight = max(currentRowHeight, itemSize.height)
            measuredWidth = max(measuredWidth, currentX)
        }

        return WrappingLayoutMetrics(
            size: CGSize(width: measuredWidth, height: currentY + currentRowHeight),
            placements: placements
        )
    }
}
