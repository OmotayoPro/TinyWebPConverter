import CoreGraphics

/// PRD §6.2: resize is optional; a blank field or 100% means no resize. Supplying only one
/// of width/height preserves aspect ratio.
public enum ResizeOption: Sendable, Equatable {
    case none
    case percentage(Double)
    case dimensions(width: Int?, height: Int?)

    func targetSize(for originalSize: CGSize) -> CGSize {
        switch self {
        case .none:
            return originalSize

        case .percentage(let percent):
            let factor = percent / 100.0
            return CGSize(
                width: max(1, (originalSize.width * factor).rounded()),
                height: max(1, (originalSize.height * factor).rounded())
            )

        case .dimensions(let width, let height):
            switch (width, height) {
            case (nil, nil):
                return originalSize
            case (let w?, nil):
                let scale = CGFloat(w) / originalSize.width
                return CGSize(width: CGFloat(w), height: max(1, (originalSize.height * scale).rounded()))
            case (nil, let h?):
                let scale = CGFloat(h) / originalSize.height
                return CGSize(width: max(1, (originalSize.width * scale).rounded()), height: CGFloat(h))
            case (let w?, let h?):
                return CGSize(width: CGFloat(w), height: CGFloat(h))
            }
        }
    }
}
