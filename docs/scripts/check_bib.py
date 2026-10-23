#!/usr/bin/env python3
"""Check the DOIs of doc/h2-radiation-molecules/references.bib against CrossRef.

    python docs/scripts/check_bib.py

For every entry with a doi, fetches https://api.crossref.org/works/<doi> (one request a second) and
compares the year (any of CrossRef's issued, published-print and published-online), the first author's
family name and the title. Prints one line per entry:

    ok                   year, first author and title agree
    MISMATCH (year|author)  the year or the first author differs
    TITLE? (ratio)       year and author agree, the titles' difflib ratio is below 0.85
    NOT FOUND            CrossRef has no record of the DOI (or could not be reached)
    no DOI               the entry has no doi field

and a count. Exits 1 on any MISMATCH or NOT FOUND. Reads the bib file and changes nothing. Needs pybtex.
"""
import difflib
import json
import os
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

from pybtex.database import parse_file

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
BIB = os.path.join(REPO, 'doc', 'h2-radiation-molecules', 'references.bib')
API = 'https://api.crossref.org/works/'
USER_AGENT = 'mocassin-pdr-docs (https://github.com/hektor-monteiro/mocassin-pdr)'
RATIO = 0.85


def norm_name(s):
    """NFKD, accents and non-letters dropped, lower case"""
    return ''.join(c for c in unicodedata.normalize('NFKD', s) if c.isalpha()).lower()


def norm_title(s):
    """LaTeX commands, braces and $ removed, lower case, letters and digits only"""
    s = re.sub(r'\\[A-Za-z]+', '', s)
    s = s.replace('{', '').replace('}', '').replace('$', '')
    return ''.join(c for c in s.lower() if c.isalnum())


def crossref(doi):
    req = urllib.request.Request(API + urllib.parse.quote(doi, safe='/'), headers={'User-Agent': USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)['message']


def years(msg):
    out = set()
    for k in ('issued', 'published-print', 'published-online'):
        for parts in (msg.get(k) or {}).get('date-parts') or []:
            if parts and parts[0] is not None:
                out.add(int(parts[0]))
    return out


def check(key, entry, msg):
    """(status, detail) of one entry against its CrossRef record"""
    bad, detail = [], []
    year = entry.fields.get('year', '')
    ys = years(msg)
    if not year.strip().isdigit() or int(year) not in ys:
        bad.append('year')
        detail.append(f'year bib {year} crossref {sorted(ys)}')
    authors = entry.persons.get('author', [])
    bib_family = norm_name(' '.join(authors[0].prelast_names + authors[0].last_names)) if authors else ''
    cr = (msg.get('author') or [{}])[0]
    cr_family = norm_name(cr.get('family') or cr.get('name') or '')
    if bib_family != cr_family:
        bad.append('author')
        detail.append(f'first author bib {bib_family!r} crossref {cr_family!r}')
    t_bib = norm_title(entry.fields.get('title', ''))
    t_cr = norm_title((msg.get('title') or [''])[0])
    ratio = difflib.SequenceMatcher(None, t_bib, t_cr).ratio()
    if ratio < RATIO:
        detail.append(f'title ratio {ratio:.2f}: crossref "{(msg.get("title") or [""])[0]}"')
    if bad:
        return f'MISMATCH ({"|".join(bad)})', '; '.join(detail)
    if ratio < RATIO:
        return f'TITLE? ({ratio:.2f})', '; '.join(detail)
    return 'ok', ''


def main():
    bib = parse_file(BIB)
    counts = {}
    first = True
    for key, entry in bib.entries.items():
        doi = entry.fields.get('doi', '').strip()
        if not doi:
            status, detail = 'no DOI', ''
        else:
            if not first:
                time.sleep(1)
            first = False
            try:
                status, detail = check(key, entry, crossref(doi))
            except (urllib.error.URLError, OSError, ValueError, KeyError) as e:
                status, detail = 'NOT FOUND', f'{doi}: {e}'
        counts[status.split(' (')[0]] = counts.get(status.split(' (')[0], 0) + 1
        print(f'{key}: {status}' + (f'  [{detail}]' if detail else ''), flush=True)
    order = ['ok', 'MISMATCH', 'TITLE?', 'NOT FOUND', 'no DOI']
    print(f'{len(bib.entries)} entries: ' + ', '.join(f'{counts.get(k, 0)} {k}' for k in order))
    sys.exit(1 if counts.get('MISMATCH') or counts.get('NOT FOUND') else 0)


if __name__ == '__main__':
    main()
