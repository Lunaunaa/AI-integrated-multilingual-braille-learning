# Braille standards and current implementation scope

## English

The intended English standard is Unified English Braille (UEB). The
International Council on English Braille identifies its 2024 rulebook as the
definitive UEB specification: <https://iceb.org/publications/ueb/>.

`EnglishGrade1Engine` is an initial, uncontracted subset. It currently covers
the 26 basic letters, digits and numeric mode, single and word capitalization,
spaces, and selected punctuation. Its numeric-mode fixtures cover ICEB 2024
examples `32`, `3b`, `3B`, `3m`, `4.2`, `4.b`, `4.B`, and `4.m` from Rule
6.5.2. Numeric mode remains active across decimal comma/period and ends at
spaces and unsupported punctuation; a grade 1 symbol indicator disambiguates
lowercase a–j after a digit, comma, or period.

This remains a subset, not complete UEB. It has no Grade 2 contractions or
shortforms, no grade 1 word/passage mode, and limited punctuation. The
exclamation mark, for example, shares a cell with a letter and is explicitly
rejected until its context rules are handled. Other unsupported cases raise an
error instead of being silently decoded.

## Hindi and Kannada

Forward translation is implemented as two separate Grade 1 modules using the
Unicode-mapped tables in NIEPVD's *Standard Bharati Braille Codes* (2025):
<https://niepvd.nic.in/publications/>. Fixtures cover chart entries for
consonants, dependent vowels, published conjuncts, native digits, and
unsupported-input rejection.

NIEPVD published Bharati Braille 2.1 on 20 July 2026 after technical
validation/refinement of the 2025 tables and states that it finalizes forward
translation across 13 languages. Its PDF could not be loaded for direct
cell-by-cell comparison in this environment, so the current mappings are
verified against the official 2025 edition and are not claimed to be current
2.1-complete. The modules reject unlisted characters. Unicode normalization,
extended/Vedic signs, full punctuation coverage, and 2.1 differences need
further review. Reverse translation is explicitly unimplemented and
unvalidated for both languages.

## Reference material

- ICEB, *Rules of Unified English Braille, Third Edition (2024)*:
  <https://iceb.org/wp-content/uploads/2025/10/Rules-of-Unified-English-Braille-2024.pdf>
- NIEPVD, *Bharati Braille 2.1* (2026) and earlier standards:
  <https://niepvd.nic.in/publications/>
- NIEPVD, *Standard Bharati Braille Codes with Unicode Mapped Chart* (2025),
  including Devanagari (Hindi) and Kannada tables:
  <https://cdnbbsr.s3waas.gov.in/s36ee69d3769e832ec77c9584e0b7ba112/uploads/2025/01/20250104954295710.pdf>
