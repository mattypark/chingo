import SwiftUI
import SwiftData
import ChinGoDesign
import ChinGoEngine

/// You, your people, and your photos.
///
/// Rails rather than a grid. A grid says "here is your data"; a rail says "here is some of
/// it, there is more that way" — and on a page about people you have met, implying more is
/// closer to the truth than showing a wall.
///
/// Nothing here is a number for its own sake. Every count is something that happened.
struct ProfileScreen: View {
    @Environment(\.accent) private var accent

    let state: MapState

    @Query(sort: \FriendRecord.metDate, order: .reverse) private var friends: [FriendRecord]
    @Query(sort: \CatchRecord.happenedAt, order: .reverse) private var catches: [CatchRecord]
    @Query private var memories: [MemoryRecord]
    @Query private var me: [MeRecord]

    @Environment(\.modelContext) private var context
    @State private var selected: FriendRecord?
    @State private var editing = false
    @State private var pickingPortrait = false

    private var identity: MeRecord? { me.first }

    private var withPhotos: [CatchRecord] {
        catches.filter { $0.photoFile != nil }
    }

    private var places: [String] {
        // Ordered by how often you have been there, so the place you actually live comes
        // first rather than whichever city sorts alphabetically.
        let counted = Dictionary(grouping: catches.compactMap(\.placeLabel), by: { $0 })
            .mapValues(\.count)
        return counted.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map(\.key)
    }

    var body: some View {
        SheetShell {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.section) {
                    banner
                    identityBlock
                    stats
                    peopleRail
                    photoRail
                    placeChips
                }
                .padding(.bottom, Space.step)
            }
            // The banner runs to the very top of the screen, under the status bar, the way a
            // profile page is supposed to. Insetting it would leave a strip of ground above
            // the artwork and turn a header into a card.
            .ignoresSafeArea(edges: .top)
        }
        .fullScreenCover(isPresented: $pickingPortrait) {
            CameraPicker { image in
                guard let identity else { return }
                // Written before the old one is deleted. If the write fails there is still a
                // portrait, which is a better failure than a profile that silently loses its
                // face because the camera roll handed back something unencodable.
                guard let saved = PhotoStore.savePortrait(image) else { return }
                PhotoStore.deletePortrait(identity.portraitFile)
                identity.portraitFile = saved
                try? context.save()
            }
            .ignoresSafeArea()
        }
        #if DEBUG
        // `-open edit` lands on the editor rather than on the profile behind it. The icon
        // picker is two taps in, which is two taps simctl cannot make.
        .task { if DemoSeed.opens == "edit" { editing = true } }
        #endif
        .sheet(isPresented: $editing) {
            IdentityEditor(record: identity ?? newIdentity(), level: state.level)
                .presentationDetents([.height(560)])
                .presentationBackground(Ink.ground)
                .presentationCornerRadius(Radius.surface)
        }
        .sheet(item: $selected) { friend in
            SheetShell(friend.handle) {
                CardDetail(friend: friend)
            }
            .presentationBackground(Ink.ground)
            .presentationCornerRadius(Radius.surface)
        }
    }

    // MARK: Banner and identity

    /// The banner, with the bear sitting on its lower edge.
    ///
    /// A flat field of the mascot's own colour rather than a photograph. A photo banner on a
    /// profile with four friends in it is an empty frame asking to be filled; a colour is
    /// finished the moment the account exists.
    private var banner: some View {
        ZStack(alignment: .bottom) {
            // The player's colour, not the mascot's. Berry is the bear's own colour and it
            // belongs to full-screen takeovers; on a profile it just meant every player's
            // page was purple regardless of the colour they chose on the first screen.
            LinearGradient(
                colors: [accent.signalDeep, accent.signal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 190)

            // Your face if you set one, your bear if you did not, and the level gauge around
            // whichever it is. This used to draw the raw berry mascot -- so the one avatar in
            // the app that was definitely *you* was the only one not in your colour.
            PortraitWell(
                portraitFile: identity?.portraitFile,
                diameter: 96,
                progress: state.levelProgress,
                onPick: { pickingPortrait = true },
                onClear: {
                    guard let identity else { return }
                    // The file goes with the field. A portrait nobody can reach is still a
                    // photograph of a face sitting in Application Support.
                    PhotoStore.deletePortrait(identity.portraitFile)
                    identity.portraitFile = nil
                    try? context.save()
                }
            )
            // Straddling the edge is what makes it a profile rather than a card with a
            // coloured lid.
            .offset(y: 46)
        }
        .padding(.bottom, 46)
    }

    private var identityBlock: some View {
        VStack(spacing: Space.tight) {
            Text(identity?.handle.isEmpty == false ? identity!.handle : "you")
                .font(.custom(Typeface.bagel, size: 34))
                .foregroundStyle(Ink.text)
                .tracking(-0.6)

            Text("Level \(state.level) · \(state.xp) XP")
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)

            Group {
                if let bio = identity?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.chinHand)
                        .foregroundStyle(Ink.textSoft)
                } else {
                    // Not a blank line. An empty bio should ask for something, in the voice
                    // the rest of the app uses.
                    Text("Say what you're into.")
                        .font(.chinHand)
                        .foregroundStyle(Ink.textFaint)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.top, Space.hair)

            Button { editing = true } label: {
                Text(identity?.bio.isEmpty == false ? "Edit" : "Add yours")
                    .font(.custom(Typeface.bagel, size: 15))
                    // The accent decides its own label colour. Ink here would be unreadable
                    // on the darker half of the set -- pine puts it at 3.3:1.
                    .foregroundStyle(accent.onSignal)
                    .padding(.horizontal, Space.inset)
                    .padding(.vertical, Space.tight)
            }
            .buttonStyle(StickerButtonStyle(fill: accent.signal, radius: Radius.surface))
            .hitTarget()
            .padding(.top, Space.snug)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.margin)
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat("\(catches.filter { $0.kind == "snap" }.count)", "meetups")
            Divider().frame(height: 28)
            stat("\(friends.count)", friends.count == 1 ? "person" : "people")
            Divider().frame(height: 28)
            // Days, matching the pill on the map. The week count still exists in the engine
            // and is still tested -- it is the honest long-horizon number -- but two different
            // units for one word in two places is how somebody concludes the app is broken.
            stat("\(state.streakDays)", state.streakDays == 1 ? "day" : "days")
        }
        .padding(.vertical, Space.step)
        .sticker(fill: Ink.groundRaised)
        .padding(.horizontal, Space.margin)
        // The hard shadow sits outside the block, so the row needs room for it or it clips
        // against whatever comes next.
        .padding(.bottom, Sticker.drop)
    }

    private func newIdentity() -> MeRecord {
        let record = MeRecord()
        context.insert(record)
        return record
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.custom(Typeface.bagel, size: 26))
                .foregroundStyle(Ink.text)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Rails

    private var peopleRail: some View {
        rail("Your people", isEmpty: friends.isEmpty, emptyLine: "Nobody yet. Catch someone.") {
            ForEach(friends.sorted { $0.tier > $1.tier }) { friend in
                Button { selected = friend } label: {
                    CardView(face: friend.face, width: 132)
                }
                .buttonStyle(SquashButtonStyle())
            }
        }
    }

    private var photoRail: some View {
        rail(
            "Your photos",
            isEmpty: withPhotos.isEmpty,
            emptyLine: "Photos you take together show up here."
        ) {
            ForEach(withPhotos) { record in
                VStack(alignment: .leading, spacing: Space.hair) {
                    Group {
                        if !record.isDeveloped {
                            Developing(developsAt: record.developsAt, showsCaption: false)
                        } else if let image = PhotoStore.load(record.photoFile) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Ink.groundSunk
                        }
                    }
                    .frame(width: 118, height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .sticker(fill: .clear)

                    Text(record.friend?.handle ?? "someone")
                        .font(.chinFootnote)
                        .foregroundStyle(Ink.textSoft)
                        .lineLimit(1)
                }
            }
        }
    }

    private var placeChips: some View {
        rail("Places", isEmpty: places.isEmpty, emptyLine: "Everywhere you meet someone.") {
            ForEach(places, id: \.self) { place in
                Text(place)
                    .font(.custom(Typeface.bagel, size: 15))
                    .foregroundStyle(Ink.text)
                    .padding(.horizontal, Space.step)
                    .padding(.vertical, Space.tight)
                    .sticker(fill: Ink.groundRaised, radius: Radius.surface)
            }
        }
    }

    /// One rail: a heading, then either its contents or a line from the bear.
    ///
    /// The empty state is a sentence, not a blank row. An empty rail with nothing in it is
    /// the moment an app is most obviously a database with no rows.
    @ViewBuilder
    private func rail<Content: View>(
        _ heading: String,
        isEmpty: Bool,
        emptyLine: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.snug) {
            Text(heading)
                .font(.custom(Typeface.bagel, size: 20))
                .foregroundStyle(Ink.text)
                .padding(.horizontal, Space.margin)

            if isEmpty {
                Text(emptyLine)
                    .font(.chinHand)
                    .foregroundStyle(Ink.textSoft)
                    .padding(.horizontal, Space.margin)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Space.snug) {
                        content()
                    }
                    .padding(.horizontal, Space.margin)
                    // Rails clip their own shadows without this; a card whose shadow is cut
                    // off at the scroll edge reads as a rendering bug. Hard shadows sit
                    // entirely outside the block, so this needs to clear the full drop.
                    .padding(.vertical, Space.tight + Sticker.drop)
                }
            }
        }
    }
}

/// Editing who you are. Two fields and a colour, because a profile people actually fill in
/// is one that fits on a single screen with the keyboard up.
///
/// The accent lives here rather than behind a Settings screen the app does not have. It was
/// chosen during onboarding as part of saying who you are, so this is where somebody comes
/// looking to change it.
struct IdentityEditor: View {
    @Environment(\.accent) private var accent

    @Bindable var record: MeRecord
    /// What has been earned, for the icon picker. Passed in rather than recomputed: the level
    /// is derived from the catch list and this sheet does not have one.
    let level: Int

    @Environment(\.modelContext) private var context

    var body: some View {
        SheetShell("You") {
            VStack(alignment: .leading, spacing: Space.step) {
                field("What you go by", text: $record.handle, placeholder: "matthew")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                field(
                    "What you're into",
                    text: $record.bio,
                    placeholder: "Builds things, walks everywhere, always knows a coffee place."
                )

                VStack(alignment: .leading, spacing: Space.snug) {
                    Text("Your colour")
                        .chinLabelStyle()
                        .foregroundStyle(Ink.textFaint)
                    AccentPicker(selection: $record.bannerTint)
                }
                .padding(.top, Space.tight)

                // Next to the colour, and for the reason this file's own doc comment already
                // gives for the colour being here: it was chosen as part of saying who you
                // are, so this is where somebody comes looking to change it. An icon is the
                // same kind of choice, and there is no Settings screen in the app.
                AppIconPicker(selection: $record.alternateIcon, level: level)
                    .padding(.top, Space.step)

                // The one that cannot be automatic. See `MeRecord.wantsLapseIcon`.
                Toggle(isOn: $record.wantsLapseIcon) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Let the bear change the icon")
                            .font(.chinBody)
                            .foregroundStyle(Ink.text)
                        Text("If you've been away a while, it swaps to the sleeping one until you're back. iOS shows an alert when it does.")
                            .font(.chinFootnote)
                            .foregroundStyle(Ink.textSoft)
                    }
                }
                .tint(accent.signal)
                .padding(.top, Space.step)

                // The only notification the app sends, and the only switch for it. Turning it
                // off cancels what is already scheduled as well as what would be -- a toggle
                // that leaves tomorrow's alert armed is why people say these settings do
                // nothing.
                Toggle(isOn: $record.wantsDevelopAlerts) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tell me when photos develop")
                            .font(.chinBody)
                            .foregroundStyle(Ink.text)
                        Text("Once, at nine the next morning. Nothing else.")
                            .font(.chinFootnote)
                            .foregroundStyle(Ink.textSoft)
                    }
                }
                .tint(accent.signal)
                .padding(.top, Space.step)

                // Its own switch, not a sub-setting of the one above. This never leaves the
                // app, needs no permission and costs no battery, so somebody who declined
                // push should not silently lose it too.
                Toggle(isOn: $record.wantsMemoryNudges) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mention memories as I walk past")
                            .font(.chinBody)
                            .foregroundStyle(Ink.text)
                        Text("On the map only, once a day at most per place.")
                            .font(.chinFootnote)
                            .foregroundStyle(Ink.textSoft)
                    }
                }
                .tint(accent.signal)
                .padding(.top, Space.snug)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.margin)
        }
        // Saved on the way out for the text fields, which change on every keystroke. The
        // accent is deliberately not waiting for that -- see below.
        .onDisappear { try? context.save() }
        // A colour change has to survive the sheet being dismissed by a swipe, and it has to
        // reach the map behind it immediately, so it commits on the tap rather than on exit.
        .onChange(of: record.bannerTint) { _, _ in try? context.save() }
        // Same reasoning as the colour: the icon commits the moment the system accepts it,
        // because the change is already visible on the home screen by then.
        .onChange(of: record.alternateIcon) { _, _ in try? context.save() }
        .onChange(of: record.wantsLapseIcon) { _, _ in try? context.save() }
        .onChange(of: record.wantsMemoryNudges) { _, _ in try? context.save() }
        .onChange(of: record.wantsDevelopAlerts) { _, wants in
            try? context.save()
            Task {
                if wants {
                    await DevelopAlerts.requestPermission()
                } else {
                    await DevelopAlerts.cancelAll()
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: Space.hair) {
            Text(label)
                .chinLabelStyle()
                .foregroundStyle(Ink.textFaint)
            TextField(placeholder, text: text, axis: .vertical)
                .font(.chinBody)
                .foregroundStyle(Ink.text)
                .padding(Space.snug)
                .background(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(Ink.groundRaised)
                )
        }
    }
}
