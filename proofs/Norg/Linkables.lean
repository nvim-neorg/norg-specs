/-
  Lexical linkable-span recognition for Norg 1.0 (spec lines 1298-1613).
  Not a resolver: it finds `{}`, `[]`, `<>` spans and validates their local
  shape.  Escapes and verbatim eligibility belong to the caller (`Norg.Inline`).

  Decisions: an edge line ending invalidates `{}`/`<>` but makes `[]` plain
  text (the explicit description rule); `{:path:...}` accepts empty, digits,
  a run of `*` (heading level), or one `$`/`^`/`#` followed by whitespace.
-/
import Norg.Basic

namespace Norg.Linkables

open Norg

inductive Kind
  | location
  | description
  | inlineTarget
  deriving Repr, DecidableEq, BEq

structure Span where
  start : Nat
  stop : Nat          -- index one past the closing delimiter
  kind : Kind
  valid : Bool
  reason : String     -- "" for valid spans
  deriving Repr, DecidableEq, BEq

structure Result where
  spans : List Span
  deriving Repr, DecidableEq, BEq

/-- Consume `cs` (characters after an opener) through the matching closer.
`stack` holds the expected closers, innermost first; with `nest`, `{}` and `[]`
groups nest inside each other.  Returns characters consumed, or `none`. -/
private def findClose (nest : Bool) : List Char → Nat → List Char → Option Nat
  | [], _, _ => some 0
  | top :: stack, fuel, c :: rest =>
      if c == top then
        match stack with
        | [] => some 1
        | _ => (findClose nest stack fuel rest).map (· + 1)
      else
        let stack' :=
          if nest && c == '{' then '}' :: top :: stack
          else if nest && c == '[' then ']' :: top :: stack
          else top :: stack
        (findClose nest stack' fuel rest).map (· + 1)
  | _ :: _, 0, _ => none
  | _ :: _, _, [] => none
/-- `(stop, closed, content)`, with `stop` relative to the opening character. -/
private def spanInfo (nest : Bool) (closer : Char) (rest : List Char) :
    Nat × Bool × List Char :=
  match findClose nest [closer] rest.length rest with
  | some n => (1 + n, true, rest.take (n - 1))
  | none => (1 + rest.length, false, rest)

private def isDigit (c : Char) : Bool :=
  '0'.toNat <= c.toNat && c.toNat <= '9'.toNat
private def allDigits (cs : List Char) : Bool := cs.all isDigit
private def dropTrailingWhitespace : List Char → List Char
  | [] => []
  | c :: cs =>
      let rest := dropTrailingWhitespace cs
      if rest.isEmpty && isOperationalWhitespace c then [] else c :: rest

/-- Split after the first `:`, returning the path and the remainder. -/
private def splitFirstColon : List Char → Option (List Char × List Char)
  | [] => none
  | ':' :: rest => some ([], rest)
  | c :: cs => (splitFirstColon cs).map fun (path, rest) => (c :: path, rest)

/-- The requirement shared by `*`, `$`, `^`, `/`, `@`, `?`, `=`, `#`. -/
private def afterSigil (rest : List Char) : Bool × String :=
  match rest with
  | d :: _ =>
      if isOperationalWhitespace d then (true, "") else (false, "missing whitespace after sigil")
  | [] => (false, "missing whitespace after sigil")

/-- The target after `{:path:`.  Allowed: empty, digits, a run of `*` followed
by whitespace, or a single `$`/`^`/`#` followed by whitespace.  A run of `*`
encodes the heading level (spec line 1375); doubled `$`/`^` are the ranged
forms the spec disallows in link syntax. -/
private def fileTarget (r : List Char) : Bool × String :=
  let trimmed := dropTrailingWhitespace r
  if trimmed.isEmpty then (true, "")
  else if allDigits trimmed then (true, "")
  else
    match r with
    | c :: _ =>
        if c == '*' then
          let (_, rest) := countRun '*' r
          match rest with
          | d :: _ =>
              if isOperationalWhitespace d then (true, "")
              else (false, "unsupported file-location target")
          | [] => (false, "unsupported file-location target")
        else if c == '$' || c == '^' || c == '#' then
          match r with
          | _ :: d :: _ =>
              if isOperationalWhitespace d then (true, "")
              else (false, "unsupported file-location target")
          | _ => (false, "unsupported file-location target")
        else (false, "unsupported file-location target")
    | [] => (false, "unsupported file-location target")

/-- Validate the content of `{...}` (without the braces). -/
private def location (content : List Char) : Bool × String :=
  match content with
  | [] => (false, "empty link location")
  | c :: rest =>
      if c == '*' then
        -- Repeated `*` is a heading level, not a "ranged" target: `{** Heading}`
        -- is valid (spec lines 1411-1429, corpus `Basic Links`).
        let (_, rest') := countRun '*' (c :: rest)
        afterSigil rest'
      else if c == '$' || c == '^' then
        if rest.head? == some c then (false, "ranged link target") else afterSigil rest
      else if c == ':' then
        match splitFirstColon rest with
        | none => (false, "file location missing its second ':'")
        | some (path, tail) =>
            if path.isEmpty then (false, "empty file path") else fileTarget tail
      else if c == '/' || c == '@' || c == '?' || c == '=' || c == '#' then
        afterSigil rest
      else (true, "")
private def mk (kind : Kind) (stop : Nat) (valid : Bool) (reason : String) : Span :=
  { start := 0, stop, kind, valid, reason }

private def lastChar : List Char → Option Char
  | [] => none
  | cs => cs.reverse.head?
private def spanBrace (cs : List Char) : Option Span :=
  match cs with
  | '{' :: rest =>
      let (stop, closed, content) := spanInfo true '}' rest
      match content with
      | [] =>
          let why := if closed then "empty link location" else "unclosed link location"
          some (mk .location stop false why)
      | c :: _ =>
          if isOperationalWhitespace c then
            none
          else if isLineEnding c || (lastChar content).any isLineEnding then
            some (mk .location stop false "line ending at a link-location edge")
          else if !closed then
            some (mk .location stop false "unclosed link location")
          else
            let (ok, reason) := location content
            some (mk .location stop ok reason)
  | _ => none

private def spanBracket (cs : List Char) : Option Span :=
  match cs with
  | '[' :: rest =>
      let (stop, closed, content) := spanInfo true ']' rest
      match content with
      | [] =>
          let why := if closed then "empty description" else "unclosed description"
          some (mk .description stop false why)
      | c :: _ =>
          if isOperationalWhitespace c || isLineEnding c then
            none
          else
            match lastChar content with
            | some d =>
                if isOperationalWhitespace d || isLineEnding d then none
                else if !closed then some (mk .description stop false "unclosed description")
                else some (mk .description stop true "")
            | none => none
  | _ => none

private def spanAngle (cs : List Char) : Option Span :=
  match cs with
  | '<' :: rest =>
      let (stop, closed, content) := spanInfo false '>' rest
      match content with
      | [] =>
          let why := if closed then "empty inline link target" else "unclosed inline link target"
          some (mk .inlineTarget stop false why)
      | c :: _ =>
          if isOperationalWhitespace c then
            none
          else
            match lastChar content with
            | some d =>
                if isOperationalWhitespace d then none
                else if isLineEnding c || isLineEnding d || !closed then
                  some (mk .inlineTarget stop false "edge line ending or unclosed target")
                else some (mk .inlineTarget stop true "")
            | none => none
  | _ => none

/-- If `cs` starts with `{`, `[`, or `<`, return the span beginning at index 0.
`stop` is the number of characters consumed.  Returns `none` when the construct
is not a linkable at all (e.g. `{ not a link }`, `[ not a link ]`). -/
def spanAt (cs : List Char) : Option Span :=
  match cs with
  | '{' :: _ => spanBrace cs
  | '[' :: _ => spanBracket cs
  | '<' :: _ => spanAngle cs
  | _ => none

/-- Scan a whole paragraph, returning non-overlapping spans in source order. -/
def scan (s : String) : Result :=
  let cs := s.toList
  let rec go (fuel i skip : Nat) (acc : List Span) : List Span :=
    match fuel with
    | 0 => acc.reverse
    | fuel + 1 =>
        if i < skip then
          go fuel (i + 1) skip acc
        else
          match cs.drop i with
          | [] => acc.reverse
          | c :: rest =>
              match c with
              | '{' | '[' | '<' =>
                  match spanAt (c :: rest) with
                  | some sp =>
                      let sp := { sp with start := i, stop := i + sp.stop }
                      go fuel (i + 1) sp.stop (sp :: acc)
                  | none => go fuel (i + 1) skip acc
              | _ => go fuel (i + 1) skip acc
  { spans := go cs.length 0 0 [] }

def errorCount (r : Result) : Nat :=
  (r.spans.filter fun sp => !sp.valid).length

private def accepts (s : String) (kind : Kind) (stop : Nat) : Bool :=
  match spanAt s.toList with
  | some sp =>
      sp.start == 0 && sp.stop == stop && sp.kind == kind && sp.valid && sp.reason == ""
  | none => false

private def rejects (s : String) (kind : Kind) (stop : Nat) : Bool :=
  match spanAt s.toList with
  | some sp =>
      sp.start == 0 && sp.stop == stop && sp.kind == kind && !sp.valid && sp.reason != ""
  | none => false

private def ignores (s : String) : Bool := (spanAt s.toList).isNone

#guard accepts "{link}" .location 6 && accepts "{* text}" .location 8
#guard rejects "{*text}" .location 7 && rejects "{$$ text}" .location 9 &&
  accepts "{** heading}" .location 12
#guard accepts "{:link:}" .location 8 && accepts "{:link:20}" .location 10
#guard rejects "{:file:/ x}" .location 11 && rejects "{:file:@ x}" .location 11
#guard rejects "{:file:https://x}" .location 17 && accepts "{:file:** x}" .location 12
#guard accepts "{# link}" .location 8 && rejects "{?link}" .location 7
#guard accepts "{/ x}" .location 5
#guard ignores "{ * text}" && ignores "{ not a link }"
#guard accepts "[anchor]" .description 8 && ignores "[ not a link ]"
#guard accepts "<inline link target>" .inlineTarget 20 && ignores "< link target >"
#guard accepts "{* Link to {# headings}[heading]}" .location 33 &&
  (scan "{* Link to {# headings}[heading]}").spans.length == 1
#guard (scan "[anchor][description]").spans.map (fun sp => (sp.start, sp.stop, sp.valid)) ==
  [(0, 8, true), (8, 21, true)]
#guard (scan "Click {* link}(attribute) now.").spans ==
  [{ start := 6, stop := 14, kind := .location, valid := true, reason := "" }]
#guard (scan "This is [ not a link ] description.").spans.isEmpty &&
  errorCount (scan "Click {* link}[here] to see {*text}.") == 1

end Norg.Linkables
