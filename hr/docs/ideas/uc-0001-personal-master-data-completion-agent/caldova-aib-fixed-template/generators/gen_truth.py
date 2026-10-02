# -*- coding: utf-8 -*-
"""Ground truth: expected extraction per document per field."""
import os, sys, csv, json

PACKAGE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

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
    personas = people()
    fixed_documents = []
    for collection_index, (folder, _function, _name) in enumerate(
        gen_fixed.COLLECTIONS
    ):
        for document_index in range(6):
            person = personas[(collection_index * 6 + document_index) % 24]
            fixed_documents.append(
                (
                    f"{folder[0]}{document_index + 1:02d}-"
                    f"{person['candidate_id']}-{person['last_name'].lower()}.pdf",
                    folder,
                    person,
                )
            )
    count, present, total = write(
        PACKAGE_ROOT,
        rows_for(fixed_documents, FIXED_COVER, lambda group: group),
        "fixed-template",
    )
    print(
        f"fixed  : {count} docs, {present}/{total} field values present "
        f"({total - present} deliberate gaps)"
    )
