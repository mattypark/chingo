import SwiftUI
import SwiftData
import CoreLocation
import ChinGoDesign
import ChinGoEngine

/// First run.
///
/// Six screens, bookended by two heroes with four questions between them. The order is not
/// arbitrary and one property of it is load-bearing: **age is settled before any permission is
/// asked for.** A person who cannot use the app should find that out before handing anything
/// over, and the previous version of this flow defended the same rule.
///
/// Every screen is one decision. Onboarding that asks two things at once is where people start
/// tapping to make it stop -- which is why the permissions screen, despite holding two
/// switches, asks for nothing: it presents, and each switch is its own answer.
struct OnboardingFlow: View {
    let location: LocationService
    var onFinished: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var me: [MeRecord]

    @State private var step: Step = OnboardingFlow.opening
    @State private var handle = ""
    @State private var age = ""
    @State private var wantsLocation = false
    @State private var wantsNotifications = false
    @State private var wantsGlobe = false
    @State private var blocked = false

    private enum Step: Int, CaseIterable {
        case welcome, name, age, look, permissions, friends, done
    }

    /// Where `-onboardStep` says to start. Release builds carry no flags, so this is always
    /// `.welcome` outside a debug run.
    private static var opening: Step {
        #if DEBUG
        switch DemoSeed.onboardStep {
        case "name": return .name
        case "age": return .age
        case "look": return .look
        case "permissions", "location": return .permissions
        case "friends": return .friends
        case "done", "safety": return .done
        default: return .welcome
        }
        #else
        return .welcome
        #endif
    }

    var body: some View {
        ZStack {
            Ink.ground.ignoresSafeArea()

            Group {
                switch step {
                case .welcome: welcome
                case .name: name
                case .age: ageStep
                case .look: look
                case .permissions: permissions
                case .friends: friends
                case .done: done
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
        OnboardingHero(
            headline: "Catch the people\nyou meet.",
            primary: "Get me in",
            // The terms live here rather than on a screen of their own. A screen that only
            // says "I agree" is one everybody taps through; a line under the button they are
            // already reading is at least in front of them.
            footnote: "By tapping “Get me in” you're accepting the Terms and Privacy Policy."
        ) {
            advance(to: .name)
        } art: {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(height: 200)
                // Hard, not blurred, and in the deep end of the field's own gradient. The bear
                // is a sticker and this is the shadow a sticker throws.
                .shadow(color: Ink.berryDeep.opacity(0.55), radius: 0, x: 8, y: 8)
        }
    }

    private var name: some View {
        OnboardingQuestion(
            question: "What should we call you?",
            primary: "That's me",
            canAdvance: cleanHandle.count >= 2,
            footnote: "This is what people see when you're nearby."
        ) {
            identity().handle = cleanHandle
            try? context.save()
            advance(to: .age)
        } answer: {
            AnswerField(text: $handle, placeholder: "your name", limit: 20)
        }
    }

    private var ageStep: some View {
        OnboardingQuestion(
            question: "How old are you?",
            primary: "Next",
            canAdvance: Int(age) != nil && !blocked,
            // Deliberately does not say what the threshold is. A screen that announces the
            // cut-off is a screen that tells people which answer to give.
            footnote: blocked ? nil : "There's an age limit, because ChinGo puts you in the same place as other people. We keep the answer, not the number."
        ) {
            let tier = AgeGate.tier(age: Int(age) ?? 0)
            identity().ageTier = tier.rawValue
            try? context.save()

            if tier == .adult {
                advance(to: .look)
            } else {
                withAnimation(Motion.surface) { blocked = true }
            }
        } answer: {
            VStack(spacing: Space.inset) {
                AnswerField(text: $age, placeholder: "00", keyboard: .numberPad, limit: 3)

                if blocked {
                    // Plain, and not written by the bear. Cuteness in a moment that closes a
                    // door reads as evasive, and this is the one screen where being liked
                    // matters less than being clear.
                    Text("You're not old enough to use ChinGo yet. Come back when you are — it'll still be here.")
                        .font(.chinBody)
                        .foregroundStyle(Ink.text)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    /// The one screen that gives something rather than asking for something.
    ///
    /// After the age gate and before the permissions, on purpose: there is no point letting
    /// somebody decorate an app that is about to turn them away, and by the time it asks for
    /// location it should already be theirs.
    private var look: some View {
        OnboardingQuestion(
            question: "Pick your colour.",
            primary: "That's the one",
            canAdvance: true,
            footnote: "Your bear, your buttons, your pin on the map. Change it any time."
        ) {
            advance(to: .permissions)
        } answer: {
            VStack(spacing: Space.section) {
                // The choice previews itself at the size it will actually be seen: this is the
                // bear that stands on the map, in the colour being chosen, repainting live.
                if let bear = BearIcons.all[BearIcons.name(accent: accentChoice.wrappedValue, phase: nil)] {
                    Image(uiImage: bear)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 132)
                        .animation(Motion.tap, value: accentChoice.wrappedValue)
                }

                AccentPicker(selection: accentChoice)
            }
        }
    }

    private var permissions: some View {
        OnboardingQuestion(
            question: "ChinGo needs a couple of things.",
            primary: "Done",
            canAdvance: true
        ) {
            identity().globeEnabled = wantsGlobe
            try? context.save()
            advance(to: .friends)
        } answer: {
            PermissionList(
                wantsLocation: $wantsLocation,
                wantsNotifications: $wantsNotifications,
                wantsGlobe: $wantsGlobe,
                onLocation: {
                    location.requestPermission()
                },
                onNotifications: {
                    identity().wantsDevelopAlerts = true
                    try? context.save()
                    Task { await DevelopAlerts.requestPermission() }
                }
            )
        }
    }

    /// The last thing before the map: how you get your first person.
    ///
    /// Bump's version of this screen lists contacts who are already on the app with an Invite
    /// button each. ChinGo cannot do that and should not want to. There is no contacts
    /// permission -- the permissions screen deliberately does not ask for one -- and the whole
    /// premise is that you catch people you are standing next to, so a list of phone contacts
    /// would be suggesting friends by the one method the app exists to replace.
    ///
    /// What it does instead is the honest equivalent: hand over your handle. That is how the
    /// first friendship in this app actually starts, and putting it here means the first thing
    /// you do after onboarding is the thing the app is for.
    private var friends: some View {
        OnboardingQuestion(
            question: "One more thing.",
            primary: "Got it",
            canAdvance: true,
            footnote: "You can also add someone by their handle any time, from the catch button."
        ) {
            advance(to: .done)
        } answer: {
            VStack(spacing: Space.step) {
                Text("This is you.")
                    .font(.chinBody)
                    .foregroundStyle(Ink.textSoft)

                Text(cleanHandle.isEmpty ? "you" : cleanHandle)
                    .font(.chinAnswer)
                    .foregroundStyle(accentColour.onSignal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, Space.inset)
                    .padding(.vertical, Space.margin)
                    .frame(maxWidth: .infinity)
                    .sticker(fill: accentColour.signal, radius: Radius.surface)
                    .padding(.trailing, Sticker.drop)

                Text("Show it to somebody you're standing with and they can add you. That's the whole thing.")
                    .font(.chinFootnote)
                    .foregroundStyle(Ink.textSoft)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var done: some View {
        OnboardingHero(
            headline: "You're in.",
            primary: "Go outside"
        ) {
            let record = identity()
            record.onboardedAt = .now
            try? context.save()
            onFinished()
        } art: {
            if let bear = BearIcons.all[BearIcons.name(accent: accentChoice.wrappedValue, phase: nil)] {
                Image(uiImage: bear)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .shadow(color: Ink.berryDeep.opacity(0.55), radius: 0, x: 8, y: 8)
                    // The one reward beat onboarding is allowed. It fires on arrival, once.
                    .rewardBeat(on: step)
            }
        }
    }

    // MARK: Plumbing

    /// Trimmed and lower-cased, because a handle is an address rather than a name. Two people
    /// typing "Sam" and "sam " are the same person to everybody who has to find them.
    /// The chosen accent, resolved. The flow is not inside the environment that carries it,
    /// because the record it is written to is being created on these very screens.
    private var accentColour: Accent { Accent.at(accentChoice.wrappedValue) }

    private var cleanHandle: String {
        handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func advance(to next: Step) {
        withAnimation(Motion.surface) { step = next }
    }

    /// Reads and writes the accent index on the record itself rather than parking it in
    /// `@State` until the step ends. The `@Query` above republishes on the write, `RootView`
    /// re-resolves the accent, and the whole flow recolours on the same frame.
    private var accentChoice: Binding<Int> {
        Binding(
            get: { me.first?.bannerTint ?? Accent.fallback.id },
            set: { chosen in
                identity().bannerTint = chosen
                try? context.save()
            }
        )
    }

    private func identity() -> MeRecord {
        if let existing = me.first { return existing }
        let record = MeRecord()
        context.insert(record)
        return record
    }
}
