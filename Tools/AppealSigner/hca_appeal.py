#!/usr/bin/env python3
"""Hardcore Achievements appeal code signer (admin-only tool, not shipped with the addon).

See README.md in this folder for the token format. Requires: pip install cryptography
"""
import argparse
import base64
import datetime
import os
import re
import secrets
import sys
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

PREFIX = "HCA:"
VERSION = "1"
KEY_BITS = 1024
SIG_LEN = KEY_BITS // 8
REPO_ROOT = Path(__file__).resolve().parents[2]
ADDON_LUA = REPO_ROOT / "Utils" / "AppealCodes.lua"
DEFAULT_KEY = Path.home() / ".hca" / "appeal_signing_key.pem"

OPS = {
    "complete": "C",
    "update": "U",
    "delete": "D",
    "delete-permanent": "DP",
    "unban": "UB",
    "gf-override": "GO",
    "gf-clear": "GC",
}

GUID_RE = re.compile(r"^Player-\d+-[0-9A-Fa-f]+$")
NAME_BAD_RE = re.compile(r"[\x00-\x20\x7f,;=]")


def b64u_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def fail(msg: str):
    sys.exit(f"error: {msg}")


# ---------------------------------------------------------------------------
# Field validation (mirrors Utils/AppealCodes.lua exactly)
# ---------------------------------------------------------------------------
def check_guid(guid: str, what="GUID") -> str:
    if not GUID_RE.fullmatch(guid) or len(guid) > 64:
        fail(f"{what} must look like Player-1234-0ABC1234 (copy it from /hca appeal), got {guid!r}")
    return guid


def check_ach_id(ach: str) -> str:
    raw = ach.encode("utf-8")
    if not 1 <= len(raw) <= 64:
        fail("achievement ID must be 1-64 bytes")
    if ";" in ach or re.search(r"[\x00-\x1f\x7f]", ach) or ach != ach.strip(" \t\n\v\f\r"):
        fail("achievement ID may not contain ';', control characters, or leading/trailing spaces")
    return ach


def check_name(name: str) -> str:
    if not 1 <= len(name.encode("utf-8")) <= 48 or NAME_BAD_RE.search(name):
        fail("winner name must be 1-48 bytes without spaces, ',', ';' or '='")
    return name


def parse_date(text: str) -> str:
    try:
        d = datetime.datetime.strptime(text.replace("-", ""), "%Y%m%d").date()
    except ValueError:
        fail("date must be YYYY-MM-DD")
    if not 2004 <= d.year <= 2099:
        fail("date year must be 2004-2099")
    return d.strftime("%Y%m%d")


def build_options(op: str, a) -> str:
    if op != "GO" and (a.winner_name or a.winner_guid):
        fail("--winner-name/--winner-guid only apply to gf-override")
    if op in ("C", "U"):
        parts = []
        if a.points is not None:
            if not 0 <= a.points <= 100000:
                fail("points must be 0-100000")
            parts.append(f"p={a.points}")
        if a.level is not None:
            if not 1 <= a.level <= 255:
                fail("level must be 1-255")
            parts.append(f"l={a.level}")
        if a.solo:
            parts.append("s=1")
        if a.date:
            parts.append(f"d={parse_date(a.date)}")
        return ",".join(parts)
    if any(v not in (None, False) for v in (a.points, a.level, a.solo, a.date)):
        fail("--points/--level/--solo/--date only apply to complete and update")
    if op == "GO":
        if not a.winner_name or not a.winner_guid:
            fail("gf-override requires --winner-name and --winner-guid")
        return f"n={check_name(a.winner_name)},g={check_guid(a.winner_guid, 'winner GUID')}"
    return ""


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
def load_private_key(path: Path):
    if not path.exists():
        fail(f"signing key not found at {path} (run keygen first)")
    return serialization.load_pem_private_key(path.read_bytes(), password=None)


def modulus_line(key) -> str:
    modulus = key.public_key().public_numbers().n.to_bytes(SIG_LEN, "big")
    return f'local PUBLIC_MODULUS_B64 = "{b64u_encode(modulus)}"'


def cmd_keygen(a):
    path = Path(a.out).resolve()
    if path == REPO_ROOT or REPO_ROOT in path.parents:
        fail("refusing to write the private key inside the addon folder")
    if path.exists():
        fail(f"{path} already exists; refusing to overwrite (move it away first)")
    key = rsa.generate_private_key(public_exponent=65537, key_size=KEY_BITS)
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(pem)
    print(f"Private key written to {path}  (back it up; never commit or share it)")
    print("Paste this line into Utils/AppealCodes.lua:")
    print(modulus_line(key))


def cmd_pubkey(a):
    print(modulus_line(load_private_key(Path(a.key))))


def cmd_sign(a):
    op = OPS[a.operation]
    guid = check_guid(a.guid)
    ach = check_ach_id(a.achievement)
    opts = build_options(op, a)
    cid = b64u_encode(secrets.token_bytes(12))

    key = load_private_key(Path(a.key))
    if modulus_line(key) not in ADDON_LUA.read_text(encoding="utf-8"):
        print("warning: this key does not match PUBLIC_MODULUS_B64 in Utils/AppealCodes.lua", file=sys.stderr)

    payload = ";".join([VERSION, cid, guid, op, ach, opts]).encode("utf-8")
    sig = key.sign(payload, padding.PKCS1v15(), hashes.SHA256())
    print(PREFIX + b64u_encode(payload + sig))
    print(f"\n  payload: {payload.decode('utf-8')}", file=sys.stderr)


def main(argv=None):
    p = argparse.ArgumentParser(description="Hardcore Achievements appeal code signer")
    sub = p.add_subparsers(dest="cmd", required=True)

    k = sub.add_parser("keygen", help="create the RSA-1024 signing key (once)")
    k.add_argument("--out", default=str(DEFAULT_KEY))
    k.set_defaults(func=cmd_keygen)

    pk = sub.add_parser("pubkey", help="print the Lua public-key line for the signing key")
    pk.add_argument("--key", default=str(DEFAULT_KEY))
    pk.set_defaults(func=cmd_pubkey)

    s = sub.add_parser("sign", help="create an appeal code")
    s.add_argument("operation", choices=list(OPS))
    s.add_argument("guid", help="player GUID shown in the /hca appeal window")
    s.add_argument("achievement", help="achievement ID, e.g. \"Sha'tari Skyguard\"")
    s.add_argument("--points", type=int)
    s.add_argument("--level", type=int)
    s.add_argument("--solo", action="store_true")
    s.add_argument("--date", help="completion date YYYY-MM-DD (keeps the original time of day)")
    s.add_argument("--winner-name")
    s.add_argument("--winner-guid")
    s.add_argument("--key", default=str(DEFAULT_KEY))
    s.set_defaults(func=cmd_sign)

    a = p.parse_args(argv)
    a.func(a)


if __name__ == "__main__":
    main()
