#!/bin/bash
DOCX="$1"; OUT="$2"; SC=/Users/bnprs/BPR/GitRepos1/aim.pat/nagents/na-002-bnprs-core/008-bnprs-tech-docs/04-axon/workflows/iis-kiosk-proposal
rm -rf "$SC/media"
pandoc "$DOCX" --toc --toc-depth=2 --extract-media="$SC" -s -o "$SC/full.html" 2>/dev/null
python3 - "$SC/full.html" "$SC/cover.html" <<'PY'
import re,sys
p=sys.argv[1]; cover_out=sys.argv[2]; h=open(p).read()
# 1) TOC -> titled own-page block before Executive Summary
m=re.search(r'<nav id="TOC".*?</nav>', h, re.S); nav=m.group(0); h=h.replace(nav,"",1)
toc_div=f'<div class="toc-page"><h1 class="toc-title">Table of Contents</h1>{nav}</div>\n'
h=h.replace('<h1 id="executive-summary"', toc_div+'<h1 id="executive-summary"',1)
# 2) K3-style HTML cover (pandoc drops docx run formatting)
COVER = '''<div class="cover">
  <div class="cover-type-main">DESIGN &amp; COMMERCIAL PROPOSAL</div>
  <div class="cover-type-sub">SOLUTION DESIGN DOCUMENT</div>
  <hr class="cover-rule"/>
  <div class="cover-product">Instant Card Issuance Solution (Kiosk)</div>
  <div class="cover-subtitle">Next-Generation Self-Service Card Personalisation &amp; Dispensing Platform</div>
  <div class="cover-subtitle2">Multiple Design Options &mdash; Basic / Pro / Max</div>
  <table class="cover-meta">
    <tr><td class="k">Document ID</td><td>PROP-ICISKIOSK-2026-001</td></tr>
    <tr><td class="k">Version</td><td>1.0 (High-Level Proposal)</td></tr>
    <tr><td class="k">Classification</td><td class="conf">CONFIDENTIAL</td></tr>
    <tr><td class="k">Date</td><td>18 August 2026</td></tr>
    <tr><td class="k">Prepared By</td><td>BNPRS</td></tr>
    <tr><td class="k">Manufacturing Partner</td><td>Alpha91 KP Solutions (enclosure fabrication)</td></tr>
    <tr><td class="k">Prepared For</td><td><strong>MENTA</strong> &mdash; Managing Director review</td></tr>
    <tr><td class="k">Status</td><td>For approval &mdash; multiple design options</td></tr>
  </table>
</div>
'''
# force the §4 capability comparison table (first table after the §4 heading) onto its own page
d=h.find('id="design-options"')
if d!=-1:
    t=h.find('<table', d)
    if t!=-1: h=h[:t]+'<div class="pbreak"></div>'+h[t:]
bs=h.find('>',h.find('<body'))+1
rv=h.find('<h1 id="revision-history"')
# BODY render = everything from Revision History on (cover dropped); page counter starts at 2.
# Fixed full-width header/footer rules (K3 draws these) live here, on every body page.
RULES='<div id="hrule"></div><div id="frule"></div><div class="page-start-2"></div>'
h=h[:bs]+RULES+h[rv:]
open(p,"w").write(h)
# COVER render = clean standalone page 1 (no rules, no header/footer text)
open(cover_out,"w").write('<!doctype html><html><head><meta charset="utf-8"></head><body>'+COVER+'</body></html>')
PY
# two lean renders (cover + body) then a 2-file merge — avoids pdfseparate font-duplication bloat
weasyprint "$SC/cover.html" "$SC/cover.pdf" -s "$SC/proposal.css" 2>/dev/null
weasyprint "$SC/full.html"  "$SC/body.pdf"  -s "$SC/proposal.css" 2>/dev/null
pdfunite "$SC/cover.pdf" "$SC/body.pdf" "$OUT" 2>/dev/null
