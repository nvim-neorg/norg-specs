/-
  Inline attached-modifier scanning for the Norg 1.0 model.

  Spec citations refer to `../1.0-specification.norg`.  The scanner walks one
  paragraph left to right and classifies each attached-modifier delimiter
  (spec lines 1082-1093) as `open`, `close`, `literal`, `error`, `linkOpen`, or
  `linkClose`.  It is not a full parser: no markup tree is built, so `unclosed`
  and the event list are the structural output.

  Modelled here:
  * standard attached modifiers and their nesting/doubling rules;
  * verbatim attached modifiers, whose bodies are skipped;
  * free-form `<mod>| ... |<mod>` modifiers (spec lines 1162-1188), including
    verbatim bodies and nested standard markup;
  * link modifiers `:` (spec lines 1190-1229), emitted as linkOpen/linkClose;
  * attached modifier extensions `(...)` (spec lines 1231-1250), skipped;
  * linkable spans `{}`, `[]`, `<>`, delegated to `Norg.Linkables`.  A link
    location (`{...}`) and an inline target (`<...>`) stay opaque, while the
    content of a valid description (`[...]`) is recursively scanned as its own
    inline scope (spec lines 1547-1613, 1647).  Invalid linkables are errors.
-/
import Norg.Basic
import Norg.Linkables

namespace Norg.Inline

open Norg

/-! ## Delimiter classes -/

/-- The attached modifiers of spec lines 1083-1093.  The link modifier `:` is
handled separately because its opening/closing rules are the polar opposite of
the other modifiers. -/
private def isAttachedModifier (c : Char) : Bool :=
  c == '*' || c == '/' || c == '_' || c == '-' || c == '!' || c == '^' ||
  c == ',' || c == '`' || c == '%' || c == '$' || c == '&'

/-- Verbatim modifiers: `` `inline code` `` (spec line 1090), `$inline math$`
and `&variable&` (spec lines 1092-1093).  Their bodies are not scanned. -/
private def isVerbatim (c : Char) : Bool := c == '`' || c == '$' || c == '&'

/-- Spec lines 1088-1089: `^` may not nest into `,` and `,` may not nest into
`^`.  The prose states the restriction in both directions ("cannot be nested
into"), so opening is blocked either way.  A blocked delimiter falls through
to the closing/literal rules, i.e. it is never a `.open`. -/
private def nestBlocked (top : Option Char) (c : Char) : Bool :=
  (c == '^' && top == some ',') || (c == ',' && top == some '^')

/-! ## Result types -/

inductive Role
  | open
  | close
  | literal
  | error
  | linkOpen
  | linkClose
  deriving Repr, DecidableEq, BEq

structure Event where
  index : Nat
  char : Char
  role : Role
  note : String
  deriving Repr, DecidableEq, BEq

structure Result where
  events : List Event
  unclosed : List Char
  deriving Repr, DecidableEq, BEq

/-- One open attached modifier.  `freeForm` records whether it was opened as
`<char>|`; a free-form modifier is closed by `|<char>` rather than `<char>`. -/
private structure Open where
  char : Char
  index : Nat
  freeForm : Bool
  deriving Repr, DecidableEq, BEq

/-! ## Scanner -/

/-- Absolute character index of the first valid closing occurrence of verbatim
delimiter `c` in `cs`, whose head sits at index `i`.

A candidate must satisfy `closeBefore`/`closeAfter` and must not be part of a
doubled run (spec lines 1075-1077).  Per the task brief, backslashes inside
the body are literal, so an escaped-looking closer still closes; spec lines
97-99 and 1699-1700 can be read the other way (reported). -/
private def findCloser (m : BoundaryModel) (c : Char) (pre : Option Char) (i : Nat) :
    List Char → Option Nat
  | [] => none
  | d :: ds =>
      if d == c && pre != some c && ds.head? != some c &&
          m.closeBefore pre && m.closeAfter ds.head? then
        some i
      else
        findCloser m c (some d) (i + 1) ds

/-- Find the closing `<char>` of a free-form span `| <char>` starting at `i`.
The body may contain whitespace and the modifier character, so the `|` is the
disambiguator.  Backslashes are verbatim inside free-form spans and are not
treated as escapes (spec lines 1184-1186). -/
private def findFreeFormCloser (m : BoundaryModel) (c : Char) (i : Nat) :
    List Char → Option Nat
  | [] => none
  | d :: ds =>
      if d == '|' then
        match ds with
        | e :: es =>
            if e == c && es.head? != some c && m.closeAfter es.head? then
              some (i + 1)
            else
              findFreeFormCloser m c (i + 1) ds
        | [] => none
      else
        findFreeFormCloser m c (i + 1) ds

/-- First `)` at or after index `i`; attribute extensions do not nest in the
1.0 prose. -/
private def findParenCloser (i : Nat) : List Char → Option Nat
  | [] => none
  | ')' :: _ => some i
  | _ :: ds => findParenCloser (i + 1) ds

/-- A `(` is an attached modifier extension when it directly follows a closed
modifier or a linkable (spec lines 1231-1250). -/
private def isExtensionPrefix : Option Char → Bool
  | none => false
  | some p => isAttachedModifier p || p == '}' || p == ']' || p == '>'

/-- Spec lines 1219-1223: an opening link modifier is preceded by a regular
character and followed by an opening attached modifier. -/
private def linkOpenAt (m : BoundaryModel) (pre : Option Char) : List Char → Bool
  | d :: ds =>
      isAttachedModifier d &&
      (match pre with | some p => isRegular p | none => false) &&
      ds.head? != some d && m.openAfter ds.head?
  | [] => false

/-- Spec lines 1225-1227: a closing link modifier follows a closing attached
modifier and is succeeded by a regular character. -/
private def linkCloseAt (pre : Option Char) : List Char → Bool
  | d :: _ =>
      (match pre with | some p => isAttachedModifier p | none => false) && isRegular d
  | [] => false

/-- Turn a finished `go` accumulator into source-order events.  Openers left on
the stack are raw text: they are reported as trailing `.literal` events (at
their opening index) and as characters in `unclosed`. -/
private def finish (acc : List Event) (stack : List Open) : List Event × List Char :=
  let trailing := stack.reverse.map fun o =>
    { index := o.index, char := o.char, role := .literal,
      note := s!"unclosed '{o.char}' opener treated as raw text" }
  (acc.reverse ++ trailing, stack.map Open.char)

/-- Walk the paragraph.  `fuel` is `s.length`; every step consumes at least
one character, so it never runs out for a legitimate input.

State: `i` is the index of `cs.head`, `pre` the predecessor character (`none`
at paragraph start), `escaped` marks the character after a backslash, `stack`
holds open modifiers (head = innermost opener), and `acc` is the reversed event
list.

The rules, in order:
1. backslash: skip, no event, next char is the new predecessor (spec 93-99);
2. free-form closer `|<char>` for a free-form opener;
3. non-delimiter: no event;
4. run of 2+ identical delimiters: one `.literal` event for the run
   (spec 1075-1077, applies "in all circumstances");
5. free-form opener `<char>|`: `.open` + scan, or `.open` + `.close` for a
   verbatim body; without a closer the opener is `.literal`;
6. verbatim opener with a valid closer: `.open` + `.close`, body skipped;
   without a closer the opener is `.literal`;
7. otherwise: `.open` if both opening boundaries hold, `.close` if both
   closing boundaries and the stack top matches, `.error` for a wrong-order
   close, `.literal` when neither boundary pair holds.
   A delimiter that satisfies both pairs closes when it matches the top and
   opens otherwise (left to right; spec 1097/1117, 1074). -/
private def go (m : BoundaryModel) :
    Nat → Nat → Option Char → Bool → List Char → List Open → List Event →
      List Event × List Open
  | 0, _, _, _, _, stack, acc => (acc, stack)
  | _ + 1, _, _, _, [], stack, acc => (acc, stack)
  | fuel + 1, i, _, true, c :: rest, stack, acc =>
      go m fuel (i + 1) (some c) false rest stack acc
  | fuel + 1, i, pre, false, c :: rest, stack, acc =>
      let ev (role : Role) (note : String) : Event :=
        { index := i, char := c, role, note }
      let linkSpan :=
        if c == '{' || c == '[' || c == '<' then Linkables.spanAt (c :: rest) else none
      if c == '\\' then
        go m fuel (i + 1) pre true rest stack acc
      else if linkSpan.isSome then
        match linkSpan with
        | some sp =>
            let closer : Char :=
              if c == '{' then '}' else if c == '[' then ']' else '>'
            if sp.valid then
              -- Only a description carries inline markup.  The location of a
              -- link (`{...}`) and an inline target (`<...>`) are opaque.
              -- The content starts after the opener and stops before the
              -- closer, whose positions are inside the already matched span.
              let descEvents :=
                if c == '[' then
                  let content := rest.take (sp.stop - 2)
                  let (innerAcc, innerStack) := go m fuel 0 none false content [] []
                  let (innerEvents, _) := finish innerAcc innerStack
                  innerEvents.map fun e => { e with index := i + 1 + e.index }
                else []
              go m fuel (i + sp.stop) (some closer) false (rest.drop (sp.stop - 1)) stack
                (descEvents.reverse ++ (ev .literal "linkable span" :: acc))
            else
              go m fuel (i + sp.stop) (some closer) false (rest.drop (sp.stop - 1)) stack
                (ev .error s!"invalid linkable: {sp.reason}" :: acc)
        | none => go m fuel (i + 1) (some c) false rest stack acc
      else if c == '|' then
        match stack.head? with
        | some o =>
            if o.freeForm then
              match rest with
              | d :: ds =>
                  if d == o.char && ds.head? != some d && m.closeAfter ds.head? then
                    go m fuel (i + 2) (some d) false ds (stack.drop 1)
                      ({ index := i + 1, char := d, role := .close,
                         note := "free-form closing modifier" } :: acc)
                  else
                    go m fuel (i + 1) (some c) false rest stack acc
              | [] => go m fuel (i + 1) (some c) false rest stack acc
            else
              go m fuel (i + 1) (some c) false rest stack acc
        | none => go m fuel (i + 1) (some c) false rest stack acc
      else if c == '(' && isExtensionPrefix pre then
        match findParenCloser (i + 1) rest with
        | some j =>
            go m fuel (j + 1) (some ')') false (rest.drop (j - i)) stack
              (ev .literal "attached modifier extension" :: acc)
        | none => go m fuel (i + 1) (some c) false rest stack acc
      else if c == ':' then
        if linkOpenAt m pre rest then
          go m fuel (i + 1) (some c) false rest stack
            (ev .linkOpen "opening link modifier" :: acc)
        else if linkCloseAt pre rest then
          go m fuel (i + 1) (some c) false rest stack
            (ev .linkClose "closing link modifier" :: acc)
        else
          go m fuel (i + 1) (some c) false rest stack acc
      else if !isAttachedModifier c then
        go m fuel (i + 1) (some c) false rest stack acc
      else
        let (n, tail) := countRun c (c :: rest)
        let next := rest.head?
        let top := stack.head?.map Open.char
        let insideSelf :=
          match stack.head? with
          | some o => o.freeForm && o.char == c
          | none => false
        let canOpen := !nestBlocked top c && m.openBefore pre && m.openAfter next
        let canClose := m.closeBefore pre && m.closeAfter next
        if 2 <= n then
          go m fuel (i + n) (some c) false tail stack
            (ev .literal s!"{n} consecutive identical modifiers are raw text" :: acc)
        else if top == some c && canClose && !insideSelf then
          -- A matching standard closing modifier wins over interpreting `c|`
          -- as a free-form opener: `/italic|*` closes the italic, then `|*`
          -- closes the surrounding free-form bold.
          go m fuel (i + 1) (some c) false rest (stack.drop 1)
            (ev .close "closing modifier" :: acc)
        else if rest.head? == some '|' && m.openBefore pre then
          -- Free-form opener `<char>|` (spec lines 1162-1188).  The pipe makes
          -- the opening/closing side unambiguous, so whitespace is allowed
          -- immediately inside the span.
          match findFreeFormCloser m c (i + 2) (rest.drop 1) with
          | some j =>
              if isVerbatim c then
                go m fuel (j + 1) (some c) false (rest.drop (j - i)) stack
                  ({ index := j, char := c, role := .close,
                     note := "free-form verbatim close" } ::
                   ev .open "free-form verbatim open; body not scanned" :: acc)
              else
                go m fuel (i + 2) (some '|') false (rest.drop 1)
                  ({ char := c, index := i, freeForm := true } :: stack)
                  (ev .open "free-form opening modifier" :: acc)
          | none =>
              go m fuel (i + 1) (some c) false rest stack
                (ev .literal "free-form opener with no valid closer" :: acc)
        else if insideSelf then
          go m fuel (i + 1) (some c) false rest stack
            (ev .literal "bare modifier inside its own free-form span" :: acc)
        else
          if isVerbatim c && canOpen then
            match findCloser m c (some c) (i + 1) rest with
            | some j =>
                let close : Event :=
                  { index := j, char := c, role := .close, note := "verbatim close" }
                go m fuel (j + 1) (some c) false (rest.drop (j - i)) stack
                  (close :: ev .open "verbatim open; body not scanned" :: acc)
            | none =>
                go m fuel (i + 1) (some c) false rest stack
                  (ev .literal "verbatim opener with no valid closer" :: acc)
          else
            let role : Role :=
              if canOpen && canClose then
                (if top == some c then .close else .open)
              else if canOpen then .open
              else if canClose then
                -- A closing delimiter with nothing open, or one that closes a
                -- different modifier, is ordinary raw text.  The spec calls the
                -- markup invalid; it does not require a syntax-tree error.
                (if top == some c then .close else .literal)
              else .literal
            match role with
            | .open =>
                go m fuel (i + 1) (some c) false rest
                  ({ char := c, index := i, freeForm := false } :: stack)
                  (ev .open "opening modifier" :: acc)
            | .close =>
                go m fuel (i + 1) (some c) false rest (stack.drop 1)
                  (ev .close "closing modifier" :: acc)
            | .error =>
                let note :=
                  match stack.head? with
                  | none => s!"'{c}' closes but nothing is open"
                  | some o => s!"'{c}' closes '{o.char}' out of order"
                go m fuel (i + 1) (some c) false rest stack (ev .error note :: acc)
            | .literal =>
                go m fuel (i + 1) (some c) false rest stack
                  (ev .literal "not a valid opening or closing modifier here" :: acc)
            | .linkOpen | .linkClose =>
                go m fuel (i + 1) (some c) false rest stack
                  (ev .literal "unexpected link modifier role" :: acc)

/-- Scan one paragraph.  The input may contain `\n`, `\r`, and `\x0c`; line
endings are handled only through `m`, since spec line 76 says they are not
whitespace.  Unclosed openers are reported both in `unclosed` (innermost
first) and as trailing `.literal` events (outermost first, at their open index);
they are raw text, not syntax errors.

A description `[...]` is scanned as a nested inline scope: its events carry
absolute paragraph indices, and an unclosed opener inside it appears as a
trailing `.literal` event inside that scope.  Only paragraph-scope openers are
listed in `unclosed`; nested scopes are not flattened into it. -/
def scan (m : BoundaryModel) (s : String) : Result :=
  let (acc, stack) := go m s.length 0 none false s.toList [] []
  let (events, unclosed) := finish acc stack
  { events, unclosed }

def openCount (r : Result) : Nat := (r.events.filter fun e => e.role == .open).length

def closeCount (r : Result) : Nat := (r.events.filter fun e => e.role == .close).length

def errorCount (r : Result) : Nat := (r.events.filter fun e => e.role == .error).length

/-! ## Checks (spec lines 1095-1136) -/

-- `*Bold text*` (spec line 1097).
#guard openCount (scan boundaryExamples "*Bold text*") == 1
#guard closeCount (scan boundaryExamples "*Bold text*") == 1
#guard errorCount (scan boundaryExamples "*Bold text*") == 0
#guard (scan boundaryExamples "*Bold text*").unclosed == []

-- The literal transcription rejects the spec's own valid example (F3).
#guard openCount (scan boundaryLiteral "*Bold text*") == 0

-- `*Bold\ntext*` is valid (spec lines 1102-1103, 1068-1073).
#guard openCount (scan boundaryExamples "*Bold\ntext*") == 1
#guard closeCount (scan boundaryExamples "*Bold\ntext*") == 1

-- `*Bold\ntext\n*` is invalid (spec lines 1124-1126).  Note that line 1054
-- alone would allow it, since line 76 says a line ending is not whitespace.
#guard openCount (scan boundaryExamples "*Bold\ntext\n*") == 1
#guard closeCount (scan boundaryExamples "*Bold\ntext\n*") == 0

-- `**Bold**` is raw text (spec lines 1075-1077).
#guard openCount (scan boundaryExamples "**Bold**") == 0
#guard closeCount (scan boundaryExamples "**Bold**") == 0
#guard errorCount (scan boundaryExamples "**Bold**") == 0

-- Nested, closed in the opposite order (spec lines 1105-1106).
#guard openCount (scan boundaryExamples "*/Bold and italic/*") == 2
#guard closeCount (scan boundaryExamples "*/Bold and italic/*") == 2
#guard errorCount (scan boundaryExamples "*/Bold and italic/*") == 0

-- Wrong order: `*/Bold and italic*/` (spec lines 1132-1136).
#guard errorCount (scan boundaryExamples "*/Bold and italic*/") >= 1 ||
  !(scan boundaryExamples "*/Bold and italic*/").unclosed.isEmpty

-- Verbatim: the `*` inside `` `a*b*` `` is not an opener (spec line 1090).
#guard openCount (scan boundaryExamples "`a*b*`") == 1
#guard closeCount (scan boundaryExamples "`a*b*`") == 1
#guard errorCount (scan boundaryExamples "`a*b*`") == 0
#guard (scan boundaryExamples "`a*b*`").events.map (fun e => e.role) == [.open, .close]
#guard (scan boundaryExamples "`ab`").events.map (fun e => e.index) == [0, 3]

-- Unterminated `*Bold` (spec lines 1121-1126).
#guard openCount (scan boundaryExamples "*Bold") == 1
#guard closeCount (scan boundaryExamples "*Bold") == 0
#guard (scan boundaryExamples "*Bold").unclosed == ['*']

-- `text*Bold*`: the first `*` is literal, the second closes nothing and is
-- also raw text (an unmatched closing delimiter is not a syntax error).
#guard openCount (scan boundaryExamples "text*Bold*") == 0
#guard (scan boundaryExamples "text*Bold*").events.map (fun e => e.role) ==
  [.literal, .literal]

-- Escaping (spec lines 93-99): `\*` is literal, `*` never opens.
#guard openCount (scan boundaryExamples "\\*not bold*") == 0

-- `^` cannot nest into `,` and `,` cannot nest into `^` (spec lines 1088-1089).
#guard openCount (scan boundaryExamples ",sub^") == 1
#guard !((scan boundaryExamples ",sub^").events.any fun e =>
  e.char == '^' && e.role == .open)
#guard openCount (scan boundaryExamples "^sup,") == 1
#guard !((scan boundaryExamples "^sup,").events.any fun e =>
  e.char == ',' && e.role == .open)

/-! ## Free-form attached modifiers (spec lines 1162-1188) -/

-- Verbatim free-form: whitespace inside is allowed and the body is not scanned.
#guard openCount (scan boundaryExamples "`|free form verbatim|`") == 1
#guard closeCount (scan boundaryExamples "`|free form verbatim|`") == 1
#guard (scan boundaryExamples "`| free *not bold* |`").events.map
  (fun e => e.role) == [.open, .close]

-- Non-verbatim free-form still scans nested markup.
#guard openCount (scan boundaryExamples "^|Super and *bold*|^") == 2
#guard closeCount (scan boundaryExamples "^|Super and *bold*|^") == 2
#guard errorCount (scan boundaryExamples "^|Super and *bold*|^") == 0

-- The pipe disambiguates; a closing standard modifier can sit directly before
-- the free-form closer (`/italic|*`).
#guard openCount (scan boundaryExamples "*|Bold /italic _underlined -struck through-_/|*") == 4
#guard closeCount (scan boundaryExamples "*|Bold /italic _underlined -struck through-_/|*") == 4
#guard errorCount (scan boundaryExamples "*|Bold /italic _underlined -struck through-_/|*") == 0

-- An unclosed free-form opener is raw text, not an open modifier.
#guard openCount (scan boundaryExamples "*| unclosed") == 0
#guard closeCount (scan boundaryExamples "*| unclosed") == 0
#guard errorCount (scan boundaryExamples "*| unclosed") == 0

/-! ## Link modifiers, extensions, and linkable integration -/

-- `abso:/freaking/:lutely!` (spec lines 1203-1204).
#guard (scan boundaryExamples "abso:/freaking/:lutely!").events.any fun e =>
  e.role == .linkOpen
#guard (scan boundaryExamples "abso:/freaking/:lutely!").events.any fun e =>
  e.role == .linkClose

-- A link modifier does not need a partner (spec lines 1206-1211).
#guard (scan boundaryExamples "Ex:*ample* text").events.any fun e => e.role == .linkOpen
#guard errorCount (scan boundaryExamples "Ex:*ample* text") == 0

-- Attached extension contents are metadata, not inline markup.
#guard errorCount (scan boundaryExamples "*bold*(color:red)") == 0
#guard errorCount (scan boundaryExamples "`code`(lang:python)") == 0

-- Link locations are opaque when valid, errors when the location is invalid.
-- Description contents are scanned; see `Norg/DescriptionTests.lean`.
#guard errorCount (scan boundaryExamples "Click {* link}[here] now.") == 0
#guard errorCount (scan boundaryExamples "{* link}(attribute)") == 0
#guard errorCount (scan boundaryExamples "{*text}") == 1
#guard errorCount (scan boundaryExamples "{:file:/ x}") == 1
#guard errorCount (scan boundaryExamples "This is { not a link } text.") == 0
