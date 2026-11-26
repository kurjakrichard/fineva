"""Puts the personal test user of test_data.json into Monekin's database, so
the two apps can be compared with the same data:

    python3 tool/test_data/seed_monekin.py ~/Dokumentumok/database.db

Close Monekin first. Its database is backed up next to it (.teszt-elotti) the
first time. The test accounts (and their transactions) are replaced on every
run; Monekin's other data stays. Monekin's own default categories are used,
expenses are stored as negative values, dates as drift's local time text
('2026-01-05T12:00:00.000 +01:00'), and a EUR rate is added for each month so
the EUR account counts in HUF.

Only the standard library.
"""

import datetime as dt
import json
import os
import sqlite3
import sys
import uuid
from zoneinfo import ZoneInfo

sys.path.insert(0, os.path.dirname(__file__))
from build_test_data import eur_rate  # noqa: E402

BUDAPEST = ZoneInfo('Europe/Budapest')

# Fineva's built-in categories (and the entry's note, where one Fineva
# category has two Monekin ones) -> Monekin's default categories.
CATEGORIES = {
    ('salary', None): 'Salary',
    ('housing', None): 'Rental',
    ('utilities', None): 'Housing',
    ('food', None): 'Groceries',
    ('transport', None): 'Public Transport',
    ('entertainment', None): 'Leisure',
    ('health', None): 'Medical',
    ('otherIncome', 'Kamat'): 'Investments',
    ('otherIncome', 'Visszatérítés'): 'Others',
}
ICONS = {'bank': 'account_balance', 'cash': 'wallet', 'savings': 'savings',
         'old': 'account_balance'}
DECIMALS = {'HUF': 0, 'EUR': 2, 'USD': 2}


def drift_date(date, hour=12):
    """A local date and time as drift stores it as text."""
    local = dt.datetime(date.year, date.month, date.day, hour, tzinfo=BUDAPEST)
    offset = local.utcoffset()
    minutes = int(offset.total_seconds() // 60)
    sign = '-' if minutes < 0 else '+'
    minutes = abs(minutes)
    return f'{local:%Y-%m-%dT%H:%M:%S}.000 {sign}{minutes // 60:02d}:{minutes % 60:02d}'


def main(db_path):
    data_path = os.path.join(os.path.dirname(__file__), 'test_data.json')
    data = json.load(open(data_path))
    user = next(u for u in data['users'] if u['profile']['userType'] == 'personal')
    year = data['year']

    backup = db_path + '.teszt-elotti'
    if not os.path.exists(backup):
        src = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True)
        dst = sqlite3.connect(backup)
        src.backup(dst)
        dst.close()
        src.close()

    db = sqlite3.connect(db_path)
    db.execute('PRAGMA foreign_keys = ON')
    categories = {name: id_ for id_, name in db.execute('SELECT id, name FROM categories')}
    missing = set(CATEGORIES.values()) - set(categories)
    if missing:
        sys.exit(f'Monekin has no category {missing}')

    with db:
        # Replace the test accounts of an earlier run (transactions go with them).
        names = [a['name'] for a in user['accounts']]
        db.execute(f'DELETE FROM accounts WHERE name IN ({",".join("?" * len(names))})', names)
        db.execute("DELETE FROM exchangeRates WHERE currencyCode = 'EUR'")

        accounts = {}
        for a in user['accounts']:
            id_ = str(uuid.uuid4())
            accounts[a['key']] = (id_, a['currency'])
            closed = a.get('closedDate')
            db.execute(
                'INSERT INTO accounts (id, name, iniValue, date, description, type, iconId, '
                'currencyId, closingDate, iban, swift) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                (id_, a['name'], a['initialBalance'] / 10 ** DECIMALS[a['currency']],
                 drift_date(dt.date(year, 1, 1), 0), a.get('description') or None,
                 'saving' if a['type'] == 'savings' else 'normal', ICONS[a['key']],
                 a['currency'],
                 drift_date(dt.date.fromisoformat(closed), 23) if closed else None,
                 a.get('bankAccount') or None, a.get('swift') or None))

        for e in user['entries']:
            account_id, currency = accounts[e['account']]
            name = CATEGORIES.get((e['category'], None)) or CATEGORIES[(e['category'], e['note'])]
            value = e['amount'] / 10 ** DECIMALS[currency]
            if e['type'] == 'expense':
                value = -value
            db.execute(
                'INSERT INTO transactions (id, date, accountID, value, title, categoryID, '
                'isHidden) VALUES (?, ?, ?, ?, ?, ?, 0)',
                (str(uuid.uuid4()), drift_date(dt.date.fromisoformat(e['date'])), account_id,
                 value, e['note'], categories[name]))

        # Monekin's transfer: the amount leaving (positive), the amount
        # arriving in the other currency (none in the same one), no category.
        for t in user.get('transfers', []):
            from_id, from_currency = accounts[t['from']]
            to_id, to_currency = accounts[t['to']]
            to_amount = t.get('toAmount')
            db.execute(
                'INSERT INTO transactions (id, date, accountID, value, title, categoryID, '
                'isHidden, receivingAccountID, valueInDestiny) '
                'VALUES (?, ?, ?, ?, ?, NULL, 0, ?, ?)',
                (str(uuid.uuid4()), drift_date(dt.date.fromisoformat(t['date'])), from_id,
                 t['fromAmount'] / 10 ** DECIMALS[from_currency], t['note'], to_id,
                 None if from_currency == to_currency or to_amount is None
                 else to_amount / 10 ** DECIMALS[to_currency]))

        for month in range(1, 13):
            date = dt.date(year, month, 1)
            if date > dt.date.today():
                break
            db.execute('INSERT INTO exchangeRates (id, date, currencyCode, exchangeRate) '
                       'VALUES (?, ?, ?, ?)',
                       (str(uuid.uuid4()), drift_date(date, 0), 'EUR', eur_rate(date)))

        db.execute("UPDATE userSettings SET settingValue = ? WHERE settingKey = 'userName'",
                   (user['profile']['name'],))

    count = db.execute('SELECT count(*) FROM transactions').fetchone()[0]
    print(f'{len(accounts)} accounts, {count} transactions; backup: {backup}')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(os.path.expanduser(sys.argv[1]))
