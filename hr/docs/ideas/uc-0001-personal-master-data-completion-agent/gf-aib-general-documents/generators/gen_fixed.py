# -*- coding: utf-8 -*-
"""Fixed-template package: 4 collections x 6 docs. Layout constant, values vary."""
import os, sys
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from personas import people

W, H = A4
NAVY = (0.047, 0.208, 0.349)
GREY = (0.38, 0.37, 0.36)
LINE = (0.80, 0.79, 0.78)

def hdr(c, org, sub, ref):
    c.setFillColorRGB(*NAVY); c.rect(0, H-26*mm, W, 26*mm, stroke=0, fill=1)
    c.setFillColorRGB(1,1,1); c.setFont("Helvetica-Bold", 15)
    c.drawString(20*mm, H-15*mm, org)
    c.setFont("Helvetica", 9); c.drawString(20*mm, H-21*mm, sub)
    c.setFont("Helvetica", 8); c.drawRightString(W-20*mm, H-15*mm, ref)

def foot(c, note):
    c.setFillColorRGB(*GREY); c.setFont("Helvetica-Oblique", 7)
    c.drawString(20*mm, 14*mm, "SYNTHETIC TEST DOCUMENT - fictional data, generated for AI Builder model training. Not a real person.")
    c.drawString(20*mm, 10.5*mm, note)

def label(c, x, y, t):
    c.setFillColorRGB(*GREY); c.setFont("Helvetica", 8); c.drawString(x, y, t)

def value(c, x, y, t, bold=False, size=10):
    c.setFillColorRGB(0.1,0.1,0.1); c.setFont("Helvetica-Bold" if bold else "Helvetica", size)
    c.drawString(x, y, t if t else "")

def rule(c, y, x0=20*mm, x1=None):
    c.setStrokeColorRGB(*LINE); c.setLineWidth(0.5); c.line(x0, y, x1 or W-20*mm, y)

def box(c, x, y, w, h):
    c.setStrokeColorRGB(*LINE); c.setLineWidth(0.5); c.rect(x, y, w, h, stroke=1, fill=0)

def section(c, y, t):
    c.setFillColorRGB(*NAVY); c.setFont("Helvetica-Bold", 9.5); c.drawString(20*mm, y, t)
    rule(c, y-2.5*mm)

# ---------------- Collection A : GF Personalblatt ----------------
def personalblatt(path, p, seq):
    c = canvas.Canvas(path, pagesize=A4)
    hdr(c, "GF  Georg Fischer", "Personalblatt - Eintritt", f"PB-{seq:04d}")
    y = H-38*mm
    c.setFillColorRGB(0.1,0.1,0.1); c.setFont("Helvetica-Bold", 13)
    c.drawString(20*mm, y, "Personalstammdaten Erfassung"); y -= 6*mm
    label(c, 20*mm, y, "Kandidaten-Nr."); value(c, 50*mm, y, p["candidate_id"], bold=True)
    y -= 10*mm
    section(c, y, "1  PERSONALIEN"); y -= 9*mm
    label(c, 20*mm, y, "Vorname");      value(c, 20*mm, y-5*mm, p["first_name"])
    label(c, 80*mm, y, "Name");         value(c, 80*mm, y-5*mm, p["last_name"])
    label(c, 140*mm, y, "Geburtsdatum");value(c, 140*mm, y-5*mm, p["dob"])
    y -= 14*mm
    label(c, 20*mm, y, "Nationalitaet");    value(c, 20*mm, y-5*mm, p["nationality"])
    label(c, 80*mm, y, "Zivilstand");       value(c, 80*mm, y-5*mm, p["marital"])
    label(c, 140*mm, y, "Heimatort");       value(c, 140*mm, y-5*mm, p["heimatort"])
    y -= 14*mm
    label(c, 20*mm, y, "AHV-Nummer");   value(c, 20*mm, y-5*mm, p["ahv"], bold=True)
    label(c, 80*mm, y, "Bewilligung");  value(c, 80*mm, y-5*mm, p["permit"])
    y -= 16*mm
    section(c, y, "2  WOHNADRESSE"); y -= 9*mm
    label(c, 20*mm, y, "Strasse / Nr.");  value(c, 20*mm, y-5*mm, p["street"])
    label(c, 110*mm, y, "PLZ");           value(c, 110*mm, y-5*mm, p["plz"], bold=True)
    label(c, 130*mm, y, "Ort");           value(c, 130*mm, y-5*mm, p["city"])
    y -= 16*mm
    section(c, y, "3  KONTAKT PRIVAT"); y -= 9*mm
    label(c, 20*mm, y, "Telefon privat"); value(c, 20*mm, y-5*mm, p["phone"])
    label(c, 90*mm, y, "E-Mail privat");  value(c, 90*mm, y-5*mm, p["email"])
    y -= 16*mm
    section(c, y, "4  NOTFALLKONTAKT"); y -= 9*mm
    label(c, 20*mm, y, "Name");     value(c, 20*mm, y-5*mm, p["ec_name"])
    label(c, 90*mm, y, "Telefon");  value(c, 90*mm, y-5*mm, p["ec_phone"])
    y -= 16*mm
    section(c, y, "5  ZAHLUNGSVERBINDUNG"); y -= 9*mm
    label(c, 20*mm, y, "IBAN"); value(c, 20*mm, y-5*mm, p["iban"], bold=True, size=10.5)
    y -= 20*mm
    box(c, 20*mm, y-10*mm, 70*mm, 16*mm); label(c, 22*mm, y-14*mm, "Unterschrift Mitarbeitende/r")
    box(c, 110*mm, y-10*mm, 60*mm, 16*mm); label(c, 112*mm, y-14*mm, "Datum")
    foot(c, "Collection A - Personalblatt | Fixed template")
    c.showPage(); c.save()

# ---------------- Collection B : Anmeldung Gemeinde ----------------
def anmeldung(path, p, seq):
    c = canvas.Canvas(path, pagesize=A4)
    hdr(c, f"Einwohnerkontrolle {p['city']}", "Anmeldebestaetigung", f"EWK-{seq:04d}")
    y = H-40*mm
    c.setFillColorRGB(0.1,0.1,0.1); c.setFont("Helvetica-Bold", 12)
    c.drawString(20*mm, y, "Bestaetigung der Anmeldung"); y -= 8*mm
    c.setFont("Helvetica", 9); c.setFillColorRGB(*GREY)
    c.drawString(20*mm, y, "Die nachstehend aufgefuehrte Person hat sich bei der Einwohnerkontrolle angemeldet.")
    y -= 12*mm
    # two-column label/value block, fixed positions
    rows = [("Name, Vorname", f"{p['last_name']}, {p['first_name']}"),
            ("Geburtsdatum", p["dob"]),
            ("Buergerort / Heimatort", p["heimatort"]),
            ("Staatsangehoerigkeit", p["nationality"]),
            ("Zivilstand", p["marital"]),
            ("Ausweisart", p["permit"])]
    for lab, val in rows:
        label(c, 20*mm, y, lab); value(c, 75*mm, y, val); rule(c, y-2*mm); y -= 9*mm
    y -= 6*mm
    section(c, y, "WOHNSITZ"); y -= 10*mm
    label(c, 20*mm, y, "Strasse"); value(c, 75*mm, y, p["street"]); rule(c, y-2*mm); y -= 9*mm
    label(c, 20*mm, y, "Postleitzahl"); value(c, 75*mm, y, p["plz"], bold=True); rule(c, y-2*mm); y -= 9*mm
    label(c, 20*mm, y, "Wohnort"); value(c, 75*mm, y, p["city"]); rule(c, y-2*mm); y -= 9*mm
    label(c, 20*mm, y, "AHV-Nummer"); value(c, 75*mm, y, p["ahv"]); rule(c, y-2*mm); y -= 16*mm
    c.setFont("Helvetica", 8.5); c.setFillColorRGB(*GREY)
    c.drawString(20*mm, y, "Diese Bestaetigung dient ausschliesslich Testzwecken.")
    y -= 22*mm
    box(c, 20*mm, y, 75*mm, 18*mm); label(c, 22*mm, y-4*mm, "Stempel Einwohnerkontrolle")
    foot(c, "Collection B - Anmeldung Gemeinde | Fixed template")
    c.showPage(); c.save()

# ---------------- Collection C : Sozialversicherung ----------------
def sozial(path, p, seq):
    c = canvas.Canvas(path, pagesize=A4)
    hdr(c, "Ausgleichskasse", "Meldung Sozialversicherung / AHV", f"SV-{seq:04d}")
    y = H-42*mm
    c.setFillColorRGB(0.1,0.1,0.1); c.setFont("Helvetica-Bold", 12)
    c.drawString(20*mm, y, "Versichertenmeldung"); y -= 10*mm
    box(c, 20*mm, y-14*mm, W-40*mm, 16*mm)
    label(c, 24*mm, y-4*mm, "Versichertennummer (AHV)")
    value(c, 24*mm, y-11*mm, p["ahv"], bold=True, size=13)
    y -= 26*mm
    section(c, y, "VERSICHERTE PERSON"); y -= 10*mm
    label(c, 20*mm, y, "Name");         value(c, 20*mm, y-5.5*mm, p["last_name"])
    label(c, 75*mm, y, "Vorname");      value(c, 75*mm, y-5.5*mm, p["first_name"])
    label(c, 130*mm, y, "Geburtsdatum");value(c, 130*mm, y-5.5*mm, p["dob"])
    y -= 15*mm
    label(c, 20*mm, y, "Zivilstand");      value(c, 20*mm, y-5.5*mm, p["marital"])
    label(c, 75*mm, y, "Staatsangeh.");    value(c, 75*mm, y-5.5*mm, p["nationality"])
    label(c, 130*mm, y, "Heimatort");      value(c, 130*mm, y-5.5*mm, p["heimatort"])
    y -= 17*mm
    section(c, y, "ZUSTELLADRESSE"); y -= 10*mm
    value(c, 20*mm, y, p["street"]); y -= 5.5*mm
    value(c, 20*mm, y, f"{p['plz']}  {p['city']}"); y -= 16*mm
    section(c, y, "AUSZAHLUNG"); y -= 10*mm
    label(c, 20*mm, y, "IBAN"); value(c, 20*mm, y-5.5*mm, p["iban"], bold=True)
    y -= 18*mm
    section(c, y, "ARBEITGEBER"); y -= 10*mm
    value(c, 20*mm, y, "Georg Fischer AG, Amsler-Laffon-Strasse 9, 8201 Schaffhausen")
    foot(c, "Collection C - Sozialversicherung | Fixed template")
    c.showPage(); c.save()

# ---------------- Collection D : Bankverbindung ----------------
def bank(path, p, seq):
    c = canvas.Canvas(path, pagesize=A4)
    hdr(c, "GF  Georg Fischer", "Zahlungsverbindung Lohn", f"BV-{seq:04d}")
    y = H-40*mm
    c.setFillColorRGB(0.1,0.1,0.1); c.setFont("Helvetica-Bold", 12.5)
    c.drawString(20*mm, y, "Meldung Bankverbindung"); y -= 7*mm
    c.setFont("Helvetica", 8.5); c.setFillColorRGB(*GREY)
    c.drawString(20*mm, y, "Bitte vollstaendig ausfuellen und an HR Operations retournieren.")
    y -= 14*mm
    section(c, y, "MITARBEITENDE / R"); y -= 10*mm
    label(c, 20*mm, y, "Kandidaten-Nr."); value(c, 20*mm, y-5.5*mm, p["candidate_id"], bold=True)
    label(c, 75*mm, y, "Name, Vorname");  value(c, 75*mm, y-5.5*mm, f"{p['last_name']}, {p['first_name']}")
    y -= 15*mm
    label(c, 20*mm, y, "Geburtsdatum"); value(c, 20*mm, y-5.5*mm, p["dob"])
    label(c, 75*mm, y, "AHV-Nummer");   value(c, 75*mm, y-5.5*mm, p["ahv"])
    y -= 17*mm
    section(c, y, "KONTOVERBINDUNG"); y -= 11*mm
    box(c, 20*mm, y-9*mm, W-40*mm, 14*mm)
    label(c, 24*mm, y-1*mm, "IBAN")
    value(c, 24*mm, y-7*mm, p["iban"], bold=True, size=12)
    y -= 20*mm
    label(c, 20*mm, y, "Kontoinhaber/in"); value(c, 20*mm, y-5.5*mm, p["full_name"])
    y -= 17*mm
    section(c, y, "ADRESSE KONTOINHABER"); y -= 10*mm
    label(c, 20*mm, y, "Strasse"); value(c, 55*mm, y, p["street"]); y -= 7*mm
    label(c, 20*mm, y, "PLZ / Ort"); value(c, 55*mm, y, f"{p['plz']}  {p['city']}")
    y -= 22*mm
    box(c, 20*mm, y, 70*mm, 16*mm); label(c, 22*mm, y-4*mm, "Unterschrift")
    foot(c, "Collection D - Bankverbindung | Fixed template")
    c.showPage(); c.save()

COLLECTIONS = [("a-personalblatt", personalblatt, "Personalblatt"),
               ("b-anmeldung-gemeinde", anmeldung, "Anmeldung Gemeinde"),
               ("c-sozialversicherung", sozial, "Sozialversicherung"),
               ("d-bankverbindung", bank, "Bankverbindung")]

def build(base):
    made = []
    for ci, (folder, fn, nice) in enumerate(COLLECTIONS):
        d = os.path.join(base, folder); os.makedirs(d, exist_ok=True)
        for i in range(6):                      # 6 per collection = 24 total
            p = people()[(ci*6 + i) % 24]
            name = f"{folder[0]}{i+1:02d}-{p['candidate_id']}-{p['last_name'].lower()}.pdf"
            fn(os.path.join(d, name), p, ci*6+i+1)
            made.append((folder, name, p, nice))
    return made

if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pkg-fixed", "documents")
    m = build(out)
    print("generated", len(m), "PDFs across", len(COLLECTIONS), "collections")
