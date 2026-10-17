# CampusVote

Confidential student elections, built with **Flutter + Firebase (free Spark plan)**.

Every ballot is **encrypted on the voter's device** before it reaches Firebase.
While voting is open, nobody (not the host, not the developer, not someone
with full access to the Firebase console) can see who is winning or how
anyone voted. Results are decrypted on the host's device only after voting
closes.

- **Host app** (Android / iOS / web): create elections, upload eligible matric
  numbers, share a link + QR code, watch live turnout, close voting, decrypt
  and publish results.
- **Voter page** (web link, no install): sign in, verify matric number, vote,
  get a receipt code, verify it was counted once results are out.

---

## 1. Setup (about 20 minutes)

You need: Flutter 3.29 or newer, Node.js (for the Firebase CLI), and a Google account.

```bash
# 1. In this folder, generate the platform folders (does not overwrite lib/)
flutter create . --platforms=android,ios,web --project-name campus_vote

# 2. Install packages and run the tests
flutter pub get
flutter test
```

### Firebase (Spark plan)

1. Go to <https://console.firebase.google.com> and create a project (Spark / free is fine).
2. **Build → Authentication → Get started → Sign-in method → Email/Password → Enable.**
3. **Build → Firestore Database → Create database** (production mode, pick a nearby location like `europe-west`).
4. Connect the app:

```bash
npm install -g firebase-tools
firebase login
firebase use --add                     # choose your project

dart pub global activate flutterfire_cli
flutterfire configure                  # pick android, ios, web — this replaces lib/firebase_options.dart
```

5. Deploy the security rules (this is what makes the voting secure):

```bash
firebase deploy --only firestore:rules
```

> **Android:** if the build complains about `minSdk`, set `minSdk = 23` in
> `android/app/build.gradle(.kts)`.

### Deploy the voter website

```bash
flutter build web --release
firebase deploy --only hosting
```

The CLI prints your URL, e.g. `https://campusvote-abc12.web.app`.
Put it in `lib/config.dart` → `webBaseUrl` so share links from the **mobile**
host app point to the website, then rebuild the mobile app.
(The web build uses its own address automatically.)

### Run the host app on your phone

```bash
flutter run            # Android/iOS device
flutter run -d chrome  # or host from the browser
```

---

## 2. How it works

```
 Host device                    Firebase (Spark)                     Voter phone (web link)
 ───────────                    ────────────────                     ──────────────────────
 generate X25519 key pair ──►   elections/{id}.publicKey  ─────────► download public key
 private key stays HERE         (public key only)                    encrypt ballot locally
                                                                      │
                                voters/{uid}        ◄──── ONE batch ──┤ "this person voted"
                                eligible/{matric}   ◄──── write   ────┤ "matric used"
                                ballots/{random}    ◄─────────────────┘ ciphertext only
 after close: download ◄─────── ballots (unreadable)
 ballots, decrypt, count ─────► public/results (totals + receipt list)
```

**Encryption (lib/services/ballot_crypto.dart)**
- Each election has an **X25519** key pair. The public key is stored in Firestore.
  The private key is never uploaded. It's saved on the host's device and shown once for backup.
- To vote, the voter's device creates a one-time key pair, derives a shared
  secret with the election public key, runs **HKDF-SHA256** to get an
  **AES-256-GCM** key, and encrypts the ballot.
- Ballots are **padded to 1024 bytes** so ciphertext size reveals nothing.
- The election id is bound as **associated data**, so a ballot can't be copied into another election.
- GCM's authentication tag means a modified ballot fails to decrypt and is counted as invalid.

**Optional 2-key results.** When "Require an electoral officer key" is on,
the private key is split: `private = hostShare XOR officerShare`. Neither
share alone reveals anything, so results need both people.

**Anonymity.** *Who voted* (`voters/{uid}`) and *what was voted*
(`ballots/{randomId}`) are separate documents with nothing linking them: no
user id, no matric number, no timestamp on the ballot.

**One person, one vote, without Cloud Functions** (`firestore.rules`).
The vote is one atomic batched write. The rules cross-check the three documents:
- a ballot can only be created if `voters/{uid}` did **not** exist before
  the write and **does** exist after it (`exists` / `existsAfter`);
- `voters/{uid}` can only be created if the matric number was unused before
  and is claimed by this user after (`get` / `getAfter`);
- all of this only while `status == 'open'` **and** the **server clock** is
  inside the voting window;
- ballots and voter records can never be edited or deleted.

**Receipts.** Each voter gets a code = first 8 bytes of SHA-256(ciphertext).
After results are published, voters enter it to confirm their ballot was in
the count. It proves inclusion without revealing the choice.

**Audit summary.** The results page compares number of ballots vs number of
voters, so any tampering with the ballot count is visible to everyone.

---

## 3. Known limitations (say these yourself in the defence)

1. **Timing correlation.** Google/Firebase project admins could, in theory,
   use infrastructure logs to match the time a voter record and a ballot were
   written. Future work: a separate ballot server or a mix-net that shuffles ballots.
2. **The host could decrypt early** (if single-key mode) by downloading ciphertexts
   manually. The app's UI doesn't allow it, and **2-key mode** prevents it.
3. **A hand-crafted request could add 2 ballots in one batch.** The rules
   can't count documents, but the audit summary flags `ballots ≠ voters`.
4. **Matric impersonation.** Anyone who knows another student's matric number
   could claim it first. Future work: school-email verification or OTP via the
   student portal.
5. On the web, the host key is kept in browser storage, so keep the backup.

---

## 4. Defence demo script (~5 minutes)

1. **Create** an election on your phone: e.g. "NACOS Demo Election", positions
   *President* and *PRO*, 2–3 candidates each, 2-key mode on.
   Show the key backup screen and send the officer key to a panel member.
2. **Paste** 5–10 matric numbers and **open voting**.
3. Show the **QR code**. Have 3–4 people scan and vote on their phones.
4. Show **live turnout** going up, with no results visible anywhere.
5. Open the **Firebase console → Firestore → ballots**: only unreadable ciphertext.
6. **Close voting → Decrypt & publish**: enter the officer key, and results appear.
7. A voter enters their **receipt** on the results page and gets "Found".
8. Bonus: try voting twice, or after closing, and show the rejection.

---

## 5. Project structure

```
lib/
  main.dart, router.dart, theme.dart, config.dart
  models/election.dart              Election, Position, Candidate, Results
  services/ballot_crypto.dart       encryption, key split, receipts
  services/election_service.dart    Firestore reads/writes, voting batch, tally
  services/auth_service.dart        email/password auth
  services/key_store.dart           on-device storage (host key, receipt)
  screens/landing_screen.dart
  screens/auth_screen.dart
  screens/host/                     home, create, key backup, dashboard
  screens/voter/                    entry (link), ballot, receipt
  screens/results_screen.dart
  widgets/
firestore.rules                     the security model
test/ballot_crypto_test.dart        crypto unit tests
```

## Spark plan notes

Uses only **Auth, Firestore and Hosting**, all of which are free. No Cloud Functions,
no Cloud Storage, no SMS. Free Firestore quota (50k reads / 20k writes per
day) easily covers a departmental election.
