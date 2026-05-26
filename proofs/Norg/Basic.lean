/-
  Basic character classes and line handling for the Norg 1.0 model.

  Every definition here cites the relevant line range in
  `../1.0-specification.norg`.  The point of the model is to make the
  specification's edge cases executable, so where the prose is ambiguous we
  keep both readings available rather than silently picking one.
-/
namespace Norg

/-! ## Character classes (spec lines 51-105) -/

/-- Unicode `Zs` (space separator) code points.  This is the literal
definition of whitespace in spec lines 56-60. -/
def isZs (c : Char) : Bool :=
  let n := c.toNat
  n == 0x20 || n == 0xA0 || n == 0x1680 ||
  (0x2000 <= n && n <= 0x200A) || n == 0x202F || n == 0x205F || n == 0x3000

/-- `U+0009` is category `Cc`, not `Zs`, so it is *not* whitespace under the
literal definition.  The spec nevertheless discusses tab stops (line 62) and
`norg.peg` includes `\t` in its whitespace class.  We keep both predicates. -/
def isTab (c : Char) : Bool := c == '\t'

/-- Literal reading: only Unicode `Zs`. -/
def isSpecWhitespace (c : Char) : Bool := isZs c

/-- Reading needed to match the spec's own examples and `norg.peg`. -/
def isOperationalWhitespace (c : Char) : Bool := isZs c || isTab c

/-- Spec lines 78-81. -/
def isLineEnding (c : Char) : Bool :=
  c == '\n' || c == '\r' || c == '\x0c'

/-- ASCII punctuation exactly as listed in spec line 90.  The non-ASCII
general categories `Pc Pd Pe Pf Pi Po Ps` are not modelled yet; that needs a
UCD table. -/
def isAsciiPunctuation (c : Char) : Bool :=
  let n := c.toNat
  (0x21 <= n && n <= 0x2F) || (0x3A <= n && n <= 0x40) ||
  (0x5B <= n && n <= 0x60) || (0x7B <= n && n <= 0x7E)

def isPunctuation (c : Char) : Bool := isAsciiPunctuation c

/-- "Regular characters" (spec lines 103-105): everything that is not
whitespace, a line ending, or punctuation.  Note that this excludes the
backslash and every punctuation character; see FINDINGS.md F1. -/
def isRegular (c : Char) : Bool :=
  !isOperationalWhitespace c && !isLineEnding c && !isPunctuation c

/-! ## Lines (spec lines 73-86) -/

inductive LineEnding where
  | lf
  | cr
  | crlf
  | ff
  deriving Repr, DecidableEq

structure Line where
  /-- The line content, without its line ending. -/
  text : String
  ending : Option LineEnding
  deriving Repr, DecidableEq

/-- Split one line off the front.  CRLF is consumed as a single ending. -/
def splitLineChars : List Char -> List Char × Option LineEnding × List Char
  | [] => ([], none, [])
  | '\r' :: '\n' :: rest => ([], some .crlf, rest)
  | '\r' :: rest => ([], some .cr, rest)
  | '\n' :: rest => ([], some .lf, rest)
  | '\x0c' :: rest => ([], some .ff, rest)
  | c :: rest =>
      let (body, ending, rest') := splitLineChars rest
      (c :: body, ending, rest')

/-- Fuel is `s.length`; every iteration consumes at least one character. -/
def splitLines (s : String) : List Line :=
  let rec go : Nat -> List Char -> List Line
    | 0, _ => []
    | _, [] => []
    | fuel + 1, cs =>
        let (body, ending, rest) := splitLineChars cs
        { text := String.ofList body, ending := ending } :: go fuel rest
  go s.length s.toList

/-- Number of leading operationally-whitespace characters. -/
def indentWidth (s : String) : Nat :=
  (s.toList.takeWhile isOperationalWhitespace).length

/-- Drop leading operational whitespace. -/
def stripIndent (s : String) : String :=
  String.ofList (s.toList.dropWhile isOperationalWhitespace)

/-- True when the string contains only operational whitespace. -/
def isBlank (s : String) : Bool :=
  s.toList.all isOperationalWhitespace

/-! ## Runs and small list helpers -/

/-- Count the run of `c` at the front of `cs`, returning the count and the
remaining suffix. -/
def countRun (c : Char) : List Char -> Nat × List Char
  | [] => (0, [])
  | d :: ds =>
      if d == c then
        let (n, rest) := countRun c ds
        (n + 1, rest)
      else
        (0, d :: ds)

/-! ## Attached-modifier boundary models (spec lines 1045-1077)

  The prose says an opening modifier may only be preceded by whitespace or
  punctuation and a closing modifier may only be succeeded by whitespace or
  punctuation.  Line endings are explicitly *not* whitespace (line 76), and
  the prose says nothing about the beginning/end of a paragraph.  Taken
  literally, the spec's own valid example `*Bold text*` is invalid at both
  ends.  We therefore carry two models. -/

structure BoundaryModel where
  /-- May an opening delimiter appear after this character? -/
  openBefore : Option Char -> Bool
  /-- May the character after an opening delimiter be this one? -/
  openAfter : Option Char -> Bool
  /-- May a closing delimiter appear after this character? -/
  closeBefore : Option Char -> Bool
  /-- May the character after a closing delimiter be this one? -/
  closeAfter : Option Char -> Bool

/-- Literal transcription of lines 1052-1055. -/
def boundaryLiteral : BoundaryModel where
  openBefore
    | none => false
    | some c => isOperationalWhitespace c || isPunctuation c
  openAfter
    | none => false
    | some c => !isOperationalWhitespace c && !isLineEnding c
  closeBefore
    | none => false
    | some c => !isOperationalWhitespace c && !isLineEnding c
  closeAfter
    | none => false
    | some c => isOperationalWhitespace c || isPunctuation c

/-- The reading required by the spec's valid/invalid examples: paragraph and
line edges count as boundaries, and a line ending may precede a closing
delimiter's right-hand side but may not precede the delimiter itself. -/
def boundaryExamples : BoundaryModel where
  openBefore
    | none => true
    | some c => isOperationalWhitespace c || isPunctuation c || isLineEnding c
  openAfter
    | none => false
    | some c => !isOperationalWhitespace c && !isLineEnding c
  closeBefore
    | none => false
    | some c => !isOperationalWhitespace c && !isLineEnding c
  closeAfter
    | none => true
    | some c => isOperationalWhitespace c || isPunctuation c || isLineEnding c

end Norg
