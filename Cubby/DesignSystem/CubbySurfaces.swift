import SwiftUI

extension CubbyDesign {
    struct Elevation {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        static let none = Elevation(color: .clear, radius: 0, x: 0, y: 0)
        static let low = Elevation(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        static let medium = Elevation(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    enum Surface {
        case flat
        case card
        case raised

        fileprivate var fill: Color {
            switch self {
            case .flat:
                Palette.canvas
            case .card:
                Palette.surface
            case .raised:
                Palette.elevatedSurface
            }
        }

        fileprivate var radius: CGFloat {
            switch self {
            case .flat:
                Radius.medium
            case .card:
                Radius.large
            case .raised:
                Radius.xLarge
            }
        }

        fileprivate var strokeColor: Color {
            switch self {
            case .flat:
                .clear
            case .card, .raised:
                Palette.separator.opacity(0.35)
            }
        }

        fileprivate var elevation: Elevation {
            switch self {
            case .flat:
                .none
            case .card:
                .low
            case .raised:
                .medium
            }
        }
    }
}

extension View {
    func cubbySurface(_ surface: CubbyDesign.Surface = .card) -> some View {
        modifier(CubbySurfaceModifier(surface: surface))
    }
}

private struct CubbySurfaceModifier: ViewModifier {
    let surface: CubbyDesign.Surface

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: surface.radius, style: .continuous)
        let elevation = surface.elevation

        content
            .background(surface.fill, in: shape)
            .overlay {
                shape.stroke(surface.strokeColor, lineWidth: CubbyDesign.Stroke.hairline)
            }
            .shadow(
                color: elevation.color,
                radius: elevation.radius,
                x: elevation.x,
                y: elevation.y
            )
    }
}
