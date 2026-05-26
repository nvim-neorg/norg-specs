/-
  Line-level block recognition for the Norg 1.0 model.

  Every rule cites `../1.0-specification.norg`:
  - 147-202: detached modifier table and the three prefix rules
  - 204-351: structural / nestable modifiers and their invalid examples
  - 353-419: range-able modifiers (`$`, `^`, `:`) and their closers
  - 449-494: delimiting modifiers (`-`, `=`) and the horizontal rule (`_`)
  - 496-515: detached modifier extensions, which this module does not model
  - 727-776: tags, tag names, parameters and the `end` statement

  The spec defines syntax per line, so `classifyDocument` is only a line split
  followed by `classifyBlock`.  Nesting, grouping and extension parameters are
  deliberately left to later layers.
-/
import Norg.Basic

namespace Norg.Blocks

open Norg

/-- The detached modifiers that can be closed by a range-able closer
(spec lines 183-197, 353-419). -/
inductive DetachedKind
  | heading | unorderedList | orderedList | quote | definition | footnote | tableCell | attribute
  deriving Repr, DecidableEq, BEq

/-- A classified physical line.  `invalid` carries the spec rule it breaks. -/
inductive Block
  | blank
  | heading (level : Nat) (title : String)
  | listItem (ordered : Bool) (level : Nat) (content : String)
  | quote (level : Nat) (content : String)
  | attribute (level : Nat) (content : String)
  | definition (ranged : Bool) (title : String)
  | footnote (ranged : Bool) (title : String)
  | tableCell (ranged : Bool) (title : String)
  | close (kind : DetachedKind)
  | delimWeak (count : Nat)
  | delimStrong (count : Nat)
  | horizontalRule (count : Nat)
  | tag (sigil : Char) (name : String) (params : String)
  | paragraph (text : String)
  | invalid (reason : String)
  deriving Repr, DecidableEq, BEq

/-! ## Small helpers -/

/-- True when the list starts with an operational whitespace character. -/
private def startsWithWhitespace (cs : List Char) : Bool :=
  match cs with
  | [] => false
  | c :: _ => isOperationalWhitespace c

/-- Drop leading operational whitespace (spec lines 60-71: whitespace has no
semantic meaning and leading whitespace is discarded). -/
private def dropWhitespace (cs : List Char) : List Char :=
  cs.dropWhile isOperationalWhitespace

/-- The text following a marker's mandatory whitespace. -/
private def restText (cs : List Char) : String :=
  String.ofList (dropWhitespace cs)

/-! ## Range-able modifiers (spec lines 353-419)

  One character opens the non-ranged form, two characters open the ranged form,
  and the same two characters alone on the line close it (lines 357-362).
  Runs of three or more are therefore not valid markers.  The distinction
  between "opens" and "closes" is decided by what follows the run: a closer is
  immediately followed by a line ending (line 362), which `classifyBlock`
  observes as an empty remainder because it is handed one line at a time. -/

private def classifyRangeable (c : Char) (mk : Bool → String → Block)
    (closed : DetachedKind) (raw : String) (cs : List Char) : Block :=
  let (n, rest) := countRun c cs
  if startsWithWhitespace rest then
    if n == 1 then
      mk false (restText rest)
    else if n == 2 then
      mk true (restText rest)
    else
      .invalid s!"a run of {n} `{c}` is not a valid range-able detached modifier"
  else if rest.isEmpty then
    if n == 2 then
      .close closed
    else if n == 1 then
      .paragraph raw
    else
      .invalid s!"a run of {n} `{c}` is not a valid range-able detached modifier"
  else
    .paragraph raw

/-! ## Tags (spec lines 727-776) -/

/-- The six tag sigils (spec line 738). -/
private def isTagSigil (c : Char) : Bool :=
  c == '=' || c == '|' || c == '@' || c == '#' || c == '+' || c == '.'

/-- Tag names consist of regular characters (lines 103-105) plus `-`, `_`
(line 741) and `.` for hierarchy (line 742). -/
private def isTagNameChar (c : Char) : Bool :=
  isRegular c || c == '-' || c == '_' || c == '.'

/-- Parse a tag beginning at the start of `s`.  `none` means the line is not a
tag declaration; a name followed by a non-whitespace non-name character is
`invalid` rather than silently truncated (e.g. `#tag!`).  Parameters are the
raw remainder of the line after the mandatory whitespace (lines 744-754). -/
private def parseTag (s : String) : Option Block :=
  match s.toList with
  | sigil :: rest =>
    if !isTagSigil sigil then
      none
    else
      match rest with
      | [] => none
      | c :: _ =>
        if !isTagNameChar c then
          none
        else
          let name := String.ofList (rest.takeWhile isTagNameChar)
          match rest.dropWhile isTagNameChar with
          | [] => some (.tag sigil name "")
          | d :: ds =>
            if isOperationalWhitespace d then
              some (.tag sigil name (String.ofList (dropWhitespace (d :: ds))))
            else
              some (.invalid s!"character `{d}` is not allowed after tag name `{name}`")
  | [] => none

/-! ## Classification -/

/-- Classify one physical line (without its line ending).

  Leading operational whitespace is discarded before looking for a marker
  (spec lines 66-71).  `.paragraph` keeps the original `raw`, since paragraph
  text still carries its indentation. -/
def classifyBlock (raw : String) : Block :=
  if isBlank raw then
    .blank
  else
    let cs := (stripIndent raw).toList
    match cs with
    | [] => .blank
    | c :: _ =>
      match c with
      | '*' =>
        let (n, rest) := countRun '*' cs
        if startsWithWhitespace rest then
          .heading n (restText rest)
        else
          .paragraph raw
      | '-' =>
        let (n, rest) := countRun '-' cs
        if n >= 2 && rest.isEmpty then
          .delimWeak n
        else if startsWithWhitespace rest then
          .listItem false n (restText rest)
        else
          .paragraph raw
      | '~' =>
        let (n, rest) := countRun '~' cs
        if startsWithWhitespace rest then
          .listItem true n (restText rest)
        else
          .paragraph raw
      | '>' =>
        let (n, rest) := countRun '>' cs
        if startsWithWhitespace rest then
          .quote n (restText rest)
        else
          .paragraph raw
      | '%' =>
        let (n, rest) := countRun '%' cs
        if startsWithWhitespace rest then
          .attribute n (restText rest)
        else
          .paragraph raw
      | '_' =>
        let (n, rest) := countRun '_' cs
        if n >= 2 && rest.isEmpty then
          .horizontalRule n
        else
          .paragraph raw
      | '=' =>
        let (n, rest) := countRun '=' cs
        if n >= 2 && rest.isEmpty then
          .delimStrong n
        else
          match parseTag (String.ofList cs) with
          | some b => b
          | none => .paragraph raw
      | '$' => classifyRangeable '$' (fun r t => .definition r t) .definition raw cs
      | '^' => classifyRangeable '^' (fun r t => .footnote r t) .footnote raw cs
      | ':' => classifyRangeable ':' (fun r t => .tableCell r t) .tableCell raw cs
      | _ =>
        match parseTag (String.ofList cs) with
        | some b => b
        | none => .paragraph raw

/-- Split a document into physical lines and classify each one (spec lines
73-86).  Line endings are not part of any block. -/
def classifyDocument (s : String) : List Block :=
  (splitLines s).map (fun l => classifyBlock l.text)

/-! ## Compile-time checks -/

private def check (raw : String) (expected : Block) : Bool :=
  classifyBlock raw == expected

private def isInvalidBlock : Block → Bool
  | .invalid _ => true
  | _ => false

-- Blank and indentation (spec lines 66-71, 142-145)
#guard check "" .blank
#guard check "   " .blank
#guard check "\t" .blank
#guard check "  * Indented" (.heading 1 "Indented")

-- Structural headings (spec lines 219-238); no level-6 clamp in the spec.
#guard check "* Heading level 1" (.heading 1 "Heading level 1")
#guard check "** Heading level 2" (.heading 2 "Heading level 2")
#guard check "******* Heading level 7" (.heading 7 "Heading level 7")
#guard check "*Heading*" (.paragraph "*Heading*")
#guard check "*" (.paragraph "*")

-- Nestable modifiers and the invalid examples (spec lines 240-351)
#guard check "- item" (.listItem false 1 "item")
#guard check "-- item" (.listItem false 2 "item")
#guard check "~ ordered" (.listItem true 1 "ordered")
#guard check ">> quote" (.quote 2 "quote")
#guard check "> quote" (.quote 1 "quote")
#guard check ">I am not a quote" (.paragraph ">I am not a quote")
#guard check ">- not a quote" (.paragraph ">- not a quote")
#guard check "> > only level 1" (.quote 1 "> only level 1")
#guard check "% note" (.attribute 1 "note")
#guard check "%comment%" (.paragraph "%comment%")

-- Range-able modifiers and their closers (spec lines 353-419)
#guard check "$ Term" (.definition false "Term")
#guard check "$$ Term" (.definition true "Term")
#guard check "$$" (.close .definition)
#guard check "^ Footnote" (.footnote false "Footnote")
#guard check "^^ Footnote" (.footnote true "Footnote")
#guard check "^^" (.close .footnote)
#guard check ": A1" (.tableCell false "A1")
#guard check ":: A2" (.tableCell true "A2")
#guard check "::" (.close .tableCell)
#guard check "::: A" (.invalid "a run of 3 `:` is not a valid range-able detached modifier")
#guard isInvalidBlock (classifyBlock "^^^ A")

-- Delimiting modifiers and horizontal rules (spec lines 449-494)
#guard check "---" (.delimWeak 3)
#guard check "--- " (.listItem false 3 "")
#guard check "===" (.delimStrong 3)
#guard check "___" (.horizontalRule 3)
#guard check "__" (.horizontalRule 2)
#guard check "_" (.paragraph "_")

-- Tags (spec lines 727-776)
#guard check "@code lua" (.tag '@' "code" "lua")
#guard check "@document.meta" (.tag '@' "document.meta" "")
#guard check "@ document" (.paragraph "@ document")
#guard check "#tag-name.subtag p1 p2" (.tag '#' "tag-name.subtag" "p1 p2")
#guard check "# tag" (.paragraph "# tag")
#guard isInvalidBlock (classifyBlock "#tag!")
#guard check "=see url" (.tag '=' "see" "url")
#guard check "=end" (.tag '=' "end" "")
#guard check "= macro" (.paragraph "= macro")
#guard check "+color red" (.tag '+' "color" "red")
#guard check ".see url" (.tag '.' "see" "url")
#guard check "|example" (.tag '|' "example" "")
#guard check "| example" (.paragraph "| example")

-- Document splitting: exactly three blocks, in order, no phantom line.
#guard classifyDocument "* Heading\n\n- item\n" ==
  [.heading 1 "Heading", .blank, .listItem false 1 "item"]

end Norg.Blocks
