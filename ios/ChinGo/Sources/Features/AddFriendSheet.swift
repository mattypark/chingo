import SwiftUI
import SwiftData
import ChinGoDesign

/// Adding someone without a photo — the TAG path.
///
/// A code rather than a search field, because there is no directory of people to search.
/// You cannot look someone up in ChinGo; they have to hand you something. That is a product
/// decision as much as a safety one: it means the album can only ever fill up with people
/// you actually met.
struct AddFriendSheet: View {
    let cell: String
    let placeLabel: String?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var handle = ""

    private var canAdd: Bool { !handle.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        SheetShell("Add by handle") {
        VStack(spacing: Space.step) {
            Text("They tell you their handle. No search, no directory — you can only add people who hand it to you.")
                .font(.chinFootnote)
                .foregroundStyle(Ink.textSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

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
                    .foregroundStyle(canAdd ? Ink.onSignal : Ink.textFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(canAdd ? Ink.signal : Ink.groundSunk))
            }
            .buttonStyle(SquashButtonStyle())
            .disabled(!canAdd)
            .padding(.horizontal, Space.margin)
        }
        }
    }

    private func add() {
        let clean = handle.trimmingCharacters(in: .whitespaces).lowercased()
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
