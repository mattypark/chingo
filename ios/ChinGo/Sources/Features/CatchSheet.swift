import SwiftUI
import SwiftData
import UIKit
import ChinGoDesign
import ChinGoEngine

/// Catching someone.
///
/// The flow is: take the photo, then say who it was. That order matters — the photo is the
/// thing that has to happen while you are still standing together, and typing a handle is
/// the thing that can wait ten seconds. Asking for the name first would mean fumbling with
/// a keyboard in front of a person you just met.
///
/// A real SNAP will also require the other phone to accept, using findi's proximity
/// handshake. That lands at stage 5; the record this writes is already shaped for it.
struct CatchSheet: View {
    @Environment(\.accent) private var accent

    let cell: String
    let placeLabel: String?
    let coordinate: (lat: Double, lon: Double)
    /// Handed the saved photo so the map can fly it into the album. Nil for a TAG.
    var onSaved: (UIImage?) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var me: [MeRecord]

    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var handle = ""
    @State private var move = ""
    @State private var saving = false

    private var canSave: Bool {
        !handle.trimmingCharacters(in: .whitespaces).isEmpty && !saving
    }

    var body: some View {
        SheetShell("Catch") {
        VStack(spacing: 0) {
            photoWell

            VStack(alignment: .leading, spacing: 14) {
                field("Their handle", text: $handle, placeholder: "sunny")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                field("One thing they do", text: $move, placeholder: "Turns any errand into a whole day out")
            }
            .padding(.top, 22)

            if let placeLabel {
                Text(placeLabel)
                    .chinLabelStyle()
                    .foregroundStyle(Ink.textFaint)
                    .padding(.top, 16)
            }

            Spacer(minLength: 18)

            Button(action: save) {
                Text(image == nil ? "Save without a photo" : "Catch")
                    .font(.chinShout)
                    .foregroundStyle(canSave ? accent.onSignal : Ink.textFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(canSave ? accent.signal : Ink.groundSunk))
            }
            .buttonStyle(SquashButtonStyle())
            .disabled(!canSave)
        }
        .padding(.horizontal, Space.margin)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image = $0 }
                .ignoresSafeArea()
        }
    }

    private var photoWell: some View {
        Button { showCamera = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Ink.groundSunk)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 26))
                        Text("Take it together")
                            .font(.chinCallout)
                    }
                    .foregroundStyle(Ink.textSoft)
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(SquashButtonStyle())
        .accessibilityLabel(image == nil ? "Take a photo together" : "Retake the photo")
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)
            TextField(placeholder, text: text, axis: .vertical)
                .font(.chinBody)
                .foregroundStyle(Ink.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Ink.groundRaised)
                )
        }
    }

    private func save() {
        saving = true
        let cleanHandle = handle.trimmingCharacters(in: .whitespaces).lowercased()
        let photoFile = image.flatMap(PhotoStore.save)
        // A photo means you were actually there, so it is a SNAP. Without one it is a TAG,
        // which is an introduction rather than an afternoon — and only SNAPs move a tier.
        let kind = photoFile == nil ? "tag" : "snap"

        let friend = existingFriend(handle: cleanHandle) ?? {
            let new = FriendRecord(
                handle: cleanHandle,
                metCity: placeLabel ?? "somewhere",
                move: move.trimmingCharacters(in: .whitespaces)
            )
            context.insert(new)
            return new
        }()

        if !move.trimmingCharacters(in: .whitespaces).isEmpty {
            friend.move = move.trimmingCharacters(in: .whitespaces)
        }

        if kind == "snap" {
            friend.meetups += 1
            // A place is only new if you have never caught this person in this cell before.
            // Without that check, ten coffees at the same café would read as ten places and
            // the tier ladder would be trivial to farm.
            let seenHere = friend.catches.contains { $0.cell == cell && $0.kind == "snap" }
            if !seenHere { friend.distinctPlaceCount += 1 }
        }

        // A photo does not arrive until nine tomorrow morning. A tag has no photo, so it
        // has nothing to wait for.
        let developsAt = kind == "snap" ? Develop.next(after: .now) : nil

        let record = CatchRecord(
            kind: kind,
            cell: cell,
            placeLabel: placeLabel,
            photoFile: photoFile,
            developsAt: developsAt,
            friend: friend
        )
        context.insert(record)

        // The catch photo is also the memory. This is the whole reason SNAP is the engine
        // of the product: nobody has to remember to save anything.
        if kind == "snap" {
            context.insert(
                MemoryRecord(
                    friendHandle: cleanHandle,
                    placeLabel: placeLabel ?? "somewhere",
                    happenedOn: .now,
                    latitude: coordinate.lat,
                    longitude: coordinate.lon,
                    photoFile: photoFile,
                    developsAt: developsAt
                )
            )
        }

        try? context.save()

        // Ask for permission here and nowhere else. There is now a specific photo arriving at
        // a specific time, which is the only moment the ask explains itself -- and if it is
        // declined the photo still develops, it is just waiting when the app is next opened.
        if let developsAt, me.first?.wantsDevelopAlerts != false {
            let developing = developingHandles(at: developsAt, including: cleanHandle)
            Task { await DevelopAlerts.schedule(at: developsAt, handles: developing) }
        }

        onSaved(photoFile == nil ? nil : image)
        dismiss()
    }

    /// Everyone whose photo lands on the same morning, so one alert can name them all rather
    /// than one alert per person arriving at the same second.
    private func developingHandles(at developsAt: Date, including handle: String) -> [String] {
        let descriptor = FetchDescriptor<CatchRecord>()
        let all = (try? context.fetch(descriptor)) ?? []
        let sameMorning = all
            .filter { $0.developsAt == developsAt }
            .compactMap { $0.friend?.handle }
        return Array(Set(sameMorning + [handle]))
    }

    private func existingFriend(handle: String) -> FriendRecord? {
        let descriptor = FetchDescriptor<FriendRecord>(
            predicate: #Predicate { $0.handle == handle }
        )
        return try? context.fetch(descriptor).first
    }
}
