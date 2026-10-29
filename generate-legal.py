#!/usr/bin/env python3
"""Turns the two policy pages into text bundled inside the apps.

The hosted pages stay the published source of truth — both stores require a URL — but the
apps carry their own copy so the consent screen works with no network, and on day one before
the site is even up. Generating one from the other is the only way they stay the same
document: a hand-copied policy diverges the first time either side is edited.

Run after editing either HTML page:

    ./generate-legal.py

Writes:
    PayWise/TrackWise/UI/Common/LegalText.swift
    E_track/app/src/main/java/com/etrack/budget/ui/legal/LegalText.kt
"""

from html.parser import HTMLParser
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
IOS = Path.home() / "Desktop/CODING/PayWise/TrackWise/UI/Common/LegalText.swift"
ANDROID = (Path.home() / "Desktop/CODING/E_track/app/src/main/java/com/etrack/budget"
           / "ui/legal/LegalText.kt")


class PolicyParser(HTMLParser):
    """Collects the page as (heading, [paragraphs]); lists and tables become paragraphs."""

    def __init__(self):
        super().__init__()
        self.title = ""
        self.updated = ""
        self.sections: list[tuple[str, list[str]]] = []
        self._heading: str | None = None
        self._paragraphs: list[str] = []
        self._buffer: list[str] = []
        self._capture = None
        self._cell: list[str] = []
        self._row: list[str] = []
        self._in_style = False

    def handle_starttag(self, tag, attrs):
        classes = dict(attrs).get("class", "")
        if tag == "style":
            self._in_style = True
        elif tag in ("h1", "h2", "p", "li", "td", "th"):
            if tag == "p" and "eyebrow" in classes:
                # The site's kicker above the title; a heading on the page, noise in the app.
                self._capture = "skip"
            elif tag == "p" and "updated" in classes:
                self._capture = "updated"
            else:
                self._capture = tag
            self._buffer = []
        elif tag == "tr":
            self._row = []

    def handle_endtag(self, tag):
        if tag == "style":
            self._in_style = False
            return
        if tag not in ("h1", "h2", "p", "li", "td", "th", "tr"):
            return

        text = re.sub(r"\s+", " ", "".join(self._buffer)).strip()

        if tag == "tr":
            # A two-column row reads as "Camera — scanning a payee's QR code".
            if len(self._row) == 2 and self._row[0].lower() not in ("permission", "what it is for"):
                self._paragraphs.append(f"{self._row[0]} — {self._row[1]}")
            self._row = []
            self._capture = None
            return

        if tag in ("td", "th"):
            self._row.append(text)
            self._capture = None
            return

        if not text:
            self._capture = None
            return

        if self._capture == "skip":
            self._capture = None
            return

        if tag == "h1":
            self.title = text
        elif self._capture == "updated":
            self.updated = text
        elif tag == "h2":
            self._flush()
            # Drop the "7" that the numbered terms headings carry as a separate span.
            self._heading = re.sub(r"^\d+\s*", "", text)
        elif tag == "li":
            self._paragraphs.append(f"•  {text}")
        else:
            self._paragraphs.append(text)
        self._capture = None

    def handle_data(self, data):
        if self._capture and not self._in_style:
            self._buffer.append(data)

    def _flush(self):
        if self._heading is not None or self._paragraphs:
            self.sections.append((self._heading or "", list(self._paragraphs)))
        self._paragraphs = []

    def finish(self):
        self._flush()
        # Anything before the first <h2> is the opening, which needs no heading.
        return self


def parse(path: Path) -> PolicyParser:
    parser = PolicyParser()
    parser.feed(path.read_text(encoding="utf-8"))
    return parser.finish()


def swift_string(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"')


def kotlin_string(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$")


def emit_swift(privacy: PolicyParser, terms: PolicyParser) -> str:
    def doc(p: PolicyParser) -> str:
        sections = ",\n".join(
            "            LegalSection(\n"
            f'                heading: "{swift_string(heading)}",\n'
            "                paragraphs: [\n"
            + ",\n".join(f'                    "{swift_string(x)}"' for x in paragraphs)
            + "\n                ])"
            for heading, paragraphs in p.sections
        )
        return (f'        title: "{swift_string(p.title)}",\n'
                f'        updated: "{swift_string(p.updated)}",\n'
                f"        sections: [\n{sections}\n        ]")

    return f'''// Generated by trackanywhere/landing/generate-legal.py — do not edit by hand.
// Edit the HTML pages in that folder and re-run it, so the bundled copy and the published
// pages stay the same document.

import Foundation

struct LegalSection: Identifiable {{
    let heading: String
    let paragraphs: [String]
    var id: String {{ heading + (paragraphs.first ?? "") }}
}}

struct LegalDocument {{
    let title: String
    let updated: String
    let sections: [LegalSection]
}}

enum LegalText {{
    static let privacy = LegalDocument(
{doc(privacy)}
    )

    static let terms = LegalDocument(
{doc(terms)}
    )
}}
'''


def emit_kotlin(privacy: PolicyParser, terms: PolicyParser) -> str:
    def doc(p: PolicyParser) -> str:
        sections = ",\n".join(
            "            LegalSection(\n"
            f'                heading = "{kotlin_string(heading)}",\n'
            "                paragraphs = listOf(\n"
            + ",\n".join(f'                    "{kotlin_string(x)}"' for x in paragraphs)
            + "\n                )\n            )"
            for heading, paragraphs in p.sections
        )
        return (f'        title = "{kotlin_string(p.title)}",\n'
                f'        updated = "{kotlin_string(p.updated)}",\n'
                f"        sections = listOf(\n{sections}\n        )")

    return f'''// Generated by trackanywhere/landing/generate-legal.py — do not edit by hand.
// Edit the HTML pages in that folder and re-run it, so the bundled copy and the published
// pages stay the same document.

package com.etrack.budget.ui.legal

data class LegalSection(val heading: String, val paragraphs: List<String>)

data class LegalDocument(
    val title: String,
    val updated: String,
    val sections: List<LegalSection>
)

object LegalText {{
    val privacy = LegalDocument(
{doc(privacy)}
    )

    val terms = LegalDocument(
{doc(terms)}
    )
}}
'''


def main() -> int:
    privacy = parse(HERE / "trackwise-privacy.html")
    terms = parse(HERE / "trackwise-terms.html")
    for name, p in (("privacy", privacy), ("terms", terms)):
        if not p.sections:
            print(f"error: parsed no sections from the {name} page", file=sys.stderr)
            return 1

    IOS.write_text(emit_swift(privacy, terms), encoding="utf-8")
    ANDROID.write_text(emit_kotlin(privacy, terms), encoding="utf-8")
    print(f"privacy: {len(privacy.sections)} sections, terms: {len(terms.sections)} sections")
    print(f"wrote {IOS}")
    print(f"wrote {ANDROID}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
