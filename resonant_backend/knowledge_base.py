"""Small, traceable retrieval corpus backed by Resonant's verified subset.

This is intentionally not a complete UEB rulebook. Exact letter cells come
from the same basic-cell table used by verified_braille.py; wider claims are
excluded until documented fixtures exist.
"""
import re
from typing import Iterable

from verified_braille import _LETTERS, verified_single_letter

UEB_URL = "https://iceb.org/Rules%20of%20Unified%20English%20Braille%202024.pdf"
UEB_TITLE = "ICEB, Rules of Unified English Braille, Third Edition (2024)"


def _dots(cell: int) -> str:
    return ", ".join(str(bit + 1) for bit in range(6) if cell & (1 << bit)) or "no raised dots"


_DOCUMENTS: list[dict[str, object]] = [
    {
        "id": "english-six-dot-cell",
        "title": "Six-dot Braille cell and dot numbering",
        "content": (
            "A standard six-dot Braille cell has two columns and three positions. "
            "The left column is dots 1, 2, 3 from top to bottom. The right column "
            "is dots 4, 5, 6 from top to bottom. The dot identifiers do not change "
            "with the device screen layout."
        ),
        "terms": "cell layout columns rows positions upper lower left right numbering dots",
        "source": {"title": UEB_TITLE, "url": UEB_URL},
        "scope": "basic six-dot cell layout",
    },
]

for _letter, _cell in _LETTERS.items():
    _evidence = verified_single_letter(_letter)
    assert _evidence is not None
    _DOCUMENTS.append({
        "id": f"english-letter-{_letter}",
        "title": f"Uncontracted English Braille letter {_letter.upper()}",
        "content": (
            f"In Resonant's verified uncontracted English subset, letter "
            f"{_letter.upper()} uses {_dots(_cell)}. The engine cell value is {_cell}. "
            "This is a single-letter cell and does not describe contractions "
            "or a complete word encoding."
        ),
        "terms": f"letter {_letter} {_letter.upper()} alphabet uncontracted basic english braille pattern dots",
        "source": {"title": UEB_TITLE, "url": UEB_URL},
        "scope": "verified basic uncontracted English letter cell",
    })

_DOCUMENTS.extend([
    {
        "id": "resonant-english-scope",
        "title": "What Resonant currently supports in English Braille",
        "content": (
            "Resonant currently verifies uncontracted English letters and a limited "
            "set of indicators and punctuation. It does not implement full UEB, "
            "Grade 2 contractions, shortforms, or every context rule. Unsupported "
            "cases must be identified instead of guessed."
        ),
        "terms": "scope limitation supported unsupported full UEB grade 2 contractions shortforms context rules",
        "source": {"title": "Resonant verified engine scope", "url": "docs/braille-standards.md#english"},
        "scope": "implementation limitation, not a UEB rule",
    },
    {
        "id": "resonant-language-scope",
        "title": "Language support in the voice tutor",
        "content": (
            "The voice tutor currently accepts English only. Hindi and Kannada "
            "voice tutoring and backend Braille responses are not enabled or "
            "validated end to end. Do not infer speech support from a language "
            "selector or from a model's multilingual claims."
        ),
        "terms": "Hindi Kannada language multilingual speech voice recognition unsupported not enabled",
        "source": {"title": "Resonant project status", "url": "docs/project-status.md"},
        "scope": "current product capability",
    },
])

_TOKEN = re.compile(r"[a-z0-9]+", re.IGNORECASE)
_ALIASES = {
    "upper": "top capital",
    "uppercase": "capital letter",
    "lowercase": "small letter",
    "raised": "dot",
    "positions": "layout",
    "column": "left right",
    "columns": "left right",
    "contraction": "contractions",
    "ueb": "unified english braille",
    "language": "Hindi Kannada English",
}


def _tokens(text: str) -> set[str]:
    tokens = set(_TOKEN.findall(text.lower()))
    expanded = set(tokens)
    for token in tokens:
        if token in _ALIASES:
            expanded.update(_TOKEN.findall(_ALIASES[token].lower()))
    return expanded


def _effective_query(question: str, history: Iterable[dict] = (), lesson_context: str = "") -> str:
    query = question.strip()
    # Resolve short follow-ups such as "why?" with the preceding learner turn.
    if len(_tokens(query)) <= 2:
        previous_user = next((
            turn.get("content", "") for turn in reversed(list(history))
            if turn.get("role") == "user" and isinstance(turn.get("content"), str)
        ), "")
        if previous_user:
            query = f"{previous_user} {query}"
    return f"{query} {lesson_context[:400]}"


def retrieve_evidence(
    question: str,
    *,
    history: Iterable[dict] = (),
    lesson_context: str = "",
    limit: int = 4,
) -> list[dict[str, object]]:
    """Rank verified evidence by lexical overlap; no external service required."""
    effective_query = _effective_query(question, history, lesson_context)
    # Keep retrieval precise for common intents instead of returning adjacent
    # alphabet entries merely because their documents share generic terms.
    letter = requested_english_letter(effective_query)
    if letter and re.search(r"\b(braille|pattern|letter|dots?|cell|encode)\b", effective_query, re.I):
        exact = evidence_for_letter(letter)
        if exact:
            return exact[:limit]
    if re.search(r"\b(hindi|kannada|bharati|language|multilingual)\b", effective_query, re.I):
        return [dict(_DOCUMENTS[-1])]
    if re.search(r"\b(ueb|contractions?|shortforms?|supported|support|scope)\b", effective_query, re.I):
        return [dict(_DOCUMENTS[-2])]
    if re.search(r"\b(six[- ]dot|layout|numbering|columns?)\b", effective_query, re.I):
        return [dict(_DOCUMENTS[0])]

    query_tokens = _tokens(effective_query)
    scored: list[tuple[int, dict[str, object]]] = []
    for document in _DOCUMENTS:
        if str(document["id"]).startswith("english-letter-"):
            continue
        title_tokens = _tokens(str(document["title"]))
        term_tokens = _tokens(str(document["terms"]))
        content_tokens = _tokens(str(document["content"]))
        score = (
            4 * len(query_tokens & title_tokens)
            + 3 * len(query_tokens & term_tokens)
            + len(query_tokens & content_tokens)
        )
        if score:
            scored.append((score, document))
    scored.sort(key=lambda item: (-item[0], str(item[1]["id"])))
    return [dict(document) for score, document in scored[:limit] if score >= 3]


def source_references(evidence: Iterable[dict[str, object]]) -> list[dict[str, str]]:
    references: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for item in evidence:
        source = item.get("source")
        if not isinstance(source, dict):
            continue
        title, url = source.get("title"), source.get("url")
        if isinstance(title, str) and isinstance(url, str) and (title, url) not in seen:
            seen.add((title, url))
            references.append({"title": title, "url": url})
    return references


def format_evidence(evidence: Iterable[dict[str, object]]) -> str:
    blocks = []
    for item in evidence:
        source = item.get("source", {})
        source_title = source.get("title", "Resonant verified source") if isinstance(source, dict) else "Resonant verified source"
        blocks.append(
            f"[{item.get('id')}] {item.get('title')} (scope: {item.get('scope')}; source: {source_title})\n"
            f"{item.get('content')}"
        )
    return "\n\n".join(blocks)


def has_braille_scope(question: str) -> bool:
    return bool(re.search(
        r"\b(braille|dots?|cell|letter|contractions?|ueb|bharati|hindi|kannada|pattern|transcrib)\b",
        question,
        re.IGNORECASE,
    ))


def requested_english_letter(question: str) -> str | None:
    patterns = (
        r"\bletter\s+([a-z])\b",
        r"\b(?:braille|pattern)\s+(?:pattern\s+)?for\s+([a-z])\b",
        r"\bencode\s+([a-z])\b",
        r"(?<![a-zA-Z'’])([a-z])\s+in\s+braille\b",
    )
    for pattern in patterns:
        match = re.search(pattern, question, re.IGNORECASE)
        if match:
            return match.group(1)
    return None


def evidence_for_letter(letter: str) -> list[dict[str, object]]:
    key = f"english-letter-{letter.lower()}"
    return [dict(document) for document in _DOCUMENTS if document["id"] == key]
