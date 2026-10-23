#!/usr/bin/env python3
"""Check the DOIs of doc/h2-radiation-molecules/references.bib against CrossRef.

    python docs/scripts/check_bib.py

For every entry with a doi, fetches https://api.crossref.org/works/<doi> (one request a second) and
compares the year (any of CrossRef's issued, published-print and published-online), the first author's
family name and the title. The bib's author and title are decoded from LaTeX first (latexcodec), and
CrossRef's strings stripped of HTML tags and entities. Prints one line per entry:

    ok                   year, first author and title agree
    ok (registered outside CrossRef; metadata not checked)
                         CrossRef has no record, the DOI handle system has (doi.org/api/handles)
    MISMATCH (year|author)  the year or the first author differs
    TITLE? (ratio)       year and author agree, the titles' difflib ratio is below 0.85
    NOT FOUND            neither CrossRef nor the handle system has the DOI (or could not be reached)
    no DOI               the entry has no doi field
    reviewed: <reason>   the status is the one docs/scripts/check_bib_reviewed.toml records for the
                         entry, checked by hand

and a count. Exits 1 on any MISMATCH or NOT FOUND that is not reviewed. Reads the bib file and changes
nothing. Needs pybtex (and its latexcodec).
"""
import codecs
import difflib
import html
import json
import os
import re
import sys
import time
import tomllib
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

import latexcodec  # noqa: F401  (registers the ulatex codec)
from pybtex.database import parse_file

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
BIB = os.path.join(REPO, 'doc', 'h2-radiation-molecules', 'references.bib')
REVIEWED = os.path.join(HERE, 'check_bib_reviewed.toml')
API = 'https://api.crossref.org/works/'
HANDLES = 'https://doi.org/api/handles/'
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


def latex(s):
    """a bib string decoded from LaTeX"""
    return codecs.decode(s, 'ulatex')


def plain(s):
    """a CrossRef string without HTML tags and entities"""
    return html.unescape(re.sub(r'<[^>]+>', '', s))


def get(base, doi):
    req = urllib.request.Request(base + urllib.parse.quote(doi, safe='/'), headers={'User-Agent': USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def crossref(doi):
    return get(API, doi)['message']


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
    bib_family = norm_name(latex(' '.join(authors[0].prelast_names + authors[0].last_names))) if authors else ''
    cr = (msg.get('author') or [{}])[0]
    cr_family = norm_name(plain(cr.get('family') or cr.get('name') or ''))
    if bib_family != cr_family:
        bad.append('author')
        detail.append(f'first author bib {bib_family!r} crossref {cr_family!r}')
    t_bib = norm_title(latex(entry.fields.get('title', '')))
    cr_title = plain(' '.join(msg.get('title') or []))
    t_cr = norm_title(cr_title)
    ratio = difflib.SequenceMatcher(None, t_bib, t_cr).ratio()
    if ratio < RATIO:
        shown = ' '.join(cr_title.split())
        detail.append(f'title ratio {ratio:.2f}: crossref "{shown}"')
    if bad:
        return f'MISMATCH ({"|".join(bad)})', '; '.join(detail)
    if ratio < RATIO:
        return f'TITLE? ({ratio:.2f})', '; '.join(detail)
    return 'ok', ''


def handle(doi):
    """the status of a DOI CrossRef does not know, from the DOI handle system"""
    try:
        code = get(HANDLES, doi).get('responseCode')
    except (urllib.error.URLError, OSError, ValueError) as e:
        return 'NOT FOUND', f'{doi}: not in CrossRef; handle system: {e}'
    if code == 1:
        return 'ok (registered outside CrossRef; metadata not checked)', ''
    return 'NOT FOUND', f'{doi}: not in CrossRef; handle system responseCode {code}'


def main():
    bib = parse_file(BIB)
    with open(REVIEWED, 'rb') as f:
        reviewed = tomllib.load(f)
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
            except urllib.error.HTTPError as e:
                if e.code == 404:
                    time.sleep(1)
                    status, detail = handle(doi)
                else:
                    status, detail = 'NOT FOUND', f'{doi}: {e}'
            except (urllib.error.URLError, OSError, ValueError, KeyError) as e:
                status, detail = 'NOT FOUND', f'{doi}: {e}'
        if key in reviewed and reviewed[key]['status'] == status:
            status, detail = f'reviewed: {reviewed[key]["reason"]}', ''
        kind = status.split(' (')[0].split(':')[0]
        counts[kind] = counts.get(kind, 0) + 1
        print(f'{key}: {status}' + (f'  [{detail}]' if detail else ''), flush=True)
    order = ['ok', 'MISMATCH', 'TITLE?', 'NOT FOUND', 'no DOI', 'reviewed']
    print(f'{len(bib.entries)} entries: ' + ', '.join(f'{counts.get(k, 0)} {k}' for k in order))
    sys.exit(1 if counts.get('MISMATCH') or counts.get('NOT FOUND') else 0)


if __name__ == '__main__':
    main()
