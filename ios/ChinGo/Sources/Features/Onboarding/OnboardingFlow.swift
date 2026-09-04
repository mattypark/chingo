import SwiftUI
import SwiftData
import CoreLocation
import ChinGoDesign
import ChinGoEngine

/// First run.
///
/// Five screens, in the order the Pokémon GO reference uses, because the order is not
/// arbitrary: age before anything else (a person who cannot use the app should find out
/// before handing over a permission), then the permission the app cannot work without, then
/// the terms, then the safety note, and only then the map.
///
/// Every screen is one decision. Onboarding that asks two things at once is where people
/// start tapping to make it stop.
struct OnboardingFlow: View {
    let location: LocationService
    var onFinished: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var me: [MeRecord]

    @State private var step: Step = .welcome
    @State private var birthdate = Calendar.current.date(byAdding: .year, value: -20, to: .now) ?? .now
    @State private var blocked = false

    private enum Step: Int, CaseIterable {
        case welcome, age, location, terms, safety
    }

    var body: some View {
        ZStack {
            Ink.ground.ignoresSafeArea()

            Group {
                switch step {
                case .welcome: welcome
                case .age: age
                case .location: locationStep
                case .terms: terms
                case .safety: safety
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .animation(Motion.surface, value: step)
    }

    // MARK: Screens

    private var welcome: some View {
        OnboardingStep(
            art: .bearFull,
            title: "ChinGo",
            message: "Collect the people you meet. Never lose the ones you had.",
            primary: "Start"
        ) {
            advance(to: .age)
        }
    }

    private var age: some View {
        OnboardingStep(
            art: .bearCorner,
            title: "When were you born?",
            // Deliberately does not say what the threshold is. A screen that announces the
            // cut-off is a screen that tells people which answer to give.
            message: "ChinGo puts you in the same place as other people, so there's an age limit. We keep the answer, not the date.",
            primary: "Next"
        ) {
            let tier = AgeGate.tier(bornOn: birthdate)
            identity().ageTier = tier.rawValue
            try? context.save()

            if tier == .adult {
                advance(to: .location)
            } else {
                withAnimation(Motion.surface) { blocked = true }
            }
        } content: {
            DatePicker(
                "Date of birth",
                selection: $birthdate,
                in: ...AgeGate.latestSelectableBirthdate(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()

            if blocked {
                // Plain, and not written by the bear. Cuteness in a moment that closes a door
                // reads as evasive, and this is the one screen where being liked matters less
                // than being clear.
                Text("You're not old enough to use ChinGo yet. Come back when you are — it'll still be here.")
                    .font(.chinBody)
                    .foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)
                    .padding(.top, Space.step)
            }
        }
    }

    private var locationStep: some View {
        OnboardingStep(
            art: .bearCorner,
            title: "Where you are",
            message: "ChinGo shows the places you've already been with people, and lets you catch someone you're standing next to. Nobody ever sees where you are — others only see a rough area, and only when you switch yourself visible.",
            primary: "Allow location",
            secondary: "Not now"
        ) {
            location.requestPermission()
            // The system alert answers on its own schedule, and nothing here depends on the
            // answer — the map has a manual fallback either way. So move on.
            advance(to: .terms)
        } onSecondary: {
            advance(to: .terms)
        }
    }

    private var terms: some View {
        OnboardingStep(
            art: .bearCorner,
            title: "The deal",
            message: "Every catch needs both people to agree. Your photos stay on your phone. You can delete your account, and everything in it, whenever you like.",
            primary: "I agree",
            footnote: "Terms · Privacy"
        ) {
            advance(to: .safety)
        }
    }

    private var safety: some View {
        OnboardingStep(
            art: .bearFull,
            title: "Look up",
            message: "ChinGo happens outside. Watch where you're going, don't play it while driving, and only meet people you actually want to meet.",
            primary: "Got it"
        ) {
            let record = identity()
            record.onboardedAt = .now
            try? context.save()
            onFinished()
        }
    }

    // MARK: Plumbing

    private func advance(to next: Step) {
        withAnimation(Motion.surface) { step = next }
    }

    private func identity() -> MeRecord {
        if let existing = me.first { return existing }
        let record = MeRecord()
        context.insert(record)
        return record
    }
}
