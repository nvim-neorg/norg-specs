/-
  Checks for inline markup inside link descriptions `[...]`.

  Spec lines 1547-1613 define descriptions; 1647 gives the nested example.
  A link location `{...}` stays opaque, but a valid description is rescanned as
  its own inline scope, so attached modifiers, free-form/verbatim modifiers,
  link modifiers, and nested linkables inside it are recognised.  This module
  is a test fixture; `Norg.lean` imports it so `lake build` runs the guards.
-/
import Norg.Inline
import Norg.Linkables

open Norg
open Norg.Inline

/-! ## Description content is scanned -/

-- `{* text}[*bold*]`: the outer `[`/`]` contribute one literal event for the
-- span; the `*` pair inside the description is an open/close pair.
#guard (Inline.scan boundaryExamples "{* text}[*bold*]").events.map
    (fun e => (e.index, e.role)) ==
  [(0, .literal), (8, .literal), (9, .open), (14, .close)]

-- The spec's nested example: the inner `{# headings}[heading]` sits inside the
-- outer *location* and stays opaque; only the outer description is scanned.
#guard (Inline.scan boundaryExamples
    "{* Link to {# headings}[heading]}[*markup*]").events.map
    (fun e => (e.index, e.role)) ==
  [(0, .literal), (33, .literal), (34, .open), (41, .close)]

-- Anchor plus description: both descriptions are scanned.
#guard openCount (Inline.scan boundaryExamples
    "[anchor][description with *bold* and /italic/]") == 2
#guard closeCount (Inline.scan boundaryExamples
    "[anchor][description with *bold* and /italic/]") == 2
#guard errorCount (Inline.scan boundaryExamples
    "[anchor][description with *bold* and /italic/]") == 0

-- An anchor declaration without markup adds no attached events.
#guard (Inline.scan boundaryExamples "[anchor]").events.map (fun e => e.role) ==
  [.literal]

-- A plain description adds no attached events.
#guard (Inline.scan boundaryExamples "{* text}[plain]").events.map
    (fun e => e.role) == [.literal, .literal]

-- A trailing space is allowed before the closer (spec line 1617).
#guard openCount (Inline.scan boundaryExamples "{* text}[content ]") == 0
#guard closeCount (Inline.scan boundaryExamples "{* text}[content ]") == 0

-- A description may span a line ending (spec lines 1640-1642), and markup on
-- the later line is still scanned with an absolute index.
#guard (Linkables.scan "{* a\nlink to a heading}[with\na description]").spans.length == 2
#guard errorCount (Inline.scan boundaryExamples
    "{* a\nlink to a heading}[with\n*bold*]") == 0
#guard openCount (Inline.scan boundaryExamples
    "{* a\nlink to a heading}[with\n*bold*]") == 1
#guard closeCount (Inline.scan boundaryExamples
    "{* a\nlink to a heading}[with\n*bold*]") == 1

/-! ## Nesting and recursive descriptions -/

-- A description may contain a linkable; only the description's own markup is
-- scanned.
#guard openCount (Inline.scan boundaryExamples
    "[see {* x}[y] and *bold*]") == 1
#guard closeCount (Inline.scan boundaryExamples
    "[see {* x}[y] and *bold*]") == 1
#guard errorCount (Inline.scan boundaryExamples
    "[see {* x}[y] and *bold*]") == 0

-- Nested descriptions work to arbitrary depth (three levels here).
#guard openCount (Inline.scan boundaryExamples "[a [b [c *x*]]]") == 1
#guard closeCount (Inline.scan boundaryExamples "[a [b [c *x*]]]") == 1
#guard errorCount (Inline.scan boundaryExamples "[a [b [c *x*]]]") == 0

/-! ## Locations stay opaque -/

-- A valid location containing `*` produces no attached events.
#guard (Inline.scan boundaryExamples "{* a * b}").events.map (fun e => e.role) ==
  [.literal]
#guard openCount (Inline.scan boundaryExamples "{# x * y * z}") == 0
#guard closeCount (Inline.scan boundaryExamples "{# x * y * z}") == 0

-- Link modifiers and `:` inside a location are not inline markup either.
#guard !(Inline.scan boundaryExamples "{https://example.com}").events.any
  fun e => e.role == .linkOpen

-- `{:#x}` is an invalid link location, not an attached modifier.
#guard openCount (Inline.scan boundaryExamples "{:#x}") == 0
#guard closeCount (Inline.scan boundaryExamples "{:#x}") == 0
#guard errorCount (Inline.scan boundaryExamples "{:#x}") == 1

/-! ## Other inline constructs inside descriptions -/

-- Link modifiers `:` inside a description.
#guard (Inline.scan boundaryExamples "[abso:/freaking/:lutely!]").events.any
  fun e => e.role == .linkOpen
#guard (Inline.scan boundaryExamples "[abso:/freaking/:lutely!]").events.any
  fun e => e.role == .linkClose

-- Free-form markup inside a description, with nested standard markup.
#guard openCount (Inline.scan boundaryExamples "[^|Super and *bold*|^]") == 2
#guard closeCount (Inline.scan boundaryExamples "[^|Super and *bold*|^]") == 2
#guard errorCount (Inline.scan boundaryExamples "[^|Super and *bold*|^]") == 0

-- Verbatim markup inside a description: the `*` in the body is not scanned.
#guard openCount (Inline.scan boundaryExamples "[`a*b*`]") == 1
#guard closeCount (Inline.scan boundaryExamples "[`a*b*`]") == 1
#guard !(Inline.scan boundaryExamples "[`a*b*`]").events.any fun e => e.char == '*'

-- Escapes inside a description (spec lines 93-99).
#guard openCount (Inline.scan boundaryExamples "[not \\*bold\\*]") == 0
#guard errorCount (Inline.scan boundaryExamples "[not \\*bold\\*]") == 0

/-! ## No double counting -/

-- `[...]` is scanned exactly once: the brackets themselves are literal span
-- markers and the content is not also rescanned as outer paragraph text.
#guard (Inline.scan boundaryExamples "[*bold*]").events.map
    (fun e => (e.index, e.role)) ==
  [(0, .literal), (1, .open), (6, .close)]

/-! ## Invalid descriptions keep the old behavior -/

-- Descriptions with edge line endings are plain text, not links (spec lines
-- 1650-1679; F35), so their `*` is not an attached modifier either.
#guard errorCount (Inline.scan boundaryExamples "{* text}[\n text\n]") == 0
#guard openCount (Inline.scan boundaryExamples "{* text}[\n text\n]") == 0
#guard closeCount (Inline.scan boundaryExamples "{* text}[\n text\n]") == 0
#guard (Linkables.scan "{* text}[\n text\n]").spans.length == 1

#guard (Linkables.spanAt "[text\n]".toList).isNone
#guard (Linkables.spanAt "[\ntext]".toList).isNone
