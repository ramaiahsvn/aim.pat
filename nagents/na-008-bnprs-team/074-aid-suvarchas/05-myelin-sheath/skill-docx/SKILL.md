# Skill: Word Document Creation

## Description
Creates professional .docx files with proper formatting, headers,
footers, tables, and branding.

## Triggers
Use this skill when:
- User requests a Word document, report, memo, or letter
- Output requires professional formatting (TOC, headers, page numbers)
- User mentions ".docx" or "Word doc"

## Instructions

1. Determine document type (report, letter, memo, template)
2. Choose appropriate library (python-docx for Python, docx for Node.js)
3. Set up page layout: margins, orientation, header/footer
4. Apply consistent typography: Calibri/Cambria, proper heading hierarchy
5. Use brand colors if specified, otherwise professional defaults
6. Add table of contents for documents > 3 pages
7. Include page numbers in footer
8. Save to deliverables output folder

## Quality Checks
- [ ] Fonts render correctly when opened in Word
- [ ] Headers/footers appear on all pages
- [ ] Table formatting is consistent
- [ ] File size is reasonable (< 5MB for text-only docs)
