#!/usr/bin/env python3
"""Signe un APK avec le schéma APK Signature Scheme v2 (RSA 2048 / SHA-256).

Utilisé car le SDK Android (apksigner) n'est pas disponible dans l'environnement de build.
Usage : sign_apk.py <entrée.apk> <sortie.apk> [dossier_clé]
La clé et le certificat sont créés dans dossier_clé (par défaut ~/.cardverse-signing) s'ils n'existent pas.
Vérification indépendante : `apksigtool verify sortie.apk`.
"""
import datetime
import hashlib
import os
import struct
import sys

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.x509.oid import NameOID

V2_BLOCK_ID = 0x7109871A
ALGO_RSA_PKCS1_SHA256 = 0x0103
CHUNK = 1024 * 1024
MAGIC = b"APK Sig Block 42"


def load_or_create_key(folder):
    os.makedirs(folder, exist_ok=True)
    kp, cp = os.path.join(folder, "key.pem"), os.path.join(folder, "cert.der")
    if os.path.exists(kp) and os.path.exists(cp):
        key = serialization.load_pem_private_key(open(kp, "rb").read(), None)
        return key, open(cp, "rb").read()
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Cardverse"),
                      x509.NameAttribute(NameOID.ORGANIZATION_NAME, "Cardverse Studio"),
                      x509.NameAttribute(NameOID.COUNTRY_NAME, "FR")])
    now = datetime.datetime(2026, 1, 1)
    cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name)
            .public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now).not_valid_after(now + datetime.timedelta(days=365 * 30))
            .sign(key, hashes.SHA256()))
    der = cert.public_bytes(serialization.Encoding.DER)
    open(kp, "wb").write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                           serialization.NoEncryption()))
    open(cp, "wb").write(der)
    return key, der


def lp(b):
    """Préfixe de longueur uint32 little-endian."""
    return struct.pack("<I", len(b)) + b


def find_eocd(data):
    pos = data.rfind(b"PK\x05\x06", max(0, len(data) - 65557))
    if pos < 0:
        raise SystemExit("EOCD introuvable : ce n'est pas un ZIP valide")
    return pos


def chunked_digest(sections):
    digests = []
    for sec in sections:
        for i in range(0, len(sec), CHUNK):
            c = sec[i:i + CHUNK]
            digests.append(hashlib.sha256(b"\xa5" + struct.pack("<I", len(c)) + c).digest())
    return hashlib.sha256(b"\x5a" + struct.pack("<I", len(digests)) + b"".join(digests)).digest()


def sign(src, dst, keydir):
    data = open(src, "rb").read()
    eocd_pos = find_eocd(data)
    cd_size, cd_off = struct.unpack("<II", data[eocd_pos + 12:eocd_pos + 20])
    if data[cd_off - 16:cd_off] == MAGIC:
        raise SystemExit("APK déjà signé (v2) : utiliser l'APK non signé")
    entries, cd, eocd = data[:cd_off], data[cd_off:cd_off + cd_size], bytearray(data[eocd_pos:])

    digest = chunked_digest([entries, cd, bytes(eocd)])  # offset du CD = offset du bloc de signature
    key, cert = load_or_create_key(keydir)
    pub = key.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)

    digests = lp(lp(struct.pack("<I", ALGO_RSA_PKCS1_SHA256) + lp(digest)))
    signed_data = digests + lp(lp(cert)) + lp(b"")
    sig = key.sign(signed_data, padding.PKCS1v15(), hashes.SHA256())
    signatures = lp(struct.pack("<I", ALGO_RSA_PKCS1_SHA256) + lp(sig))  # séquence d'une signature
    signer = lp(signed_data) + lp(signatures) + lp(pub)
    v2_value = lp(lp(signer))

    pair = struct.pack("<Q", 4 + len(v2_value)) + struct.pack("<I", V2_BLOCK_ID) + v2_value
    block_size = len(pair) + 8 + 16  # paires + taille de fin + magic
    block = struct.pack("<Q", block_size) + pair + struct.pack("<Q", block_size) + MAGIC

    struct.pack_into("<I", eocd, 16, cd_off + len(block))
    open(dst, "wb").write(entries + block + cd + bytes(eocd))
    print(f"APK signé (v2) : {dst} ({os.path.getsize(dst) // 1024} Ko)")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    sign(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else os.path.expanduser("~/.cardverse-signing"))
