/-
  Intersecting modifier ` : ` for the Norg 1.0 model.

  Spec map (citations refer to `../1.0-specification.norg`):

  * 1261-1296: definition.  The token is whitespace + `:` + whitespace, it
    intersects two *paragraph segments* "on the same line", and it "expands to
    a newline".  The table-cell example at 1284-1296 is the normative
    before/after pair.
  * 115-127: a paragraph segment is a line of text; 134-145: a paragraph is
    consecutive paragraph segments and a paragraph break is an empty line.
    Therefore the expansion inserts a *line ending inside the paragraph*, not
    a paragraph break: the result is several paragraph segments, one per line,
    with no blank line between them.
  * 66-71: leading whitespace of a line is indentation and is discarded before
    the segment starts.  `find` scans its argument as given; callers should
    pass `stripIndent line` when the line's indentation is not content.
  * 56-64: whitespace is Unicode `Zs`; tabs are not `Zs` (see Basic.lean
    13-33).  `find` uses operational whitespace (Zs + tab) so the spec's own
    examples work; `findSpec` exposes the literal `Zs` reading.
  * 1691-1702: the precedence list does not mention intersecting modifiers
    (FINDINGS F6).  1759-1768: they are layer 4.

  FINDINGS F14 says the rule has no scope restriction and, read literally, is
  a global textual rewrite.  This module keeps both readings executable:

  * `findRaw` is the literal reading: every `ws : ws` is a hit, wherever it
    occurs.
  * `find` is the scoped reading recommended by F14: hits are recognized only
    at paragraph-segment top level.  Verbatim attached modifiers
    (`` ` ``, `$`, `&`, including their free-form `|...|` forms), escaped
    characters, and valid-or-attempted linkable spans `{}`, `[]`, `<>` are
    opaque.  Standard attached modifiers (`*bold : text*`) and standard
    free-form modifiers are *not* opaque, because F14 only excludes verbatim
    and link descriptions; the structural consequence is that such a hit
    splits the attached modifier across paragraph segments.

  `expand` replaces each hit's whole span (leading whitespace run + `:` +
  trailing whitespace run) with one `\n`.  When the span sits at a segment
  edge the empty segment is preserved (`segments` returns `""`).
-/
import Norg.Basic
import Norg.Linkables

namespace Norg.Intersecting

open Norg

/-- One intersecting modifier.  Indices are character (code point) positions in
the scanned string, matching the `List Char` model in `Norg.Basic`.

`start` is the first whitespace character of the run before the colon, `colon`
the colon itself, and `stop` is one past the last whitespace character of the
run after it.  `s[start:stop]` is the text `expand` replaces with a newline. -/
structure Hit where
  start : Nat
  colon : Nat
  stop : Nat
  deriving Repr, DecidableEq, BEq

/-! ## Opaque spans for the scoped reading (spec 1691-1702, F14) -/

/-- Length of the verbatim span starting at its opening delimiter `c`, or
`none` when no valid closer exists.  `pre` is the character before the opener
and `k` counts the characters of the body already consumed.  The same
close-boundary model as `Norg.Inline` is used (`boundaryExamples`), including
the "doubled delimiters are literal" rule of spec 1075-1077. -/
private def findVerbatimClose (m : BoundaryModel) (c : Char) :
    Option Char → Nat → List Char → Option Nat
  | _, _, [] => none
  | pre, k, d :: ds =>
      if d == c && pre != some c && ds.head? != some c &&
          m.closeBefore pre && m.closeAfter ds.head? then
        some (k + 2)
      else
        findVerbatimClose m c (some d) (k + 1) ds

/-- Number of body characters consumed by a free-form closer `|<c>` (spec
1162-1188), `none` if the span is unclosed. -/
private def findFreeFormClose (m : BoundaryModel) (c : Char) :
    Nat → List Char → Option Nat
  | _, [] => none
  | k, '|' :: d :: ds =>
      if d == c && ds.head? != some c && m.closeAfter ds.head? then
        some (k + 2)
      else
        findFreeFormClose m c (k + 1) (d :: ds)
  | k, _ :: ds => findFreeFormClose m c (k + 1) ds

/-- If an opaque construct starts at the head of the list, the number of
characters to skip; otherwise `1`.  Backslash escapes one character (spec
93-99), verbatim modifiers skip their whole body, and linkables are delegated
to `Norg.Linkables`.  Attached modifier extensions `(...)` are deliberately
*not* masked: the spec does not say whether ` : ` inside attribute metadata is
structural, and this model leaves the colon visible there. -/
private def opaqueLen (m : BoundaryModel) (pre : Option Char) : List Char → Nat
  | [] => 1
  | c :: rest =>
      if c == '\\' then
        match rest with
        | [] => 1
        | _ :: _ => 2
      else if c == '`' || c == '$' || c == '&' then
        if !m.openBefore pre then 1
        else
          match rest with
          | '|' :: body =>
              match findFreeFormClose m c 0 body with
              | some k => 2 + k
              | none => 1
          | d :: ds =>
              if d == c || !m.openAfter (some d) then 1
              else
                match findVerbatimClose m c (some c) 0 (d :: ds) with
                | some k => k
                | none => 1
          | [] => 1
      else if c == '{' || c == '[' || c == '<' then
        match Linkables.spanAt (c :: rest) with
        | some sp => sp.stop
        | none => 1
      else 1

/-! ## Scanner -/

/-- Walk one paragraph segment.  `i` is the index of `cs.head`, `pre` the
preceding character, and `wsStart` the start of the whitespace run ending at
`pre` (`none` when `pre` is not whitespace).  After a hit the trailing
whitespace run is dropped and `wsStart` is reset, so a colon immediately after
an expansion point is not matched using whitespace that was already consumed:
`a : : b` has one hit, not two overlapping ones. -/
private def scanAll (mask : Bool) (ws : Char → Bool) (m : BoundaryModel)
    (s : String) : List Hit :=
  let rec go :
      Nat → Nat → Option Char → Option Nat → List Char → List Hit → List Hit
    | 0, _, _, _, _, acc => acc.reverse
    | _, _, _, _, [], acc => acc.reverse
    | fuel + 1, i, pre, wsStart, c :: rest, acc =>
        let skip := if mask then opaqueLen m pre (c :: rest) else 1
        if 1 < skip then
          let last := (c :: rest).drop (skip - 1) |>.head?
          go fuel (i + skip) last none ((c :: rest).drop skip) acc
        else if c == ':' && wsStart.isSome &&
            (match pre with | some p => ws p | none => false) &&
            (match rest.head? with | some d => ws d | none => false) then
          let start := wsStart.getD i
          let k := (rest.takeWhile ws).length
          let stop := i + 1 + k
          go fuel stop none none (rest.drop k) ({ start, colon := i, stop } :: acc)
        else
          go fuel (i + 1) (some c)
            (if ws c then
               match wsStart with
               | some s => some s
               | none => some i
             else none)
            rest acc
  go (s.toList.length + 1) 0 none none s.toList []

/-- Scoped reading of F14: `ws : ws` at paragraph-segment top level, outside
verbatim and linkables.  Operational whitespace (Zs + tab). -/
def find (s : String) : List Hit :=
  scanAll true isOperationalWhitespace boundaryExamples s

/-- Literal `Zs` reading of spec 56-60 (tabs are not whitespace).  Only the
colon-adjacency predicate changes; verbatim and linkable boundaries still use
`boundaryExamples`. -/
def findSpec (s : String) : List Hit :=
  scanAll true isSpecWhitespace boundaryExamples s

/-- Literal F14 reading: the global textual rewrite, with no scope and no
opaque spans.  Operational whitespace. -/
def findRaw (s : String) : List Hit :=
  scanAll false isOperationalWhitespace boundaryExamples s

/-! ## Expansion (spec 1290-1296) -/

/-- Replace each hit span with `\n`.  Hits are expected in source order; a hit
that starts before `i` (only possible for caller-supplied lists) is skipped. -/
private def expandHits (fuel : Nat) (i : Nat) (cs : List Char) (hs : List Hit) :
    List Char :=
  match fuel with
  | 0 => cs
  | fuel + 1 =>
      match cs, hs with
      | [], _ => []
      | c :: rest, [] => c :: rest
      | c :: rest, h :: hs' =>
          if i < h.start then
            c :: expandHits fuel (i + 1) rest (h :: hs')
          else if i == h.start then
            '\n' :: expandHits fuel h.stop (cs.drop (h.stop - i)) hs'
          else
            expandHits fuel i cs hs'

/-- Insert the newline; every character outside the hit spans is preserved. -/
def expandWith (hs : List Hit) (s : String) : String :=
  String.ofList (expandHits (s.toList.length + 1) 0 s.toList hs)

/-- Expansion of the scoped reading: a line ending *inside* the paragraph
(spec 1290-1296, 121-145), not a paragraph break. -/
def expand (s : String) : String :=
  expandWith (find s) s

/-- Expansion of the literal F14 reading, for comparison. -/
def expandRaw (s : String) : String :=
  expandWith (findRaw s) s

/-- Split on the inserted `\n`, preserving empty segments at the edges. -/
def splitNewlines (s : String) : List String :=
  let rec go (cur : List Char) : List Char → List String
    | [] => [String.ofList cur.reverse]
    | '\n' :: rest => String.ofList cur.reverse :: go [] rest
    | c :: rest => go (c :: cur) rest
  go [] s.toList

/-- The paragraph segments produced by the expansion.  `[""]` for an empty
input; `["", ""]` when the whole segment was one intersecting modifier. -/
def segments (s : String) : List String :=
  splitNewlines (expand s)

/-- Whether the scoped reading finds at least one intersecting modifier. -/
def hasHit (s : String) : Bool := !(find s).isEmpty

/-- Everything a caller needs: where the hits are, the expanded segment, and
the resulting paragraph segments. -/
structure Report where
  hits : List Hit
  expanded : String
  segments : List String
  deriving Repr, DecidableEq, BEq

/-- Classify one paragraph segment. -/
def classify (s : String) : Report :=
  let hits := find s
  let expanded := expandWith hits s
  { hits, expanded, segments := splitNewlines expanded }

/-! ## Checks -/

-- Basic positive case (spec 1265-1271).
#guard find "foo : bar" == ([{ start := 3, colon := 4, stop := 6 }] : List Hit)
#guard expand "foo : bar" == "foo\nbar"
#guard segments "foo : bar" == ["foo", "bar"]
#guard hasHit "foo : bar"

-- The colon must be directly surrounded by whitespace on both sides.
#guard find "foo: bar" == ([] : List Hit)
#guard find "foo :bar" == ([] : List Hit)
#guard find "foo:bar" == ([] : List Hit)
#guard find "foo :" == ([] : List Hit)
#guard find ": foo" == ([] : List Hit)
#guard !hasHit "foo: bar"

-- Whole whitespace runs are part of the token (multiple spaces).
#guard find "foo  :  bar" == ([{ start := 3, colon := 5, stop := 8 }] : List Hit)
#guard expand "foo  :  bar" == "foo\nbar"

-- Paragraph edges.  As given, a leading space is whitespace and the hit is at
-- index 0.  After `stripIndent` (spec 66-71) it is indentation, so the colon
-- is at the start of the segment and no longer has a left boundary.
#guard find " : " == ([{ start := 0, colon := 1, stop := 3 }] : List Hit)
#guard expand " : " == "\n"
#guard segments " : " == ["", ""]
#guard find (stripIndent " : ") == ([] : List Hit)
#guard find " : bar" == ([{ start := 0, colon := 1, stop := 3 }] : List Hit)
#guard expand "foo : " == "foo\n"
#guard segments "foo : " == ["foo", ""]

-- Multiple hits expand left to right.
#guard (find "foo : bar : baz").length == 2
#guard expand "foo : bar : baz" == "foo\nbar\nbaz"
#guard segments "foo : bar : baz" == ["foo", "bar", "baz"]

-- Overlap policy: the shared space belongs to the first hit, so `a : : b` has
-- one hit and the remaining `:` is not a second hit after expansion.
#guard (find "foo : : bar").length == 1
#guard expand "foo : : bar" == "foo\n: bar"

-- Tab: operational whitespace accepts it, the literal Zs reading rejects it
-- (spec 56-64, Basic.lean 20-29).
#guard isOperationalWhitespace '\t'
#guard !isSpecWhitespace '\t'
#guard find "foo\t:\tbar" == ([{ start := 3, colon := 4, stop := 6 }] : List Hit)
#guard findSpec "foo\t:\tbar" == ([] : List Hit)
#guard expand "foo\t:\tbar" == "foo\nbar"

-- A non-ASCII Zs space works under both readings.
#guard find "foo\u00A0:\u00A0bar" == ([{ start := 3, colon := 4, stop := 6 }] : List Hit)
#guard findSpec "foo\u00A0:\u00A0bar" == ([{ start := 3, colon := 4, stop := 6 }] : List Hit)

-- Escaping (spec 93-99).  `\:` has no whitespace on its left, so neither
-- reading matches.  `\ :` is opaque in the scoped reading because the escaped
-- space is verbatim; the raw reading still sees a whitespace code point.
#guard find "foo \\: bar" == ([] : List Hit)
#guard findRaw "foo \\: bar" == ([] : List Hit)
#guard find "foo \\ : bar" == ([] : List Hit)
#guard findRaw "foo \\ : bar" == ([{ start := 5, colon := 6, stop := 8 }] : List Hit)

-- Verbatim attached modifiers are opaque to `find` but not to `findRaw`.
#guard find "`a : b`" == ([] : List Hit)
#guard findRaw "`a : b`" == ([{ start := 2, colon := 3, stop := 5 }] : List Hit)
#guard expand "`a : b`" == "`a : b`"
#guard expandRaw "`a : b`" == "`a\nb`"

-- Free-form verbatim (spec 1162-1188) is opaque too.
#guard find "`|a : b|`" == ([] : List Hit)
#guard (findRaw "`|a : b|`").length == 1

-- Linkable spans are opaque (F14: outside link descriptions).
#guard find "{* a : b}[c]" == ([] : List Hit)
#guard (findRaw "{* a : b}[c]").length == 1

-- Attached modifiers are *not* opaque: the spec does not restrict the colon,
-- so `*bold : text*` produces a hit and the bold opener/closer end up in
-- different paragraph segments (each one unclosed).  FINDINGS F14.
#guard find "*bold : text*" == ([{ start := 5, colon := 6, stop := 8 }] : List Hit)
#guard expand "*bold : text*" == "*bold\ntext*"
#guard segments "*bold : text*" == ["*bold", "text*"]

-- The spec's own table example, before and after expansion (1284-1296).
#guard expand ": A1 : Content of the cell at A1" ==
  ": A1\nContent of the cell at A1"
#guard segments ": A1 : Content of the cell at A1" ==
  [": A1", "Content of the cell at A1"]

-- The term example (1275-1283).  `$` with no valid closer is not verbatim, so
-- the term line is scanned normally; the expansion inserts no indentation.
#guard expand "$ Term : This is a definition of that term." ==
  "$ Term\nThis is a definition of that term."

-- `classify` bundles the three answers.
#guard (classify "foo : bar").hits.length == 1
#guard (classify "foo : bar").expanded == "foo\nbar"
#guard (classify "foo : bar").segments == ["foo", "bar"]
#guard (classify "foo: bar").hits == ([] : List Hit)
#guard segments "" == [""]

end Norg.Intersecting
