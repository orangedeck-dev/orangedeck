// Prueft die gebuendelte Ableitung gegen den Testvektor aus BIP84
// (Mnemonic "abandon abandon ... about", Konto m/84'/0'/0').
//
//   node tools/spenden/test.mjs            nur der Testvektor
//   node tools/spenden/test.mjs <zpub> 20  zeigt die ersten 20 Empfangsadressen,
//                                          zum Vergleich mit Sparrow (Reiter
//                                          Addresses), bevor die Seite sie ausgibt
import { readFileSync } from "node:fs";

const quelle = new URL("../../functions/_lib/ableitung.js", import.meta.url);
const { adresse } = await import("data:text/javascript;base64," +
  readFileSync(quelle).toString("base64"));

const zpub = "zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs";
const soll = ["bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu",
              "bc1qnjg0jd8228aq7egyzacy8cys3knf9xvrerkf9g"];
let fehler = 0;
soll.forEach((s, i) => {
  const ist = adresse(zpub, i);
  if (ist !== s) { fehler++; console.log("FALSCH", i, ist, "soll", s); }
});
console.log(fehler ? "Testvektor: FEHLER" : "Testvektor: beide Adressen stimmen");

const [eigen, anzahl] = process.argv.slice(2);
if (eigen) for (let i = 0; i < Number(anzahl || 20); i++) console.log(i, adresse(eigen, i));
process.exit(fehler ? 1 : 0);
