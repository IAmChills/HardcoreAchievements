# Appeal codes (admin tool)

Admin corrections (award, update, remove, unban, Guild First fixes) are delivered as **signed appeal codes**.
The admin signs a code offline for one character; the player pastes it into `/hca appeal` and it is applied once.
No whispers, online admin, or shared secret are involved. This folder is excluded from the packaged addon.

## Security model

- Codes are RSA signatures (RSASSA-PKCS1-v1_5, SHA-256, 1024-bit key, e = 65537).
- The addon contains only the public key (`PUBLIC_MODULUS_B64` in `Utils/AppealCodes.lua`).
- The private key lives outside the repository (default `%USERPROFILE%\.hca\appeal_signing_key.pem`) and must never be committed or shared. `.gitignore` blocks `*.pem`/`*.key`, and `keygen` refuses to write inside the addon folder.
- Every field below is covered by the signature. Codes are bound to the full character GUID, never expire, and are single-use per character.
- Accepted limitations: RSA-1024 deters casual forgery, not a well-funded attacker. A player who edits their own addon files or SavedVariables can bypass any client-side check, but that affects only their own client, and corrections still cannot be forged for other players.

## Setup (once)

```
pip install cryptography
python Tools/AppealSigner/hca_appeal.py keygen
```

Paste the printed `local PUBLIC_MODULUS_B64 = "..."` line into `Utils/AppealCodes.lua` and back up the `.pem` file.
`pubkey` reprints that line from an existing key. Generating a new key and updating that line invalidates every previously issued code.

## Issuing a code

1. The player runs `/hca appeal` and sends you the character ID (GUID) shown in the window.
2. Sign the correction:

```
python Tools/AppealSigner/hca_appeal.py sign complete Player-4395-0207A3F9 "Ragefire"
python Tools/AppealSigner/hca_appeal.py sign complete Player-4395-0207A3F9 "Sha'tari Skyguard" --points 25 --level 70 --solo --date 2025-03-14
python Tools/AppealSigner/hca_appeal.py sign update Player-4395-0207A3F9 "Ragefire" --points 10
python Tools/AppealSigner/hca_appeal.py sign delete Player-4395-0207A3F9 "Ragefire"
python Tools/AppealSigner/hca_appeal.py sign delete-permanent Player-4395-0207A3F9 "Ragefire"
python Tools/AppealSigner/hca_appeal.py sign unban Player-4395-0207A3F9 "Ragefire"
python Tools/AppealSigner/hca_appeal.py sign gf-override Player-4395-0207A3F9 "<GuildFirstId>" --winner-name Bob --winner-guid Player-4395-00AB12CD
python Tools/AppealSigner/hca_appeal.py sign gf-clear Player-4395-0207A3F9 "<GuildFirstId>"
```

3. Send the printed `HCA:...` code (~280 characters). The player pastes it into the `/hca appeal` window and clicks **Redeem**.

Guild First codes go through the addon's normal Guild First claim logic, so they only work for a character in a guild where that achievement is in scope. The redeeming character relays the change to its guild, and it must be a member of that guild.

## Token format, version 1

```
code      = "HCA:" base64url( payload || signature )      ; RFC 4648 section 5, no padding, canonical
signature = last 128 bytes                                ; RSASSA-PKCS1-v1_5 / SHA-256 over payload bytes
payload   = "1" ";" cid ";" guid ";" op ";" achId ";" opts ; UTF-8, exactly six fields
cid       = 16 base64url characters (12 random bytes)      ; correction ID, the single-use key
guid      = "Player-" digits "-" hex                       ; compared exactly with UnitGUID("player")
op        = "C" complete | "U" update (force) | "D" delete | "DP" delete permanently
          | "UB" unban | "GO" Guild First override | "GC" Guild First clear
achId     = 1-64 bytes, no ";" or control characters, no leading/trailing whitespace
opts      = "" for D, DP, UB, GC
          | for C/U, any subset in this order, comma separated:
              p=<0..100000>  points (no leading zeros)
              l=<1..255>     level
              s=1            solo
              d=YYYYMMDD     completion date, 2004-2099, valid calendar day
                             (the time of day is kept from the original failure/progress if known)
          | for GO, both required: n=<winner name>,g=<winner Player GUID>
```

Whitespace and backticks are stripped from pasted codes before decoding. Anything else malformed, unknown, repeated, out of order, or out of range rejects the whole code.

Redemption order: parse/validate → verify signature → check GUID → check
`HardcoreAchievementsCharDB[...].redeemedAppeals[cid]` → apply → record `{ at, op, achId }`.
A code is recorded only after the operation succeeds, so a failed code can be retried. Records are never purged.

Results are shown only in the appeal window (nothing is printed to chat), using the achievement's name.
Each failure message starts with the stage that failed, so players can report it:
`Invalid correction code: <what was wrong>`, `Unsupported operation`, `Invalid signature`,
`Incorrect character`, `Already redeemed on <date>`, `Failed to apply correction: <reason>`.

Solo and updates:
- `complete` without `--solo` always records a non-solo completion. With `--solo`, the achievement must be
  solo-eligible on that character (same rule as gameplay), and points are recalculated unless `--points` is given.
- `update` changes only the fields in the code. If nothing differs, the window says the achievement is already
  up to date (the code is still recorded as used). Solo can be turned on but not off.
- `delete` also clears a failed state. For the Ridiculous challenges (no jump, no weapon, nude, no quests,
  Warforged) it restarts the run as clean from the current point, so use it to undo a false failure.
- `delete --permanent` blocks normal earning until `unban`; a signed `complete` overrides it and clears the block.

## Tests

```
pip install cryptography lupa
python Tools/AppealSigner/tests/run_tests.py
```

The suite runs the addon's actual Lua files in Lua 5.1, with stubbed WoW APIs and a throwaway key substituted into the source text. It covers:

- SHA-256 test vectors;
- NIST CAVP SigGen15 and Wycheproof RSA signature vectors (in `tests/vectors/`);
- forged and malformed signatures, tampered or malformed tokens, and replay;
- every admin operation, the window, legacy-system removal, and the signer CLI.
