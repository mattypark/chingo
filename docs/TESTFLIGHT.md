# Getting ChinGo onto other people's phones

TestFlight, start to finish. Do it in this order — several steps block the ones after them.

Two kinds of tester, and the difference matters:

| | **Internal** | **External** |
|---|---|---|
| Who | Up to 100 people on your App Store Connect team | Up to 10,000, anyone with an email |
| Apple review? | **No** — live within minutes of processing | **Yes** — Beta App Review, usually a day |
| Needs a privacy policy URL | No | **Yes** |
| Best for | You, friends you can add as users | Anyone else |

**Start internal.** It skips review entirely, so you find out whether the build works before
anyone at Apple looks at it.

---

## One-time setup

### 1. Create the app record

App Store Connect → **Apps** → **+** → **New App**.

- Platform: **iOS**
- Name: **ChinGo** (must be unique across the whole App Store)
- Primary language: English (U.S.)
- Bundle ID: **com.matthewpark.chingo**
- SKU: anything unique, e.g. `chingo-001`

> **If the bundle ID is not in that dropdown**, it has no explicit App ID yet. The app is
> signing against the team wildcard profile, which builds fine but registers nothing. Fixed by
> declaring any capability — ChinGo declares Sign in with Apple — then building once with
> `-allowProvisioningUpdates`. Xcode registers the ID and it appears after a page refresh.

### 2a. Or just use an app-specific password (quicker)

**appleid.apple.com** → Sign-In and Security → **App-Specific Passwords** → **+**. Then:

```bash
xcrun altool --store-password-in-keychain-item --item AC_PASSWORD \
  -u you@example.com -p the-app-specific-password
export ASC_APPLE_ID=you@example.com   # add to your shell profile
```

> **`--item` is required, and altool's own `--help` leaves it out.** Without it you get
> `Expected item argument is missing, --item. (29)` — which reads as though you omitted the
> name you just typed. Verified against altool 26.40.1 shipped with Xcode 26.

### 2b. Get an API key (better for CI)

App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** →
**+**. Role: **App Manager**. Download the `.p8` — **you get exactly one chance**, it cannot be
downloaded again.

Put these in your shell profile:

```bash
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_PATH=~/private_keys/AuthKey_XXXXXXXXXX.p8
```

Skip this if you would rather drag the file into Transporter.

---

## Optional but worth it: drive App Store Connect from here

`asc-mcp` exposes App Store Connect as MCP tools, so builds, testers, feedback and reviews can
be handled in conversation instead of by clicking. Already installed at `~/.mint/bin/asc-mcp`.

```bash
./scripts/asc-setup.sh ~/Downloads/AuthKey_XXXXXXXXXX.p8 <KEY_ID> <ISSUER_ID>
```

That moves the key to `~/.keys` at 0600, links it where `altool` searches — it will not accept
a path, only a fixed set of directories, which is why the **same key covers uploading and the
MCP** — writes the config, and registers the server. Restart Claude Code afterwards.

**It is deliberately scoped.** The server ships 502 tools across 33 domains; ten workers are
enabled:

`apps` · `builds` · `build_uploads` · `beta_app` · `beta_groups` · `beta_testers` ·
`beta_feedback` · `pre_release` · `export_compliance` · `reviews`

Pricing, subscriptions, in-app purchases, users and provisioning are not exposed at all. The
key's role still permits them at Apple's end — the point is that the tools to reach them do
not exist in the session, so an accident cannot. Verified: an unknown worker name is rejected
and the server falls back to the core three rather than silently enabling everything.

---

## Every build

```bash
./scripts/testflight.sh --upload
```

That bumps the build number, archives, exports a signed `.ipa`, and uploads it. Without
`--upload` it stops after the `.ipa` and you can drag that into **Transporter.app**.

Then wait. **Processing takes 5–15 minutes** and the build simply is not there until it
finishes — the most common "it's broken" is impatience.

### Add testers

App Store Connect → your app → **TestFlight**.

- **Internal**: Users and Access → add them as users first, then add to an internal group.
  They get an email, install TestFlight, and it appears.
- **External**: create a group, add emails or use a public link. Fill in **What to Test**, then
  submit for Beta App Review.

---

## What Apple checks before external testing

ChinGo's state as of this writing:

- ✅ App icon — 1024, no alpha
- ✅ `PrivacyInfo.xcprivacy` — **missing this fails at upload**, not review, so it blocks
  everything
- ✅ Export compliance — `ITSAppUsesNonExemptEncryption: false`, which skips the questionnaire
  on every single upload
- ✅ Purpose strings naming the actual feature
- ✅ Age gate
- ⬜ **Privacy policy URL** — required for external testers
- ⬜ **In-app account deletion** — required once accounts exist (5.1.1(v))
- ⬜ **Report and block** — required once people can see each other's content (1.2)
- ⬜ **Demo account** in review notes — required once there is a login
- ⬜ **Review notes explaining the two-device catch** — one reviewer with one phone cannot
  trigger it, and an untestable core feature is a rejection

The last five are not needed for **internal** testing. They are all needed before external.

---

## Things that waste an afternoon

- **Duplicate build number.** App Store Connect refuses a build number it has seen before, and
  it tells you after the archive. The script bumps it for you.
- **Version in the plist not matching the build setting.** XcodeGen writes a default `1.0`
  unless `CFBundleShortVersionString` is wired to `$(MARKETING_VERSION)`. It is, now.
- **Renaming the bundle ID after a build exists.** You cannot. It means a whole new app record.
- **Expecting a build instantly.** 5–15 minutes of processing, every time.
- **Missing compliance answers.** Handled by the `ITSAppUsesNonExemptEncryption` key already in
  `project.yml`.
