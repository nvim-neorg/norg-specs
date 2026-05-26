/-
  Run the tree-sitter-norg corpus through the current Lean model.

  This is a *coverage* check, not a full parser comparison.  `Document.assemble`
  knows paragraphs and line-level blocks; it does not build the tree-sitter
  tree.  A case is "accepted" when no line is `.invalid` and no paragraph has an
  inline error.  Unclosed attached modifiers are reported but treated as raw
  text, matching the spec's "disqualified" language; only linkables may be
  errors (spec line 1328).

  Run with: `lake env lean Norg/CorpusCheck.lean`
-/
import Norg
import Norg.TreeSitterCorpus

open Norg

namespace Norg.CorpusCheck

structure CaseResult where
  file : String
  name : String
  expectedError : Bool
  invalidBlocks : Nat
  inlineErrors : Nat
  unclosed : Nat
  blocks : Nat
  paragraphs : Nat
  deriving Repr, DecidableEq

def countBlocks : List Document.Chunk -> Nat
  | [] => 0
  | .block _ :: rest => 1 + countBlocks rest
  | _ :: rest => countBlocks rest

def countParagraphs : List Document.Chunk -> Nat
  | [] => 0
  | .paragraph _ :: rest => 1 + countParagraphs rest
  | _ :: rest => countParagraphs rest

def countInvalid : List Document.Chunk -> Nat
  | [] => 0
  | .block (.invalid _) :: rest => 1 + countInvalid rest
  | _ :: rest => countInvalid rest

def inlineTotals : List Document.Chunk -> Nat × Nat
  | [] => (0, 0)
  | chunk :: rest =>
      let (errors, unclosed) := inlineTotals rest
      match Document.scanParagraph chunk with
      | some result => (errors + Inline.errorCount result, unclosed + result.unclosed.length)
      | none => (errors, unclosed)

def checkCase (c : TreeSitterCorpus.Case) : CaseResult :=
  let chunks := Document.assemble c.input
  let (inlineErrors, unclosed) := inlineTotals chunks
  {
    file := c.file
    name := c.name
    expectedError := c.expectedError
    invalidBlocks := countInvalid chunks
    inlineErrors := inlineErrors
    unclosed := unclosed
    blocks := countBlocks chunks
    paragraphs := countParagraphs chunks
  }

def results : List CaseResult := TreeSitterCorpus.cases.map checkCase

def isClean (r : CaseResult) : Bool :=
  r.invalidBlocks == 0 && r.inlineErrors == 0

def countWhere (p : CaseResult -> Bool) : Nat :=
  (results.filter p).length

def acceptedValid : Nat := countWhere (fun r => !r.expectedError && isClean r)
def rejectedValid : Nat := countWhere (fun r => !r.expectedError && !isClean r)
def rejectedInvalid : Nat := countWhere (fun r => r.expectedError && !isClean r)
def acceptedInvalid : Nat := countWhere (fun r => r.expectedError && isClean r)

def describe (r : CaseResult) : String :=
  s!"{r.file} :: {r.name} (invalid={r.invalidBlocks}, inline={r.inlineErrors}, unclosed={r.unclosed})"

def firstRejectedValid (n : Nat) : List String :=
  ((results.filter (fun r => !r.expectedError && !isClean r)).take n).map describe

def firstAcceptedInvalid (n : Nat) : List String :=
  ((results.filter (fun r => r.expectedError && isClean r)).take n).map describe

def firstRejectedInvalid (n : Nat) : List String :=
  ((results.filter (fun r => r.expectedError && !isClean r)).take n).map describe

def report : IO Unit := do
  IO.println s!"cases: {results.length}"
  IO.println s!"expected-valid accepted: {acceptedValid}"
  IO.println s!"expected-valid rejected: {rejectedValid}"
  IO.println s!"expected-error rejected: {rejectedInvalid}"
  IO.println s!"expected-error accepted: {acceptedInvalid}"
  IO.println "--- first expected-valid rejections ---"
  for line in firstRejectedValid 20 do
    IO.println line
  IO.println "--- expected-error rejections ---"
  for line in firstRejectedInvalid 10 do
    IO.println line
  IO.println "--- expected-error acceptances ---"
  for line in firstAcceptedInvalid 10 do
    IO.println line

#eval report

end Norg.CorpusCheck
