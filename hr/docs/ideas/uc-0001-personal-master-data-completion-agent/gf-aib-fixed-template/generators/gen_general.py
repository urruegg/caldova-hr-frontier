# -*- coding: utf-8 -*-
"""General-documents package: 24 PDFs, 8 layout families, deliberately varied."""
import os, sys, random
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.utils import simpleSplit
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from personas import people

W, H = A4
random.seed(20260925)

def stamp(c, note, skew=False):
    c.setFillColorRGB(0.45,0.44,0.43); c.setFont("Helvetica-Oblique", 7)
    c.drawString(18*mm, 12*mm, "SYNTHETIC TEST DOCUMENT - fictional data for AI Builder training. Not a real person.")
    c.drawString(18*mm, 8.5*mm, note)

def para(c, x, y, text, width, size=9.5, lead=4.6*mm, font="Helvetica"):
    c.setFont(font, size); c.setFillColorRGB(0.12,0.12,0.12)
    for ln in simpleSplit(text, font, size, width):
        c.drawString(x, y, ln); y -= lead
    return y

# 1 — Arbeitsvertrag extract: dense prose, data inline
def contract(path, p, n):
    c = canvas.Canvas(path, pagesize=A4)
    c.setFont("Helvetica-Bold", 14); c.drawString(22*mm, H-28*mm, "ARBEITSVERTRAG")
    c.setFont("Helvetica", 9); c.setFillColorRGB(0.4,0.4,0.4)
    c.drawString(22*mm, H-34*mm, "zwischen Georg Fischer AG, 8201 Schaffhausen (Arbeitgeberin)")
    c.drawString(22*mm, H-39*mm, "und der nachstehend bezeichneten Person (Arbeitnehmer/in)")
    c.setStrokeColorRGB(0.7,0.7,0.7); c.line(22*mm, H-43*mm, W-22*mm, H-43*mm)
    y = H-54*mm
    t = (f"Herr/Frau {p['full_name']}, geboren am {p['dob']}, "
         f"Staatsangehoerigkeit {p['nationality']}, Zivilstand {p['marital']}, "
         f"wohnhaft {p['street']}, {p['plz']} {p['city']}, "
         f"Heimatort {p['heimatort']}, AHV-Nummer {p['ahv']}, "
         "tritt per 01.11.2026 in die Dienste der Arbeitgeberin ein.")
    y = para(c, 22*mm, y, t, W-44*mm); y -= 5*mm
    y = para(c, 22*mm, y, f"Die Kandidatenreferenz lautet {p['candidate_id']}. "
             f"Die Bewilligungsart ist {p['permit']}.", W-44*mm); y -= 5*mm
    y = para(c, 22*mm, y, "Der Lohn wird monatlich auf das folgende Konto ueberwiesen:", W-44*mm); y -= 2*mm
    c.setFont("Helvetica-Bold", 10.5); c.drawString(28*mm, y, p["iban"]); y -= 10*mm
    y = para(c, 22*mm, y, f"Fuer Rueckfragen ist die Arbeitnehmerin/der Arbeitnehmer unter "
             f"{p['phone']} beziehungsweise {p['email']} erreichbar. Als Notfallkontakt "
             f"wurde {p['ec_name']}, {p['ec_phone']}, bezeichnet.", W-44*mm)
    y -= 12*mm
    y = para(c, 22*mm, y, "Im Uebrigen gelten die Bestimmungen des Schweizerischen "
             "Obligationenrechts sowie das Personalreglement der Arbeitgeberin. "
             "Dieses Dokument ist ein Testdokument und entfaltet keine Rechtswirkung.", W-44*mm, size=8.5)
    y -= 20*mm
    c.setStrokeColorRGB(0.6,0.6,0.6)
    c.line(22*mm, y, 80*mm, y); c.line(110*mm, y, 168*mm, y)
    c.setFont("Helvetica", 8); c.setFillColorRGB(0.4,0.4,0.4)
    c.drawString(22*mm, y-4*mm, "Arbeitgeberin"); c.drawString(110*mm, y-4*mm, "Arbeitnehmer/in")
    stamp(c, f"General documents | Layout 1 - Arbeitsvertrag | doc {n:02d}")
    c.showPage(); c.save()

# 2 — Anschreiben: letter, right-aligned sender block
def letter(path, p, n):
    c = canvas.Canvas(path, pagesize=A4)
    c.setFont("Helvetica", 9.5); c.setFillColorRGB(0.12,0.12,0.12)
    y = H-26*mm
    for ln in [p["full_name"], p["street"], f"{p['plz']} {p['city']}", p["phone"], p["email"]]:
        c.drawRightString(W-22*mm, y, ln); y -= 4.8*mm
    y -= 10*mm
    c.setFont("Helvetica", 9.5)
    for ln in ["Georg Fischer AG", "HR Operations", "Amsler-Laffon-Strasse 9", "8201 Schaffhausen"]:
        c.drawString(22*mm, y, ln); y -= 4.8*mm
    y -= 8*mm
    c.drawRightString(W-22*mm, y, f"{p['city']}, 12. Oktober 2026"); y -= 14*mm
    c.setFont("Helvetica-Bold", 10.5); c.drawString(22*mm, y, "Einreichung der Personalunterlagen"); y -= 10*mm
    y = para(c, 22*mm, y, "Sehr geehrte Damen und Herren", W-44*mm); y -= 3*mm
    y = para(c, 22*mm, y, f"gerne reiche ich Ihnen meine Personalangaben ein. Ich bin am {p['dob']} "
             f"geboren, {p['nationality']}e Staatsangehoerige/r und {p['marital']}. "
             f"Mein Heimatort ist {p['heimatort']}. Meine AHV-Nummer lautet {p['ahv']}.", W-44*mm); y -= 4*mm
    y = para(c, 22*mm, y, f"Die Lohnzahlung erbitte ich auf mein Konto {p['iban']}. "
             f"Als Notfallkontakt nenne ich {p['ec_name']} ({p['ec_phone']}). "
             f"Meine Kandidatennummer ist {p['candidate_id']}.", W-44*mm); y -= 6*mm
    y = para(c, 22*mm, y, "Freundliche Gruesse", W-44*mm); y -= 14*mm
    c.setFont("Helvetica-Oblique", 11); c.drawString(22*mm, y, p["full_name"])
    stamp(c, f"General documents | Layout 2 - Anschreiben | doc {n:02d}")
    c.showPage(); c.save()

# 3 — Aufenthaltsbewilligung: official card-style, two columns
def permit(path, p, n):
    c = canvas.Canvas(path, pagesize=A4)
    c.setFillColorRGB(0.12,0.28,0.18); c.rect(0, H-20*mm, W, 20*mm, stroke=0, fill=1)
    c.setFillColorRGB(1,1,1); c.setFont("Helvetica-Bold", 12)
    c.drawString(22*mm, H-13*mm, "MIGRATIONSAMT - AUFENTHALTSBEWILLIGUNG")
    y = H-32*mm
    c.setFillColorRGB(0.12,0.12,0.12); c.setFont("Helvetica-Bold", 11)
    c.drawString(22*mm, y, "Bewilligungsentscheid"); y -= 10*mm
    left = [("Familienname", p["last_name"]), ("Vorname", p["first_name"]),
            ("Geburtsdatum", p["dob"]), ("Staatsangehoerigkeit", p["nationality"])]
    right = [("Bewilligungsart", p["permit"]), ("Zivilstand", p["marital"]),
             ("AHV-Nr.", p["ahv"]), ("Gueltig bis", "31.10.2029")]
    yy = y
    for lab, val in left:
        c.setFont("Helvetica", 8); c.setFillColorRGB(0.4,0.4,0.4); c.drawString(22*mm, yy, lab)
        c.setFont("Helvetica", 10); c.setFillColorRGB(0.12,0.12,0.12); c.drawString(22*mm, yy-5*mm, val)
        yy -= 13*mm
    yy = y
    for lab, val in right:
        c.setFont("Helvetica", 8); c.setFillColorRGB(0.4,0.4,0.4); c.drawString(110*mm, yy, lab)
        c.setFont("Helvetica", 10); c.setFillColorRGB(0.12,0.12,0.12); c.drawString(110*mm, yy-5*mm, val)
        yy -= 13*mm
    y = yy - 6*mm
    c.setStrokeColorRGB(0.75,0.75,0.75); c.line(22*mm, y, W-22*mm, y); y -= 10*mm
    c.setFont("Helvetica", 8); c.setFillColorRGB(0.4,0.4,0.4); c.drawString(22*mm, y, "Gemeldete Adresse")
    c.setFont("Helvetica", 10); c.setFillColorRGB(0.12,0.12,0.12)
    c.drawString(22*mm, y-6*mm, f"{p['street']}, {p['plz']} {p['city']}")
    y -= 24*mm
    c.setFont("Helvetica", 8.5); c.setFillColorRGB(0.4,0.4,0.4)
    para(c, 22*mm, y, "Dieser Entscheid ist ein Testdokument und hat keine amtliche Gueltigkeit.", W-44*mm, size=8.5)
    stamp(c, f"General documents | Layout 3 - Aufenthaltsbewilligung | doc {n:02d}")
    c.showPage(); c.save()

# 4 — Versicherungspolice: table-driven, boxed
def policy(path, p, n):
    c = canvas.Canvas(path, pagesize=A4)
    c.setFont("Helvetica-Bold", 13); c.setFillColorRGB(0.35,0.10,0.10)
    c.drawString(22*mm, H-26*mm, "VORSORGE  |  Policenauszug")
    c.setFont("Helvetica", 8.5); c.setFillColorRGB(0.4,0.4,0.4)
    c.drawString(22*mm, H-32*mm, f"Police Nr. VP-{n:05d}  -  Ausgabedatum 05.10.2026")
    y = H-44*mm
    rows = [("Versicherte Person", p["full_name"]),
            ("Geburtsdatum", p["dob"]),
            ("AHV-Nummer", p["ahv"]),
            ("Zivilstand", p["marital"]),
            ("Staatsangehoerigkeit", p["nationality"]),
            ("Heimatort", p["heimatort"]),
            ("Adresse", f"{p['street']}, {p['plz']} {p['city']}"),
            ("Telefon", p["phone"]),
            ("E-Mail", p["email"]),
            ("Auszahlungskonto", p["iban"]),
            ("Begunstigte Person", p["ec_name"]),
            ("Kontakt Beguenstigte", p["ec_phone"])]
    c.setStrokeColorRGB(0.82,0.82,0.82); c.setLineWidth(0.5)
    for i, (lab, val) in enumerate(rows):
        if i % 2 == 0:
            c.setFillColorRGB(0.965,0.962,0.960); c.rect(22*mm, y-2.5*mm, W-44*mm, 8*mm, stroke=0, fill=1)
        c.setFillColorRGB(0.35,0.35,0.35); c.setFont("Helvetica", 8.5); c.drawString(25*mm, y, lab)
        c.setFillColorRGB(0.12,0.12,0.12); c.setFont("Helvetica", 9.5); c.drawString(88*mm, y, val)
        y -= 8*mm
    c.rect(22*mm, y+5.5*mm, W-44*mm, (len(rows))*8*mm, stroke=1, fill=0)
    stamp(c, f"General documents | Layout 4 - Versicherungspolice | doc {n:02d}")
    c.showPage(); c.save()

# 5 — Zivilstandsausweis: centred certificate
def civil(path, p, n):
    c = canvas.Canvas(path, pagesize=A4)
    c.setStrokeColorRGB(0.55,0.45,0.20); c.setLineWidth(2)
    c.rect(16*mm, 16*mm, W-32*mm, H-32*mm, stroke=1, fill=0)
    c.setLineWidth(0.5); c.rect(19*mm, 19*mm, W-38*mm, H-38*mm, stroke=1, fill=0)
    c.setFont("Helvetica-Bold", 15); c.setFillColorRGB(0.20,0.17,0.10)
    c.drawCentredString(W/2, H-42*mm, "ZIVILSTANDSAUSWEIS")
    c.setFont("Helvetica", 9); c.setFillColorRGB(0.4,0.4,0.4)
    c.drawCentredString(W/2, H-50*mm, f"Zivilstandsamt {p['city']}")
    y = H-70*mm
    items = [("Name", p["last_name"]), ("Vorname", p["first_name"]),
             ("Geburtsdatum", p["dob"]), ("Heimatort", p["heimatort"]),
             ("Staatsangehoerigkeit", p["nationality"]), ("Zivilstand", p["marital"]),
             ("AHV-Nummer", p["ahv"]), ("Wohnadresse", f"{p['street']}, {p['plz']} {p['city']}")]
    for lab, val in items:
        c.setFont("Helvetica", 8.5); c.setFillColorRGB(0.45,0.42,0.35)
        c.drawCentredString(W/2, y, lab.upper())
        c.setFont("Helvetica-Bold", 11); c.setFillColorRGB(0.12,0.12,0.12)
        c.drawCentredString(W/2, y-6*mm, val)
        y -= 16*mm
    c.setFont("Helvetica-Oblique", 8); c.setFillColorRGB(0.5,0.5,0.5)
    c.drawCentredString(W/2, 34*mm, "Testdokument - ohne amtliche Gueltigkeit")
    stamp(c, f"General documents | Layout 5 - Zivilstandsausweis | doc {n:02d}")
    c.showPage(); c.save()

# 6 — Selbstdeklaration: handwriting-style form, cramped
def declaration(path, p, n):
    c = canvas.Canvas(path, pagesize=A4)
    c.setFont("Courier-Bold", 12); c.setFillColorRGB(0.1,0.1,0.1)
    c.drawString(20*mm, H-24*mm, "SELBSTDEKLARATION  PERSONALDATEN")
    c.setFont("Courier", 8); c.drawString(20*mm, H-29*mm, "Formular HR-04 / Rev. 3 / Seite 1 von 1")
    c.setStrokeColorRGB(0.3,0.3,0.3); c.setLineWidth(1)
    c.line(20*mm, H-32*mm, W-20*mm, H-32*mm)
    y = H-44*mm
    fields = [("Kandidaten-Nr", p["candidate_id"]), ("Nachname", p["last_name"]),
              ("Vorname", p["first_name"]), ("Geb.Datum", p["dob"]),
              ("Nationalitaet", p["nationality"]), ("Zivilstand", p["marital"]),
              ("Heimatort", p["heimatort"]), ("Bewilligung", p["permit"]),
              ("Strasse", p["street"]), ("PLZ", p["plz"]), ("Ort", p["city"]),
              ("AHV-Nr", p["ahv"]), ("IBAN", p["iban"]),
              ("Tel privat", p["phone"]), ("Mail privat", p["email"]),
              ("Notfall Name", p["ec_name"]), ("Notfall Tel", p["ec_phone"])]
    for lab, val in fields:
        c.setFont("Courier", 9); c.setFillColorRGB(0.35,0.35,0.35)
        c.drawString(20*mm, y, (lab + " ").ljust(18, ".") + ":")
        c.setFont("Courier-Bold", 9.5); c.setFillColorRGB(0.1,0.1,0.1)
        c.drawString(72*mm, y, val)
        y -= 7.2*mm
    y -= 6*mm
    c.setFont("Courier", 8); c.setFillColorRGB(0.4,0.4,0.4)
    c.drawString(20*mm, y, "Ich bestaetige die Richtigkeit der Angaben.")
    stamp(c, f"General documents | Layout 6 - Selbstdeklaration | doc {n:02d}")
    c.showPage(); c.save()

# 7 — "Scan": rotated, grey background, degraded — Tier 2 escalation case
def scanned(path, p, n):
    c = canvas.Canvas(path, pagesize=A4)
    c.setFillColorRGB(0.91,0.90,0.88); c.rect(0,0,W,H, stroke=0, fill=1)
    c.saveState(); c.translate(W/2, H/2); c.rotate(random.choice([-1.6,-1.1,1.3,1.8])); c.translate(-W/2,-H/2)
    c.setFillColorRGB(0.99,0.99,0.975); c.rect(12*mm, 18*mm, W-24*mm, H-36*mm, stroke=0, fill=1)
    c.setFillColorRGB(0.22,0.22,0.22); c.setFont("Helvetica-Bold", 11)
    c.drawString(22*mm, H-38*mm, "PERSONALMELDUNG  (Kopie)")
    c.setFont("Helvetica", 8); c.setFillColorRGB(0.45,0.45,0.45)
    c.drawString(22*mm, H-43*mm, "eingescannt am 18.10.2026 - Qualitaet reduziert")
    y = H-56*mm
    c.setFillColorRGB(0.27,0.27,0.27)
    lines = [f"Name:  {p['last_name']}, {p['first_name']}",
             f"Geboren:  {p['dob']}", f"Nationalitaet:  {p['nationality']}",
             f"Zivilstand:  {p['marital']}", f"Heimatort:  {p['heimatort']}",
             f"Adresse:  {p['street']}", f"PLZ/Ort:  {p['plz']} {p['city']}",
             f"AHV:  {p['ahv']}", f"IBAN:  {p['iban']}",
             f"Telefon:  {p['phone']}", f"E-Mail:  {p['email']}",
             f"Notfall:  {p['ec_name']} / {p['ec_phone']}"]
    for ln in lines:
        c.setFont("Helvetica", 9.5); c.drawString(24*mm, y, ln); y -= 7.5*mm
    c.restoreState()
    stamp(c, f"General documents | Layout 7 - Scan (degraded) | doc {n:02d}")
    c.showPage(); c.save()

# 8 — Onboarding summary: two-column, English/German mixed
def summary(path, p, n):
    c = canvas.Canvas(path, pagesize=A4)
    c.setFillColorRGB(0.098,0.396,0.639); c.rect(0, H-22*mm, W, 22*mm, stroke=0, fill=1)
    c.setFillColorRGB(1,1,1); c.setFont("Helvetica-Bold", 12)
    c.drawString(22*mm, H-14*mm, "New Joiner Data Sheet / Eintrittsblatt")
    y = H-34*mm
    c.setFillColorRGB(0.098,0.396,0.639); c.setFont("Helvetica-Bold", 9)
    c.drawString(22*mm, y, "PERSONAL DETAILS"); c.drawString(106*mm, y, "ADMINISTRATIVE")
    c.setStrokeColorRGB(0.8,0.8,0.8); c.line(22*mm, y-2*mm, 96*mm, y-2*mm); c.line(106*mm, y-2*mm, W-22*mm, y-2*mm)
    y -= 10*mm
    L = [("Surname / Name", p["last_name"]), ("First name / Vorname", p["first_name"]),
         ("Date of birth", p["dob"]), ("Nationality", p["nationality"]),
         ("Marital status", p["marital"]), ("Place of origin", p["heimatort"])]
    R = [("Candidate ref.", p["candidate_id"]), ("Social security no.", p["ahv"]),
         ("Permit type", p["permit"]), ("Bank account (IBAN)", p["iban"]),
         ("Private phone", p["phone"]), ("Private e-mail", p["email"])]
    yy = y
    for lab, val in L:
        c.setFont("Helvetica", 7.5); c.setFillColorRGB(0.45,0.45,0.45); c.drawString(22*mm, yy, lab)
        c.setFont("Helvetica", 9.5); c.setFillColorRGB(0.12,0.12,0.12); c.drawString(22*mm, yy-4.5*mm, val)
        yy -= 12*mm
    yy = y
    for lab, val in R:
        c.setFont("Helvetica", 7.5); c.setFillColorRGB(0.45,0.45,0.45); c.drawString(106*mm, yy, lab)
        c.setFont("Helvetica", 9.5); c.setFillColorRGB(0.12,0.12,0.12); c.drawString(106*mm, yy-4.5*mm, val)
        yy -= 12*mm
    y = yy - 6*mm
    c.setFillColorRGB(0.098,0.396,0.639); c.setFont("Helvetica-Bold", 9)
    c.drawString(22*mm, y, "HOME ADDRESS"); c.setStrokeColorRGB(0.8,0.8,0.8); c.line(22*mm, y-2*mm, W-22*mm, y-2*mm)
    y -= 10*mm
    c.setFont("Helvetica", 9.5); c.setFillColorRGB(0.12,0.12,0.12)
    c.drawString(22*mm, y, f"{p['street']}"); c.drawString(106*mm, y, f"{p['plz']}  {p['city']}")
    y -= 14*mm
    c.setFillColorRGB(0.098,0.396,0.639); c.setFont("Helvetica-Bold", 9)
    c.drawString(22*mm, y, "EMERGENCY CONTACT"); c.line(22*mm, y-2*mm, W-22*mm, y-2*mm)
    y -= 10*mm
    c.setFont("Helvetica", 9.5); c.setFillColorRGB(0.12,0.12,0.12)
    c.drawString(22*mm, y, p["ec_name"]); c.drawString(106*mm, y, p["ec_phone"])
    stamp(c, f"General documents | Layout 8 - New Joiner Sheet | doc {n:02d}")
    c.showPage(); c.save()

LAYOUTS = [("arbeitsvertrag", contract), ("anschreiben", letter), ("bewilligung", permit),
           ("versicherung", policy), ("zivilstand", civil), ("selbstdeklaration", declaration),
           ("scan-degraded", scanned), ("new-joiner-sheet", summary)]

def build(base):
    os.makedirs(base, exist_ok=True)
    ps = people(); made = []; n = 0
    for li, (nm, fn) in enumerate(LAYOUTS):
        for k in range(3):                      # 8 layouts x 3 = 24
            p = ps[(li*3 + k) % 24]; n += 1
            name = f"g{n:02d}-{nm}-{p['candidate_id']}.pdf"
            fn(os.path.join(base, name), p, n)
            made.append((name, nm, p))
    return made

if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "pkg-general", "documents")
    m = build(out); print("generated", len(m), "PDFs across", len(LAYOUTS), "layout families")
