/-
  Tags for the Norg 1.0 model.  Line numbers refer to
  `../1.0-specification.norg`.

  Line 738 lists six sigils (`=`, `|`, `@`, `#`, `+`, `.`) and line 1692
  names their kinds `=macro`, `|standard`, `@verbatim`, `#infecting`,
  `+carryover` and `.infirm`.  We call the `#` kind `strong`: lines 971-998
  call `#` the *strong* carryover tag, while `+` is the weak one (lines
  925-935).  Hence `Kind.strong` is `#` and `Kind.carryover` is `+`.

  `=` is overloaded, which this model keeps in one place: it opens macro tags
  (lines 778-794) and closes them with `=end` (line 776); the strong
  *delimiting* modifier `===` also begins with `=` (lines 472-483).  None of
  the closing forms is special-cased here: `=end`, `=end.strong`, `@end` and
  `|end` are ordinary tags whose names happen to be `end` or `end.strong`,
  and the surrounding context decides whether they close anything.  `===`
  cannot collide with a tag because `=` is not a name character, so a sigil
  without a following name character yields `none`.

  Parameters are kept raw: splitting them on spaces and interpreting the
  `\ ` escape of lines 749-752 are later stages, so `params` still contains
  backslashes and any extra inner or trailing whitespace.
-/
import Norg.Basic

namespace Norg.Tags

open Norg

/-- The six tag types (lines 734-735, 1692). -/
inductive Kind where
  /-- `#`: the "infecting" / strong carryover tag (lines 971-998, 1753). -/
  | strong
  /-- `.`: single-line macro invocation (lines 1025-1027). -/
  | infirm
  /-- `|`: standard ranged tag (lines 816-820, 1763). -/
  | standard
  /-- `+`: weak carryover tag (lines 925-935, 1753). -/
  | carryover
  /-- `=`: macro tag (lines 778-794, 1773). -/
  | macro
  /-- `@`: verbatim ranged tag (lines 899-913, 1745). -/
  | verbatim
  deriving Repr, DecidableEq, BEq

/-- One tag declaration.  `sigil` is kept even though `kind` determines it so
that a parsed tag can be printed back; `name` keeps the hierarchy dots;
`params` is uninterpreted (see the module comment). -/
structure Tag where
  kind : Kind
  sigil : Char
  name : String
  params : String
  deriving Repr, DecidableEq, BEq

/-- Sigil to kind for the six tag characters of line 738. -/
def kindOfSigil : Char -> Option Kind
  | '#' => some .strong
  | '.' => some .infirm
  | '|' => some .standard
  | '+' => some .carryover
  | '=' => some .macro
  | '@' => some .verbatim
  | _ => none

/-- Line 741 allows regular characters plus `-` and `_` in a name; line 742
adds `.` as the hierarchy delimiter.  Both readings are served by collecting
`.` here and validating the hierarchy afterwards. -/
def isTagNameChar (c : Char) : Bool :=
  isRegular c || c == '-' || c == '_' || c == '.'

/-- A name is a nonempty sequence of nonempty `.`-separated components, each
made of regular characters, `-` and `_`.  Because `.` delimits a hierarchy
(line 742) rather than belonging to a name (line 741), a leading, trailing or
doubled dot denotes an empty component and is rejected; lines 764-766 permit
dropping a name only when it breaks the name rules, which this does. -/
private def isHierarchicalName (name : String) : Bool :=
  let components := name.splitOn "."
  !components.isEmpty &&
    components.all (fun part =>
      !part.isEmpty && part.toList.all (fun c => isRegular c || c == '-' || c == '_'))

/-- Parse one line as a tag.

  Leading operational whitespace is skipped (lines 736-737), then the sigil
  must be followed immediately by a name character (lines 739-741).  The name
  runs to the first non-name character; if that character is punctuation
  outside the name set (`#tag!`), the line is not a tag at all.  Everything
  after the first whitespace character following the name is the raw
  parameter text (lines 744-754). -/
def parseTag (raw : String) : Option Tag :=
  match (stripIndent raw).toList with
  | [] => none
  | sigil :: rest =>
      match kindOfSigil sigil with
      | none => none
      | some kind =>
          let nameChars := rest.takeWhile isTagNameChar
          let afterName := rest.drop nameChars.length
          let name := String.ofList nameChars
          if nameChars.isEmpty || !isHierarchicalName name then
            none
          else
            match afterName with
            | [] => some { kind, sigil, name, params := "" }
            | c :: rest' =>
                if isOperationalWhitespace c then
                  some { kind, sigil, name, params := String.ofList rest' }
                else
                  none

/-- Every line may start a tag (lines 736-737); lines that are not tags are
dropped.  Closing forms are not filtered out, see the module comment. -/
def parseDocumentTags (s : String) : List Tag :=
  (splitLines s).filterMap fun line => parseTag line.text

/-! ## Compile-time checks -/

private def shape (raw : String) : Option (Kind × Char × String × String) :=
  (parseTag raw).map fun t => (t.kind, t.sigil, t.name, t.params)

#guard shape "@code lua" == some (.verbatim, '@', "code", "lua")
#guard shape "@document.meta" == some (.verbatim, '@', "document.meta", "")
#guard shape "@ document" == none
#guard shape "#tag-name.subtag p1 p2" == some (.strong, '#', "tag-name.subtag", "p1 p2")
#guard shape "# tag" == none
#guard shape "#tag!" == none
#guard shape "#tag trailing" == some (.strong, '#', "tag", "trailing")
#guard shape "=see url" == some (.macro, '=', "see", "url")
#guard shape "=end" == some (.macro, '=', "end", "")
#guard shape "= macro" == none
#guard shape "+color red" == some (.carryover, '+', "color", "red")
#guard shape ".see url" == some (.infirm, '.', "see", "url")
#guard shape "|example" == some (.standard, '|', "example", "")
#guard shape "| example" == none
#guard shape "|end" == some (.standard, '|', "end", "")
#guard shape "@end" == some (.verbatim, '@', "end", "")
#guard shape "  @indented" == some (.verbatim, '@', "indented", "")
-- Dots delimit a hierarchy (line 742), so every component must be nonempty:
-- these three are malformed hierarchies, not names containing a literal dot.
#guard shape "#a.b.c x" == some (.strong, '#', "a.b.c", "x")
#guard shape "#.leading x" == none
#guard shape "#trailing. x" == none
#guard shape "#double..dot x" == none

#guard (parseDocumentTags "@code lua\nnot a tag\n#x p\n").length == 2
#guard (parseDocumentTags "@code lua\nnot a tag\n#x p\n").map (fun t => t.name) ==
  ["code", "x"]

end Norg.Tags
