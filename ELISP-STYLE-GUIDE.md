# Elisp Style and Architecture Guide

This guide governs the Emacs Lisp written across all Doom Emacs IDE configurations in this project. It is intended for use by the project author, collaborators, and AI coding assistants. Every rule is grounded in a specific source; sources are listed inline so they can be consulted directly when a decision is being made or revisited.

The guiding philosophy draws from the evolution of Common Lisp practice: **old Lisp culture rewarded cleverness; modern Lisp culture rewards clarity and explicit intent.** That shift is the through-line for every rule below.

> **Companion documents:**
> - `GNU-EMACS-GUIDE.md` — foundational Emacs concepts
> - `DOOM-EMACS-GUIDE.md` — Doom macros and module system
> - `ELISP-ARCHITECTURE-GUIDE.md` — high-level architectural patterns

---

## 1. File Header: Lexical Binding Is Mandatory

Every `.el` file must begin with this header:

```elisp
;;; -*- lexical-binding: t -*-
```

Without it, Emacs defaults to dynamic binding for the entire file. Lexical binding enables closures, makes variable scope textually predictable, and eliminates an entire class of spooky-action-at-a-distance bugs where a called function silently sees a different variable value based on the call stack.

Converting existing files: byte-compiling a file without lexical binding will surface free-variable warnings that identify bindings that need to be made explicit before the switch is safe.

> **Sources:**
> - [GNU Emacs Lisp Reference Manual — Lexical Binding](https://www.gnu.org/software/emacs/manual/html_node/elisp/Lexical-Binding.html)
> - [GNU Emacs Lisp Reference Manual — Converting to Lexical Binding](https://www.gnu.org/software/emacs/manual/html_node/elisp/Converting-to-Lexical-Binding.html)
> - [Lexical Binding Gotchas and Best Practices — Yoo Box](https://yoo2080.wordpress.com/2013/09/11/emacs-lisp-lexical-binding-gotchas-and-related-best-practices/)

---

## 2. Use `cl-lib`, Never `cl`

When CL idioms are needed, require `cl-lib`:

```elisp
(require 'cl-lib)
```

Never `(require 'cl)`. The old `cl` library dumps Common Lisp function names into the global namespace without prefixes, causing conflicts and shadowing. `cl-lib` namespaces everything under `cl-` (`cl-loop`, `cl-defstruct`, `cl-reduce`, `cl-destructuring-bind`, etc.). The old `cl` library is deprecated and will be removed in a future Emacs version.

> **Sources:**
> - [GNU Emacs Lisp Reference Manual — Coding Conventions](https://www.gnu.org/software/emacs/manual/html_node/elisp/Coding-Conventions.html): *"If you need Common Lisp extensions, use the cl-lib library rather than the old cl library, which does not use a clean namespace (its definitions do not start with a 'cl-' prefix)."*

---

## 3. Naming Conventions

### 3.1 General form: `lisp-case`

All symbols use hyphen-separated lowercase: `my-function-name`, `some-var`. Never `camelCase`, `PascalCase`, or `under_score`.

### 3.2 Namespace prefix: every top-level symbol gets one

Choose a short prefix for each file or logical module and apply it to every top-level `defun`, `defvar`, `defcustom`, `defconst`, and `defmacro`. This is the elisp substitute for a package system.

```elisp
;; Good
(defun mercury-ide/setup-flycheck () ...)
(defvar mercury-ide/mmc-path nil)

;; Bad — collides with anything else defining `setup`
(defun setup () ...)
```

### 3.3 Private symbols: double hyphen

Symbols not intended for use outside their file use a double hyphen to separate prefix from name:

```elisp
(defun mercury-ide--parse-error-line (line) ...)
```

Single hyphen is public API. Double hyphen is internal. This is a convention, not enforced by the runtime.

### 3.4 Predicate functions: `-p` suffix

Functions returning boolean use a `-p` suffix (one word: `activep`; multiple words: `buffer-live-p`). Do not use `-p` on boolean *variables* — use `-flag` or `is-foo` instead.

### 3.5 Dynamic (special) variables: `*earmuffs*`

Variables intended for dynamic binding get wrapped in asterisks:

```elisp
(defvar *mercury-ide-current-project* nil)
```

This convention signals "this variable may be dynamically rebound — treat it accordingly." It also prevents accidentally shadowing a dynamic variable with a lexical binding.

> **Sources:**
> - [GNU Emacs Lisp Reference Manual — Coding Conventions](https://www.gnu.org/software/emacs/manual/html_node/elisp/Coding-Conventions.html)
> - [bbatsov/emacs-lisp-style-guide](https://github.com/bbatsov/emacs-lisp-style-guide)
> - [GNU Emacs Lisp Reference Manual — Dynamic Binding Tips](https://www.gnu.org/software/emacs/manual/html_node/elisp/Dynamic-Binding-Tips.html)
> - [Emacs Lisp Naming Convention — Xah Lee](http://xahlee.info/emacs/misc/elisp_naming_convention.html)

---

## 4. Variable Discipline: `defvar` vs `defconst`

Elisp has two forms for declaring top-level variables. Understand the difference and use each intentionally:

| Form | Behavior on file reload | Use for |
|---|---|---|
| `defvar` | Only sets value if variable is currently **unbound** | User-customizable values; runtime state that should survive reload |
| `defconst` | Always resets the value; marks variable as constant (setq warns) | Values you own completely and want authoritative on reload |

`defconst` is elisp's closest equivalent to Common Lisp's `defparameter` — both always set the value on load. The key difference: `defconst` additionally signals to readers and tools that the variable should not be modified at runtime. If a value truly needs to be reset on reload but is also modified at runtime, use `defvar` and document the reload behavior explicitly.

`cl-lib` does **not** provide a `cl-defparameter` — that is a CL construct with no direct cl-lib equivalent. The idiomatic elisp tools are `defvar` and `defconst`.

The old mistake was using `defvar` and `defconst` interchangeably, or using `defconst` for a user-configured value that gets clobbered silently on file reload.

> **Sources:**
> - [The Common Lisp Cookbook — Variables](https://lispcookbook.github.io/cl-cookbook/variables.html)
> - [Lisp Tutorial: Variables — Lisp Journey](https://lisp-journey.gitlab.io/blog/lisp-tutorial-variables/)
> - [GNU Emacs Lisp Reference Manual — Defining Variables](https://www.gnu.org/software/emacs/manual/html_node/elisp/Defining-Variables.html)

---

## 5. Dynamic Variables: Use Sparingly and Intentionally

Dynamic variables (`defvar` with `*earmuffs*`) are appropriate for *intentional* environmental configuration that you want to flow implicitly through a call stack — think logging level, current project context, active buffer. Rebind them locally with `let`, never mutate them with `setq` in production code paths.

```elisp
;; Good: temporary rebinding for a scope
(let ((*mercury-ide-current-project* my-project))
  (mercury-ide--compile))

;; Bad: global mutation
(setq *mercury-ide-current-project* my-project)
(mercury-ide--compile)
(setq *mercury-ide-current-project* nil)  ; easy to forget, not reset on error
```

Prefer lexical closures over dynamic variables for state that does not need to cross call-stack boundaries. If the state doesn't need to be visible to called functions that aren't in your lexical scope, it shouldn't be dynamic.

> **Sources:**
> - [GNU Emacs Lisp Reference Manual — Dynamic Binding Tips](https://www.gnu.org/software/emacs/manual/html_node/elisp/Dynamic-Binding-Tips.html)
> - [Advanced Troubleshooting in Common Lisp: Performance, State, and Macro Pitfalls — Mindful Chase](https://www.mindfulchase.com/explore/troubleshooting-tips/programming-languages/advanced-troubleshooting-in-common-lisp-performance,-state,-and-macro-pitfalls.html)
> - [Aartaka — Lisp Design Patterns](https://aartaka.me/lisp-design-patterns.html): *"The main use for dynamic variables is not setting them directly, but rather binding them lexically with `let`."*

---

## 6. Macros: Functions First

Write a macro only when you need new syntax or new control flow that a function cannot provide. If a function will do, write a function.

The test: **does the macro need to suppress or transform the evaluation of its arguments?** If not — if it would work identically as a function — it should be a function.

The old mistake was reaching for macros because Lisp makes them easy to write. The burns: code that is hard to read without `macroexpand`, debugging tools that can't step into macro-generated code, variable capture bugs, and combinatorial code explosion when macros nest.

When you do write a macro:
- Use `gensym` for every symbol the macro introduces into the expansion that should not be visible to the caller. Without this, the macro captures variables from the call site.
- Evaluate arguments exactly once unless the macro's purpose is specifically to control evaluation.
- Test the expansion with `macroexpand-1` before considering it done.

```elisp
;; Variable capture bug — don't do this
(defmacro mercury-ide/with-project (proj &rest body)
  `(let ((proj ,proj))       ; 'proj' captures any 'proj' in caller's scope
     ,@body))

;; Correct — gensym prevents capture
(defmacro mercury-ide/with-project (proj &rest body)
  (let ((proj-sym (gensym "proj")))
    `(let ((,proj-sym ,proj))
       ,@body)))
```

> **Sources:**
> - [The Proper Use of Macros in Lisp — TFEB.ORG](https://www.tfeb.org/fragments/2021/11/11/the-proper-use-of-macros-in-lisp/): *"Macros are useful where you want a new language: not just the same language with extra functions in it... If you are writing functions whose range is something which is not the syntax of a language built on Common Lisp, don't write macros."*
> - [When to Use Macros — On Lisp (UMBC)](https://courses.cs.umbc.edu/331/resources/lisp/onLisp/08whenToUseMacros.pdf)
> - [Other Macro Pitfalls — On Lisp (UMBC)](https://courses.cs.umbc.edu/331/resources/lisp/onLisp/10otherMacroPitfalls.pdf)
> - [Lisp Macro Pitfalls — GitHub Gist (nimaai)](https://gist.github.com/nimaai/2f98cc421c9a51930e16)

---

## 7. Data: `cl-defstruct` First, EIEIO When Justified

Start with `cl-defstruct` for data aggregates. It produces fast, typed, printable structures with generated accessors. Reach for EIEIO (`defclass`) only when you specifically need:
- Multiple inheritance
- Generic dispatch via `defgeneric`/`defmethod`
- Runtime class redefinition (useful during interactive development)

The old mistake was using the OOP system for everything because it was available. Structs are faster and simpler for plain data. CLOS-style dispatch adds overhead that matters on hot paths.

```elisp
;; Good for plain data
(cl-defstruct mercury-ide/project
  name root-dir grade build-flags)

;; Reach for EIEIO when you need dispatch
(defclass mercury-ide/backend ()
  ((name :initarg :name :reader mercury-ide/backend-name)))

(defgeneric mercury-ide/compile (backend project)
  "Compile PROJECT using BACKEND.")
```

> **Sources:**
> - [Abstract Heresies — defclass vs defstruct](http://funcall.blogspot.com/2025/03/defclass-vs-defstruct.html): *"Unless you have a compelling reason to use defstruct, just use defclass"* — note this is the opposite recommendation for interactive CL development; for elisp, prefer `cl-defstruct` first because EIEIO's redefinition story is less critical in a config context.
> - [Do You Start with a Struct or a Class? — Lisper.in](https://lisper.in/do-you-start-with-a-struct-or-a-class)
> - [The Common Lisp Cookbook — Fundamentals of CLOS](https://lispcookbook.github.io/cl-cookbook/clos.html)

---

## 8. Protocol Design: Define the Interface Before the Implementation

When using EIEIO or generic dispatch, declare the `defgeneric` first as a standalone form with only the signature and docstring — no methods. This declares the protocol. Implementations follow separately.

```elisp
;; Protocol declaration — what this thing is supposed to do
(defgeneric mercury-ide/compile (backend project)
  "Compile PROJECT using BACKEND. Returns a process object or signals an error.")

(defgeneric mercury-ide/check-syntax (backend buffer)
  "Run syntax checking on BUFFER using BACKEND.")

;; Implementation — how it currently does it
(cl-defmethod mercury-ide/compile ((backend mercury-ide/mmc-backend) project)
  ...)
```

This pattern makes extension points visible and explicit. A reader sees the full protocol in one place before any implementation details.

> **Sources:**
> - [Aartaka — Lisp Design Patterns](https://aartaka.me/lisp-design-patterns.html): *"Common Lisp protocols usually come in the form of defgeneric declarations — one defines a generic function but they don't define any implementation, and down the line, they write code conforming to the contract this generic function established."*

---

## 9. Functional Style: Minimize Side Effects

Prefer functions that take inputs and return values over functions that work by mutating shared state. Side-effecting functions should be clearly named and isolated at the boundary of the system (hooks, commands, process callbacks), not buried in the middle of logic.

```elisp
;; Good — pure transformation, easy to test
(defun mercury-ide--parse-grade-string (grade-str)
  "Return a plist of grade components from GRADE-STR."
  ...)

;; Side-effecting boundary function — clearly named, isolated
(defun mercury-ide/apply-grade-to-buffer (grade-str)
  "Set buffer-local compilation grade from GRADE-STR."
  (setq-local mercury-ide/current-grade
              (mercury-ide--parse-grade-string grade-str)))
```

> **Sources:**
> - [EmacsWiki — Coding Style](https://www.emacswiki.org/emacs/CodingStyle): *"As many functions as possible should be written in a functional style, meaning they should not work by side effect... instead returning interesting values."*
> - [Google Common Lisp Style Guide](https://google.github.io/styleguide/lispguide.xml)

---

## 10. Error Handling: Know What Elisp Cannot Do

Elisp's `condition-case` exits the protected form entirely before the handler runs. **There is no resumption.** This is a fundamental difference from Common Lisp's condition and restart system, where a handler can invoke a restart without unwinding the stack.

Do not design elisp error handling expecting CL restart semantics — they are not available. The practical consequence: design for explicit return values at boundaries where recovery options need to be communicated upward.

```elisp
;; Pattern: tagged return for recoverable conditions
(defun mercury-ide--invoke-mmc (args)
  "Run mmc with ARGS. Returns (:ok output) or (:error code output)."
  (condition-case err
      (list :ok (mercury-ide--run-process args))
    (error (list :error (error-message-string err)))))

;; Caller pattern-matches on the tag
(cl-destructuring-bind (status &rest data)
    (mercury-ide--invoke-mmc my-args)
  (pcase status
    (:ok   (mercury-ide--handle-success (car data)))
    (:error (mercury-ide--handle-failure (car data)))))
```

> **Sources:**
> - [GNU Emacs Lisp Reference Manual — Handling Errors](https://www.gnu.org/software/emacs/manual/html_node/elisp/Handling-Errors.html): *"because the protected form is exited completely before execution of the handler, the handler cannot resume execution at the point of the error."*
> - [The Common Lisp Cookbook — Error and Exception Handling](https://lispcookbook.github.io/cl-cookbook/error_handling.html)
> - [Practical Common Lisp — Beyond Exception Handling: Conditions and Restarts](https://gigamonkeys.com/book/beyond-exception-handling-conditions-and-restarts)

---

## 11. Doom-Specific Conventions

### 11.1 Use `with-eval-after-load`, never `eval-after-load`

```elisp
;; Good
(with-eval-after-load 'mercury-mode
  (mercury-ide/setup-flycheck))

;; Bad — old form, less readable
(eval-after-load 'mercury-mode
  '(mercury-ide/setup-flycheck))
```

### 11.2 Use `after!` in Doom `config.el`

Inside Doom's `config.el`, prefer Doom's own `after!` macro over `with-eval-after-load` — it is Doom's idiomatic wrapper for the same concept and integrates with Doom's module loading.

### 11.3 Use `map!` for keybindings in Doom config

Doom's `map!` is the standard keybinding macro. Prefer it over direct `define-key` or `evil-define-key` calls in config files. Reserve `define-key` for module-level code where Doom's macros may not be loaded.

### 11.4 Code annotations

Use these standard markers in comments:

| Marker | Meaning |
|---|---|
| `TODO` | Missing feature or planned work |
| `FIXME` | Broken code |
| `OPTIMIZE` | Known inefficiency |
| `HACK` | Code smell — works but needs a better solution |
| `REVIEW` | Needs verification or second opinion |

> **Sources:**
> - [bbatsov/emacs-lisp-style-guide](https://github.com/bbatsov/emacs-lisp-style-guide): `with-eval-after-load`, annotation conventions
> - [Doom Emacs Discourse — Style](https://discourse.doomemacs.org/t/style/3723): Doom-specific macro conventions

---

## 12. Formatting and Indentation

- Two-space indentation for body forms. Four-space indentation for special arguments on a new line.
- No hard tabs — spaces only.
- Vertically align function arguments when they span multiple lines.
- One blank line between top-level forms.
- Two blank lines between major sections of a file.
- Keep lines under 100 characters.

Emacs with `aggressive-indent-mode` or standard `prog-mode` indentation will handle most of this automatically if you let it.

> **Sources:**
> - [bbatsov/emacs-lisp-style-guide](https://github.com/bbatsov/emacs-lisp-style-guide)
> - [Google Common Lisp Style Guide](https://google.github.io/styleguide/lispguide.xml)

---

## 13. Idiom Quick Reference

Prefer the right-column form:

| Avoid | Prefer | Why |
|---|---|---|
| `(+ x 1)` | `(1+ x)` | Idiomatic elisp |
| `(- x 1)` | `(1- x)` | Idiomatic elisp |
| `:else` in `cond` | `t` in `cond` | Standard catch-all |
| `(require 'cl)` | `(require 'cl-lib)` | cl is deprecated |
| `eval-after-load` | `with-eval-after-load` | Modern form |
| `defun` + manual dispatch | `cl-defstruct` accessors | Structured data |
| `setq` on dynamic vars in logic | `let` rebinding | Predictable scope |

> **Sources:**
> - [bbatsov/emacs-lisp-style-guide](https://github.com/bbatsov/emacs-lisp-style-guide)
> - [GNU Emacs Lisp Reference Manual — Coding Conventions](https://www.gnu.org/software/emacs/manual/html_node/elisp/Coding-Conventions.html)

---

## Master Reference List

All sources cited in this guide, for direct re-access:

### Elisp-specific
- [GNU Emacs Lisp Reference Manual — Coding Conventions](https://www.gnu.org/software/emacs/manual/html_node/elisp/Coding-Conventions.html)
- [GNU Emacs Lisp Reference Manual — Defining Variables](https://www.gnu.org/software/emacs/manual/html_node/elisp/Defining-Variables.html)
- [GNU Emacs Lisp Reference Manual — Lexical Binding](https://www.gnu.org/software/emacs/manual/html_node/elisp/Lexical-Binding.html)
- [GNU Emacs Lisp Reference Manual — Converting to Lexical Binding](https://www.gnu.org/software/emacs/manual/html_node/elisp/Converting-to-Lexical-Binding.html)
- [GNU Emacs Lisp Reference Manual — Dynamic Binding Tips](https://www.gnu.org/software/emacs/manual/html_node/elisp/Dynamic-Binding-Tips.html)
- [GNU Emacs Lisp Reference Manual — Handling Errors](https://www.gnu.org/software/emacs/manual/html_node/elisp/Handling-Errors.html)
- [bbatsov/emacs-lisp-style-guide](https://github.com/bbatsov/emacs-lisp-style-guide)
- [EmacsWiki — Coding Style](https://www.emacswiki.org/emacs/CodingStyle)
- [Emacs Lisp Naming Convention — Xah Lee](http://xahlee.info/emacs/misc/elisp_naming_convention.html)
- [Lexical Binding Gotchas and Best Practices — Yoo Box](https://yoo2080.wordpress.com/2013/09/11/emacs-lisp-lexical-binding-gotchas-and-related-best-practices/)
- [Doom Emacs Discourse — Style](https://discourse.doomemacs.org/t/style/3723)

### Common Lisp (patterns that apply to elisp)
- [Google Common Lisp Style Guide](https://google.github.io/styleguide/lispguide.xml)
- [lisp-lang.org — Common Lisp Style Guide](https://lisp-lang.org/style-guide/)
- [The Common Lisp Cookbook — Variables](https://lispcookbook.github.io/cl-cookbook/variables.html)
- [The Common Lisp Cookbook — Packages](https://lispcookbook.github.io/cl-cookbook/packages.html)
- [The Common Lisp Cookbook — Fundamentals of CLOS](https://lispcookbook.github.io/cl-cookbook/clos.html)
- [The Common Lisp Cookbook — Error and Exception Handling](https://lispcookbook.github.io/cl-cookbook/error_handling.html)
- [The Common Lisp Cookbook — Macros](https://lispcookbook.github.io/cl-cookbook/macros.html)
- [Practical Common Lisp — Beyond Exception Handling: Conditions and Restarts](https://gigamonkeys.com/book/beyond-exception-handling-conditions-and-restarts)
- [Aartaka — Lisp Design Patterns](https://aartaka.me/lisp-design-patterns.html)
- [Abstract Heresies — defclass vs defstruct](http://funcall.blogspot.com/2025/03/defclass-vs-defstruct.html)
- [Do You Start with a Struct or a Class? — Lisper.in](https://lisper.in/do-you-start-with-a-struct-or-a-class)
- [The Proper Use of Macros in Lisp — TFEB.ORG](https://www.tfeb.org/fragments/2021/11/11/the-proper-use-of-macros-in-lisp/)
- [When to Use Macros — On Lisp (UMBC)](https://courses.cs.umbc.edu/331/resources/lisp/onLisp/08whenToUseMacros.pdf)
- [Other Macro Pitfalls — On Lisp (UMBC)](https://courses.cs.umbc.edu/331/resources/lisp/onLisp/10otherMacroPitfalls.pdf)
- [Lisp Macro Pitfalls — GitHub Gist (nimaai)](https://gist.github.com/nimaai/2f98cc421c9a51930e16)
- [Lisp Tutorial: Variables — Lisp Journey](https://lisp-journey.gitlab.io/blog/lisp-tutorial-variables/)
- [Advanced Troubleshooting in CL: Performance, State, Macro Pitfalls — Mindful Chase](https://www.mindfulchase.com/explore/troubleshooting-tips/programming-languages/advanced-troubleshooting-in-common-lisp-performance,-state,-and-macro-pitfalls.html)
