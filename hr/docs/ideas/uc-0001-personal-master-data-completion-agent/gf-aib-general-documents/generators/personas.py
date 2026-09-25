# -*- coding: utf-8 -*-
"""Synthetic Swiss HR personas. ALL DATA FICTIONAL.
AHV and IBAN carry valid CHECK DIGITS so format validation can be tested,
but the numbers identify nobody."""

def ahv(seed12):
    """Swiss AHV: 756.XXXX.XXXX.XC — EAN-13 check digit."""
    d = [int(c) for c in seed12]
    s = sum(v * (3 if i % 2 else 1) for i, v in enumerate(d))
    return seed12 + str((10 - s % 10) % 10)

def fmt_ahv(n):
    return f"{n[0:3]}.{n[3:7]}.{n[7:11]}.{n[11:13]}"

def iban(bank5, acct12):
    """Swiss IBAN: CHkk BBBBB AAAAAAAAAAAA — mod-97 check digits."""
    body = bank5 + acct12
    rear = body + "CH00"
    num = "".join(str(ord(c) - 55) if c.isalpha() else c for c in rear)
    chk = 98 - (int(num) % 97)
    return f"CH{chk:02d}" + body

def fmt_iban(s):
    return " ".join(s[i:i+4] for i in range(0, len(s), 4))

# 24 fictional people. Swiss + cross-border mix, matching GF's real footprint.
P = [
 # id, first, last, dob, nat, marital, street, plz, city, heimatort, permit, phone, email, ec_name, ec_phone, ahv12, bank5, acct12, candidate
 ("CAND-2026-0411","Livia","Brunner","14.03.1994","Schweiz","ledig","Sonnenbergstrasse 14","8203","Schaffhausen","Stein am Rhein SH","—","+41 79 412 88 03","l.brunner@example.ch","Marco Brunner","+41 79 655 21 40","756194302118","00700","0011 4552 331","CAND-2026-0411"),
 ("CAND-2026-0412","Tobias","Ochsner","02.11.1988","Schweiz","verheiratet","Rheinhaldenstrasse 7","8200","Schaffhausen","Neunkirch SH","—","+41 76 330 14 92","t.ochsner@example.ch","Sandra Ochsner","+41 76 812 09 55","756188211047","00784","0022 8891 004","CAND-2026-0412"),
 ("CAND-2026-0413","Mirjam","Iten","27.06.1996","Schweiz","ledig","Bachtelweg 22","8280","Kreuzlingen","Zug ZG","—","+41 78 221 63 17","m.iten@example.ch","Beat Iten","+41 78 904 33 21","756196627085","00230","0033 1276 889","CAND-2026-0413"),
 ("CAND-2026-0414","Andrea","Perren","09.09.1991","Schweiz","geschieden","Dorfstrasse 41","3920","Zermatt","Randa VS","—","+41 79 508 77 26","a.perren@example.ch","Nadia Perren","+41 79 118 44 07","756199109334","06390","0044 7710 552","CAND-2026-0414"),
 ("CAND-2026-0415","Valentin","Steiner","18.01.1985","Schweiz","verheiratet","Im Lindenhof 3","8005","Zürich","Herisau AR","—","+41 44 271 55 18","v.steiner@example.ch","Céline Steiner","+41 79 733 62 10","756198501822","00779","0055 3304 116","CAND-2026-0415"),
 ("CAND-2026-0416","Noemi","Gerber","30.04.1999","Schweiz","ledig","Quellenstrasse 58","3007","Bern","Langnau BE","—","+41 31 992 14 63","n.gerber@example.ch","Peter Gerber","+41 79 221 87 44","756199943012","00792","0066 9985 773","CAND-2026-0416"),
 ("CAND-2026-0417","Lukas","Bosshard","11.07.1990","Schweiz","ledig","Alte Landstrasse 90","8802","Kilchberg","Bülach ZH","—","+41 79 664 20 81","l.bosshard@example.ch","Irene Bosshard","+41 76 447 31 09","756199007116","00873","0077 2216 448","CAND-2026-0417"),
 ("CAND-2026-0418","Sofia","Keller","23.02.1993","Schweiz","verheiratet","Weinbergweg 12","8400","Winterthur","Elgg ZH","—","+41 52 318 06 74","s.keller@example.ch","Daniel Keller","+41 79 880 55 12","756199322641","00840","0088 6640 227","CAND-2026-0418"),
 ("CAND-2026-0419","Matthias","Widmer","05.12.1987","Schweiz","verheiratet","Hauptstrasse 205","5000","Aarau","Zofingen AG","—","+41 62 844 90 33","m.widmer@example.ch","Anja Widmer","+41 79 306 77 58","756198712509","05000","0099 4471 336","CAND-2026-0419"),
 ("CAND-2026-0420","Chantal","Vogt","16.08.1995","Schweiz","ledig","Seestrasse 77","6003","Luzern","Sursee LU","—","+41 41 210 48 25","c.vogt@example.ch","Reto Vogt","+41 78 559 21 86","756199508774","06000","0110 7783 995","CAND-2026-0420"),
 ("CAND-2026-0421","Fabian","Ammann","21.05.1992","Schweiz","ledig","Industriestrasse 9","9000","St. Gallen","Wattwil SG","—","+41 71 445 66 90","f.ammann@example.ch","Karin Ammann","+41 79 002 66 31","756199205183","09000","0121 3358 664","CAND-2026-0421"),
 ("CAND-2026-0422","Elena","Schnyder","03.10.1989","Schweiz","verheiratet","Kirchgasse 18","4051","Basel","Leukerbad VS","—","+41 61 703 22 47","e.schnyder@example.ch","Stefan Schnyder","+41 76 119 84 25","756198910306","04835","0132 9926 117","CAND-2026-0422"),
 # cross-border / permit holders
 ("CAND-2026-0423","Marco","Ferrari","07.03.1990","Italien","verheiratet","Via Motta 24","6900","Lugano","—","B (EU/EFTA)","+41 91 921 33 08","m.ferrari@example.it","Giulia Ferrari","+39 340 118 22 76","756199003719","08000","0143 4417 228","CAND-2026-0423"),
 ("CAND-2026-0424","Anja","Müller","29.01.1986","Deutschland","ledig","Hauptstrasse 61","8262","Ramsen","—","G (Grenzgänger)","+41 52 660 19 04","a.mueller@example.de","Jonas Müller","+49 170 553 20 88","756198601294","00700","0154 8802 551","CAND-2026-0424"),
 ("CAND-2026-0425","Pierre","Dubois","12.06.1993","Frankreich","ledig","Route de Lyon 88","1203","Genève","—","B (EU/EFTA)","+41 22 340 77 19","p.dubois@example.fr","Sylvie Dubois","+33 6 22 41 09 53","756199306122","01100","0165 2239 884","CAND-2026-0425"),
 ("CAND-2026-0426","Katarzyna","Nowak","08.08.1991","Polen","verheiratet","Bahnhofstrasse 33","8180","Bülach","—","C (Niederlassung)","+41 44 860 12 55","k.nowak@example.pl","Piotr Nowak","+48 601 774 220","756199108456","00779","0176 6674 117","CAND-2026-0426"),
 ("CAND-2026-0427","Daniel","Bühler","25.09.1984","Schweiz","verheiratet","Rebbergweg 5","8212","Neuhausen","Thayngen SH","—","+41 52 675 30 41","d.buehler@example.ch","Monika Bühler","+41 79 448 12 67","756198409258","00700","0187 1106 443","CAND-2026-0427"),
 ("CAND-2026-0428","Sarah","Frei","19.04.1997","Schweiz","ledig","Talstrasse 102","7000","Chur","Davos GR","—","+41 81 252 88 16","s.frei@example.ch","Thomas Frei","+41 79 773 55 20","756199704197","07000","0198 5531 776","CAND-2026-0428"),
 ("CAND-2026-0429","Nicolas","Pfister","14.02.1988","Schweiz","ledig","Mühlegasse 27","6300","Zug","Baar ZG","—","+41 41 711 44 93","n.pfister@example.ch","Eva Pfister","+41 76 220 91 38","756198802144","06310","0209 9963 224","CAND-2026-0429"),
 ("CAND-2026-0430","Laura","Meier","06.11.1994","Schweiz","ledig","Feldstrasse 46","8500","Frauenfeld","Amriswil TG","—","+41 52 721 05 62","l.meier@example.ch","Urs Meier","+41 78 336 70 14","756199411063","08500","0210 4428 559","CAND-2026-0430"),
 ("CAND-2026-0431","Stefan","Roth","28.07.1982","Schweiz","verheiratet","Oberdorfstrasse 8","8442","Hettlingen","Andelfingen ZH","—","+41 52 304 17 88","s.roth@example.ch","Petra Roth","+41 79 661 04 27","756198207286","00779","0221 7754 336","CAND-2026-0431"),
 ("CAND-2026-0432","Miriam","Baumann","02.05.1998","Österreich","ledig","Lindenplatz 11","9100","Herisau","—","B (EU/EFTA)","+41 71 350 62 09","m.baumann@example.at","Georg Baumann","+43 664 227 88 51","756199805023","09000","0232 3317 885","CAND-2026-0432"),
 ("CAND-2026-0433","Jonas","Hofer","17.12.1990","Schweiz","ledig","Schulhausweg 3","8253","Diessenhofen","Basadingen TG","—","+41 52 657 91 24","j.hofer@example.ch","Lena Hofer","+41 79 512 33 60","756199012172","00700","0243 8840 117","CAND-2026-0433"),
 # DELIBERATE near-duplicate of persona index 1 — tests the D-03 matching-key weakness
 ("CAND-2026-0434","Tobias","Ochsner","19.05.1995","Schweiz","ledig","Rheinhaldenstrasse 7","8200","Schaffhausen","Beringen SH","—","+41 79 224 61 08","t.ochsner2@example.ch","Heidi Ochsner","+41 79 338 12 04","756199505196","00784","0254 2206 998","CAND-2026-0434"),
]

KEYS = ["candidate_id","first_name","last_name","dob","nationality","marital","street","plz","city",
        "heimatort","permit","phone","email","ec_name","ec_phone","_ahv12","_bank5","_acct12","_cand2"]

def people():
    out = []
    for row in P:
        d = dict(zip(KEYS, row))
        d["ahv"] = fmt_ahv(ahv(d.pop("_ahv12")))
        d["iban"] = fmt_iban(iban(d.pop("_bank5"), d.pop("_acct12").replace(" ", "")))
        d.pop("_cand2", None)
        d["full_name"] = f"{d['first_name']} {d['last_name']}"
        out.append(d)
    return out

if __name__ == "__main__":
    ps = people()
    print(len(ps), "personas")
    for p in ps[:3]:
        print(" ", p["candidate_id"], p["full_name"], p["ahv"], p["iban"])
    print("dup check:", ps[1]["full_name"], "/", ps[23]["full_name"], "same PLZ:", ps[1]["plz"]==ps[23]["plz"])
