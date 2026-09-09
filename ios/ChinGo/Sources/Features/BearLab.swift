#if DEBUG
import SwiftUI
import ChinGoDesign

/// Every bear state on one screen, behind `-open bears`.
///
/// The map draws one bear doing one thing at a time, which makes "does the sleep clip actually
/// play" a question you answer by waiting a week. This is the sheet the 3D work is judged on:
/// all five motions side by side, in a real accent, at the size the map uses.
struct BearLab: View {
    @Environment(\.accent) private var accent

    @State private var hug: Double = 1

    private let motions: [(BearMotion, String)] = [
        (.idle, "idle"),
        (.walking, "walk"),
        (.sleeping, "sleep"),
        (.hugging, "hug"),
        (.caught, "catch"),
    ]

    var body: some View {
        SheetShell("Bears") {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Space.step)],
                          spacing: Space.step) {
                    ForEach(motions, id: \.1) { motion, label in
                        VStack(spacing: Space.tight) {
                            BearScene(accent: accent, motion: motion, hug: hug)
                                .frame(height: 150)
                                .background(Ink.groundSunk)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))

                            Text(label)
                                .chinLabelStyle()
                                .foregroundStyle(Ink.textSoft)
                        }
                    }
                }
                .padding(.horizontal, Space.margin)

                // The hug is the one clip driven by a finger rather than played, so the lab
                // needs a finger. Everything else runs on its own.
                VStack(alignment: .leading, spacing: Space.tight) {
                    Text("Hug, held")
                        .chinLabelStyle()
                        .foregroundStyle(Ink.textFaint)
                    Slider(value: $hug, in: 0...1)
                        .tint(accent.signal)
                }
                .padding(.horizontal, Space.margin)
                .padding(.top, Space.section)
            }
        }
    }
}
#endif
