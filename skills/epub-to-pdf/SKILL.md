---
name: epub-to-pdf
description: "Convert epub files to PDF using calibre's ebook-convert CLI. Use when the user asks to: convert epub to pdf, turn an epub into pdf, make a pdf from epub, or mentions epub conversion. Trigger on keywords: epub, epub to pdf, convert book, ebook convert."
---

# EPUB to PDF Conversion

Convert epub files to PDF via calibre's `ebook-convert` CLI.

## Prerequisites

Ensure `ebook-convert` is available. If not, install calibre:

```bash
brew install --cask calibre
```

## Conversion

```bash
ebook-convert <input.epub> <output.pdf> --paper-size a4 --pdf-default-font-size 12
```

- Output filename: derive a clean, short name from the book title (strip publisher/site suffixes).
- Use glob (`*.epub`) when the filename contains special characters (quotes, parentheses) that break shell quoting.

## Batch Conversion

When multiple epub files need conversion, loop over them:

```bash
for f in *.epub; do
  ebook-convert "$f" "${f%.epub}.pdf" --paper-size a4 --pdf-default-font-size 12
done
```

## Common Options

| Flag | Purpose | Default |
|---|---|---|
| `--paper-size` | Page size (a4, letter, etc.) | a4 |
| `--pdf-default-font-size` | Base font size in pt | 12 |
| `--pdf-page-margin-top/bottom/left/right` | Margins in pt | 72 |
| `--pdf-serif-family` | Serif font name | System default |

## Notes

- Link anchor warnings during conversion are normal for most epub files and do not affect output quality.
- Skia Graphite backend errors are cosmetic and can be ignored.
- Conversion time scales with book length; large books (500+ pages) may take a few minutes.
