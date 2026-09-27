import { HDKey } from "@scure/bip32";
import { bech32 } from "@scure/base";
import { sha256 } from "@noble/hashes/sha2.js";
import { ripemd160 } from "@noble/hashes/legacy.js";

// Kennungen der erweiterten oeffentlichen Schluessel. zpub ist BIP84 (native
// SegWit), xpub dasselbe mit der alten Kennung, wie manche Wallets es zeigen.
const KENNUNG = { zpub: 0x04b24746, xpub: 0x0488b21e };

export function adresse(schluessel, index) {
  const art = schluessel.slice(0, 4);
  if (!(art in KENNUNG)) throw new Error("nur zpub oder xpub");
  const konto = HDKey.fromExtendedKey(schluessel, { public: KENNUNG[art], private: 0 });
  const kind = konto.deriveChild(0).deriveChild(index);
  const h = ripemd160(sha256(kind.publicKey));
  return bech32.encode("bc", [0, ...bech32.toWords(h)]);
}
