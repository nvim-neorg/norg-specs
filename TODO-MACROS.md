# TODO: Macros

Working checklist for the Norg v2 macro system and the macro-related parts of
`2.0-specification.md`.

Sources:

- ["Norg Macros"](https://vhyrro.neorg.org/posts/neorg-macros) (2024-04-24)
- current `2.0-specification.md` definitions and layers
- the Definitions review

The blog is theoretical and predates the v2 draft. Treat it as a source of
requirements and open questions, not as normative text.

## 0. Design decisions

- [x] Quasiquote is a first-class content model, not just raw text with `\`
      escapes.
- [x] `:name ... :end` supports full quasiquote.
- [x] `<>` delimits an embedded Norg sub-document inside quasiquote.
- [x] Content models, parameter filters, Janet boundary values, and macro
      results share one unified type system.
- [x] The type system is intrinsic to the macro system: it describes macro
      signatures, content models, invocation sites, and expansion results. It is
      not an external validator or a runtime tag scheme.

## 1. Macro system

### 1.0 Unified macro type system

One type vocabulary must cover content models, parameter filters, Janet
boundary values, and macro results. Do not define separate unrelated type
systems for "quasiquote", "raw", "markup", parameter prefixes, and Janet
values.

- [ ] Define the type universe: `Markup`, `Raw`, `Verbatim`,
      `Quasiquote`/`Template`, `MacroName`, and `AbstractObject`.
- [ ] Define content models as constructors of that universe: markup is parsed
      Norg; raw is opaque text; quasiquote is a template of raw text plus
      embedded Norg sub-documents; verbatim is raw text with tag metadata.
- [ ] Define invocation forms in terms of the type they produce or consume:
      `|` consumes markup, `@` consumes raw/verbatim, `:` consumes quasiquote,
      `&` requires a macro name, and `#` supplies a carryover argument.
- [ ] Define parameter descriptors as `prefix? base-type quantifier?`, where
      the prefix is one of `#`, `@`, `|`, `&`, the base type is a content type,
      and the quantifier is one of `?`, `*`, `+`.
- [ ] Define the matching relation between an argument value and a parameter
      descriptor, including any subtyping or coercion rules.
- [ ] Define macro signatures as parameter lists plus a result type.
- [ ] Bind the type system to macro definitions: every macro signature declares
      its parameter types/filters and result type, and invocation and expansion
      are checked against that signature.
- [ ] Define the typing judgment for an invocation and for a macro body.
- [ ] Define the quasiquote typing rule: `:name ... :end` produces a
      `Template`; `<>` introduces a `Markup` hole; `\` introduces a character
      scalar.
- [ ] Define the Janet boundary as a translation from the type universe to
      Janet values, not as a separate ad-hoc convention.
- [ ] Define errors for unknown types, ill-typed arguments, arity mismatch,
      quantifier mismatch, and unresolved macro names.
- [ ] Formalize the type system in Lean 4 at `proofs/Norg/MacroTypes.lean`.
- [ ] Write the human-readable type-system document in Typst at
      `MACRO-TYPES.typ`, covering grammar, judgments, examples, and errors.

### 1.1 Core semantics

- [ ] Define a macro as a named definition that can be invoked to produce
      content. Do not use "advanced substitution" as the whole definition:
      abstract objects and unbakeable macros are not substitutions.
- [ ] Define `macro definition`, `macro invocation`, and `macro expansion`
      separately. Invocation is syntax; expansion is the process.
- [ ] Define what a macro body is: a sequence of lines, arbitrary content, or
      content selected by the invocation's content model.
- [ ] Define expansion order. The blog says bottom-up: parameters become
      bindings, then macros expand.
- [ ] Define name lookup, scope, shadowing, and hygiene.
- [ ] Define baking and previewing. Macro expansion is user-triggered, never
      automatic.
- [ ] Distinguish user-triggered macro expansion from automatic layer
      desugaring. Layers 1–10 lower surface syntax as part of parsing; that is
      not the same operation as baking a macro.
- [ ] Define bakeability. A macro returning an abstract object is not bakeable.
- [ ] Define errors: unknown macro, bad argument type, bad arity, unmatched
      quantifier, invalid abstract object, unbakeable invocation.
- [ ] Decide whether macros run on the surface AST or the core Layer 0 AST.
- [ ] Reconcile blog syntax with v2 syntax: `=`, `@`, `|`, `:`, `&`, `.`, `#`.
- [ ] Decide whether Janet, abstract objects, and the macro standard library are
      normative parts of v2 or optional/appendix material.

### 1.2 Invocation forms

- [ ] `=name ... =end` — macro definition.
- [ ] `@name ... @end` — verbatim ranged invocation; raw content.
- [ ] `|name ... |end` — standard ranged invocation; Norg markup content.
- [ ] `:name ... :end` — full quasiquote; raw text with `\` character escapes
      and `<>` embedded Norg sub-documents.
- [ ] `&name&` — inline invocation; parameterless only; newlines become spaces.
- [ ] `.name` — infirm invocation; arguments supplied.
- [ ] `#name` — carryover invocation; next object becomes the last argument.
- [ ] Decide which forms survive into v2 and how they map to Layer 1.
- [ ] Document the content model accepted by each form.
- [ ] Document terminators, nesting, and precedence for every form.

### 1.3 Janet inputs and content models

- [ ] Raw verbatim (`@code ... @end`): pass a verbatim node, not a bare string.
      Preserve tag name, language, source span, and raw text. Example:
      `{:kind :verbatim :name "code" :language "lua" :text "..." :span [...]}`.
- [ ] Markup (`|span ... |end`): pass a canonical AST fragment/subtree, not a
      string. A string loses attributes, source spans, and nested invocations.
- [ ] Quasiquote (`:name ... :end`): pass a `Template` value, not a bare
      string. It contains raw text segments and embedded Norg sub-documents,
      not a single flattened string.
- [ ] Define `<>` as an embedded Norg sub-document inside quasiquote. Specify
      what may appear inside, nesting, literal `<`/`>` escaping, interaction
      with `:end`, and whether `<>` is also legal in markup or raw contexts.
- [ ] Decide whether embedded `<>` sub-documents are parsed and expanded
      eagerly when the quasiquote is formed, or lazily when the macro uses
      them.
- [ ] Decide whether the macro receives each embedded sub-document as a
      `Markup` node, a `Template` hole, or a thunk; define how it inserts it.
- [ ] Decide whether `@` macros receive a raw string, a verbatim node, or both.
- [ ] Define convenience accessors such as `(neorg/ast/node-text node)`.

### 1.4 Parameter types, filters, and quantifiers

- [ ] Write the formal grammar for parameter lists.
- [ ] Define type prefixes:
      `#` carryover only, `@` verbatim ranged only, `|` standard ranged only,
      `&` macro names only.
- [ ] Define quantifiers: `?` zero or one, `*` zero or more, `+` one or more.
- [ ] Enforce that there is only one quantifier in a parameter list.
- [ ] Define greedy `&*`: with no supplied arguments it captures all macros in
      the current scope.
- [ ] Define that `&` arguments must name existing macros.
- [ ] Define behavior when a quantifier captures zero arguments.
- [ ] Write up the concrete filter examples `&opt`, `@opt`, `opt?`, `opt+`,
      `opt*`, and any mixed prefix+quantifier forms.
- [ ] Define the matching relation between argument shape and parameter type.
- [ ] Define the error for every type/quantifier mismatch.
- [ ] Add conformance test vectors for matching, greedy capture, and errors.

### 1.5 Janet bridge

- [ ] Define `.invoke-janet`: only an infirm tag; inputs are Janet code.
- [ ] Define the return contract. Accept both strings and abstract objects;
      resolve the blog's string-only contradiction.
- [ ] Define `(neorg/execute)` signature and arity. Resolve the contradiction
      between captured macros as the first argument and a language name as the
      first argument; split into two functions if necessary.
- [ ] Specify the Janet sandbox: no filesystem, FFI, subprocesses, environment
      variables, or inbound network.
- [ ] Specify application-provided glue: `(neorg/from-object)`,
      `(neorg/to-object)`, AST accessors/predicates, abstract-object support,
      and schema handling.
- [ ] Clarify which parts of the Janet stdlib Norg specifies and which each
      Neorg-like application implements.
- [ ] Expand the "fully support macros" checklist to include the glue functions,
      standard-library macros, and abstract objects.

### 1.6 Canonical AST normalization

- [ ] Define a versioned canonical Norg AST schema in the specification.
- [ ] Use a minimal node algebra: `kind`, optional `name`, `attrs`, `children`,
      `text`, `span`.
- [ ] Standardize only exposed node kinds: document, fragment, block, inline,
      span, text, char, whitespace, macro invocation, verbatim tag, abstract
      object, unknown/opaque node.
- [ ] Make accessors/constructors the public contract, not raw table layout:
      `(neorg/ast/node? x)`, `(neorg/ast/node-kind x)`,
      `(neorg/ast/node-children x)`, `(neorg/ast/node-text x)`,
      `(neorg/ast/with-children x children)`.
- [ ] Provide one canonical serialization for conformance tests.
- [ ] Preserve unknown nodes as
      `{:kind :unknown :name ... :attrs ... :children ... :text ...}`.
- [ ] Decide explicitly whether macros see the surface AST or the core AST.
- [ ] Use immutable plain data, not host objects or live parser nodes.
- [ ] Treat normalization as a boundary contract: applications keep their own
      AST and convert at the macro boundary.

### 1.7 Abstract objects

- [ ] Define the abstract-object data model: required translation schema(s) and
      optional custom data.
- [ ] Decide whether `:schema` is singular or a list.
- [ ] Define unknown-schema behavior: error, ignore, or pass through.
- [ ] Define export/rendering behavior for known schemas.
- [ ] Define that an abstract-object result is unbakeable and that baking errors.
- [ ] Define conformance requirements for applications that support AOs.

### 1.8 Blog inconsistencies to resolve

- [ ] `.invoke-janet` accepts only strings vs also accepts abstract objects.
- [ ] `(neorg/execute)` takes captured macros vs takes a language name.
- [ ] "Macro is a substitution" vs abstract objects and unbakeable macros.
- [ ] The "fully support macros" checklist omits app-provided glue and stdlib.
- [ ] Norg bundles the stdlib vs the Janet stdlib is only partially implemented.
- [ ] Abstract objects are "opaque" vs applications read their schemas.
- [ ] Expansion examples sound automatic vs the rule that expansion is manual.
- [ ] Clarify that Janet `;` is splice syntax, not a comment.
- [ ] Document the `&...&` newline normalization and its AST hash check.

### 1.9 Conformance

- [ ] Correct macro expansion.
- [ ] Correct type-prefix checking and quantifier matching.
- [ ] Bundled Janet runtime.
- [ ] `.invoke-janet` support.
- [ ] `(neorg/execute)` support.
- [ ] Application-provided AST/object glue.
- [ ] Abstract-object and schema support.
- [ ] Standard-library macro support.
- [ ] Deterministic canonical serialization for test vectors.

## 2. Definitions checklist for `2.0-specification.md`

### 2.1 Must fix

- [ ] `Macro Expansion` is unfinished: it currently ends with "substituting a
      Macro Invocation with". Suggested: "Macro expansion is the act of
      replacing a macro invocation with the result of expanding its body in the
      invocation environment."
- [ ] `Content Model` is wrong. Markup is parsed as Norg. Raw text is passed
      through unchanged. Quasiquote is raw text in which `\` introduces escapes
      to character scalars; it is not parsed as Norg markup.
- [ ] `Shadowing` still says "temporarily overwrites" and "old binding is
      restored". A binding is hidden in an inner scope; the outer binding
      remains visible outside that scope.
- [ ] `Hygiene` has an unclear antecedent. Names introduced by a macro body do
      not capture or conflict with names at the invocation site. Norg is
      unhygienic because a macro body may resolve names from the environment in
      which the macro is invoked.
- [ ] `Layer` must state that Layers 1 through 10 add surface syntax by
      desugaring into lower layers.
- [ ] `Conventions` should use plain `Layer N`, not `Layer $N$`, which reads as
      Norg math syntax. State that Layer N includes Layer 0 and all layers
      through N.
- [ ] `Macro` is too thin: "a construct with one property: a name." Suggested:
      "A macro is a named definition that can be invoked to produce content."
- [ ] `Macro Definition` currently says the body is a sequence of lines. Decide
      whether that is true for all content models and for verbatim/quasiquote
      bodies.
- [ ] `Macro Invocation` uses lowercase "must supply" in what reads like a
      requirement. Capitalize it with an explicit subject, or rewrite it
      declaratively.
- [ ] `Parameter and Argument` should either define type prefixes and
      quantifiers or link to the formal macro type system.
- [ ] `Context` is missing, but Layers 8 and 9 use "inline context" and "span
      context". Re-add a short definition or define them at first use.
- [ ] `Syntax` and `Surface Syntax` are missing, but `Layer` refers to surface
      syntax. Re-add one or both.
- [ ] `Paragraph` is still purely lexical, so heading and list-item lines
      satisfy it. Add block-level precedence or state that `Paragraph` is only
      a lexical grouping.
- [ ] `Document` refers to "the grammar defined in this specification", but no
      grammar is defined yet. Replace with well-formedness rules or define
      well-formed vs valid.

### 2.2 Terms to add or decide

- [ ] `Context`: block context, inline context, span context.
- [ ] `Abstract Syntax Tree` or `Node`, if Layer 0 and the Janet bridge rely on
      the term.
- [ ] `Type Prefix`, `Quantifier`, and `Parameter Type`, if the type system lands
      in Definitions rather than a separate section.
- [ ] `Baking` and `Previewing`, if the macro model keeps these operations.
- [ ] `Abstract Object` and `Translation Schema`, if AOs are normative v2.
- [ ] `Well-Formed` and `Valid`, if conformance distinguishes syntax from
      semantic validity.
- [ ] `Conforming Implementation`, if the Conformance section is added.

### 2.3 Cross-reference and consistency

- [ ] Make `Attribute` and `Parameter` distinct: an attribute is a binding;
      a parameter is a named input that becomes a binding.
- [ ] Align `Environment`, `Scope`, and `Shadowing` with one visibility model.
- [ ] Link `Macro Invocation` to `Macro Expansion` with a stable anchor.
- [ ] Link `Content Model` to the invocation forms in the Syntax Reference.
- [ ] Link `Layer` to the layer sections and to `Surface Syntax`.
- [ ] Link `Context` to the layers that use block, inline, and span contexts.
- [ ] Check that every normative reference is cited from the definitions that
      rely on it.
- [ ] Keep definitions declarative; put `MUST`/`SHOULD`/`MAY` requirements in
      the layer or conformance sections with an explicit subject.
