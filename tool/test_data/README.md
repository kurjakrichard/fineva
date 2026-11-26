# Test data

One test user for every kind of Fineva user, in the app and in the
workbooks of `assets/`, so the app's results can be checked against them.

| # | User | Workbook |
|---|------|----------|
| 1 | Teszt Magánszemély: three accounts (one in EUR, the bank one with its account number), ~100 entries, a currency exchange (a transfer at the bank's rate), and an old account emptied by a transfer and closed | – |
| 2 | Teszt Átalányadós (alanyi adómentes): 45%, main occupation, invoices only (no accounts); three EUR invoices to a Swiss client (one issued before its fulfillment, one paid in the next quarter, one partly paid), at their own bank's rate, in the workbook in forints at the same rate | `_Bevételi nyilvántartás (átalány-2026).xlsx` |
| 3 | Teszt Átalányadós (havi áfás): 80%, 27% and 5% sales, costs, EU services | `_Bevételi nyilvántartás (átalány-HAVI áfás-2026).xlsx` |
| 4 | Teszt Átalányadós (negyedéves áfás): 45%, not main occupation | `_Bevételi nyilvántartás (átalány-NÉVES-2026).xlsx` |
| 6 | Teszt KATA: invoices to private persons, costs | – |
| 7 | Teszt Vállalkozói SZJA: till, HUF, EUR and second HUF bank ledger, invoices, two assets | `vállalkozói szja 2026.xlsx` |

There is no 5: the foreign currency flat-rate user is gone (every user
handles other currencies); the numbers make the users' tax numbers, so they
stay. Its workbook (`_Bevételi nyilvántartás-devizás (átalány-2026).xlsx`)
gets user 2's invoices, each in its own currency at its rate (forints at 1):
the workbook's formulas make the forints.

The data includes a payment in the next quarter, a partial payment, unpaid
invoices, a payment after 45 days (VAT date) and a cash payment.

Paid invoices are booked as the app books them (`invoiceEntries`): the
VAT registered flat-rate and the KATA users' on their bank account as
business income / expense (the flat-rate, VAT exempt users keep invoices
only: no accounts, nothing booked), the itemized user's on the account of the ledger row, at the rate of
the payment day, with the VAT in the VAT category. So the itemized ledger's
rows of invoice payments (the Epsilon sales, the accountant and the IT
invoices) aren't separate entries in `test_data.json`; the workbook still has
them.

## Making it

```bash
python3 tool/test_data/build_test_data.py
FINEVA_DB=~/.local/share/com.example.fineva/fineva.db flutter test tool/seed_test_data.dart
```

The first writes `test_data.json` and fills the workbooks (standard library
only; `xlsx_cells.py` edits the cells in the workbook's XML, so nothing else
changes, and marks it to be recalculated when opened). The originals are kept
in `assets/_eredeti/`, and every run starts from them.

The second replaces every user of the database with the test users (close the
app first, back up the database if it matters). With `FINEVA_RESULTS=file.json`
it also writes what the app calculates from them.

The personal test user can go into Monekin too (close it first), with
Monekin's own default categories, for comparing the two apps:

```bash
python3 tool/test_data/seed_monekin.py ~/Dokumentumok/database.db
```

It replaces only the test accounts (and their transactions, the transfers as
Monekin's own, the closed account with its closing date), adds a monthly EUR
rate, and backs up the database (`.teszt-elotti`) the first time.

## Fixed in the itemized tax workbook

- EV: the L column (euros in forints) had its formula only in the rows that
  had euros; now every row has it.
- EV: the AB check left out the material costs (U).
- HIPA!B6 referred to EV!U254 (empty) instead of U255.
- ÁFA: the totals of the Q3 block left out two rows; the opening balance (U1)
  and the reclaim (U18) are 0, as the app has neither yet.

## Known differences from the itemized tax workbook

- Depreciation: the ÉCS sheet counts one day more in every quarter after the
  first (91/92/93/93 days a year), and writes off the first asset from the
  start of 2023 Q2 instead of its purchase day; the app counts calendar days
  from the purchase day.
- SZOCHO on the dividend base: the workbook expects 12 months of withdrawal,
  the app uses the SZOCHO actually paid so far.
