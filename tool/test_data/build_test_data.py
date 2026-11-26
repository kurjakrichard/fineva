"""Test data of Fineva for every kind of user, in the app and in the workbooks.

    python3 tool/test_data/build_test_data.py

writes tool/test_data/test_data.json (read by tool/seed_test_data.dart, which
puts it into the app's database) and fills the same data into the
workbooks of assets/ (the originals are kept in assets/_eredeti/ the first
time; every run starts from those). So the app's results and the
workbooks' can be compared.

The users (2026, January - November):
  1. Personal finances.
  2. Flat-rate tax, VAT exempt     - _Bevételi nyilvántartás (átalány-2026).xlsx
  3. Flat-rate tax, monthly VAT    - _Bevételi nyilvántartás (átalány-HAVI áfás-2026).xlsx
  4. Flat-rate tax, quarterly VAT  - _Bevételi nyilvántartás (átalány-NÉVES-2026).xlsx
  6. KATA.
  7. Itemized tax (vállalkozói SZJA) - vállalkozói szja 2026.xlsx

(No 5: the foreign currency flat-rate user is gone, every user handles other
currencies; its workbook, _Bevételi nyilvántartás-devizás (átalány-2026).xlsx,
gets user 2's invoices in their own currencies. The numbers stay: they make
the users' tax numbers.)

Only the standard library.
"""

import datetime as dt
import json
import math
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(__file__))
from xlsx_cells import Formula, Workbook  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ASSETS = os.path.join(ROOT, 'assets')
ORIGINALS = os.path.join(ASSETS, '_eredeti')


def original(name):
    """The workbook as it was before the test data: kept in ORIGINALS the
    first time, so a new run starts from it again."""
    backup = os.path.join(ORIGINALS, name)
    if not os.path.exists(backup):
        os.makedirs(ORIGINALS, exist_ok=True)
        shutil.copy2(os.path.join(ASSETS, name), backup)
    return backup
YEAR = 2026
RATE_SCALE = 10000


def d(month, day):
    return dt.date(YEAR, month, day)


def iso(date):
    return date.isoformat() if date else None


def eur_rate(date):
    """A made-up EUR/HUF rate of the day, two decimals."""
    n = date.timetuple().tm_yday
    return round(391.5 - 0.045 * n + 2.5 * math.sin(n / 17), 2)


def huf_of(cents, rate):
    """[cents] of another currency in forints at [rate], as the app
    rounds (half away from zero, not Python's half to even)."""
    return math.floor(cents * round(rate * RATE_SCALE) / (100 * RATE_SCALE) + 0.5)


def tax_number_base(seven):
    weights = [9, 7, 3, 1, 9, 7, 3]
    s = sum(int(c) * w for c, w in zip(seven, weights))
    return seven + str((10 - s % 10) % 10)


def tax_id(days, seq):
    """A valid tax identification number; a check digit of 10 is never
    issued, then the next serial number."""
    while True:
        digits = f'8{days:05d}{seq:03d}'
        check = sum(int(c) * (i + 1) for i, c in enumerate(digits)) % 11
        if check < 10:
            return digits + str(check)
        seq += 1


MONTHS_HU = ['január', 'február', 'március', 'április', 'május', 'június',
             'július', 'augusztus', 'szeptember', 'október', 'november']

# Made-up partners. (Repdigits are valid base numbers.)
ALFA = ('Alfa Kft.', '11111111-2-41')
BETA = ('Béta Bt.', '22222222-1-42')
GAMMA = ('Gamma Zrt.', '33333333-2-43')
DELTA_HU = ('Delta Kft.', '44444444-2-44')
IRODASZER = ('Irodaszer Kft.', '55555555-2-42')
KONYVELO = ('Könyvelő Kft.', '66666666-2-41')
SZOFTVERHAZ = ('Szoftverház Kft.', '77777777-2-42')
EPSILON_NL = ('Epsilon B.V.', 'NL123456789B01')
CLOUD_DE = ('Cloudware GmbH', 'DE987654321')
OMEGA_CH = ('Omega AG', 'CHE-123.456.789')
PAYMENT_HU = {'transfer': 'Átutalás', 'cash': 'Készpénz', 'card': 'Bankkártya'}


def invoice(direction, number, partner, description, fulfillment, net, code,
            vat=None, issue=None, due=None, paid=None, paid_amount=None,
            location='domestic', payment='transfer', currency='HUF', rate=1.0,
            account='bank', category=None, paid_rate=None, booked=True):
    """An invoice of the app. [net] and [vat] in the currency's units
    (forints, or euros with cents as a float). Its payment is booked on
    [account] (a key of the user's accounts) in [category] (a system key;
    business income / expense by default), at [paid_rate] (the invoice's
    rate by default); not [booked] for an invoices only user (flat-rate,
    VAT exempt), who has no accounts."""
    factor = 1 if currency == 'HUF' else 100
    net_minor = round(net * factor)
    rates = {'vat27': 27, 'vat18': 18, 'vat5': 5, 'vat0': 0}
    if vat is None:
        vat_minor = round(net_minor * rates.get(code, 0) / 100)
    else:
        vat_minor = round(vat * factor)
    gross = net_minor + vat_minor
    return {
        'direction': direction, 'number': number, 'description': description,
        'partnerName': partner[0], 'partnerTaxNumber': partner[1],
        'partnerLocation': location, 'paymentMethod': payment,
        'issueDate': iso(issue or fulfillment), 'fulfillmentDate': iso(fulfillment),
        'dueDate': iso(due), 'currency': currency,
        'exchangeRate': round(rate * RATE_SCALE) if currency != 'HUF' else RATE_SCALE,
        'netAmount': net_minor, 'vatCode': code, 'vatAmount': vat_minor,
        'paidDate': iso(paid),
        'paidAmount': 0 if paid is None else (
            gross if paid_amount is None else round(paid_amount * factor)),
        'paidAccount': None if paid is None or not booked else account,
        'paidExchangeRate': None if paid_rate is None else round(paid_rate * RATE_SCALE),
        'category': None if not booked else (
            category or ('businessIncome' if direction == 'outgoing' else 'businessExpense')),
    }


def profile(name, number, **kw):
    p = {
        'name': name,
        'address': f'1{number}00 Budapest, Teszt utca {number}.',
        'taxId': tax_id(40000 + number * 137, 100 + number),
        'taxNumber': '', 'userType': 'personal', 'taxRegime': 'flatRate',
        'vatStatus': 'exempt', 'euReporting': False, 'euVatNumber': '',
        'vatPeriod': 'quarterly', 'costRatio': 45, 'mainOccupation': True,
    }
    p.update(kw)
    return p


def sole_proprietor(name, number, seven, vat_code, **kw):
    base = tax_number_base(seven)
    tax_number = f'{base}-{vat_code}-4{number % 10}'
    p = profile(name, number, userType='soleProprietor', taxNumber=tax_number, **kw)
    if p['euReporting']:
        p['euVatNumber'] = 'HU' + base
    return p


# ---------------------------------------------------------------------------
# 1. Personal finances
# ---------------------------------------------------------------------------

def personal():
    entries = []

    def e(account, category, type_, amount, date, note, rate=None):
        entries.append({'account': account, 'category': category, 'type': type_,
                        'amount': amount, 'date': iso(date), 'note': note,
                        'exchangeRate': rate})

    for m in range(1, 12):
        e('bank', 'salary', 'income', 524300, d(m, 5), 'Fizetés')
        e('bank', 'housing', 'expense', 185000, d(m, 6), 'Albérlet')
        e('bank', 'utilities', 'expense', 28000 + m * 900, d(m, 12), 'Rezsi')
        e('bank', 'transport', 'expense', 9500, d(m, 2), 'Bérlet')
        for day, amount, account in [(3, 23450, 'bank'), (10, 18920, 'cash'),
                                     (17, 31200, 'bank'), (24, 15670, 'bank')]:
            e(account, 'food', 'expense', amount + m * 100, d(m, day), 'Bevásárlás')
        if m % 2 == 0:
            e('cash', 'entertainment', 'expense', 12000, d(m, 20), 'Mozi, vacsora')
        if m in (3, 8):
            e('bank', 'health', 'expense', 18500, d(m, 15), 'Fogorvos')
        if m in (3, 6, 9):
            e('savings', 'otherIncome', 'income', 1250, d(m, 28), 'Kamat')
    e('bank', 'otherIncome', 'income', 50000, d(6, 18), 'Visszatérítés')
    # Money between the accounts (the app's transfers): the old account's
    # whole balance to the new one before it is closed, and a currency
    # exchange at the bank's rate (2 Ft worse than the MNB's of the day).
    exchange_day = d(6, 15)
    transfers = [
        {'from': 'old', 'to': 'bank', 'fromAmount': 120000, 'date': iso(d(2, 16)),
         'note': 'Régi számla megszüntetése'},
        {'from': 'bank', 'to': 'savings', 'fromAmount': 200000,
         'toAmount': round(200000 / (eur_rate(exchange_day) + 2) * 100),
         'date': iso(exchange_day), 'note': 'Pénzváltás'},
    ]
    return {
        'profile': profile('Teszt Magánszemély', 1),
        'accounts': [
            {'key': 'bank', 'name': 'Bankszámla', 'type': 'bank', 'currency': 'HUF', 'initialBalance': 850000,
             'description': 'Fizetési számla', 'bankAccount': '11773016-11111018-00000000',
             'swift': 'OTPVHUHB'},
            {'key': 'cash', 'name': 'Készpénz', 'type': 'cash', 'currency': 'HUF', 'initialBalance': 300000},
            {'key': 'savings', 'name': 'Megtakarítás EUR', 'type': 'savings', 'currency': 'EUR', 'initialBalance': 200000},
            # Emptied by a transfer, then closed.
            {'key': 'old', 'name': 'Régi bankszámla', 'type': 'bank', 'currency': 'HUF', 'initialBalance': 120000,
             'bankAccount': 'HU42 1177 3016 1111 1018 0000 0000', 'closedDate': iso(d(2, 28))},
        ],
        'entries': entries, 'transfers': transfers, 'invoices': [], 'assets': [],
    }


def business_account(balance):
    return [{'key': 'bank', 'name': 'Vállalkozói bankszámla', 'type': 'bank',
             'currency': 'HUF', 'initialBalance': balance}]


# ---------------------------------------------------------------------------
# 2. Flat-rate, VAT exempt
# ---------------------------------------------------------------------------

def flat_basic():
    rows = [  # number, partner, description, payment, fulfillment, due, amount, paid, paid amount
        ('2026/001', ALFA, 'Webfejlesztés', 'transfer', d(1, 15), d(1, 23), 650000, d(1, 22), None),
        ('2026/002', BETA, 'Tanácsadás', 'transfer', d(1, 31), d(2, 8), 280000, d(2, 6), None),
        ('2026/003', ALFA, 'Webfejlesztés', 'transfer', d(2, 16), d(2, 24), 720000, d(2, 24), None),
        # Paid in the next quarter.
        ('2026/004', GAMMA, 'Rendszerintegráció', 'transfer', d(3, 20), d(3, 28), 950000, d(4, 3), None),
        ('2026/005', ALFA, 'Webfejlesztés', 'transfer', d(4, 15), d(4, 23), 690000, d(4, 21), None),
        ('2026/006', BETA, 'Tanácsadás', 'cash', d(5, 12), d(5, 12), 120000, d(5, 12), None),
        ('2026/007', GAMMA, 'Rendszerintegráció', 'transfer', d(5, 29), d(6, 6), 880000, d(6, 8), None),
        ('2026/008', ALFA, 'Webfejlesztés', 'transfer', d(6, 30), d(7, 8), 700000, d(7, 7), None),
        # Partly paid.
        ('2026/009', DELTA_HU, 'Karbantartás', 'transfer', d(7, 24), d(8, 1), 900000, d(8, 3), 500000),
        ('2026/010', ALFA, 'Webfejlesztés', 'transfer', d(8, 31), d(9, 8), 740000, d(9, 8), None),
        ('2026/011', GAMMA, 'Rendszerintegráció', 'transfer', d(9, 25), d(10, 3), 1050000, d(10, 2), None),
        ('2026/012', ALFA, 'Webfejlesztés', 'transfer', d(10, 30), d(11, 7), 760000, d(11, 9), None),
        # Not paid yet.
        ('2026/013', BETA, 'Tanácsadás', 'transfer', d(11, 13), d(11, 21), 310000, None, None),
    ]
    invoices = [
        invoice('outgoing', no, partner, desc, ful, amount, 'aam', due=due, paid=paid,
                paid_amount=part, payment=pay, booked=False)
        for no, partner, desc, pay, ful, due, amount, paid, part in rows]
    # The same in the currency workbook: each in its own currency, at its rate
    # (forints at 1).
    currency_rows = [  # number, partner, description, payment, fulfillment, issue, due,
        #                currency, amount, rate, paid, paid amount
        (no, partner, desc, pay, ful, ful, due, 'HUF', amount, 1, paid,
         None if paid is None else (part or amount))
        for no, partner, desc, pay, ful, due, amount, paid, part in rows]
    # In euros, to a Swiss client (a third country), from another invoice
    # pad: at the rate of the fulfillment, or of the issue if earlier (the
    # own bank's, typed in: not reported to NAV).
    euro = [  # number, description, issue, fulfillment, due, EUR, paid, paid EUR
        ('D-2026/001', 'Szoftverfejlesztés', d(3, 10), d(3, 10), d(3, 25), 1500.00, d(3, 24), None),
        # Issued before the fulfillment; paid in the next quarter.
        ('D-2026/002', 'Szoftverfejlesztés', d(6, 10), d(6, 15), d(6, 30), 2200.00, d(7, 2), None),
        # Partly paid.
        ('D-2026/003', 'Tanácsadás', d(10, 5), d(10, 5), d(10, 20), 1800.00, d(10, 20), 1000.00),
    ]
    for no, desc, issue, ful, due, eur, paid, part in euro:
        rate = eur_rate(min(issue, ful))
        invoices.append(invoice('outgoing', no, OMEGA_CH, desc, ful, eur, 'ho', issue=issue,
                                due=due, paid=paid, paid_amount=part,
                                location='thirdCountry', currency='EUR', rate=rate,
                                booked=False))
        currency_rows.append((no, OMEGA_CH, desc, 'transfer', ful, issue, due, 'EUR', eur,
                              rate, paid, None if paid is None else (part or eur)))
        # In the workbook (forints only) at the same rate.
        rows.append((no, OMEGA_CH, desc, 'transfer', ful, due,
                     huf_of(round(eur * 100), rate), paid,
                     None if part is None else huf_of(round(part * 100), rate), issue))
    rows.sort(key=lambda r: (r[4], r[0]))
    currency_rows.sort(key=lambda r: (r[4], r[0]))
    # Invoices only: no accounts, the payments aren't booked.
    user = {
        'profile': sole_proprietor('Teszt Átalányadós (alanyi adómentes)', 2, '1234567', 1,
                                   taxRegime='flatRate', vatStatus='exempt', costRatio=45),
        'accounts': [], 'entries': [], 'invoices': invoices, 'assets': [],
    }
    return user, rows, currency_rows


def fill_flat_basic(user, rows):
    wb = Workbook(original('_Bevételi nyilvántartás (átalány-2026).xlsx'))
    p = user['profile']
    wb.set('Adattábla', 'B2', p['name'])
    wb.set('Adattábla', 'B3', p['taxNumber'])
    wb.set('Adattábla', 'B7', 'igen' if p['mainOccupation'] else 'nem')
    wb.set('Adattábla', 'B13', p['costRatio'] / 100)
    s = 'Bevételi nyilvántartás'
    for i in range(54):
        r = 3 + i
        row = rows[i] if i < len(rows) else None
        # The issue date if it isn't the fulfillment's (10th of a row).
        values = [None] * 10 if row is None else [
            row[0], row[2], PAYMENT_HU[row[3]], row[1][0], row[4],
            row[9] if len(row) > 9 else row[4], row[5],
            row[6], row[7], None if row[7] is None else (row[8] or row[6])]
        for col, value in zip('BCDEFGHIJK', values):
            wb.set(s, f'{col}{r}', value)
    return wb


def fill_flat_currency(user, rows):
    """The flat-rate, VAT exempt user in the currency workbook: every invoice
    in its own currency at its rate; the workbook's formulas make the
    forints."""
    wb = Workbook(original('_Bevételi nyilvántartás-devizás (átalány-2026).xlsx'))
    p = user['profile']
    wb.set('Adattábla', 'B2', p['name'])
    wb.set('Adattábla', 'B3', p['taxNumber'])
    wb.set('Adattábla', 'B7', 'igen' if p['mainOccupation'] else 'nem')
    wb.set('Adattábla', 'B13', p['costRatio'] / 100)
    s = 'Bevételi nyilvántartás'
    for i in range(54):
        r = 3 + i
        row = rows[i] if i < len(rows) else None
        if row is None:
            values = [None] * 10
            paid = [None, None]
        else:
            no, partner, desc, pay, ful, issue, due, cur, amount, rate, paid_date, part = row
            values = [no, desc, PAYMENT_HU[pay], partner[0], ful, issue, due, amount, cur, rate]
            paid = [paid_date, part]
        for col, value in zip('BCDEFGHIJK', values):
            wb.set(s, f'{col}{r}', value)
        wb.set(s, f'M{r}', paid[0])
        wb.set(s, f'N{r}', paid[1])
    return wb


# ---------------------------------------------------------------------------
# 3. and 4. Flat-rate with VAT (monthly / quarterly)
# ---------------------------------------------------------------------------

def flat_vat(number, name, seven, vat_period, cost_ratio, main_occupation, nets,
             late_month, cost_months, import_months, extra_5=True):
    """Outgoing 27% invoices each month (+ one 5%), incoming 27% costs,
    EU services with reverse charge."""
    out = []
    for m, net in enumerate(nets, start=1):
        ful = d(m, 10)
        if m == late_month:
            paid = ful + dt.timedelta(days=52)  # after 45 days: VAT date +45
        elif m == len(nets):
            paid = None  # still open
        else:
            paid = ful + dt.timedelta(days=12)
        partner = [ALFA, GAMMA, DELTA_HU][m % 3]
        out.append(('2026/%03d' % m, partner, 'Szoftverfejlesztés', 'transfer', ful,
                    ful + dt.timedelta(days=15), net, 'vat27', paid))
    if extra_5:
        out.append(('2026/%03d' % (len(nets) + 1), BETA, 'Szakkönyv értékesítés', 'cash',
                    d(6, 18), d(6, 18), 40000, 'vat5', d(6, 18)))
    out.sort(key=lambda r: r[4])
    costs = []
    for m in cost_months:
        costs.append(('KF-%02d/2026' % m, KONYVELO, 'Könyvelési díj', 'transfer',
                      d(m, 28), d(m, 28), d(m + 1, 5) if m < 12 else None, 30000))
    for m in (2, 5, 8, 11):
        if m in cost_months:
            costs.append(('IR-%03d' % (m * 7), IRODASZER, 'Irodaszer', 'card',
                          d(m, 14), d(m, 14), d(m, 14), 18500))
    costs.sort(key=lambda r: r[4])
    imports = []
    for m in import_months:
        date = d(m, 1)
        imports.append(('CW-2026-%02d' % m, CLOUD_DE, 'Szoftver előfizetés', 'card',
                        date, date, 49.0, eur_rate(date)))
    invoices = [
        invoice('outgoing', no, partner, desc, ful, net, code, due=due, paid=paid, payment=pay)
        for no, partner, desc, pay, ful, due, net, code, paid in out]
    invoices += [
        invoice('incoming', no, partner, desc, ful, net, 'vat27', issue=issue, paid=paid, payment=pay)
        for no, partner, desc, pay, ful, issue, paid, net in costs]
    invoices += [
        invoice('incoming', no, partner, desc, date, eur, 'euServices', paid=paid,
                location='eu', payment=pay, currency='EUR', rate=rate)
        for no, partner, desc, pay, date, paid, eur, rate in imports]
    user = {
        'profile': sole_proprietor(name, number, seven, 2, taxRegime='flatRate',
                                   vatStatus='registered', vatPeriod=vat_period,
                                   costRatio=cost_ratio, mainOccupation=main_occupation),
        'accounts': business_account(500000), 'entries': [], 'invoices': invoices, 'assets': [],
    }
    return user, out, costs, imports


def fill_flat_vat(path, user, out, costs, imports):
    wb = Workbook(original(path))
    p = user['profile']
    wb.set('Adattábla', 'B2', p['name'])
    wb.set('Adattábla', 'B3', p['taxNumber'])
    wb.set('Adattábla', 'B7', 'igen' if p['mainOccupation'] else 'nem')
    wb.set('Adattábla', 'B13', p['costRatio'] / 100)
    s = 'Bevételi nyilvántartás'
    rates = {'vat27': 0.27, 'vat5': 0.05}
    for i in range(54):
        r = 3 + i
        row = out[i] if i < len(out) else None
        if row is None:
            values = [None] * 9
            paid = [None, None]
        else:
            no, partner, desc, pay, ful, due, net, code, paid_date = row
            values = [no, desc, PAYMENT_HU[pay], partner[0], ful, ful, due, net, rates[code]]
            paid = [paid_date, None if paid_date is None else round(net * (1 + rates[code]))]
        for col, value in zip('BCDEFGHIJ', values):
            wb.set(s, f'{col}{r}', value)
        wb.set(s, f'M{r}', paid[0])
        wb.set(s, f'P{r}', paid[1])
    s = 'Költség nyilvántartás'
    for i in range(20):
        r = 3 + i
        row = costs[i] if i < len(costs) else None
        if row is None:
            values = [None] * 10
        else:
            no, partner, desc, pay, ful, issue, paid, net = row
            values = [no, desc, PAYMENT_HU[pay], partner[0], partner[1], ful, issue, paid, net, 0.27]
        for col, value in zip('BCDEFGHIJK', values):
            wb.set(s, f'{col}{r}', value)
    s = 'IMPORT'
    for i in range(20):
        r = 3 + i
        row = imports[i] if i < len(imports) else None
        if row is None:
            values = [None] * 10
        else:
            no, partner, desc, pay, date, paid, eur, rate = row
            values = [no, desc, PAYMENT_HU[pay], partner[0], partner[1], date, paid, eur, 'EUR', rate]
        for col, value in zip('BCDEFGHIJK', values):
            wb.set(s, f'{col}{r}', value)
    return wb


# ---------------------------------------------------------------------------
# 6. KATA
# ---------------------------------------------------------------------------

def kata():
    customers = [('Kovács Péter', ''), ('Nagy Éva', ''), ('Szabó Anna', ''), ('Tóth Gábor', '')]
    invoices = []
    n = 1
    for m in range(1, 12):
        for k, day in enumerate((4, 18)):
            amount = 120000 + ((m * 7 + k * 13) % 9) * 15000
            ful = d(m, day)
            paid = None if (m == 11 and day == 18) else ful + dt.timedelta(days=3)
            invoices.append(invoice('outgoing', 'K-2026/%03d' % n, customers[(m + k) % 4],
                                    'Fotózás' if k else 'Rendezvényfotó', ful, amount, 'aam',
                                    due=ful + dt.timedelta(days=8), paid=paid))
            n += 1
    for m in (1, 4, 7, 10):
        invoices.append(invoice('incoming', 'IR-%03d' % (m * 11), IRODASZER, 'Nyomtatópapír, festék',
                                d(m, 9), 22000, 'vat27', paid=d(m, 9), payment='card'))
    invoices.append(invoice('incoming', 'SZ-2026/0412', SZOFTVERHAZ, 'Képszerkesztő licenc',
                            d(4, 12), 89000, 'vat27', paid=d(4, 12), payment='card'))
    return {
        'profile': sole_proprietor('Teszt KATA', 6, '5678901', 1, taxRegime='kata', vatStatus='exempt'),
        'accounts': business_account(150000), 'entries': [], 'invoices': invoices, 'assets': [],
    }


# ---------------------------------------------------------------------------
# 7. Itemized tax (vállalkozói SZJA)
# ---------------------------------------------------------------------------

# The ledger columns and the app's business categories.
LEDGER_CATEGORIES = {
    'P': 'bizRevenue', 'Q': 'bizNonTaxableIncome', 'R': 'bizWithdrawal', 'S': 'bizSzocho',
    'T': 'bizOther', 'U': 'bizMaterial', 'V': 'bizBank', 'W': 'bizAccounting', 'X': 'bizIt',
    'Z': 'bizNonDeductible', 'AA': 'bizVat',
}
INCOME_COLUMNS = {'P', 'Q'}
ACCOUNT_COLUMNS = {'E': 'till', 'G': 'bank', 'I': 'eur', 'N': 'bank2'}


def itemized():
    """The cash-flow ledger (EV), the invoices (Vevő, Szállító) and the
    assets (ÉCS: the workbook's own two)."""
    # date, document, description, {money column: amount}, rate,
    # {category: amount}, booked by an invoice (so not an entry of its own)
    ledger = []

    def row(date, doc, desc, money, cats=None, rate=None, from_invoice=False):
        ledger.append((date, doc, desc, money, rate, cats or {}, from_invoice))

    jan1 = d(1, 1)
    row(jan1, 'Pénztár', 'Nyitás', {'E': 200000}, {'Q': 200000})
    row(jan1, 'Bank HUF', 'Nyitás', {'G': 1500000}, {'Q': 1500000})
    row(jan1, 'Bank EUR', 'Nyitás', {'I': 5000.0}, {'Q': 'L'}, eur_rate(jan1))
    row(jan1, 'Bank2 HUF', 'Nyitás', {'N': 100000}, {'Q': 100000})

    sales, purchases = [], []
    revenue_eur = [8000, 8000, 8250, 8250, 8250, 8500, 8500, 8500, 8750, 8750, 8750]
    for m in range(1, 12):
        month = MONTHS_HU[m - 1]
        row(d(m, 3), '', 'Bankköltség', {'G': -2450}, {'V': 2450})
        row(d(m, 3), '', 'Bankköltség', {'I': -5.0}, {'V': '-L'}, eur_rate(d(m, 3)))
        row(d(m, 3), '', 'Bankköltség', {'N': -573}, {'V': 573})
        # The customer pays the month's invoice.
        no = '2026-%d' % m
        sales.append((no, EPSILON_NL, d(m, 1), d(m, 1), d(m, 10), eur_rate(d(m, 1)),
                      revenue_eur[m - 1], d(m, 5)))
        row(d(m, 5), no, f'Epsilon B.V. {month}i számla', {'I': float(revenue_eur[m - 1])},
            {'P': 'L'}, eur_rate(d(m, 5)), from_invoice=True)
        # The accountant's invoice: 120 EUR + 27% VAT.
        doc = 'KF-2026/%02d' % m
        purchases.append((doc, KONYVELO, d(m, 2), d(m, 2), d(m, 8), 'EUR', eur_rate(d(m, 2)),
                          120.0, d(m, 6), 'Könyvelési díj'))
        row(d(m, 6), doc, 'Könyvelő Kft.', {'I': -152.4}, {'W': '120*K', 'AA': '32.4*K'},
            eur_rate(d(m, 6)), from_invoice=True)
        # Withdrawal: gross from the till, the deductions back, refilled.
        row(d(m, 10), '', 'Bruttó kivét', {'E': -500000}, {'R': 500000})
        row(d(m, 10), '', 'Levonások visszavétele', {'E': 167500}, {'Q': 167500})
        row(d(m, 10), '', 'Pénztár feltöltés', {'E': 332500, 'G': -332500})
        row(d(m, 12), '', 'SZOCHO utalás', {'G': -65000}, {'S': 65000})
        row(d(m, 12), '', 'TB utalás', {'G': -92500}, {'Z': 92500})
        row(d(m, 12), '', 'SZJA utalás (kivét)', {'G': -75000}, {'Z': 75000})
        # Euros changed to forints.
        eur = 6000 + (m % 3) * 500
        rate = eur_rate(d(m, 15))
        row(d(m, 15), '', 'Váltás HUF-ra', {'I': -float(eur)}, {'Z': '-L'}, rate)
        huf = round(eur * (rate - 1.5))
        row(d(m, 15), '', 'Váltás EUR-ról', {'G': huf}, {'Q': huf})
        if m in (1, 4, 7, 10):
            doc = 'SZH-2026/%02d' % m
            purchases.append((doc, SZOFTVERHAZ, d(m, 20), d(m, 20), d(m, 28), 'HUF', 1,
                              24000, d(m, 20), 'Felhő szolgáltatás'))
            row(d(m, 20), doc, 'Szoftverház Kft.', {'G': -30480}, {'X': 24000, 'AA': 6480},
                from_invoice=True)
    row(d(2, 18), 'MKIK-2026', 'MKIK tagdíj', {'G': -5000}, {'T': 5000})
    row(d(3, 16), '', 'HIPA előleg', {'G': -320000}, {'T': 320000})
    row(d(9, 15), '', 'HIPA előleg', {'G': -320000}, {'T': 320000})
    row(d(4, 10), '', 'SZJA előleg (I. negyedév)', {'G': -1600000}, {'Z': 1600000})
    row(d(7, 10), '', 'SZJA előleg (II. negyedév)', {'G': -1650000}, {'Z': 1650000})
    row(d(10, 12), '', 'SZJA előleg (III. negyedév)', {'G': -1700000}, {'Z': 1700000})
    row(d(5, 22), 'Blokk 0815', 'Irodaszer', {'E': -18600}, {'U': 18600})
    row(d(6, 9), '', 'Taxi', {'G': -7800}, {'T': 7800})
    row(d(10, 3), '', 'Taxi', {'G': -9200}, {'T': 9200})
    # Depreciation from the ÉCS sheet (quarters 2026.Q1-Q4: I19-I22).
    for q, ref in enumerate(['I19', 'I20', 'I21', 'I22']):
        row(d(q * 3 + 3, 30 if q in (1, 2) else 31), f' 2026.Q{q + 1}', 'ÉCS', {},
            {'Y': f"'ÉCS'!{ref}", 'Z': f"-'ÉCS'!{ref}"})
    ledger.sort(key=lambda r: r[0])

    # The app's entries: one per category of a ledger row, on its account.
    entries = []
    for date, doc, desc, money, rate, cats, from_invoice in ledger:
        if not money or from_invoice:
            continue  # depreciation: from the assets; payments: booked by the invoices
        (col, amount), *others = money.items()
        if others:  # a transfer between two accounts: no category
            for c, a in money.items():
                entries.append(_entry(ACCOUNT_COLUMNS[c], None, a, date, desc, None))
            continue
        account = ACCOUNT_COLUMNS[col]
        eur = col == 'I'
        for cat, value in cats.items():
            if eur:
                # A formula of the euro amount: the same in euros.
                part = {'L': abs(amount), '-L': abs(amount)}.get(value)
                if part is None:
                    part = float(value.split('*')[0])
            else:
                part = value
            type_ = 'income' if cat in INCOME_COLUMNS else 'expense'
            entries.append({
                'account': account, 'category': LEDGER_CATEGORIES[cat], 'type': type_,
                'amount': round(part * 100) if eur else part, 'date': iso(date),
                'note': desc, 'exchangeRate': round(rate * RATE_SCALE) if eur else None})

    # Booked as the ledger has them: the euros at the rate of the payment day.
    invoices = [
        invoice('outgoing', no, partner, 'Szoftverfejlesztési szolgáltatás', ful, float(eur),
                'eufad37', issue=issue, due=due, paid=paid, location='eu', currency='EUR', rate=rate,
                account='eur', category='bizRevenue', paid_rate=eur_rate(paid))
        for no, partner, ful, issue, due, rate, eur, paid in sales]
    invoices += [
        invoice('incoming', no, partner, desc, ful, net, 'vat27', issue=issue, due=due, paid=paid,
                currency=cur, rate=rate, account='eur' if cur == 'EUR' else 'bank',
                category='bizAccounting' if cur == 'EUR' else 'bizIt',
                paid_rate=eur_rate(paid) if cur == 'EUR' else None)
        for no, partner, ful, issue, due, cur, rate, net, paid, desc in purchases]
    assets = [
        {'name': 'MacBook Pro M2 Max', 'purchaseDate': '2023-05-08', 'invoiceNumber': 'SZ-2022/06',
         'supplier': 'Apple', 'amount': 1377945, 'rate': 3300},
        {'name': 'Mobiltelefon', 'purchaseDate': '2025-05-27', 'invoiceNumber': 'NTMBL-2025-3543',
         'supplier': 'Netmobil', 'amount': 280858, 'rate': 3300},
    ]
    user = {
        'profile': sole_proprietor('Teszt Vállalkozói SZJA', 7, '6789012', 2, taxRegime='itemized',
                                   vatStatus='registered', vatPeriod='quarterly', euReporting=True),
        'accounts': [
            {'key': 'till', 'name': 'Pénztár', 'type': 'cash', 'currency': 'HUF', 'initialBalance': 0},
            {'key': 'bank', 'name': 'Bank HUF', 'type': 'bank', 'currency': 'HUF', 'initialBalance': 0},
            {'key': 'eur', 'name': 'Bank EUR', 'type': 'bank', 'currency': 'EUR', 'initialBalance': 0},
            {'key': 'bank2', 'name': 'Bank2 HUF', 'type': 'bank', 'currency': 'HUF', 'initialBalance': 0},
        ],
        'businessCategories': True,
        'entries': entries, 'invoices': invoices, 'assets': assets,
    }
    return user, ledger, sales, purchases


def _entry(account, category, amount, date, note, rate):
    return {'account': account, 'category': category,
            'type': 'income' if amount > 0 else 'expense', 'amount': abs(amount),
            'date': iso(date), 'note': note, 'exchangeRate': rate}


def fill_itemized(ledger, sales, purchases):
    wb = Workbook(original('vállalkozói szja 2026.xlsx'))
    s = 'EV'
    inputs = ['B', 'C', 'D', 'E', 'G', 'I', 'K', 'N'] + list(LEDGER_CATEGORIES)
    for i in range(244):
        r = 2 + i
        for col in inputs + ['Y']:
            wb.set(s, f'{col}{r}', None)
        # The workbook has the euro -> forint formula only in the rows that
        # had euros, and its check leaves out the material costs (U).
        wb.set(s, f'L{r}', Formula(f'+I{r}*K{r}'))
        wb.set(s, f'AB{r}', Formula(
            f'E{r}+G{r}+L{r}+N{r}-P{r}-Q{r}+U{r}+V{r}+X{r}+W{r}+Y{r}+R{r}+S{r}+T{r}+Z{r}+AA{r}'))
        if i >= len(ledger):
            continue
        date, doc, desc, money, rate, cats, _ = ledger[i]
        wb.set(s, f'B{r}', date)
        wb.set(s, f'C{r}', doc or None)
        wb.set(s, f'D{r}', desc)
        for col, amount in money.items():
            wb.set(s, f'{col}{r}', amount)
        if rate is not None:
            wb.set(s, f'K{r}', rate)
        for col, value in cats.items():
            if isinstance(value, str):
                formula = value.replace('*K', f'*K{r}')
                if value in ('L', '-L'):
                    formula = value.replace('L', f'L{r}')
                wb.set(s, f'{col}{r}', Formula(formula))
            else:
                wb.set(s, f'{col}{r}', value)
    wb.set(s, 'AJ250', None)
    wb.set(s, 'AJ251', None)
    # HIPA: the material costs are in row 255 (254 is empty).
    wb.set('HIPA', 'B6', Formula('+EV!U255'))

    def sale_cells(sheet, r, sale, index):
        no, partner, ful, issue, due, rate, eur, paid = sale
        for col, value in zip('ABCDEFGHIJKLOQ', [
                f'{index}.', no, partner[0], partner[1], ful, issue, due, 'EUR', rate,
                'ÁTHK', eur, 'ÁTHK', 'ÁTHK', paid]):
            wb.set(sheet, f'{col}{r}', value)
        wb.set(sheet, f'M{r}', Formula(f'+K{r}'))
        wb.set(sheet, f'N{r}', Formula(f'+K{r}*$I{r}'))
        wb.set(sheet, f'P{r}', Formula(f'+M{r}*$I{r}'))
        wb.set(sheet, f'S{r}', Formula(f'CONCATENATE(YEAR(E{r}),"Q",INT((MONTH(E{r})+2)/3))'))

    def purchase_cells(sheet, r, purchase, index):
        no, partner, ful, issue, due, cur, rate, net, paid, _ = purchase
        for col, value in zip('ABCDEFGHIJKQ', [
                'SZ-2026/%02d' % index, no, partner[0], partner[1], ful, issue, due, cur,
                rate, 0.27, net, paid]):
            wb.set(sheet, f'{col}{r}', value)
        wb.set(sheet, f'L{r}', Formula(f'+J{r}*K{r}'))
        wb.set(sheet, f'M{r}', Formula(f'+K{r}+L{r}'))
        wb.set(sheet, f'N{r}', Formula(f'+K{r}*$I{r}'))
        wb.set(sheet, f'O{r}', Formula(f'+L{r}*I{r}'))
        wb.set(sheet, f'P{r}', Formula(f'+M{r}*I{r}'))
        wb.set(sheet, f'S{r}', Formula(f'CONCATENATE(YEAR(E{r}),"Q",ROUNDUP(MONTH(E{r})/3,0))'))

    def clear(sheet, r, last='S'):
        for col in 'ABCDEFGHIJKLMNOPQRS'[:ord(last) - 64]:
            wb.set(sheet, f'{col}{r}', None)

    for i in range(24):
        r = 2 + i
        if i < len(sales):
            sale_cells('Vevő', r, sales[i], i + 1)
        else:
            clear('Vevő', r)
    purchases = sorted(purchases, key=lambda p: p[2])
    for i in range(21):
        r = 2 + i
        if i < len(purchases):
            purchase_cells('Szállító', r, purchases[i], i + 1)
        else:
            clear('Szállító', r)

    # ÁFA: the quarters' blocks of the payable (sales) and deductible
    # (purchases) invoices, as many rows as the sheet has for them.
    blocks = [((5, 7), (12, 16)), ((23, 26), (31, 39)), ((46, 50), (55, 59)), ((66, 70), (75, 79))]
    for q, ((s1, s2), (p1, p2)) in enumerate(blocks):
        quarter = [x for x in sales if (x[2].month - 1) // 3 == q]
        assert len(quarter) <= s2 - s1 + 1
        for k, r in enumerate(range(s1, s2 + 1)):
            if k < len(quarter):
                sale_cells('ÁFA', r, quarter[k], sales.index(quarter[k]) + 1)
            else:
                clear('ÁFA', r)
        quarter = [x for x in purchases if (x[2].month - 1) // 3 == q]
        assert len(quarter) <= p2 - p1 + 1
        for k, r in enumerate(range(p1, p2 + 1)):
            if k < len(quarter):
                purchase_cells('ÁFA', r, quarter[k], purchases.index(quarter[k]) + 1)
            else:
                clear('ÁFA', r)
    # The totals of the Q3 block left two rows out.
    wb.set('ÁFA', 'M60', Formula('SUM(M55:M59)'))
    wb.set('ÁFA', 'N60', Formula('SUM(N55:N59)'))
    wb.set('ÁFA', 'P60', Formula('SUM(P55:P59)'))
    # No opening balance or reclaim: the app has neither yet.
    wb.set('ÁFA', 'U1', 0)
    wb.set('ÁFA', 'U18', 0)
    return wb


# ---------------------------------------------------------------------------

def main():
    users = [personal()]
    basic, basic_rows, basic_currency_rows = flat_basic()
    users.append(basic)
    monthly = flat_vat(3, 'Teszt Átalányadós (havi áfás)', '2345678', 'monthly', 80, True,
                       [480000, 520000, 610000, 450000, 700000, 530000, 480000, 650000,
                        590000, 720000, 560000],
                       late_month=3, cost_months=range(1, 12), import_months=range(1, 12))
    users.append(monthly[0])
    quarterly = flat_vat(4, 'Teszt Átalányadós (negyedéves áfás)', '3456789', 'quarterly', 45,
                         False, [310000, 360000, 420000, 330000, 390000, 410000, 300000,
                                 380000, 450000, 340000, 400000],
                         late_month=8, cost_months=(3, 6, 9), import_months=(1, 4, 7, 10),
                         extra_5=False)
    users.append(quarterly[0])
    users.append(kata())
    szja = itemized()
    users.append(szja[0])

    with open(os.path.join(os.path.dirname(__file__), 'test_data.json'), 'w') as f:
        json.dump({'year': YEAR, 'users': users}, f, ensure_ascii=False, indent=1)

    workbooks = {
        '_Bevételi nyilvántartás (átalány-2026).xlsx': fill_flat_basic(basic, basic_rows),
        # The same user, the invoices in their own currencies.
        '_Bevételi nyilvántartás-devizás (átalány-2026).xlsx':
            fill_flat_currency(basic, basic_currency_rows),
        '_Bevételi nyilvántartás (átalány-HAVI áfás-2026).xlsx':
            fill_flat_vat('_Bevételi nyilvántartás (átalány-HAVI áfás-2026).xlsx', *monthly),
        '_Bevételi nyilvántartás (átalány-NÉVES-2026).xlsx':
            fill_flat_vat('_Bevételi nyilvántartás (átalány-NÉVES-2026).xlsx', *quarterly),
        'vállalkozói szja 2026.xlsx': fill_itemized(*szja[1:]),
    }
    for name, wb in workbooks.items():
        wb.save(os.path.join(ASSETS, name))
    print('users:', len(users), '| workbooks:', len(workbooks))


if __name__ == '__main__':
    main()
