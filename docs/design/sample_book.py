"""Sample book for docs/design/pro-ui-reference.html.

Every number on the reference comes from here, computed with the app's own
formulas (lib/domain/rules/*) and reason-string formats, so the mockups can
be checked rather than trusted. Standard profile defaults throughout.
"""
from decimal import Decimal as D, ROUND_HALF_UP, getcontext
from datetime import date, datetime
import math

getcontext().prec = 40
NOW = datetime(2026, 9, 28, 9, 41)  # Monday
TODAY = NOW.date()

PROFIT, ASSIGN = D(50), 0.70
BASE, MID, HIGH, MIDCUT, HIGHCUT = 0.30, 0.35, 0.40, 40.0, 70.0
TAIL_DTE, TAIL_EXT = 3, D("0.05")


def band(iv):
    if iv is None:
        return BASE
    if iv > HIGHCUT:
        return HIGH
    if iv >= MIDCUT:
        return MID
    return BASE


def fmt_mag(v):  # classify.dart _fmtMagnitude
    s = f"{v:.4f}".rstrip("0")
    return s + "0" if s.endswith(".") else s


def trimmed(v):  # iv_resolution.dart _trimmedPct
    s = f"{v:.4f}".rstrip("0")
    return s[:-1] if s.endswith(".") else s


def r0(d):
    return int(d.quantize(D(1), ROUND_HALF_UP))


def m2(d):
    return f"{d.quantize(D('0.01'), ROUND_HALF_UP):,}"


def classify(leg, snap):
    if snap is None:
        return dict(bucket="No data", reason="No snapshot yet")
    cr, mark = leg["credit"], snap["mark"]
    captured = (cr - mark) / cr * 100
    mag = abs(snap["delta"])
    if snap.get("iv") is not None:
        iv, src = snap["iv"], f"from this snapshot's IV ({trimmed(snap['iv'])}%)"
    elif leg.get("ivAtOpen") is not None:
        iv, src = leg["ivAtOpen"], f"from IV at open ({trimmed(leg['ivAtOpen'])}%)"
    else:
        iv, src = None, "no IV on file"
    b = band(iv)
    dte = (leg["exp"] - TODAY).days
    spot, k = snap["spot"], leg["strike"]
    intrinsic = max(D(0), spot - k) if leg["type"] == "call" else max(D(0), k - spot)
    extrinsic = mark - intrinsic
    out = dict(captured=captured, mag=mag, band=b, band_line=f"{b:.2f} — {src}",
               dte=dte, intrinsic=intrinsic, extrinsic=extrinsic)
    if captured >= PROFIT:
        out.update(bucket="Close", reason=f"{r0(captured)}% of credit captured")
    elif mag >= ASSIGN:
        if leg.get("accepts", True):
            out.update(bucket="Assign", reason=f"Delta {fmt_mag(mag)} at or above {ASSIGN:.2f}")
        else:
            out.update(bucket="Roll", reason=f"Delta {fmt_mag(mag)} at or above {ASSIGN:.2f}, and assignment isn't wanted here")
    elif mag >= b:
        out.update(bucket="Roll", reason=f"Delta {fmt_mag(mag)} at or above the {b:.2f} band")
    elif dte <= TAIL_DTE and extrinsic <= TAIL_EXT:
        out.update(bucket="Close", reason=f"Only ${extrinsic:.2f} of time value left")
    else:
        out.update(bucket="Leave", reason=f"Delta {fmt_mag(mag)} below the {b:.2f} band")
    return out


def leg(t, strike, exp, n, opened, credit, **kw):
    return dict(type=t, strike=D(strike), exp=date.fromisoformat(exp), n=n,
                opened=date.fromisoformat(opened), credit=D(credit), **kw)


def snap(taken, mark, spot, delta, iv):
    return dict(taken=datetime.fromisoformat(taken), mark=D(mark), spot=D(spot), delta=delta, iv=iv)


# ---------------------------------------------------------------- open book
OPEN = {
    "INTC": (leg("put", "20", "2026-10-16", 4, "2026-09-08", "0.62", ivAtOpen=41.0),
             snap("2026-09-25T15:52", "0.28", "21.40", 0.19, 38.0)),
    "SOFI": (leg("put", "14", "2026-10-02", 3, "2026-09-02", "0.41", ivAtOpen=58.0),
             snap("2026-09-28T09:31", "0.52", "13.95", 0.52, 61.0)),
    "F":    (leg("put", "12", "2026-10-09", 2, "2026-09-14", "0.35", ivAtOpen=40.0),
             snap("2026-09-28T09:35", "0.98", "11.10", 0.78, 44.0)),
    "T":    (leg("call", "28", "2026-10-02", 1, "2026-09-15", "0.30", ivAtOpen=22.0),
             snap("2026-09-17T10:05", "0.22", "27.20", -0.28, 21.0)),
    "SBET": (leg("call", "11", "2026-10-16", 1, "2026-09-10", "0.35", ivAtOpen=92.0),
             snap("2026-09-25T15:48", "0.27", "9.29", -0.2534, 87.61)),
    "PFE":  (leg("put", "25", "2026-10-23", 1, "2026-09-25", "0.48"), None),
    "WBD":  (leg("put", "11", "2026-09-25", 1, "2026-09-01", "0.27"),
             snap("2026-09-24T14:10", "0.02", "12.10", 0.03, 35.0)),
    "AAL":  (leg("put", "13", "2026-09-25", 2, "2026-09-03", "0.29"),
             snap("2026-09-23T11:20", "0.46", "12.60", 0.81, 48.0)),
}

# Holding cycles: put side + share lot, for basis and capital.
HOLD = {
    "T": dict(put_nets=[(D("0.45"), 1)], assign_strike=D("27"), lot=1, calls=[(D("0.30"), 1)]),
    "SBET": dict(put_nets=[(D("0.50") - D("0.62"), 1), (D("0.92"), 1)], assign_strike=D("11.50"), lot=1,
                 calls=[(D("0.35"), 1)]),
}


def bases(h):
    shares = h["lot"] * 100
    put_total = sum(n * 100 * c for n, c in h["put_nets"])
    tax = h["assign_strike"] - put_total / shares
    call_total = sum(n * 100 * c for n, c in h["calls"])
    return tax, tax - call_total / shares


print("=== open positions (now = %s) ===" % NOW)
rows = {}
for tk, (lg, sp) in OPEN.items():
    c = classify(lg, sp)
    rows[tk] = c
    age = None if sp is None else (TODAY - sp["taken"].date()).days
    extra = "" if sp is None else (
        f" | captured {c['captured']:.4f} | mag {c['mag']} | band {c['band_line']} | dte {c['dte']}"
        f" | intrinsic {c['intrinsic']} | extrinsic {c['extrinsic']} | reading age {age}d")
    print(f"{tk:5} {lg['type']} {lg['strike']} x{lg['n']} exp {lg['exp']} -> {c['bucket']}: {c['reason']}{extra}")

# Past-expiration card
print("\n=== past expiration ===")
for tk in ("WBD", "AAL"):
    lg, sp = OPEN[tk]
    itm = sp["spot"] < lg["strike"] if lg["type"] == "put" else sp["spot"] > lg["strike"]
    print(tk, "ITM at last reading" if itm else "OTM at last reading", sp["taken"].date(), "spot", sp["spot"])

# Capital committed (current) and concentration
print("\n=== current capital committed ===")
cap = {}
for tk, (lg, sp) in OPEN.items():
    if tk in HOLD:
        tax, wheel = bases(HOLD[tk])
        cap[tk] = wheel * 100 * HOLD[tk]["lot"]
        print(f"{tk}: holding, tax basis {tax}, wheel basis {wheel}, capital {cap[tk]}")
    else:
        cap[tk] = lg["strike"] * 100 * lg["n"]
total_cap = sum(cap.values())
WHEEL_CAPITAL = D(30000)
print("total", total_cap, "of wheel capital", WHEEL_CAPITAL, f"= {total_cap / WHEEL_CAPITAL * 100:.2f}%")
for tk, v in sorted(cap.items(), key=lambda kv: -kv[1]):
    print(f"  {tk:5} {v:>9} {v / WHEEL_CAPITAL * 100:6.2f}%{'  OVER 25%' if v / WHEEL_CAPITAL * 100 > 25 else ''}")

# Expiring this week (Mon Sep 28 - Fri Oct 2)
print("\n=== expiring this week ===")
for tk, (lg, sp) in OPEN.items():
    if TODAY <= lg["exp"] <= date(2026, 10, 2):
        if lg["type"] == "put":
            print(tk, "cash if assigned", lg["strike"] * 100 * lg["n"])
        else:
            print(tk, "shares delivered", 100 * lg["n"], "at", lg["strike"], "receives", lg["strike"] * 100 * lg["n"])

# Net position delta (signed position delta, all entered in position convention)
print("\n=== net position delta ===")
net = D(0)
for tk, (lg, sp) in OPEN.items():
    if sp is None or lg["exp"] < TODAY:
        print("  left out:", tk, "no reading" if sp is None else "past expiration")
        continue
    part = D(str(sp["delta"])) * 100 * lg["n"]
    net += part
    print(f"  {tk:5} {part:+}")
for tk, h in HOLD.items():
    net += 100 * h["lot"]
    print(f"  {tk:5} shares +{100 * h['lot']}")
print("net share-equivalents", net)

# Closed cycles for September (Journal / share card) -- before fees
print("\n=== September closed cycles ===")
CLOSED = [
    # ticker, start, end, legs [(open credit, close debit or None, contracts, reason)], peak capital, stock pnl
    ("BAC", "2026-08-18", "2026-09-09", [(D("0.60"), D("0.28"), 1, "closedEarly")], D(38) * 100, D(0)),
    ("KO", "2026-08-20", "2026-09-11", [(D("0.55"), D("0.20"), 1, "closedEarly")], D("62.50") * 100, D(0)),
    ("CCL", "2026-09-01", "2026-09-16", [(D("0.40"), D("0.55"), 2, "closedEarly")], D(20) * 100 * 2, D(0)),
    ("UBER", "2026-08-25", "2026-09-18", [(D("1.10"), None, 1, "expiredWorthless")], D(70) * 100, D(0)),
    ("SNAP", "2026-07-28", "2026-09-18", [(D("0.30"), None, 2, "assigned"), (D("0.25"), None, 2, "assigned")],
     D(9) * 100 * 2, (D("9.50") - D(9)) * 100 * 2),
]
nets, peaks, days, captures, positive = [], [], [], [], 0
for tk, s, e, legs, peak, stock in CLOSED:
    prem = sum((o - (c or D(0))) * 100 * n for o, c, n, _ in legs)
    netr = prem + stock
    d = (date.fromisoformat(e) - date.fromisoformat(s)).days
    for o, c, n, _ in legs:
        captures.append((o - (c or D(0))) / o * 100)
    nets.append(netr); peaks.append(peak); days.append(d)
    positive += netr > 0
    print(f"  {tk:5} premium {prem:>8} stock {stock:>7} net {netr:>8} peak {peak:>8} days {d} roc {netr / peak * 100:.2f}%")
captures.sort()
mid = len(captures) // 2
median = captures[mid] if len(captures) % 2 else (captures[mid - 1] + captures[mid]) / 2
print("cycles", len(CLOSED), "positive", positive)
print("sum net", sum(nets), "sum peak", sum(peaks), f"roc {sum(nets) / sum(peaks) * 100:.3f}%")
print("avg days", sum(days) / len(days))
print("captures", [f"{c:.2f}" for c in captures], "median", f"{median:.2f}")

# Premium collected this month (candidate definition: credits received minus
# buyback debits paid, by trade date, before fees)
print("\n=== September net premium (candidate definition) ===")
credits = [("INTC", D("0.62"), 4), ("SOFI", D("0.41"), 3), ("F", D("0.35"), 2), ("T call", D("0.30"), 1),
           ("SBET call", D("0.35"), 1), ("PFE", D("0.48"), 1), ("WBD", D("0.27"), 1), ("AAL", D("0.29"), 2),
           ("CCL", D("0.40"), 2)]
debits = [("BAC", D("0.28"), 1), ("CCL", D("0.55"), 2), ("KO", D("0.20"), 1)]
cin = sum(p * 100 * n for _, p, n in credits)
cout = sum(p * 100 * n for _, p, n in debits)
print("credits", cin, "debits", cout, "net", cin - cout)

# Record a trade sample: CCL $19 put, Oct 16, $0.34, 2 contracts
print("\n=== record a trade sample ===")
dte = (date(2026, 10, 16) - TODAY).days
yld = (0.34 / 19) * (365 / dte) * 100
print("dte", dte, f"yield {yld:.4f}%", "capital", 19 * 100 * 2)

# Snapshot sheet sample: T $28 call, new reading
print("\n=== snapshot preview (T) ===")
tl = OPEN["T"][0]
pv = classify(tl, snap("2026-09-28T09:41", "0.12", "27.05", -0.21, 21.0))
print(pv["bucket"], "|", pv["reason"], "| captured", f"{pv['captured']:.4f}", "| band", pv["band_line"],
      "| extrinsic", pv["extrinsic"], "| dte", pv["dte"])

# SBET detail figures
print("\n=== SBET detail ===")
sb, ss = OPEN["SBET"]
c = rows["SBET"]
snap_dte = (sb["exp"] - ss["taken"].date()).days
one_sigma = ss["spot"] * D(f"{(ss['iv'] / 100) * math.sqrt(snap_dte / 365):.10f}")
tax, wheel = bases(HOLD["SBET"])
print(f"captured {c['captured']:.4f} -> {c['captured']:.0f}% | mag {c['mag']:.4f} | band {c['band_line']}")
print(f"one-sigma (spot, snapshot dte {snap_dte}) {one_sigma:.4f} | extrinsic {c['extrinsic']}")
cum = D("0.50") - D("0.62") + D("0.92") + D("0.35")
print("cumulative credit/share", cum, "total premium", cum * 100, "tax basis", tax, "wheel basis", wheel)
peak = max(D(12) * 100, D("11.50") * 100, tax * 100)
print("peak capital", peak, "days so far", (TODAY - date(2026, 8, 4)).days)

# Colour tokens: lightness and WCAG contrast


def lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lum(h):
    r, g, b = (lin(x) for x in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def cr(a, b):
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def lstar(h):
    y = lum(h)
    f = y ** (1 / 3) if y > 216 / 24389 else (24389 / 27 * y + 16) / 116
    return 116 * f - 16


def lch(L, C, H):
    a, b = C * math.cos(math.radians(H)), C * math.sin(math.radians(H))
    fy = (L + 16) / 116
    fx, fz = fy + a / 500, fy - b / 200

    def fi(t):
        return t ** 3 if t ** 3 > 216 / 24389 else (116 * t - 16) / (24389 / 27)

    X, Y, Z = 0.95047 * fi(fx), fi(fy), 1.08883 * fi(fz)
    lr = 3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z
    lg = -0.9692660 * X + 1.8760108 * Y + 0.0415560 * Z
    lb = 0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z

    def g(v):
        v = min(1, max(0, v))
        return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055

    return "#%02X%02X%02X" % tuple(round(g(v) * 255) for v in (lr, lg, lb))


print("\n=== palette ===")
DARK = dict(bg=lch(7, 3, 200), surface=lch(11, 4, 200), surface2=lch(16, 5, 200), outline=lch(32, 6, 200),
            text=lch(92, 3, 195), muted=lch(70, 7, 200), accent=lch(78, 36, 185), on_accent=lch(16, 14, 185),
            accent_soft=lch(24, 14, 185), warn=lch(76, 50, 62), error=lch(70, 45, 25))
LIGHT = dict(bg=lch(96.5, 1.5, 200), surface="#FFFFFF", surface2=lch(93, 3, 200), outline=lch(72, 6, 200),
             text=lch(13, 5, 200), muted=lch(41, 7, 200), accent=lch(46, 36, 190), on_accent="#FFFFFF",
             accent_soft=lch(90, 14, 185), warn=lch(47, 58, 55), error=lch(45, 60, 28))
BUCKET = dict(close=lch(88, 38, 150), roll=lch(75, 56, 78), assign=lch(61, 44, 288), leave=lch(45, 8, 215))
BUCKET_TEXT_DARK, BUCKET_TEXT_LIGHT = lch(14, 6, 200), lch(97, 1, 200)
for name, pal in (("dark", DARK), ("light", LIGHT)):
    print(name, pal)
    print(f"  text/bg {cr(pal['text'], pal['bg']):.2f}  text/surface {cr(pal['text'], pal['surface']):.2f}"
          f"  muted/surface {cr(pal['muted'], pal['surface']):.2f}  muted/bg {cr(pal['muted'], pal['bg']):.2f}"
          f"  accent/bg {cr(pal['accent'], pal['bg']):.2f}  on_accent/accent {cr(pal['on_accent'], pal['accent']):.2f}"
          f"  warn/surface {cr(pal['warn'], pal['surface']):.2f}  error/surface {cr(pal['error'], pal['surface']):.2f}"
          f"  outline/surface {cr(pal['outline'], pal['surface']):.2f}")
print("buckets", BUCKET, "text dark", BUCKET_TEXT_DARK, "text light", BUCKET_TEXT_LIGHT)
for k, v in BUCKET.items():
    t = BUCKET_TEXT_LIGHT if k == "leave" else BUCKET_TEXT_DARK
    print(f"  {k:6} {v} L*={lstar(v):5.1f} label contrast {cr(t, v):5.2f}  vs dark bg {cr(v, DARK['bg']):.2f}"
          f"  vs light bg {cr(v, LIGHT['bg']):.2f}")
for pal_name, pal in (("dark", DARK), ("light", LIGHT)):
    print(f"  no-data outline ({pal_name}) {pal['muted']} on surface {cr(pal['muted'], pal['surface']):.2f}")
