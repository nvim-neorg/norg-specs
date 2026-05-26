/-
  A coarse document tree for the Norg 1.0 model.

  This models the grouping prose (spec 134-145, 204-363, 421-494, 638-725),
  not tree-sitter.  `Norg.Blocks` classifies a line; this module keeps a stack
  of open containers and attaches each line to the innermost one that can hold
  it.

  F19 choices:

  - Headings nest by level and indentation.  A heading closes the previous one
    when its level is ≤, or its indentation is ≤.  Thus `*** C` at the same
    indentation as `** B` is B's sibling and A's child.
  - Lists/quotes nest by marker level; a same-level item nests only when its
    indentation is strictly greater than the open item's.  Indentation never
    promotes an item above its marker level.
  - `::`/`:` opens an `indentSegment`/`slide` child of its list item.  Content
    belongs to it while indented more than the list item's line.  A blank line
    ends a paragraph and a slide, but not an indent segment or list.
  - A weak delimiter is emitted in the innermost container and closes exactly
    that container, so a `---` under an indent segment closes the segment, not
    the heading.  A strong delimiter closes everything and is emitted at root.
  - Paragraph lines accumulate into one node; `title` keeps the first line.
    Blank lines do not emit `blank` nodes.
  - Tags/definitions/footnotes/table cells are leaves; ranged content is
    ordinary enclosing content.  Attributes/invalid lines become paragraph
    text because `Kind` has no case for them.
  - Consecutive list items stay siblings across a blank line; blank lines
    change grouping only in the paragraph layer.
-/
import Norg.Basic
import Norg.Blocks

namespace Norg.Structure

open Norg

/-- Node categories used by the coarse tree. -/
inductive Kind
  | heading | unorderedList | orderedList | quote | definition | footnote
  | tableCell | indentSegment | slide | paragraph | delimiterWeak | delimiterStrong
  | horizontalRule | tag | blank
  deriving Repr, DecidableEq, BEq

/-- One document node. -/
structure Node where
  kind : Kind
  /-- Marker run length for headings and lists; `0` otherwise. -/
  level : Nat
  /-- Leading whitespace width of the line that opened the node. -/
  indent : Nat
  /-- Heading/list title, or the first paragraph line; `""` otherwise. -/
  title : String
  children : List Node
  deriving Repr, BEq

-- Deriving does not cover the nested `List Node`; `BEq` is the executable
-- comparison used by tests, while this supplies the requested instance.
noncomputable instance : DecidableEq Node :=
  fun a b => Classical.propDecidable (a = b)

/-! ## Stack machine -/

/-- An open container; children are accumulated in reverse. -/
private structure Open where
  kind : Kind
  level : Nat
  indent : Nat
  title : String
  children : List Node

/-- Finished roots are accumulated in reverse; the stack is innermost first. -/
private structure Ctx where
  roots : List Node
  stack : List Open

private def nodeOf (o : Open) : Node :=
  { kind := o.kind, level := o.level, indent := o.indent, title := o.title,
    children := o.children.reverse }

private def addLeaf (st : Ctx) (n : Node) : Ctx :=
  match st.stack with
  | [] => { st with roots := n :: st.roots }
  | p :: ps => { st with stack := { p with children := n :: p.children } :: ps }

private def push (st : Ctx) (kind : Kind) (level indent : Nat) (title : String) : Ctx :=
  { st with
    stack :=
      { kind := kind, level := level, indent := indent, title := title, children := [] } ::
        st.stack }

/-- Close the innermost open container, attaching it to its parent or to the roots. -/
private def closeOne (st : Ctx) : Ctx :=
  match st.stack with
  | [] => st
  | o :: rest =>
      let n := nodeOf o
      match rest with
      | [] => { roots := n :: st.roots, stack := [] }
      | p :: ps => { st with stack := { p with children := n :: p.children } :: ps }

/-- Close a prefix of the stack while `pred` holds.  Fuel is the stack length,
which is an upper bound because every step pops one container. -/
private def closeWhile (pred : Open -> Bool) (st : Ctx) : Ctx :=
  let rec go (fuel : Nat) (roots : List Node) (stack : List Open) : Ctx :=
    match fuel with
    | 0 => { roots := roots, stack := stack }
    | fuel + 1 =>
        match stack with
        | [] => { roots := roots, stack := [] }
        | o :: rest =>
            if pred o then
              let n := nodeOf o
              match rest with
              | [] => go fuel (n :: roots) []
              | p :: ps => go fuel roots ({ p with children := n :: p.children } :: ps)
            else
              { roots := roots, stack := o :: rest }
  go st.stack.length st.roots st.stack

private def closeAll (st : Ctx) : Ctx := closeWhile (fun _ => true) st

private def closeParagraph (st : Ctx) : Ctx :=
  match st.stack with
  | o :: _ => if o.kind == .paragraph then closeOne st else st
  | [] => st

/-- Close containers that cannot contain a line at indentation `i`.

  Headings at the same indentation stay open, which lets a heading own
  same-indent lists and paragraphs until another heading or delimiter. -/
private def closeForContent (st : Ctx) (i : Nat) : Ctx :=
  closeWhile
    (fun o => if o.kind == .heading then o.indent > i else o.indent >= i) st

/-- Close `indentSegment`/`slide` containers when the line leaves their capture range. -/
private def closeSuffixes (st : Ctx) (i : Nat) : Ctx :=
  closeWhile
    (fun o => (o.kind == .indentSegment || o.kind == .slide) && i <= o.indent) st

private def isListish (k : Kind) : Bool :=
  k == .unorderedList || k == .orderedList || k == .quote

/-- Close list/quote containers that the new marker cannot nest under. -/
private def closeLists (st : Ctx) (kind : Kind) (level indent : Nat) : Ctx :=
  closeWhile
    (fun o =>
      if o.kind == kind then
        !(level > o.level || (level == o.level && indent > o.indent))
      else if isListish o.kind then
        !(indent > o.indent || level > o.level)
      else
        false) st

/-- Close headings that a new heading at `level`/`indent` must terminate. -/
private def closeHeadings (st : Ctx) (level indent : Nat) : Ctx :=
  closeWhile
    (fun o => o.kind == .heading && (level <= o.level || indent <= o.indent)) st

/-- Close headings that are indented more than an incoming non-heading line. -/
private def closeHeadingsAbove (st : Ctx) (indent : Nat) : Ctx :=
  closeWhile (fun o => o.kind == .heading && o.indent > indent) st

/-! ## Event handlers -/

private def handleParagraph (st : Ctx) (raw : String) : Ctx :=
  let i := indentWidth raw
  match st.stack with
  | o :: _ =>
      if o.kind == .paragraph then
        st -- consecutive paragraph lines are one node; the first line is the title
      else
        push (closeForContent st i) .paragraph 0 i (stripIndent raw)
  | [] => push st .paragraph 0 i (stripIndent raw)

private def handleBlank (st : Ctx) : Ctx :=
  let st := closeParagraph st
  match st.stack with
  | o :: _ => if o.kind == .slide then closeOne st else st
  | [] => st

private def handleHeading (st : Ctx) (level : Nat) (title : String) (raw : String) : Ctx :=
  let i := indentWidth raw
  let st := closeParagraph st
  let st := closeWhile (fun o => o.kind != .heading) st
  let st := closeHeadings st level i
  push st .heading level i title

private def handleList (st : Ctx) (kind : Kind) (level : Nat) (content : String)
    (raw : String) : Ctx :=
  let i := indentWidth raw
  let st := closeParagraph st
  let st := closeSuffixes st i
  let st := closeLists st kind level i
  let st := closeHeadingsAbove st i
  let st := push st kind level i content
  if content == "::" then
    push st .indentSegment 0 i ""
  else if content == ":" then
    push st .slide 0 i ""
  else
    st

private def handleWeak (st : Ctx) (i : Nat) : Ctx :=
  let st := closeParagraph st
  let st :=
    addLeaf st
      { kind := .delimiterWeak, level := 0, indent := i, title := "", children := [] }
  closeOne st

private def handleStrong (st : Ctx) (i : Nat) : Ctx :=
  let st := closeParagraph st
  let st := closeAll st
  addLeaf st
    { kind := .delimiterStrong, level := 0, indent := i, title := "", children := [] }

private def handleLeaf (st : Ctx) (kind : Kind) (title : String) (raw : String) : Ctx :=
  let i := indentWidth raw
  let st := closeParagraph st
  let st := closeForContent st i
  addLeaf st { kind := kind, level := 0, indent := i, title := title, children := [] }

private def handleHorizontal (st : Ctx) (raw : String) : Ctx :=
  let i := indentWidth raw
  let st := closeParagraph st
  let st := closeForContent st i
  addLeaf st
    { kind := .horizontalRule, level := 0, indent := i, title := "", children := [] }

private def closeKind : Blocks.DetachedKind -> Kind
  | .heading => .heading
  | .unorderedList => .unorderedList
  | .orderedList => .orderedList
  | .quote => .quote
  | .definition => .definition
  | .footnote => .footnote
  | .tableCell => .tableCell
  | .attribute => .paragraph

private def step (st : Ctx) (line : Line) : Ctx :=
  let raw := line.text
  match Blocks.classifyBlock raw with
  | .blank => handleBlank st
  | .paragraph _ => handleParagraph st raw
  | .heading level title => handleHeading st level title raw
  | .listItem ordered level content =>
      handleList st (if ordered then .orderedList else .unorderedList) level content raw
  | .quote level content => handleList st .quote level content raw
  | .delimWeak _ => handleWeak st (indentWidth raw)
  | .delimStrong _ => handleStrong st (indentWidth raw)
  | .horizontalRule _ => handleHorizontal st raw
  | .definition _ title => handleLeaf st .definition title raw
  | .footnote _ title => handleLeaf st .footnote title raw
  | .tableCell _ title => handleLeaf st .tableCell title raw
  | .close k => handleLeaf st (closeKind k) "" raw
  | .tag _ _ _ => handleLeaf st .tag (stripIndent raw) raw
  | .attribute _ _ => handleParagraph st raw
  | .invalid _ => handleParagraph st raw

/-- Build a forest from raw Norg text. -/
def build (s : String) : List Node :=
  let st := (splitLines s).foldl step { roots := [], stack := [] }
  (closeAll st).roots.reverse

/-! ## Rendering -/

private def kindName (k : Kind) (level : Nat) : String :=
  match k with
  | .heading => "heading" ++ toString level
  | .unorderedList => "unorderedList" ++ toString level
  | .orderedList => "orderedList" ++ toString level
  | .quote => "quote" ++ toString level
  | .definition => "definition"
  | .footnote => "footnote"
  | .tableCell => "tableCell"
  | .indentSegment => "indentSegment"
  | .slide => "slide"
  | .paragraph => "paragraph"
  | .delimiterWeak => "delimiterWeak"
  | .delimiterStrong => "delimiterStrong"
  | .horizontalRule => "horizontalRule"
  | .tag => "tag"
  | .blank => "blank"

private def escapeChar : Char -> String
  | '"' => "\\\""
  | '\\' => "\\\\"
  | '\n' => "\\n"
  | '\r' => "\\r"
  | '\t' => "\\t"
  | c => String.singleton c

private def escape (s : String) : String :=
  String.join (s.toList.map escapeChar)

private partial def renderNode (n : Node) : String :=
  let title := if n.title.isEmpty then [] else ["\"" ++ escape n.title ++ "\""]
  let parts := title ++ n.children.map renderNode
  let name := kindName n.kind n.level
  if parts.isEmpty then
    "(" ++ name ++ ")"
  else
    "(" ++ name ++ " " ++ String.intercalate " " parts ++ ")"

/-- Compact S-expression-like rendering for tests, e.g. `(heading1 "A" (paragraph))`. -/
def render (nodes : List Node) : String :=
  String.intercalate " " (nodes.map renderNode)

/-! ## Compile-time checks -/

-- Headings nest by level and indentation; the equal-indent level-3 heading
-- closes level 2 and becomes a sibling of it under level 1.
#guard render (build "* A\n  ** B\n     text\n  *** C\n") ==
  "(heading1 \"A\" (heading2 \"B\" (paragraph \"text\")) (heading3 \"C\"))"

-- The Level 2 Headings corpus case, without the trailing strong delimiter and
-- root paragraph: a level-2 heading at the root, then a level-1 heading with a
-- nested level-2 heading.
private def level2Input : String :=
  "** This is a level 2 heading\n   That has text underneath\n\n" ++
    "* And here is a level 1 heading\n  ** With a level 2 heading\n" ++
    "     And some content\n"

#guard render (build level2Input) ==
  "(heading2 \"This is a level 2 heading\" (paragraph \"That has text underneath\")) " ++
    "(heading1 \"And here is a level 1 heading\" (heading2 \"With a level 2 heading\" " ++
    "(paragraph \"And some content\")))"

-- A blank line ends the paragraph but not the indent segment.
#guard render (build "- ::\n  first\n\n  second\n") ==
  "(unorderedList1 \"::\" (indentSegment (paragraph \"first\") (paragraph \"second\")))"

-- The weak delimiter belongs to the indent segment, then `After` leaves the
-- list and becomes a paragraph under the heading.
#guard render (build "* H\n- ::\n  text\n  ---\nAfter\n") ==
  "(heading1 \"H\" (unorderedList1 \"::\" (indentSegment (paragraph \"text\") " ++
    "(delimiterWeak))) (paragraph \"After\"))"

-- A weak delimiter closes one level; a strong delimiter closes all levels.
#guard render (build "* H\n  ** Inner\n     text\n     ---\n  After\n  ===\nRoot\n") ==
  "(heading1 \"H\" (heading2 \"Inner\" (paragraph \"text\") (delimiterWeak)) " ++
    "(paragraph \"After\")) (delimiterStrong) (paragraph \"Root\")"

-- A blank line terminates a slide; the list item and its siblings remain.
#guard render (build "- :\n  text\n\nAfter\n") ==
  "(unorderedList1 \":\" (slide (paragraph \"text\"))) (paragraph \"After\")"

-- Empty and blank input produce no nodes.
#guard (render (build ""), render (build " \n\t\n")) == ("", "")
end Norg.Structure
