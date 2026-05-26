# Norg 1.0 Lean model

An executable transcription of the Norg 1.0 syntax specification, used to find
contradictions and underspecified corners. This is not an implementation of
Norg, and it does not try to be fast or complete; it tries to make every
interpretation decision visible.

## Build

```sh
cd proofs
lake build
```

Lean 4.36, no mathlib. Tests are compile-time `#guard`s in each module, so a
successful build is the test run.

## Layout

| File | Contents |
|------|----------|
| `Norg/Basic.lean` | Character classes (`Zs`, tab, line endings, ASCII punctuation, regular chars), line splitting, two attached-modifier boundary models. |
| `Norg/Blocks.lean` | Line-start classifier: headings, lists, quotes, definitions, footnotes, table cells, delimiters, tags, attributes. |
| `Norg/Inline.lean` | Attached-modifier scanner: opening/closing, nesting stack, doubles, verbatim spans, free-form `<mod>| ... |<mod>` spans, link-modifier events, attached extensions, escapes, opaque link locations, and rescanned `[...]` descriptions. |
| `Norg/Intersecting.lean` | Scoped, literal-whitespace, and raw readings of the ` : ` intersecting modifier; expansion and segment splitting. |
| `Norg/DescriptionTests.lean` | 43 guards for inline markup inside valid `[...]` descriptions; imported by `Norg.lean` so `lake build` runs them. |
| `Norg/Linkables.lean` | Lexical `{}`, `[]`, `<>` span recognition, nested matching, and local link-target validation (file location, line number, URL, detached/magic targets). |
| `Norg/Document.lean` | Paragraph assembly: groups consecutive paragraph lines, keeps blank lines and non-paragraph blocks as chunks, emits `.raw` for ranged verbatim-tag bodies; runs the inline scanner on a paragraph. |
| `Norg/Structure.lean` | Coarse tree builder: heading/list nesting, weak/strong delimiters, `::` indent segments and `:` slides. |
| `Norg/Tags.lean` | Tag sigils, names, hierarchy dots, parameters. |
| `Norg/TreeSitterCorpus.lean` | Generated data: the 160 cases from `nvim-neorg/tree-sitter-norg`'s `test/corpus`. |
| `Norg/CorpusCheck.lean` | Differential coverage harness over the tree-sitter corpus; run manually, not imported by `Norg.lean`. |
| `Norg/Corpus.lean` | Generated Lean data: all 83 `|example` blocks from the spec, with source line numbers. |
| `FINDINGS.md` | The report: contradictions, gaps, implementation leaks, model decisions. |
| `FINDINGS-SYNTAX.txt` | Minimal offending or ambiguous Norg snippet for every finding. |
| `extract_examples.py` | Pulls every `|example` block out of the spec into `examples.json` and `Norg/Corpus.lean`. |
| `import_tree_sitter_corpus.py` | Pulls the tree-sitter-norg corpus into `tree_sitter_corpus.json` and `Norg/TreeSitterCorpus.lean`. |

## Current status

Iteration 5 is in progress. The report has 44 findings (F1-F44). The Lean
model now covers linkable spans, free-form attached modifiers, the link
modifier, attached extensions, verbatim ranged-tag bodies, inline markup
inside `[...]` descriptions, and the ` : ` intersecting modifier, plus a
coarse structural tree for heading/list nesting and `::` indent segments. The
160-case tree-sitter-norg corpus is at 156/156 expected-valid accepted and
3/4 expected-error rejected; the one accepted error case is a
carryover-order corpus artifact documented in `FINDINGS.md`, not a spec
contradiction.

## Tree-sitter corpus differential

```sh
cd proofs
python3 import_tree_sitter_corpus.py
lake build Norg.TreeSitterCorpus
lake env lean Norg/CorpusCheck.lean
```

The last command prints the counts and the names of rejected cases. The
importer defaults to `/tmp/opencode/tree-sitter-norg/test/corpus`; pass a path
if the repository is cloned elsewhere. The upstream repository describes this
grammar as a full Norg V1 implementation, and its corpus is an edge-case suite,
so it is useful differential evidence but still not normative. This is a
coverage check, not a full tree comparison: the model stops at the
line/paragraph/inline layer and does not compare S-expressions. The reference
parser can be run separately from the cloned tree-sitter repository; that
harness lives outside this repo.

## Non-normative artifacts

`../norg.peg` is a lexical sketch, not the specification. It was rewritten in
iteration 3 to stop contradicting the prose on `word`, punctuation, line
endings, and heading titles, but it still covers only paragraphs and headings.
Do not use it as evidence for a finding.

## What is modelled

- Layers 1-4 of the inline syntax: characters, words/segments, detached
  modifiers, tags, attached modifiers, free-form attached modifiers, link
  modifiers, attached extensions, linkable spans, delimiters.
- Paragraph assembly (consecutive paragraph lines, blank-line chunks),
  multi-line inline scanning, and ranged verbatim-tag bodies as `.raw` chunks.
- Lexical link-target validation: detached/magic targets, file locations,
  line numbers, URLs, descriptions, anchors, and inline `<...>` targets.
- A coarse structural tree: heading/list nesting, weak/strong delimiters,
  `::` indent segments, and `:` slides.
- Both the literal reading and the "examples must pass" reading of the
  attached-modifier boundary rule. `boundaryLiteral` and `boundaryExamples`
  live in `Norg/Basic.lean`; the inline scanner is parameterized over them.
- Line endings as values (`LF`, `CR`, `CRLF`, `FF`), not as magic characters.

## What is not modelled

- Grapheme clusters (`Char` is a scalar value).
- Non-ASCII Unicode punctuation categories (needs a UCD table).
- Link resolution, document-global scoping, and anchor lookup. Linkables are
  recognised and locally validated, but not resolved.
- Tables and motions, macro expansion, attribute objects, `#eval`, and Janet
  semantics.
- Shared-stack reading of markup inside `[...]` descriptions; the model scans
  each description as a fresh inline scope (F41).
- Applying `Norg.Intersecting` during `Document.assemble`; it is a standalone
  checker/expander, so the structural tree still sees the unexpanded line.
- Full tree-sitter-compatible S-expression output; `Norg/Structure.lean` is a
  coarse model of the grouping prose, not a reference parser clone.

These are listed in `FINDINGS.md` with the spec lines that make them hard.

## Adding a finding

1. Add a `#guard` (or a small `example`) to the relevant module that
   demonstrates the disagreement.
2. Add a row to the table in `FINDINGS.md` and a short detail section with the
   spec line numbers and the decision the model makes.
3. If the prose supports two total readings, add a second model (like
   `boundaryLiteral` / `boundaryExamples`) rather than editing the first one.
