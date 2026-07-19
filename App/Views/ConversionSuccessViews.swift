import SwiftUI

// MARK: - Confetti burst (conversion success)

/// Full-window confetti: bursts from all four corners toward the centre plus a
/// radial burst outward from the middle, arcing under gravity and fading out.
struct ConfettiBurstView: View {
    private struct Particle {
        let corner: Int          // 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right, 4 centre
        let angle: Double        // launch direction aimed into the window
        let speed: Double        // points per second
        let size: CGFloat
        let color: Color
        let spin: Double         // radians per second
        let delay: Double
    }

    // Same palette as the encoding shimmer
    private static let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    private let particles: [Particle]
    private let startDate = Date()
    let lifetime: Double = 4.0

    init() {
        var made: [Particle] = []
        for corner in 0..<4 {
            // Base direction pointing diagonally into the window from each corner
            // (canvas y grows downward, so positive sin means "down")
            let base: Double = switch corner {
            case 0: .pi / 4          // top-left → down-right
            case 1: 3 * .pi / 4      // top-right → down-left
            case 2: -.pi / 4         // bottom-left → up-right
            default: -3 * .pi / 4    // bottom-right → up-left
            }
            for _ in 0..<28 {
                made.append(Particle(
                    corner: corner,
                    angle: base + Double.random(in: -0.6...0.6),
                    speed: Double.random(in: 380...980),
                    size: CGFloat.random(in: 5...10),
                    color: Self.colors.randomElement()!,
                    spin: Double.random(in: -8...8),
                    delay: Double.random(in: 0...0.25)
                ))
            }
        }
        // Centre burst: radiates outward evenly in all directions
        for _ in 0..<36 {
            made.append(Particle(
                corner: 4,
                angle: Double.random(in: 0..<(2 * .pi)),
                speed: Double.random(in: 260...760),
                size: CGFloat.random(in: 5...10),
                color: Self.colors.randomElement()!,
                spin: Double.random(in: -8...8),
                delay: Double.random(in: 0...0.25)
            ))
        }
        particles = made
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                let origins = [
                    CGPoint(x: 0, y: 0),
                    CGPoint(x: size.width, y: 0),
                    CGPoint(x: 0, y: size.height),
                    CGPoint(x: size.width, y: size.height),
                    CGPoint(x: size.width / 2, y: size.height / 2)
                ]
                let gravity = 550.0

                for particle in particles {
                    let age = elapsed - particle.delay
                    guard age > 0, age < lifetime else { continue }

                    let origin = origins[particle.corner]
                    let x = origin.x + cos(particle.angle) * particle.speed * age
                    let y = origin.y + sin(particle.angle) * particle.speed * age
                        + 0.5 * gravity * age * age

                    var piece = context
                    piece.opacity = max(0, 1 - age / lifetime)
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(particle.spin * age))
                    piece.fill(
                        Path(roundedRect: CGRect(
                            x: -particle.size / 2,
                            y: -particle.size / 3,
                            width: particle.size,
                            height: particle.size * 0.66
                        ), cornerRadius: 1.5),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Success toast

/// Toast card anchored at the lower left: checkmark, message, a View button
/// that reveals the converted files in Finder, and a manual dismiss.
struct SuccessToastView: View {
    var onView: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white, Color.green)
                .font(.system(size: 18, weight: .semibold))

            Text("Conversion successful")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.9))

            Button("View", action: onView)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(sectionFill, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 4)
        .shadow(color: .black.opacity(0.15), radius: 15, x: -2, y: 0)
        // Clicking anywhere on the card (outside the buttons) also dismisses it
        .onTapGesture(perform: onDismiss)
    }
}
