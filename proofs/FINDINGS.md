# Norg 1.0: formalization findings

This directory models the Norg 1.0 syntax in Lean 4. The model is deliberately
literal: where the prose is ambiguous, both readings are kept (for example
`boundaryLiteral` vs `boundaryExamples` in `Norg/Basic.lean`) so the
disagreement is executable rather than hidden in a parser implementation.

Line references are to `../1.0-specification.norg`. The repository's
`norg.peg` is a known-incomplete lexical sketch and is **not** treated as
normative evidence; it was updated in this iteration to match the prose where
its scope allows (`word`, punctuation, line endings, heading titles). Every
finding below is derived from the prose and the examples only.

**How to read the table.** `Contradiction` means two normative statements
cannot both hold. `Gap` means a construct used by an example has no
production. `Implementation leak` means parser behaviour is presented as
format behaviour. `Ambiguity` means the prose admits more than one total
reading. `Model limitation` means the Lean model is intentionally narrower
than the Unicode spec (currently: non-ASCII punctuation categories).

| ID | Kind | Severity | Area | Finding |
|----|------|----------|------|---------|
| F1 | Gap / contradiction | High | words | `word` excludes punctuation, but paragraph segments are only words + inline elements, so punctuation has no production. |
| F2 | Contradiction | High | whitespace | Whitespace is defined as Unicode `Zs` only, but tabs are discussed as whitespace and used for indentation. |
| F3 | Contradiction | High | attached modifiers | The boundary rule forbids paragraph edges, yet the spec's valid example `*Bold text*` needs both edges. |
| F4 | Gap | High | detached modifiers | `%` "Attributes" is in the detached-modifier table but has no section or semantics anywhere. |
| F5 | Contradiction | Medium | layers | Variables are called layer 5 but listed in layer 4; layer 1 calls `%` a "null detached modifier". |
| F6 | Gap | High | precedence | The precedence list omits delimiting modifiers and detached-modifier suffixes, and repeats a free-form token. |
| F7 | Implementation leak | Medium | detached modifiers | Level 7+ headings/lists/quotes are valid syntax, but the spec says they "fall back to level 6 in the tree-sitter parser". |
| F8 | Ambiguity | High | `:` / `::` | `:`/`::` are both range-able detached modifiers and detached-modifier suffixes; the disambiguator is only "whitespace vs immediate line ending", which is not stated as a precedence rule. |
| F9 | Contradiction | Medium | extensions | A detached-modifier extension "must be followed by whitespace", so `- (x)` at end of line is invalid; TODO states on empty items are natural. |
| F10 | Contradiction | Medium | attached modifiers | `**`, `//` etc. are disqualified "in all circumstances", but `** Heading` is a valid heading. |
| F11 | Gap | High | links | Link location is a bullet list of alternatives "with limited inter-compatibility", not a grammar. `{ * text}` vs `{# link text}`, and `{:file:}` vs `{:file:123}`, are not derivable. |
| F12 | Contradiction | High | links | Nested linkables are valid, but the format claims to need only single-character look-ahead. |
| F13 | Contradiction | High | timestamps | `<day-of-month>` is numeric with at most 3 digits, but every example uses ordinals (`12th`, `5th`, `20th`); `-` is both range separator and negative-year sign. |
| F14 | Ambiguity | High | intersecting modifiers | ` : ` has no scope restriction; as written it can split any paragraph segment, making ordinary colons structural. |
| F15 | Ambiguity | Medium | tags | Tag names allow regular chars + `-`/`_`/`.`; parameters may be "any character apart from a line ending"; `#tag!`, `.` hierarchy edge cases, and escaped spaces are unspecified. |
| F16 | Gap | High | escaping | Escaping excludes only free-form and ranged verbatim segments, leaving inline verbatim attached modifiers unspecified; the free-form notation in the precedence list is mangled. |
| F17 | Gap | Medium | line endings | `U+000C` is a line ending, but the permitted combinations list only LF, CR and CRLF; `\f\n` is unspecified. |
| F18 | Ambiguity | Medium | paragraphs | A paragraph break is "two consecutive line endings" and also "an empty line"; whitespace-only lines and consecutive empty lines are not distinguished. |
| F19 | Gap | High | tree building | Structural/nestable/range-able grouping rules are prose; the exact group/nest/close semantics are not defined precisely enough to implement from the text alone. |
| F20 | Gap | Medium | tables | Table motions (`_` floor, `/` ceiling, underflow at column 1, no populated cell) are described in the semantics doc with edge cases unspecified. |
| F21 | Contradiction | High | attached modifiers | The invalid example `*Bold\ntext\n*` cannot be rejected by "closing may not be preceded by whitespace": a line ending is explicitly *not* whitespace, so the closing is legal under the stated rule. |
| F22 | Contradiction | High | attached modifiers | Valid `*Bold\ntext*` opens at the start of a paragraph, but "opening may only be preceded by whitespace or punctuation" has no case for paragraph start. |
| F23 | Ambiguity | Medium | headings/lists | Empty titles and empty list items: `* ` and `- ` are syntactically accepted, but the spec's invalid example treats an empty heading title as invalid and never says whether empty content is allowed. |
| F24 | Ambiguity | Medium | tags | The `.` hierarchy separator has no edge rules: `#.leading`, `#trailing.`, `#double..dot` are neither accepted nor rejected by the prose. |
| F25 | Ambiguity | Medium | tags | `=` is overloaded: macro definition, strong tag end, and part of the `===` strong delimiter. `==` is not defined as either. |
| F26 | Ambiguity | Medium | links | Linkables explicitly forbid a line ending before the closing modifier; attached modifiers have the same practical restriction only in an example, not in the normative rule. |
| F27 | Scope | Medium | links | Link resolution is document-global ("first match from the top"), so link syntax cannot be validated without the whole document; this is a semantics boundary, not a local grammar. |
| F28 | Ambiguity | Medium | range-able modifiers | A ranged object with an empty title cannot be written without a trailing space: `$$` is the closer, so only `$$ ` opens an empty ranged definition. The spec never mentions this form. |
| F29 | Ambiguity | Medium | tags | `=end` is both the ranged-tag closer and an ordinary macro tag named `end`; a line classifier cannot distinguish them without open-tag state. |
| F30 | Gap | Low | detached modifiers | Arity is said to depend on modifier type, but the table has no arity column; arities are recoverable only from examples. |
| F31 | Gap | Low | tags | Parameters are "space-separated" and `\ ` escapes spaces, but leading/trailing/extra whitespace and trimming are unspecified. |
| F32 | Ambiguity | High | links | File links have three competing spellings (`{:file:}`, `{/ file}`, `{file://...}`) with different allowed combinations; the "limited inter-compatibility" table is only implied by examples. |
| F33 | Ambiguity | Medium | links | Link scoping uses `:` inside a linkable, colliding with the file-location closing colon and the table-cell sigil; no escaping or delimiter rule is given. |
| F34 | Gap | Medium | links | Inline link targets `<...>` cannot carry descriptions and are only linkable via `#`; the grammar and the reason for the restriction are absent. |
| F35 | Ambiguity | Medium | links | The "no line ending before the closer" rule is stated for linkables but only implied by examples for descriptions `[]`; the two use the same bracket pair. |
| F36 | Contradiction | Medium | verbatim | Verbatim closers are still subject to the attached-modifier boundary rules, so `` `a`b `` has no code span; this conflicts with the "deterministic start and end" and verbatim-precedence claims. |
| F37 | Contradiction | High | escaping | Escaping is excluded only inside free-form/ranged verbatim, but precedence ranks escaping above verbatim attached modifiers; whether `` `\`` `` can contain a backtick is therefore contradictory. |
| F38 | Ambiguity | Low | attached modifiers | An escaped character inside a doubled run (`\**`) is skipped before run detection; the spec does not say whether the escaped character counts toward "two or more consecutive". |
| F39 | Gap | Medium | attached modifiers | Unclosed attached modifiers have no specified result; the spec only says unclosed linkables "may be an error". The model treats them as raw text and reports them in `unclosed`. |
| F40 | Ambiguity | Low | paragraphs | Consecutive empty lines: are they one paragraph break, several, or do they create an empty paragraph? The model keeps each blank line as a separate chunk. |
| F41 | Ambiguity | Medium | descriptions | Whether inline markup inside `[...]` shares the surrounding attached-modifier stack is unspecified; the model scans each description as a fresh inline scope. |
| F42 | Ambiguity | Medium | escaping / links | Linkables outrank escaping, so `[a \] b]` closes at the escaped-looking `]`; the spec never says whether a backslash can protect a linkable delimiter. |
| F43 | Gap | Medium | links | Nested linkables inside a link location are matched structurally but not re-parsed; the spec does not say whether they are semantic links or target text. |
| F44 | Gap | Low | links | A description `[...]` following an inline target `<...>` is undefined: the spec forbids descriptions on `<...>` but not whether a following description is an error, an anchor, or ignored. |

## Details

### F1. Words do not include punctuation, and paragraph segments have no slot for it

Spec 113: "A *word* is considered to be any combination of regular
characters." Spec 103-105 defines regular characters as everything not
described by the preceding sections, and those sections include whitespace,
line endings, and punctuation. So `,`, `.`, `!`, `?`, `(`, `)`, quotes, and
even `\` are not regular.

Spec 115-119 then says a paragraph segment contains words and inline elements
(attached modifiers, linkables). There is no production for a bare punctuation
character. A sentence like `Hello, world!` therefore contains three
punctuation characters that belong to no syntactic category.

**Model decision.** `Norg.Basic.isRegular` follows the prose literally
(punctuation is not regular). The block/inline layers treat punctuation as
ordinary text at the segment level, because otherwise no example in the spec
would parse. This is a deliberate repair, not a derivation.

**Decision needed.** Either (a) add punctuation to the paragraph-segment
production, or (b) redefine `word` as "non-whitespace, non-line-ending" and
drop the "regular characters" wording. Option (b) matches every real parser.

### F2. Whitespace is `Zs` only, but tabs are whitespace in practice

Spec 56-60 defines whitespace as Unicode `Zs` and says "any combination of the
above is also considered whitespace" (vacuous: a combination of `Zs` chars is
already `Zs`). Spec 62 then discusses tabs and suggests a tab stop of 4, which
only makes sense if tabs participate in indentation.

**Model decision.** `isSpecWhitespace` = `Zs`; `isOperationalWhitespace` =
`Zs` or tab. All parsers use the operational predicate, and the difference is
visible in `Norg.Basic` (`isTab`). Tabs are therefore a deliberate extension.

**Decision needed.** Say "whitespace is `Zs` or `U+0009`" and delete the tab
stop suggestion, or keep `Zs` and say tabs are regular characters.

### F3 / F21 / F22. The attached-modifier boundary rule is not total

Spec 1051-1055 gives four rules:

1. opening may only be preceded by whitespace or punctuation;
2. opening may not be succeeded by whitespace;
3. closing may not be preceded by whitespace;
4. closing may only be succeeded by whitespace or punctuation.

Spec 76 says line endings are *not* whitespace. The rule set has no case for
the start or end of a paragraph.

The spec's own valid example at 1097 is `*Bold text*`. The opening `*` is
preceded by paragraph start (not whitespace/punctuation); the closing `*` is
succeeded by paragraph end (not whitespace/punctuation). The final line of the
document, `%| vim: set tw=100 :|%` (1780), has the same shape. Both are
invalid under the literal rule.

The invalid example at 1124-1126 is:

```
*Bold
text
*
```

The closing `*` is preceded by a line ending. Line endings are not whitespace,
so rule 3 does not reject it. The example says it is invalid, so the intended
rule must also reject a line ending before a closing delimiter.

**Model decision.** `boundaryLiteral` is the literal transcription (no edges,
no line-ending cases). `boundaryExamples` is the smallest total model that
makes 1097, 1102-1103 and 1124-1126 behave as the spec says:

- opening may be preceded by paragraph/line start, whitespace, punctuation, or
  a line ending;
- closing may *not* be preceded by whitespace or a line ending;
- closing may be followed by whitespace, punctuation, a line ending, or
  paragraph end.

`Norg/Inline.lean` runs the same scanner against both models. The divergence
on `*Bold text*` is the executable witness for F3; the divergence on
`*Bold\ntext\n*` is the witness for F21.

**Decision needed.** Replace the four bullets with the total boundary model
above, explicitly saying "start/end of paragraph" and "line ending".

### F4. `%` detached "Attributes" has no definition

Spec 198-202 lists `%` as a nestable detached modifier named "Attributes".
There is no `** Attributes` section, no example, and no statement of what it
does. Spec 1735 calls it a "null detached modifier", but `%` is already the
*attached* null modifier (1091, 1139-1155). A reader cannot tell whether
`% note` is a comment block, an attribute block, or a typo.

**Model decision.** `Norg.Blocks` recognizes `%` + whitespace as
`.attribute level content` and does not assign semantics. The attached `%` is
handled separately by `.null` in the inline layer.

**Decision needed.** Either document a detached `%` construct or remove it
from the table.

### F5. Layer numbering of variables and the null modifier

Spec 1158: "Variables are a **layer 5** attached modifier". Spec 1768 lists
`&variable&` under layer 4. Spec 1735 says layer 1 contains a "null detached
modifier", which conflates the detached `%` (F4) with the attached `%null%`.

**Decision needed.** One canonical layer table, with each modifier appearing
exactly once.

### F6. The precedence list is incomplete and partly duplicated

Spec 1691-1702 is the only precedence statement. It lists structural
detached modifiers, nestable/range-able, extensions, linkables, attached
modifiers, and free-form variants. It does **not** list:

- delimiting modifiers (`---`, `===`, `___`), even though they terminate
  structural modifiers and indent segments;
- detached-modifier suffixes (`:` / `::`), even though they change indentation
  and are ambiguous with table cells (F8);
- the relative order of tags vs detached modifiers (tags are line-start
  constructs too).

Line 1698 repeats the same free-form token twice in the parenthetical, so the
list cannot be read as an ordered grammar.

**Model decision.** Precedence is encoded operationally in `classifyBlock`:
tags/delimiters are recognized before paragraph text; detached modifiers
before inline markup. The model does not claim this is the spec's order.

**Decision needed.** A numbered precedence list with one row per construct,
including delimiters and suffixes.

### F7. Level 7 fallback is implementation behaviour

Spec 221-227, 254-275, 283-304, 313-334 show level 7 and parenthesize
"(falls back to level 6 in the tree-sitter parser)". The grammar at 153-154
allows an arbitrary number of consecutive characters. The fallback is not a
format rule; it is one parser's choice.

**Model decision.** `classifyBlock` keeps the full run length. It does not cap
at 6. If a consumer wants the tree-sitter behaviour, it can apply `min 6`
downstream.

### F8. `:` and `::` are two constructs with the same spelling

Range-able detached modifiers (353-363) use one or two characters followed by
*whitespace* and a verbatim title. Detached-modifier suffixes (638-646) use
`:` (slide) or `::` (indent segment) and must be followed *immediately* by a
line ending. Table cells use `:` / `::` as range-able modifiers (402-410).

The disambiguator is therefore:

- `:` + whitespace + text → table cell opener;
- `:` + line ending → slide suffix;
- `::` + whitespace + text → ranged table cell opener;
- `::` + line ending → indent segment, or a ranged table cell closer.

The spec never states this as a precedence rule. The closing `::` of a ranged
table cell and the opening `::` of an indent segment are distinguished only by
context and the following character. The spec's own table example at 407-409
uses `::` both as a cell opener and as a closer.

**Model decision.** `classifyBlock` treats `::` + EOL as `.close .tableCell`
and `::` + whitespace as `.tableCell true`. It cannot resolve the context
without a stateful block parser; that is deliberately left to the next layer.

### F9. Extensions cannot end a line

Spec 515: "The whole detached modifier extension /must/ be followed by
whitespace." So `- (x)` at end of line is invalid, as is `- (x)` with no
content after it. The extension grammar itself (504-513) does not require a
content segment, and TODO states on empty items are a normal use case.

**Model decision.** `Norg.Blocks` currently stops at the raw list content; it
does not parse extensions yet. When it does, the literal rule will reject
end-of-line extensions.

**Decision needed.** Allow end-of-line as a terminator for an extension, or
require a trailing space and document the empty-item limitation.

### F10. `**` cannot be both disqualified and a heading

Spec 1075-1077: "Two or more consecutive attached modifiers of the same type
(i.e. `**`, `//` etc.) should be instantly 'disqualified' and parsed as raw
text in /all/ circumstances and without any exceptions."

Spec 221-227 defines `**` at line start as a level-2 heading. If "attached
modifiers" is read literally as the character sequence, the heading is
impossible. The intended scope must be "inside a paragraph segment, when the
delimiter is treated as an attached modifier".

**Model decision.** `Norg.Blocks` gives line-start `**` to the heading
classifier. `Norg.Inline.scan` disqualifies `**` inside a paragraph segment.
The two layers do not share a precedence rule, because the spec does not give
one.

**Decision needed.** Scope the disqualification to attached modifiers after
block-level constructs have been recognized.

### F11. Link location is not a grammar

Spec 1330-1341 is a bullet list: file location, line number, URL, detached
modifier + name, custom link modifiers (`/`, `#`, `?`, `=`), timestamp. It
says "one (or more; with limited inter-compatibility)" and then gives
per-type restrictions:

- 1369-1376: a file location may only be accompanied by a detached modifier,
  line number, or the magic `#`;
- 1378-1384: `/`, `@` and URLs are not allowed with file locations.

The spec's valid/invalid examples at 1632 and 1668 use `{# link text}` and
`{ * text}`. Why `{# ...}` is valid and `{ * ...}` is not is not derivable
from 1310-1313 alone: both open with a sigil followed by whitespace. The
difference must be that `#` is a valid link-location sigil and `*` is not.

`{:path/to/file:}` (1352) and `{:path/to/file:123}` (1373) use a trailing
colon as a terminator, but `:` is also a link modifier and the prefix of a
Windows path (`C:\...`). The grammar does not say how the trailing colon is
found or whether a Windows path is a file location.

**Model decision.** `Norg/Linkables.lean` now uses an explicit `Kind`/`Span`
model for locations, descriptions, inline targets, and local target validation.
It does not resolve targets; document-global resolution is F27.

**Decision needed.** A proper grammar for link location, with a separator
rule that is unambiguous for Windows paths and timestamps.

### F12. Nested linkables require a stack, contradicting single-character look-ahead

Spec 36-37 says the format is designed to be parsed in a single pass with
"only single-character look-ahead". Spec 1647 gives a valid nested linkable:

```
{* Link to {# headings}[heading]}[*markup*]
```

Matching the inner `{...}` and `[...]` pairs requires a stack or unbounded
look-ahead. A single-character look-ahead parser can only treat the inner
braces as text, which would make the outer link's description wrong.

**Model decision.** `Norg/Linkables.lean` matches nested `{}`/`[]`/`<>` with
an explicit stack, and `Norg/Inline.lean` treats a valid span as opaque. That
is exactly the stack the single-character look-ahead claim denies.

### F13. Timestamp ordinals and the two meanings of `-`

Spec 568-569: `<day-of-month>` is "simply a numeric value with at most 3
digits". Every example uses an ordinal: `12th` (584), `5th` (589, 594, 626,
635), `20th` (589). `12th` is not numeric.

Spec 575: the year may be prefixed with `-` for B.C. Spec 589-590: `-` also
separates the two sides of a timestamp range. The grammar at 556 does not
say how to disambiguate `5th Aug 2022-20th August 2022` (range) from a
negative year, or whether `- 20th` with spaces is the same range.

**Model decision.** Timestamps are recognized as opaque extension payloads,
not parsed into fields. This matches the note at 598-602 ("a parser is not
required to perform any timestamp analysis further than detecting what set of
characters contain a timestamp").

### F14. ` : ` has no scope restriction

Spec 1261-1296 defines the intersecting modifier as whitespace + `:` +
whitespace, expanding to a newline inside a paragraph. It says it intersects
"two different paragraph segments (and *only* paragraph segments)". It does
not say whether the colon is recognized:

- inside an attached modifier (`*a : b*`),
- inside a link description (`[a : b]`),
- inside a tag parameter (`#x a : b`),
- inside inline verbatim (`` `a : b` ``),
- at the start or end of a paragraph segment.

As written, the rule is a global textual rewrite and would make ordinary
colons structural.

**Model decision.** Implemented in `Norg/Intersecting.lean`. `find` is the
scoped reading: hits are recognized only at paragraph-segment top level,
outside verbatim attached modifiers and linkable spans; standard attached
modifiers and standard free-form bodies are transparent. `findRaw` is the
literal global rewrite, and `findSpec` uses the literal `Zs`-only whitespace
reading, so the alternatives stay executable. `expand` replaces the whole
whitespace run around the colon with one newline; it does not synthesize
indentation.

Consequences worth recording:

- `*bold : text*` becomes two segments (`*bold`, `text*`), each with an
  unclosed modifier.
- `foo  :  bar` consumes both whitespace runs, although the prose reads as one
  character per side.
- `\ :` is a hit under the raw reading (the escaped space is still `Zs`) and a
  miss under the scoped reading.
- Attached-extension metadata `(a : b)` is transparent by choice, because the
  spec never says whether it is a paragraph segment.

### F15 / F24 / F25. Tag names, parameters, and `=` overload

Spec 738-743: name characters are regular characters and/or `-` and `_`, with
`.` as a hierarchy delimiter. This leaves open:

- leading dot (`#.leading`), trailing dot (`#trailing.`), double dot
  (`#double..dot`);
- whether `.` in a name can be escaped (`\.`), and whether escaped dots are
  literal;
- whether a tag name can be empty (`#` followed by whitespace is not a tag,
  but `#` followed by EOL?).

Spec 754: parameters "may consist of any character (apart from a line
ending, of course)". Spec 749-750 says spaces are escaped with `\ `. This
does not define `\\`, a trailing `\`, or whether `\ ` is a two-character
sequence in the parameter value or one space.

`=` is overloaded three ways:

- `=name` macro definition (778-794);
- `=end` closes a macro/ranged tag (768-776);
- `===` strong delimiting modifier (472-483).

`==` is neither a tag nor a delimiter. The spec does not give a precedence
between the macro tag and the delimiter; the delimiter is recognized only when
the run is 2+ and immediately followed by a line ending, which is a rule the
prose never states.

**Model decision.** `Norg.Tags.parseTag` accepts `[A-Za-z0-9...]`-style
regular chars plus `-`, `_`, `.`; it rejects a name followed by `!`; it does
not trim or unescape parameters. `Norg.Blocks` gives `===` + EOL to the
delimiter and `=name` to the tag. The edge cases above are asserted in
`#guard` tests with comments.

### F16. Escaping inside inline verbatim is unspecified

Spec 97-99: "Any character may be escaped /apart from/ characters within
free-form and ranged verbatim segments." Inline code (`` `...` ``), inline
math (`$...$`) and variables (`&...&`) are verbatim attached modifiers
(1090-1093). They are neither free-form nor ranged, so the exclusion does not
apply to them. Does `\`` escape a backtick inside inline code? If yes, inline
code can contain its own delimiter, which contradicts the free-form section's
claim that representing a backtick inside a verbatim block is impossible
(1167-1169). If no, the escaping rule's scope is wrong.

Spec 1174-1177 shows the free-form syntax as `<mod>| ... |<mod>`, e.g.
`` `| ... |` ``. Spec 1698 writes the same idea as `|``|` and `|``|` (the raw
text repeats the token), so the abstract notation in the precedence list is
mangled.

**Model decision.** `Norg.Inline` treats backslash as literal inside a
verbatim span and implements free-form `|...|` spans. The escaping
contradiction remains: the free-form form is the spec's workaround for a
delimiter that cannot otherwise be embedded.

### F17 / F18. Line endings and paragraph breaks

Spec 78-81: LF, FF, CR are line endings. Spec 83-86: permitted combinations
are LF, CR, CRLF. FF is not in the combination list, so `\f\n` is either two
line endings or an invalid pair.

Spec 142-145 defines a paragraph break as two consecutive line endings, and
says a line containing only whitespace is also empty. It does not say whether
`\n \n` (space-only line) is one break, whether `\n\n\n` is one break or two,
or whether a break at the start/end of a document counts. These matter for
grouping (421-447) and for nestable/range-able termination.

**Model decision.** `Norg.Basic.splitLines` treats LF, CR, CRLF and FF as
single endings and preserves the ending in `Line.ending`. It does not collapse
or count breaks; paragraph assembly is a later layer.

### F19. Tree building is prose, not a grammar

Spec 211-217 (structural consumes everything, closes on same/lower level),
240-248 (nestable consumes a paragraph, closes on a paragraph break),
353-363 (range-able title/content and closing delimiter), and 421-447
(grouping of consecutive same-type modifiers) are the only tree-building
rules. They are prose with examples; there is no formal statement of:

- whether a lower-level structural modifier closes a higher-level group or
  becomes its child;
- what "same or lower level" means for a mixed heading/list stack;
- whether consecutive range-able items group across blank lines;
- how a closing delimiter interacts with a group of multiple items.

`Norg/Structure.lean` is a coarse stack model that records its choices for
heading/list nesting, delimiters, and `::` indent segments. It is not a
tree-sitter clone and does not settle the prose ambiguities above.

### F20. Table motions

`1.0-semantics.norg` 425-519 describes `_` (floor) and `/` (ceiling) motions
over populated cells. Edge cases not defined there: no populated cell in the
search direction, underflow at column 1, motion repetition/combination,
whether the header row participates, and what `A1` underflow returns.

This is a good standalone Lean target because it is a small state machine
over a finite grid; it does not need the rest of the parser.

### F21 / F22. See F3 above

These are separated in the table because they are different rules with
different fixes: F21 is the missing "line ending before a closing delimiter"
case, F22 is the missing "paragraph/line start" case for openings.

### F23. Empty titles and empty content

Spec 208-209 says a structural modifier consumes one paragraph segment as its
title. A paragraph segment is a line of text (121-127), but can it be empty?
The invalid example at 349-350 is:

```
*
    I am not a valid heading title.
```

which is invalid because `*` + EOL has no whitespace after the marker, not
because the title is empty. `* ` (star + space + EOL) *does* have whitespace
and would be a heading with an empty title under a literal reading; the spec
never says whether that is valid. The same question applies to `- `, `~ `,
`> ` and the range-able openers.

**Model decision.** `Norg.Blocks` accepts an empty title/content after the
mandatory whitespace and returns `.heading 1 ""` / `.listItem false 1 ""`.
This is the literal reading; it is flagged rather than silently corrected.

### F26. Linkable closing rule is stricter than the attached-modifier rule

Spec 1311-1313:

- an opening linkable modifier may be instantly succeeded by anything but a
  line ending;
- a closing linkable modifier may *not* be preceded by a line ending.

This is exactly the missing half of F21, but stated only for linkables. The
attached-modifier section (1051-1055) omits it and relies on the invalid
example at 1124-1126. If both constructs share the same line-ending model, the
normative text should say so once.

### F27. Link resolution is document-global

Spec 1302-1304: "When resolving links, the first match should always be the
only match, starting from the top of the document and heading towards the
bottom." This makes a link's validity depend on the entire document, not on a
local parse. A syntax parser can check the *shape* of a link, but not whether
its target exists or which duplicate target wins. That belongs to the
semantics layer, which is unfinished (`1.0-semantics.norg` has TODOs at 10-12,
16 and a TODO examples section at 521-523).

### F28. Empty ranged titles need a trailing space

Spec 151-155 requires whitespace after a detached modifier. Spec 357-362
defines `$$`, `^^`, `::` alone at the end of a line as closers, and the ranged
form as `$$` *followed by whitespace*. Therefore:

- `$$` closes a definition;
- `$$ ` opens a ranged definition with an empty title;
- there is no way to write an empty ranged title without the trailing space.

The same applies to `^^` and `::`. This is a consequence of F23 (empty titles)
and the closer rule, but it is a distinct syntactic hole: the spec never shows
or discusses `$$ `. A parser that trims trailing whitespace before classifying
the line silently changes the meaning.

**Model decision.** `Norg.Blocks.classifyRangeable` checks whitespace before
the empty-remainder closer case, so `$$ ` is `.definition true ""` and `$$` is
`.close .definition`.

### F29. `=end` is two productions at once

Spec 770-776 defines the ranged-tag terminator: the same prefix as the opener,
immediately followed by a line ending. For macro tags the prefix is `=`, so
`=end` closes a macro. Spec 778-794 also defines macro tags as `=` plus a name,
and `end` is a valid name. Thus `=end` is simultaneously:

- the closing statement for the innermost `=...` macro tag, and
- a macro tag named `end`.

A line-level classifier cannot decide without a stack of open tags. The spec
does not say whether `=end` inside a macro body can be escaped or whether a
macro named `end` is shadowed by the closer. `Norg.Tags` treats `=end` as an
ordinary tag and leaves closing to the caller; `Norg.Blocks` does the same.
The ambiguity is therefore visible but unresolved.

### F30. Arity is not in the table

Spec 153-154 says the number of characters "depends on the modifier type", but
the table at 157-202 has no arity column. The arities are:

- structural headings: any run length = level (219-238);
- nestable lists/quotes: any run length = level (240-351);
- range-able `$ ^ :`: exactly one (non-ranged) or two (ranged), three or more
  invalid (357-419);
- delimiting `- =`: two or more (449-483);
- horizontal rule `_`: two or more (485-494).

The last two are stated in their own sections, not in the table. A reader who
only reads the table cannot implement it. The table should have an arity
column, or the "depends on the modifier type" sentence should point at the
sections.

### F31. Tag parameter whitespace is unspecified

Spec 744-754 says parameters are space-separated and that `\ ` escapes a
space, but does not say:

- whether the whitespace after the name is part of the parameter string;
- whether leading/trailing whitespace is trimmed;
- whether runs of spaces are one separator or several;
- whether a trailing `\` is an error.

`Norg.Tags.parseTag` preserves the raw remainder after the first whitespace
character, including extra spaces and backslashes. `Norg.Blocks.parseTag` drops
all whitespace immediately after the name. The two transcriptions therefore
disagree on `"@code   lua  "`: `Tags` gives `"  lua  "`, `Blocks` gives
`"lua  "`. This is a concrete example of the ambiguity, not a bug in either
parser.

### F32. File links have three spellings

The link-location list (1330-1341) mentions a file location, and the examples
use three different syntaxes:

- `{:file:}` / `{:file:20}` (file location with trailing colon);
- `{/ file}` (custom file linkable, mandatory space after `/`);
- `{file://...}` (URL-like file link).

Spec 1369-1384 says a file location may only be combined with a detached
modifier, a line number, and the magic `#`; `/`, `@`, and URLs are invalid.
Spec 1511-1526 then discusses the differences between these forms. The result
is a partial compatibility matrix that is stated in prose and examples but
never as a grammar. In particular:

- `{:file:https://github.com}` is invalid (URL after file location);
- `{:file:/ file.txt}` is invalid (custom file linkable after file location);
- `{:file:@ Wednesday 30th Jan}` is invalid (timestamp after file location);
- `{2}` is a line number, but `{2foo}` is not specified (URIs do not begin
  with digits, but a bare number is not a URI);
- Windows paths (`C:\...`) contain a colon and a backslash, both of which have
  other roles in the link grammar.

The three spellings should be either unified or given explicit, mutually
exclusive productions.

### F33. Link scoping collides with other colons

Spec 1528-1545 writes a scoped link as:

```
{* Heading Name : *** Level 3 heading}
```

The `:` separates the name from the scope, but `:` is also:

- the closing character of a file location (`{:file:}`);
- the table-cell sigil (`: A1`, `:: A2`);
- the link modifier (` : `, 1190-1229);
- the slide suffix (`:` at end of line, 638-696).

No escaping or precedence rule says which colon wins inside `{...}`. The
scoping example works only because the colon is surrounded by spaces and the
scope starts with `***`; a heading whose name contains ` : ` is ambiguous.

### F34. Inline link targets are second-class

Spec 1595-1613 says inline link targets `<...>` cannot have descriptions and
can only be linked via `#`. The grammar for `<...>` is not given, and the
reason for the restriction is not stated. This is a link-location production
that exists only in prose, so a parser cannot decide:

- whether `<...>` can contain `>` or `\>`;
- whether it can span a line ending;
- whether it can be combined with an anchor `[anchor]<...>`;
- why `[description]<...>` is forbidden while `[description]{...}` is not.

### F35. Descriptions share the linkable line-ending rule without saying so

The valid example `{* text}[content ]` (1617-1648) allows a trailing space
before `]`, and the invalid examples at 1670-1679 reject:

```
{* text}[
 text
]
{* text}[text
]
{* text}[
text]
```

These are exactly the linkable rules of 1311-1313 applied to `[]`: the
opening bracket may not be followed by a line ending, and the closing bracket
may not be preceded by one. But 1311-1313 names only the linkable `{}`
modifiers. The description grammar should state the same rule, or the examples
should be treated as normative.

**Consequence.** A rejected description is not an error in the model; it is
plain text. Its inner markup is therefore still scanned as ordinary paragraph
text, so `{* text}[\n *bold*\n]` produces a bold span even though the
description itself is invalid. The spec does not say whether an invalid
description should abort the paragraph, become text, or propagate an error.

### F36. Verbatim closers are not exempt from the boundary rules

Spec 1052-1055 states the opening/closing boundary rules for attached
modifiers generally. Verbatim attached modifiers are attached modifiers, so
their closer must also be followed by whitespace or punctuation and preceded
by a non-whitespace character. But the spec also says (1690, 1700) that
verbatim modifiers take precedence over non-verbatim ones and have a
"deterministic start and end". The two rules conflict for:

```
`a`b
```

The first backtick opens a code span, and the second is the natural closer,
but the character after it (`b`) is neither whitespace nor punctuation, so the
closer is invalid. The model then reports an unclosed opener instead of the
obvious span `a`. The same problem appears with `` `a` `` followed by `,`?
No: punctuation is allowed. The failure is specifically a regular character
immediately after the closer.

**Model decision.** `Norg.Inline.findCloser` requires `closeBefore` and
`closeAfter`, so `` `a`b `` yields no span. This follows 1052-1055; the
verbatim-precedence paragraph needs an explicit exception.

### F37. Escaping inside inline verbatim is contradictory

Spec 97-99 says:

- any character may be escaped with `\`;
- except characters within free-form and ranged verbatim segments.

Inline code (`` `...` ``), inline math (`$...$`), and variables (`&...&`) are
*attached* verbatim modifiers. They are neither free-form nor ranged, so the
exception does not apply and escaping should work inside them. But the
precedence list (1699-1700) puts escaping *above* verbatim attached
modifiers, which means the backslash is processed before the verbatim body is
recognized. Under that reading, `` `\`` `` contains an escaped backtick and
the final backtick closes the span. Under the "body is verbatim" reading, the
backslash is literal and the first backtick after it closes the span.

The spec's own free-form section (1174-1188) says representing the delimiter
inside the block is impossible and recommends free-form syntax instead. That
suggests inline verbatim bodies are literal (no escaping), contradicting
97-99's exception list. The model follows the literal-body reading and reports
the alternative as a finding.

### F38. Escaped characters and doubled runs

Spec 1075-1077 disqualifies "two or more consecutive attached modifiers of the
same type" in all circumstances. If the first character is escaped:

```
\**bold
```

the backslash makes the first `*` literal text (93-99), leaving a single
unprotected `*`. The model skips the escaped character before run detection,
so that remaining `*` can open a span. A parser that detects runs on the raw
character stream would instead see `**` and disqualify both. The spec does not
say whether escaped characters count toward "consecutive" for this rule.

### F39. Unclosed attached modifiers have no specified result

Spec 1311-1313 says an unclosed *linkable* "may be an error". The attached
modifier section (1045-1137) never says what happens to an opener that is
never closed: is it literal text, an error, or an implicit close at the end of
the paragraph? The model treats an unclosed opener as raw text: it emits a
trailing `.literal` event at the opener and records the character in
`unclosed`. It does not count it as a syntax error.

A closing delimiter with no opener is also raw text (`text*Bold*` has two
literals); only a wrong-order close with a nonempty stack becomes `.error`.
The spec only shows the wrong-order case (1132-1136), so the empty-stack and
unclosed cases remain choices.

### F40. Consecutive empty lines

Spec 142-145 defines a paragraph break as an empty line and says a paragraph
is terminated by one. If a document contains:

```
a


b
```

there are two empty lines and therefore two paragraph breaks by the literal
definition. The spec does not say whether they collapse into one break, or
whether the second break creates an empty paragraph between them. Most
implementations collapse, but the prose does not authorize that.

**Model decision.** `Norg.Document.assemble` keeps each blank line as a
separate `.blank` chunk and does not create empty paragraphs. This makes the
choice visible; a consumer that wants "one break per run of blank lines" can
collapse adjacent `.blank` chunks.

### F41. Description inline scope is unspecified

Spec 1547-1593 defines descriptions and says they may contain inline markup;
1647's nested example puts a link inside a location and markup in the
description. It never says whether a description shares the surrounding
attached-modifier stack or starts a fresh inline scope. Reading
`*[desc *bold*]*` with a shared stack can pair the outer and inner `*`
differently from a fresh scope. The boundary context at the description's
first and last characters is also unstated: the model uses `none` at both
edges, so a delimiter at the edge can open/close as if it were paragraph
start/end.

**Model decision.** Each valid `[...]` description is rescanned as an
independent inline scope, with indices offset back into the paragraph. An
unclosed opener inside a description is raw text inside that scope, not part
of the paragraph's `unclosed` list. `Norg/DescriptionTests.lean` covers the
nested example, four-level nesting, and location opacity.

### F42. Linkables outrank escaping, so an escaped bracket does not protect a link

Spec 1691-1702 orders linkables above escaping. `Norg.Linkables.spanAt` runs
before the inline scanner sees `\`, so `[a \] b]` closes at the escaped-looking
`]`, and `[a \[ b]` is unclosed. If escaping is meant to protect linkable
delimiters, the precedence list needs an exception or linkable matching must
honor backslashes. The interaction is unstated and also affects verbatim:
`` [`]`] `` closes at the `]` inside the code span.

**Model decision.** Follow the precedence list: linkable matching wins. The
description scanner still scans the content, but the delimiter boundary was
already chosen by `Linkables`.

### F43. Nested linkables inside a location are matched, not parsed

Spec 1647's example `{* Link to {# headings}[heading]}[*markup*]` has a
linkable inside the outer location. The spec says nested linkables are valid
but does not say whether the inner `{# headings}[heading]` is a semantic link
or merely part of the outer target text. The model matches nested
`{}`/`[]`/`<>` only to find the outer closer; it does not re-parse or resolve
the inner link, and it does not scan the inner `[heading]` description.

**Model decision.** Locations are opaque target text; only descriptions are
rescanned. `Norg/DescriptionTests.lean` proves the outer description is
scanned and the inner location is not.

### F44. A description after an inline target is undefined

Spec 1595-1613 says inline `<...>` targets cannot have descriptions and are
only linkable via `#`. It does not say what `{<...>}[desc]` means: an error, a
standalone anchor description, or text ignored by the target. The model treats
the following `[...]` as an independent description and scans its markup.

**Model decision.** Independent span; no error. This is the least surprising
local reading, but the spec should state it.

## Tree-sitter corpus differential (non-normative)

`import_tree_sitter_corpus.py` imports the 160 cases from
`nvim-neorg/tree-sitter-norg`'s `test/corpus` into
`Norg/TreeSitterCorpus.lean`. `Norg/CorpusCheck.lean` runs the current
line/inline model over every input and counts a case as clean when it produces
no `.invalid` block and no inline `.error`. Unclosed attached modifiers are
reported but are not errors: the spec calls doubled markup "raw text" and only
says an unclosed *linkable* may be an error (spec lines 1075-1077, 1328), so
the model follows the raw-text reading. This is a coverage check, not a
conformance claim: the model is only at the line/paragraph layer.

| Check | Expected-valid accepted | Expected-error rejected |
|-------|------------------------|-------------------------|
| Lean line/inline model | 156 / 156 | 3 / 4 |
| tree-sitter-norg (reference) | 152 / 156 | 4 / 4 |

The 19 earlier Lean rejections are now covered:

- **Links and free-form markup.** `Norg/Linkables.lean` recognises `{}`, `[]`,
  and `<>` spans (including nested linkables), validates the local link-target
  shape, and lets `Norg.Inline` treat a valid span as opaque. Free-form attached
  modifiers (`<mod>| ... |<mod>`) are implemented in `Norg/Inline.lean`,
  including verbatim bodies and nested standard markup.
- **Precedence tie-breaks.** A matching standard closing modifier now wins over
  a `|`-opened free-form reading; an unmatched closing delimiter is raw text,
  not a syntax error; verbatim spans hide their contents; attached extensions
  `(...)` are skipped.
- **Indentation and grouping.** `Norg/Document.lean` now emits `.raw` chunks for
  lines inside a ranged verbatim tag (`@name ... @end`), so code content is not
  inline-scanned. A separate `Norg/Structure.lean` models heading/list nesting
  and `::` indent segments.

The three rejected expected-error cases are `Basic Links`, `Links with text`,
and `Anchors`. In each, the three invalid file-location combinations
(`{:file:/ ...}`, `{:file:@ ...}`, `{:file:https://...}`) are reported as
invalid linkables. The one expected-error case the model accepts is
`tags.txt :: Ranged Tag with wrong order of carryovers`. The spec makes
carryover tags apply to the next element and does not require a same-line space
after `+color blue`; tree-sitter reports `(MISSING "_space")` at the newline.
The model intentionally keeps the spec reading rather than encoding that
implementation quirk.

As a reference point, the Rust harness
`/tmp/opencode/tree-sitter-norg/examples/corpus_check.rs` parses the same 160
inputs with the repository's own parser: 152/156 expected-valid parse clean, all
4 expected-error cases produce errors, and 4 expected-valid infirm-tag cases
produce `(MISSING "_line_break")` at end of input. That is a
tree-sitter/corpus mismatch (or a harness/trailing-newline artifact), not a
finding about the 1.0 prose, and it is not used as evidence above.

## Model limitations (intentional)

- `Char` is a Unicode scalar value. The model does not handle grapheme
  clusters, even though spec 53-54 says a character may be a grapheme.
- `isPunctuation` currently covers ASCII only. The Unicode categories
  `Pc Pd Pe Pf Pi Po Ps` need a generated UCD table. This affects
  `isRegular`, tag names, and boundary checks for non-ASCII text.
- No mathlib dependency. The model is core Lean 4.36; the parser is a plain
  recursive function, not a parser monad.
- Macros, attribute objects, `#eval`, and Janet-level semantics are out of
  scope. The model stops at the syntax/tree boundary.
- `Norg/Linkables.lean` recognises and locally validates linkable spans but
  does not resolve them. Valid description contents are now rescanned as their
  own inline scope (`Norg/DescriptionTests.lean`); link locations and inline
  targets remain opaque.
- `Norg/Structure.lean` is a coarse grouping model, not a tree-sitter clone:
  it does not aim for S-expression-compatible output or exact list-item
  continuation in every malformed-indentation case.
