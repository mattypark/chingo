import SwiftUI
import SwiftData
import ChinGoDesign

/// Adding someone without a photo — the TAG path.
///
/// Two ways in, and the order matters. **Who is actually here** comes first, because on a map
/// screen the answer to "add someone" is nearly always one of the handful of people standing
/// around you, and making them type a handle they would have to ask for first is a worse
/// version of the same thing. Typing a handle stays underneath for the person across the room
/// you cannot get to.
///
/// Still no directory and still no search. The nearby list is only ever people who have
/// switched themselves visible, already coarsened to a cell, and it disappears the moment they
/// walk off. You cannot look anybody up in ChinGo — which is what keeps the album to people
/// you were genuinely near.
struct AddFriendSheet: View {
    @Environment(\.accent) private var accent

    let cell: String
    let placeLabel: String?
    /// Who the presence gate says you may see. Empty is a real and common state.
    var nearby: [NearbyPerson] = []

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var handle = ""

    private var canAdd: Bool { !handle.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        SheetShell("Add someone") {
        VStack(spacing: Space.step) {
            if nearby.isEmpty {
                Text("Nobody around you right now. If they're here and hidden, they'll have to hand you their handle.")
                    .font(.chinFootnote)
                    .foregroundStyle(Ink.textSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                nearbyList
            }

            Text(nearby.isEmpty ? "Or type it in" : "Not on the list?")
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)
                .padding(.top, Space.tight)

            TextField("sunny", text: $handle)
                .font(.custom(Typeface.bagel, size: 22))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Ink.groundRaised)
                )
                .padding(.horizontal, 22)

            Spacer(minLength: 0)

            Button(action: add) {
                Text("Add")
                    .font(.chinShout)
                    .foregroundStyle(canAdd ? accent.onSignal : Ink.textFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(canAdd ? accent.signal : Ink.groundSunk))
            }
            .buttonStyle(SquashButtonStyle())
            .disabled(!canAdd)
            .padding(.horizontal, Space.margin)
        }
        }
    }

    /// Everyone the gate says is here, nearest first, each one addable in a tap.
    private var nearbyList: some View {
        VStack(spacing: Space.tight) {
            ForEach(nearby.sorted { $0.approxMetres < $1.approxMetres }) { person in
                Button { add(handle: person.handle) } label: {
                    HStack(spacing: Space.snug) {
                        Text(person.handle)
                            .font(.custom(Typeface.bagel, size: 19))
                            .foregroundStyle(Ink.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Spacer(minLength: Space.tight)

                        Text(Distance.spoken(metres: person.approxMetres))
                            .font(.chinFootnote)
                            .foregroundStyle(Ink.textSoft)

                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(accent.onSignal)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(accent.signal))
                    }
                    .padding(.horizontal, Space.inset)
                    .padding(.vertical, Space.snug)
                }
                .buttonStyle(StickerButtonStyle(fill: Ink.groundRaised, radius: Radius.card))
                .hitTarget()
                .accessibilityLabel("Add \(person.handle), \(Distance.away(metres: person.approxMetres))")
            }
        }
        .padding(.horizontal, Space.margin)
        // The hard shadow sits outside the row's frame and needs somewhere to land.
        .padding(.trailing, Sticker.drop)
    }

    private func add() {
        add(handle: handle)
    }

    private func add(handle typed: String) {
        let clean = typed.trimmingCharacters(in: .whitespaces).lowercased()
        guard !clean.isEmpty else { return }
        let descriptor = FetchDescriptor<FriendRecord>(predicate: #Predicate { $0.handle == clean })
        let friend = (try? context.fetch(descriptor).first) ?? {
            let new = FriendRecord(handle: clean, metCity: placeLabel ?? "somewhere")
            context.insert(new)
            return new
        }()

        // A TAG never increments meetups or places. It is an introduction, and the tier
        // ladder only moves for time actually spent together.
        context.insert(
            CatchRecord(kind: "tag", cell: cell, placeLabel: placeLabel, friend: friend)
        )
        try? context.save()
        dismiss()
    }
}
