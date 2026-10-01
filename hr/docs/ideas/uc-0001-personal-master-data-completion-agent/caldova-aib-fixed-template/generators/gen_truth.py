# -*- coding: utf-8 -*-
"""Ground truth: expected extraction per document per field."""
import os, sys, csv, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from personas import people
import gen_fixed, gen_general

FIELDS = ["candidate_id","last_name","first_name","dob","nationality","marital","heimatort",
          "permit","street","plz","city","ahv","iban","phone","email","ec_name","ec_phone"]

# Which fields each layout actually carries. "" = field absent -> expected outcome is Missing.
FIXED_COVER = {
 "a-personalblatt":     FIELDS,
 "b-anmeldung-gemeinde":["last_name","first_name","dob","nationality","marital","heimatort","permit","street","plz","city","ahv"],
 "c-sozialversicherung":["last_name","first_name","dob","nationality","marital","heimatort","street","plz","city","ahv","iban"],
 "d-bankverbindung":    ["candidate_id","last_name","first_name","dob","ahv","iban","street","plz","city"],
}
GEN_COVER = {
 "arbeitsvertrag":   ["candidate_id","last_name","first_name","dob","nationality","marital","heimatort","permit","street","plz","city","ahv","iban","phone","email","ec_name","ec_phone"],
 "anschreiben":      ["candidate_id","last_name","first_name","dob","nationality","marital","heimatort","street","plz","city","ahv","iban","phone","email","ec_name","ec_phone"],
 "bewilligung":      ["last_name","first_name","dob","nationality","marital","permit","street","plz","city","ahv"],
 "versicherung":     ["last_name","first_name","dob","nationality","marital","heimatort","street","plz","city","ahv","iban","phone","email","ec_name","ec_phone"],
 "zivilstand":       ["last_name","first_name","dob","nationality","marital","heimatort","street","plz","city","ahv"],
 "selbstdeklaration":FIELDS,
 "scan-degraded":    ["last_name","first_name","dob","nationality","marital","heimatort","street","plz","city","ahv","iban","phone","email","ec_name","ec_phone"],
 "new-joiner-sheet": FIELDS,
}

def rows_for(docs, cover_map, key_of):
    out = []
    for name, group, p in docs:
        cov = cover_map[key_of(group)]
        r = {"document": name, "collection_or_layout": group, "candidate_id_expected": p["candidate_id"]}
        for f in FIELDS:
            r[f] = p[f] if f in cov else ""
        out.append(r)
    return out

def write(base, rows, label):
    os.makedirs(base, exist_ok=True)
    cp = os.path.join(base, "ground-truth.csv")
    with open(cp, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    jp = os.path.join(base, "ground-truth.json")
    with open(jp, "w", encoding="utf-8") as fh:
        json.dump({"package": label, "field_count": len(FIELDS),
                   "note": "Empty string = field is ABSENT from that document. Expected agent outcome is 'Missing', not an extraction error.",
                   "documents": rows}, fh, indent=2, ensure_ascii=False)
    present = sum(1 for r in rows for f in FIELDS if r[f])
    total = len(rows)*len(FIELDS)
    return len(rows), present, total

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    ps = people()

    fx = []
    for ci,(folder,_fn,_nice) in enumerate(gen_fixed.COLLECTIONS):
        for i in range(6):
            p = ps[(ci*6+i)%24]
            fx.append((f"{folder[0]}{i+1:02d}-{p['candidate_id']}-{p['last_name'].lower()}.pdf", folder, p))
    n,pr,to = write(os.path.join(here,"pkg-fixed"), rows_for(fx, FIXED_COVER, lambda g: g), "fixed-template")
    print(f"fixed  : {n} docs, {pr}/{to} field values present ({to-pr} deliberate gaps)")

    gn = []; k=0
    for li,(nm,_fn) in enumerate(gen_general.LAYOUTS):
        for j in range(3):
            p = ps[(li*3+j)%24]; k+=1
            gn.append((f"g{k:02d}-{nm}-{p['candidate_id']}.pdf", nm, p))
    n,pr,to = write(os.path.join(here,"pkg-general"), rows_for(gn, GEN_COVER, lambda g: g), "general-documents")
    print(f"general: {n} docs, {pr}/{to} field values present ({to-pr} deliberate gaps)")
