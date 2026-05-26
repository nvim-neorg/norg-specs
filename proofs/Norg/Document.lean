/-
  Paragraph assembly for the Norg 1.0 model (spec lines 134-145).

  `Norg.Blocks` classifies one physical line.  This module groups consecutive
  paragraph lines into a paragraph and keeps every non-paragraph block as its
  own chunk.  That is the smallest step needed to run the inline scanner on
  the multi-line examples (`*Bold\ntext*`, 1102-1103) and on the paragraph
  break rules (142-145).

  The spec says a paragraph ends at a paragraph break, a detached modifier, a
  delimiting modifier, a ranged tag, or a strong carryover tag (138-141).
  `Norg.Blocks` already classifies all of those, so the assembly rule is just
  "paragraph lines accumulate; anything else flushes".

  Consecutive empty lines are kept as separate `.blank` chunks.  Whether they
  are one paragraph break or several is exactly F18; keeping them distinct
  makes the choice visible instead of collapsing it.
-/
import Norg.Basic
import Norg.Blocks
import Norg.Inline

namespace Norg.Document

open Norg

/-- A paragraph, a blank line, one non-paragraph block, or verbatim ranged-tag
content that must not be inline-scanned. -/
inductive Chunk
  | blank
  | block (b : Blocks.Block)
  | paragraph (lines : List String)
  | raw (text : String)
  deriving Repr, DecidableEq, BEq

/-- Finish the current paragraph, if any.  `out` is in reverse order. -/
private def flush (acc : List String) (out : List Chunk) : List Chunk :=
  if acc.isEmpty then out else .paragraph acc.reverse :: out

/-- Split a document into paragraph chunks and block chunks.  Lines inside a
ranged verbatim tag (`@name ... @end`) are emitted as `.raw`, because spec
lines 782-820 make the body verbatim: markup and linkables inside must not be
interpreted. -/
def assemble (s : String) : List Chunk :=
  let rec go (inVerbatim : Bool) (acc : List String) (out : List Chunk) :
      List Line -> List Chunk
    | [] => flush acc out
    | line :: rest =>
        let b := Blocks.classifyBlock line.text
        if inVerbatim then
          match b with
          | .tag '@' "end" _ => go false [] (.block b :: flush acc out) rest
          | _ => go true [] (.raw line.text :: flush acc out) rest
        else
          match b with
          | .blank => go false [] (.blank :: flush acc out) rest
          | .paragraph _ => go false (line.text :: acc) out rest
          | .tag '@' "end" _ => go false [] (.block b :: flush acc out) rest
          | .tag '@' _ _ => go true [] (.block b :: flush acc out) rest
          | _ => go false [] (.block b :: flush acc out) rest
  (go false [] [] (splitLines s)).reverse

/-- The text of a paragraph chunk, with physical lines joined by `\n`. -/
def paragraphText : Chunk -> Option String
  | .paragraph lines => some (String.intercalate "\n" lines)
  | _ => none

/-- Scan a paragraph with the inline attached-modifier scanner. -/
def scanParagraph (c : Chunk) : Option Inline.Result :=
  (paragraphText c).map (Inline.scan boundaryExamples)

/-! ## Compile-time checks -/

#guard assemble "a\nb\n\nc\n" ==
  [.paragraph ["a", "b"], .blank, .paragraph ["c"]]

#guard assemble "* Heading\ntext\n" ==
  [.block (.heading 1 "Heading"), .paragraph ["text"]]

#guard assemble "  \n" == [.blank]

-- Two empty lines produce two `.blank` chunks, not one merged break.  This is
-- the model decision for F18, not a claim about the spec.
#guard assemble "a\n\n\nb\n" ==
  [.paragraph ["a"], .blank, .blank, .paragraph ["b"]]

#guard assemble "" == []

-- A paragraph break ends the paragraph; the following text starts a new one.
#guard assemble "a\n \nb\n" ==
  [.paragraph ["a"], .blank, .paragraph ["b"]]

-- Multi-line attached modifier: the valid example at 1102-1103.
#guard (scanParagraph (.paragraph ["*Bold", "text*"])).map
  (fun r => (Inline.openCount r, Inline.closeCount r)) == some (1, 1)

-- The invalid example at 1124-1126 closes on its own line; the scanner must
-- not accept it.  This is F21 in executable form.
#guard (scanParagraph (.paragraph ["*Bold", "text", "*"])).map
  (fun r => (Inline.openCount r, Inline.closeCount r)) == some (1, 0)

end Norg.Document
