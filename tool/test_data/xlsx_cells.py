"""Writes cell values into an existing .xlsx, leaving everything else as it is.

Only the standard library: the workbook's XML is edited as text, so styles,
data validations, tables and pivot tables stay byte for byte. A written
cell keeps its style (s="..."). Formula cells lose their cached values, the
calculation chain is dropped and the workbook is marked to be fully
recalculated on load, so Excel / LibreOffice show fresh results.

Values: int / float, str, datetime.date (as an Excel serial number in the
cell's own date style), Formula("A1*2"), or None (empties the cell).
"""

import datetime
import html
import re
import zipfile

_ROW = re.compile(r'<row\b((?:[^>/]|/(?!>))*)(?:/>|>(.*?)</row>)', re.S)
_CELL = re.compile(r'<c\b((?:[^>/]|/(?!>))*)(?:/>|>(.*?)</c>)', re.S)
_ATTR = re.compile(r'([\w:]+)="([^"]*)"')


class Formula(str):
    """A formula without the leading '='."""


def col_index(letters):
    n = 0
    for ch in letters:
        n = n * 26 + ord(ch) - 64
    return n


def split_ref(ref):
    m = re.fullmatch(r'([A-Z]+)(\d+)', ref)
    return m.group(1), int(m.group(2))


def serial(date):
    return (date - datetime.date(1899, 12, 30)).days


def _attrs(text):
    return dict(_ATTR.findall(text))


def _attr_text(attrs):
    return ''.join(f' {k}="{v}"' for k, v in attrs.items())


class _Sheet:
    def __init__(self, xml):
        start = xml.index('<sheetData')
        if xml.startswith('<sheetData/>', start):
            self.head, self.tail = xml[:start], xml[start + len('<sheetData/>'):]
            body = ''
        else:
            open_end = xml.index('>', start) + 1
            close = xml.index('</sheetData>', open_end)
            self.head = xml[:start]
            self.tail = xml[close + len('</sheetData>'):]
            body = xml[open_end:close]
        # rows: number -> [attrs, {col: (attrs, inner)}]
        self.rows = {}
        for m in _ROW.finditer(body):
            attrs = _attrs(m.group(1))
            cells = {}
            for c in _CELL.finditer(m.group(2) or ''):
                cattrs = _attrs(c.group(1))
                col, _ = split_ref(cattrs['r'])
                cells[col] = (cattrs, c.group(2))
            self.rows[int(attrs['r'])] = [attrs, cells]

    def set(self, ref, value):
        col, row = split_ref(ref)
        if row not in self.rows:
            self.rows[row] = [{'r': str(row)}, {}]
        attrs, cells = self.rows[row]
        attrs.pop('spans', None)  # a hint only; may no longer be right
        old_attrs = cells.get(col, ({}, None))[0]
        old_inner = cells.get(col, ({}, None))[1] or ''
        shared = re.search(r'<f\b[^>]*\bt="shared"[^>]*\bref="[^"]*"[^>]*\bsi="(\d+)"', old_inner)
        if shared:
            self._check_shared_master(shared.group(1), ref)
        new = {'r': ref}
        if 's' in old_attrs:
            new['s'] = old_attrs['s']
        if value is None:
            inner = None
        elif isinstance(value, Formula):
            inner = f'<f>{html.escape(str(value), quote=False)}</f>'
        elif isinstance(value, datetime.date):
            inner = f'<v>{serial(value)}</v>'
        elif isinstance(value, bool):
            raise TypeError('bool')
        elif isinstance(value, (int, float)):
            text = repr(round(value, 10)) if isinstance(value, float) else str(value)
            inner = f'<v>{text}</v>'
        else:
            new['t'] = 'inlineStr'
            inner = f'<is><t xml:space="preserve">{html.escape(str(value), quote=False)}</t></is>'
        cells[col] = (new, inner)

    def _check_shared_master(self, si, ref):
        # Overwriting the master of a shared formula breaks its other cells,
        # unless they are all overwritten too: checked in [finish].
        self.pending_masters = getattr(self, 'pending_masters', set())
        self.pending_masters.add(si)

    def finish(self):
        for si in getattr(self, 'pending_masters', ()):
            for attrs, cells in self.rows.values():
                for cattrs, inner in cells.values():
                    if inner and re.search(rf'<f\b[^>]*\bsi="{si}"', inner):
                        raise ValueError(
                            f'shared formula {si} still used in {cattrs["r"]}')

    def xml(self):
        out = []
        for num in sorted(self.rows):
            attrs, cells = self.rows[num]
            parts = []
            for col in sorted(cells, key=col_index):
                cattrs, inner = cells[col]
                if inner and '<f' in inner:
                    # No cached value: it is calculated on load.
                    inner = re.sub(r'<v>.*?</v>|<v/>', '', inner, flags=re.S)
                    cattrs = {k: v for k, v in cattrs.items() if k != 't'}
                if inner:
                    parts.append(f'<c{_attr_text(cattrs)}>{inner}</c>')
                else:
                    parts.append(f'<c{_attr_text(cattrs)}/>')
            if parts:
                out.append(f'<row{_attr_text(attrs)}>{"".join(parts)}</row>')
            else:
                out.append(f'<row{_attr_text(attrs)}/>')
        return f'{self.head}<sheetData>{"".join(out)}</sheetData>{self.tail}'


class Workbook:
    def __init__(self, path):
        with zipfile.ZipFile(path) as z:
            self.infos = z.infolist()
            self.files = {i.filename: z.read(i.filename) for i in self.infos}
        workbook = self.files['xl/workbook.xml'].decode('utf-8')
        rels = self.files['xl/_rels/workbook.xml.rels'].decode('utf-8')
        targets = {}
        for tag in re.findall(r'<Relationship\b[^>]*>', rels):
            a = _attrs(tag)
            target = a['Target'].lstrip('/')
            targets[a['Id']] = target if target.startswith('xl/') else 'xl/' + target
        self.parts = {}
        for tag in re.findall(r'<sheet\b[^>]*>', workbook):
            a = _attrs(tag)
            self.parts[html.unescape(a['name'])] = targets[a['r:id']]
        self.sheets = {}

    def sheet(self, name):
        if name not in self.sheets:
            self.sheets[name] = _Sheet(self.files[self.parts[name]].decode('utf-8'))
        return self.sheets[name]

    def set(self, sheet, ref, value):
        self.sheet(sheet).set(ref, value)

    def save(self, path):
        for name, sheet in self.sheets.items():
            sheet.finish()
            self.files[self.parts[name]] = sheet.xml().encode('utf-8')
        # Every formula cell of every sheet: recalculated on load.
        for name, part in self.parts.items():
            if name not in self.sheets:
                s = _Sheet(self.files[part].decode('utf-8'))
                self.files[part] = s.xml().encode('utf-8')
        workbook = self.files['xl/workbook.xml'].decode('utf-8')
        if '<calcPr' in workbook:
            workbook = re.sub(r'<calcPr\b((?:[^>/]|/(?!>))*)',
                              lambda m: '<calcPr' + re.sub(r'\s*fullCalcOnLoad="[^"]*"', '', m.group(1))
                              + ' fullCalcOnLoad="1"', workbook, count=1)
        else:
            workbook = workbook.replace('</workbook>', '<calcPr fullCalcOnLoad="1"/></workbook>')
        self.files['xl/workbook.xml'] = workbook.encode('utf-8')
        # The calculation chain would name cells that are no formulas any more.
        if 'xl/calcChain.xml' in self.files:
            del self.files['xl/calcChain.xml']
            types = self.files['[Content_Types].xml'].decode('utf-8')
            types = re.sub(r'<Override\b[^>]*PartName="/xl/calcChain.xml"[^>]*/>', '', types)
            self.files['[Content_Types].xml'] = types.encode('utf-8')
            rels = self.files['xl/_rels/workbook.xml.rels'].decode('utf-8')
            rels = re.sub(r'<Relationship\b[^>]*Target="[^"]*calcChain.xml"[^>]*/>', '', rels)
            self.files['xl/_rels/workbook.xml.rels'] = rels.encode('utf-8')
        # Pivot tables are rebuilt from their (changed) source on load.
        for name in list(self.files):
            if re.fullmatch(r'xl/pivotCache/pivotCacheDefinition\d+\.xml', name):
                text = self.files[name].decode('utf-8')
                text = re.sub(r'<pivotCacheDefinition\b((?:[^>/]|/(?!>))*)>',
                              lambda m: '<pivotCacheDefinition'
                              + re.sub(r'\s*refreshOnLoad="[^"]*"', '', m.group(1))
                              + ' refreshOnLoad="1">', text, count=1)
                self.files[name] = text.encode('utf-8')
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
            for info in self.infos:
                if info.filename in self.files:
                    z.writestr(info.filename, self.files[info.filename], zipfile.ZIP_DEFLATED)
