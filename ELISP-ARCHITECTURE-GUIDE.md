# Elisp Architectural Design Guide

This guide covers high-level architectural patterns for Emacs Lisp code, grounded in the evolution of Common Lisp design practice. Each pattern is paired with its closest analogue in typed functional languages (Haskell, Scala) and object-oriented systems, so the conceptual bridge is explicit. Sources are cited inline and collected at the end.

The guiding question throughout: **how do you write elisp that stays decoupled, navigable, and changeable as it grows?** Emacs makes this harder than CL because there is no package system, no compiler-enforced module boundary, and the global namespace is shared with everything Emacs loads. These patterns address that.

> **Companion documents:**
> - `GNU-EMACS-GUIDE.md` — foundational Emacs concepts (buffers, modes, hooks, processes)
> - `DOOM-EMACS-GUIDE.md` — Doom macros and module system
> - `ELISP-STYLE-GUIDE.md` — low-level naming, formatting, and idiom conventions

---

## Pattern 1: Protocol-First Design (Tagless Final / Cake Pattern analogue)

### The idea

Define the *interface* — the set of operations that make up a capability — as a group of `defgeneric` declarations with no methods. Write all consuming code against those generic functions. Supply implementations later as `defmethod` specializations on concrete types.

This is the CL equivalent of two related patterns from typed languages:

- **Tagless final (Haskell/Scala):** define your DSL as typeclass methods; write programs in terms of those methods; provide different "interpreters" as typeclass instances. The program is abstract; the interpreter is concrete.
- **Cake pattern (Scala):** define capabilities as traits/interfaces; compose them via self-type annotations; implementations are plugged in at the top of the composition tree.

In CL you get this without the type system ceremony because `defgeneric` dispatch is dynamic. The tradeoff is that violations are runtime errors, not compile-time failures.

### Structure

```elisp
;;; -*- lexical-binding: t -*-

;; 1. Declare the protocol — the abstract algebra.
;;    No methods here. This is the interface.

(defgeneric mercury-ide/compile-buffer (backend buffer)
  "Compile BUFFER using BACKEND. Return a process object or signal an error.")

(defgeneric mercury-ide/check-syntax (backend buffer)
  "Run syntax checking on BUFFER using BACKEND. Return a list of diagnostics.")

(defgeneric mercury-ide/backend-name (backend)
  "Return a human-readable name string for BACKEND.")

;; 2. Define the concrete backend type
(cl-defstruct mercury-ide/mmc-backend
  executable grade flags)

;; 3. Implement the protocol for that type
(cl-defmethod mercury-ide/compile-buffer ((backend mercury-ide/mmc-backend) buffer)
  (mercury-ide--run-mmc
   (mercury-ide/mmc-backend-executable backend)
   (mercury-ide/mmc-backend-grade backend)
   buffer))

;; 4. Consuming code is written entirely against the protocol —
;;    it never mentions a concrete type
(defun mercury-ide/build-project (backend)
  (dolist (buf (mercury-ide--project-buffers))
    (mercury-ide/compile-buffer backend buf)))
```

The consuming function `mercury-ide/build-project` is completely decoupled from `mmc`. Swapping in a different backend (say, a mock for testing, or a future `meson` backend) requires no changes to consuming code.

### `cl-defmethod` vs EIEIO's legacy `defmethod`

Use `cl-defgeneric` and `cl-defmethod` (from `cl-generic`, part of Emacs core since 25.1) for all new generic dispatch code. Modern EIEIO is built *on top of* `cl-generic` — when you call `defclass`, EIEIO registers the class with the cl-generic dispatch system. The old EIEIO-specific `defgeneric`/`defmethod` forms are retained for backward compatibility but `cl-defgeneric`/`cl-defmethod` are the right modern forms.

`cl-generic` advantages over legacy EIEIO dispatch:
- **Multiple dispatch**: specialize on more than one argument simultaneously
- **`:around` methods**: legacy EIEIO only supports `:before` and `:after`
- **Richer specializers**: `(eql VALUE)` specializers, type-based specializers, not just classes

### The multimethod advantage

Unlike single-dispatch OO systems, `cl-defmethod` can dispatch on multiple arguments simultaneously. This lets you express behaviour that genuinely belongs to the *relationship* between two types, not to either type alone:

```elisp
(defgeneric mercury-ide/format-diagnostic (backend diagnostic-type data)
  "Format DATA as a diagnostic string for BACKEND and DIAGNOSTIC-TYPE.")

(cl-defmethod mercury-ide/format-diagnostic
    ((backend mercury-ide/mmc-backend)
     (type (eql :error))
     data)
  ...)
```

This eliminates the ad-hoc dispatch (nested `cond`/`pcase` on type tags) that accumulates in naive code.

> **Sources:**
> - [Tagless-Final Style — Oleg Kiselyov (okmij.org)](https://okmij.org/ftp/tagless-final/index.html): The original formulation — DSL as interface, interpreters as implementations.
> - [Practical Common Lisp Ch. 16 — Generic Functions (Seibel)](https://gigamonkeys.com/book/object-reorientation-generic-functions.html): *"Multimethods are perfect for situations where behaviour doesn't belong to a particular class."*
> - [Aartaka — Lisp Design Patterns](https://aartaka.me/lisp-design-patterns.html): Protocol as `defgeneric` without implementation.
> - [The Common Lisp Cookbook — Fundamentals of CLOS](https://lispcookbook.github.io/cl-cookbook/clos.html): Method dispatch mechanics and specialization.

---

## Pattern 2: Functional Core, Imperative Shell

### The idea

Separate pure computation from side-effecting interaction with the world. The *core* is a set of pure functions: given the same inputs, they always return the same outputs, touch no global state, and produce no side effects. The *shell* is a thin layer that talks to the outside world (buffers, processes, files, the display) and calls into the core with plain values.

This is the same principle as:
- **Haskell:** pure functions in `IO`-free code; `IO` only at the edges
- **Functional core / imperative shell:** coined by Gary Bernhardt, identical concept

The practical payoff: the core is trivially testable without Emacs running. The shell is hard to test but thin enough to read and trust.

### Structure

```elisp
;;; CORE — pure functions, no side effects, no buffer access

(defun mercury-ide--parse-mmc-output (output-string)
  "Parse mmc compiler output string into a list of diagnostic plists.
Each plist has :file :line :column :severity :message."
  ;; Pure string processing — no buffers, no globals
  ...)

(defun mercury-ide--filter-diagnostics (diagnostics severity)
  "Return only diagnostics matching SEVERITY from DIAGNOSTICS."
  (cl-remove-if-not
   (lambda (d) (eq (plist-get d :severity) severity))
   diagnostics))

(defun mercury-ide--grade-string (grade-components)
  "Build a Mercury grade string from GRADE-COMPONENTS plist."
  ...)

;;; SHELL — impure boundary, thin orchestration only

(defun mercury-ide/run-and-report (backend)
  "Compile current buffer and display diagnostics."
  (let* ((output   (mercury-ide--invoke-process backend))   ; impure: runs process
         (diags    (mercury-ide--parse-mmc-output output))  ; pure: parse result
         (errors   (mercury-ide--filter-diagnostics diags :error))) ; pure: filter
    (mercury-ide--display-diagnostics errors)))             ; impure: writes to buffer
```

The boundary is explicit: functions named `--invoke-*`, `--display-*`, `--read-*` are shell functions. Everything else should be pure. This naming convention makes the architecture visible without any type system.

### In Doom config specifically

Apply the same split to your `config.el`. Keep helper functions that transform configuration data (build plists, compose flag strings, merge settings) pure and at the top. Put the side-effecting calls (`add-hook`, `setq`, `map!`, `after!`) at the bottom as the shell.

> **Sources:**
> - [Functional Core, Imperative Shell — functional-architecture.org](https://functional-architecture.org/functional_core_imperative_shell/)
> - [Functional Core, Imperative Shell — Gary Bernhardt / Destroy All Software](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell): Original formulation.
> - [EmacsWiki — Functional Programming](https://www.emacswiki.org/emacs/FunctionalProgramming)
> - [EmacsWiki — Coding Style](https://www.emacswiki.org/emacs/CodingStyle): *"As many functions as possible should be written in a functional style."*

---

## Pattern 3: Dynamic Variables as Ambient Context (Reader Monad analogue)

### The idea

In Haskell, the Reader monad threads a read-only environment through a computation without making it an explicit parameter of every function. In Common Lisp, dynamic (special) variables do the same job — but with mutable rebinding via `let`.

The pattern: define a set of dynamic variables that represent the "execution context" for a subsystem. At the entry point of a significant operation, `let`-bind those variables to their contextual values. All functions called within that scope see the context without being passed it explicitly.

```elisp
;; Context variables — dynamically bound at operation entry points
(defvar *mercury-ide-active-backend* nil
  "The backend in use for the current compilation context.")

(defvar *mercury-ide-project-root* nil
  "Root directory of the project currently being operated on.")

(defvar *mercury-ide-grade* "asm_fast.gc.par.stseg"
  "Mercury grade for the current compilation.")

;; Entry point — establishes the context via let-binding
(defun mercury-ide/with-project-context (project-root grade fn)
  "Call FN with mercury IDE context bound for PROJECT-ROOT and GRADE."
  (let ((*mercury-ide-project-root* project-root)
        (*mercury-ide-grade*        grade)
        (*mercury-ide-active-backend* (mercury-ide--make-backend project-root grade)))
    (funcall fn)))

;; Deep in the call tree — reads context without it being passed in
(defun mercury-ide--build-compile-command (source-file)
  (list *mercury-ide-active-backend*
        "--grade" *mercury-ide-grade*
        source-file))
```

### Why not just pass parameters?

For shallow call stacks, pass parameters. For deep call trees where many functions at different levels all need the same contextual data, threading it as an explicit parameter to every function creates noise and makes signatures unstable (changing the context means touching every intermediate function). Dynamic variables give you the Reader monad's benefit — functions declare their environmental dependencies implicitly — without the type system machinery.

### Critical rule

**Only `let`-bind dynamic variables; never `setq` them in production code paths.** `setq` on a dynamic variable is global mutation. `let`-binding is scoped and automatically restored — even if an error is signalled within the scope.

### Honest comparison to typed alternatives

This is *less safe* than Haskell's Reader or Scala's implicit parameters because nothing prevents a called function from `setq`-ing a dynamic variable you depend on. The `*earmuffs*` naming convention is the only signal. This is a genuine tradeoff of the Lisp model; the benefit is no ceremony.

> **Sources:**
> - [Why Monads Have Not Taken the Common Lisp World by Storm — Marijn Haverbeke](https://marijnhaverbeke.nl/monad.html): *"You can mostly simulate certain Monads, including State and Reader, with special variables in Common Lisp."*
> - [Dynamic Scoping Is an Effect — Edward Yang (ezyang.com)](https://blog.ezyang.com/2020/08/dynamic-scoping-is-an-effect-implicit-parameters-are-a-coeffect/): Theoretical connection between dynamic scope, the Reader monad, and implicit parameters.
> - [Monads and Fauxnads Part 1 — hyperthings.garden](https://hyperthings.garden/posts/2021-09-29/monads-and-fauxnads-:-part-1.html)
> - [GNU Emacs Lisp Reference Manual — Dynamic Binding Tips](https://www.gnu.org/software/emacs/manual/html_node/elisp/Dynamic-Binding-Tips.html)
> - [Aartaka — Lisp Design Patterns](https://aartaka.me/lisp-design-patterns.html): *"The main use for dynamic variables is not setting them directly, but rather binding them lexically with `let`."*

---

## Pattern 4: Method Combinations for Cross-Cutting Concerns (AOP analogue)

### The idea

CLOS's `:before`, `:after`, and `:around` methods let you attach behaviour to a generic function call without modifying its primary method. This is Aspect-Oriented Programming native to the language — logging, timing, validation, caching, and audit trails are written once and applied orthogonally.

In elisp, EIEIO inherits this mechanism.

```elisp
;; Primary method — core logic only
(cl-defmethod mercury-ide/compile-buffer ((backend mercury-ide/mmc-backend) buffer)
  (mercury-ide--run-mmc backend buffer))

;; Logging aspect — added without touching primary method
(cl-defmethod mercury-ide/compile-buffer :before ((backend mercury-ide/mmc-backend) buffer)
  (message "[mercury-ide] Compiling %s with grade %s"
           (buffer-name buffer)
           (mercury-ide/mmc-backend-grade backend)))

;; Timing aspect
(cl-defmethod mercury-ide/compile-buffer :around ((backend mercury-ide/mmc-backend) buffer)
  (let ((start (float-time)))
    (cl-call-next-method)
    (message "[mercury-ide] Compile finished in %.2fs" (- (float-time) start))))
```

### Standard method combination execution order

1. All `:around` methods, most specific first (each must call `cl-call-next-method` to continue)
2. All `:before` methods, most specific first
3. The primary method (most specific only)
4. All `:after` methods, least specific first (reverse order from `:before`)

The return value is from the primary method (or the `:around` method if it doesn't call `cl-call-next-method`).

### When to use this

Use method combinations when behaviour is genuinely orthogonal to the primary logic — it would be duplicated across multiple methods if inlined, and adding or removing it should not require touching the primary method. Logging, instrumentation, and pre/post-condition checking are the canonical cases.

Do not use method combinations to hide core logic — if the `:around` method becomes the real implementation, that is a design smell.

> **Sources:**
> - [Common Lisp Object System — Wikipedia](https://en.wikipedia.org/wiki/Common_Lisp_Object_System): *"Advices are part of CLOS, as :before, :after, and :around methods, which are combined with the primary method under 'standard method combination'."*
> - [The Common Lisp Cookbook — Fundamentals of CLOS](https://lispcookbook.github.io/cl-cookbook/clos.html): Method combination mechanics and execution order.
> - [Advice in Aspect-Oriented Programming — Wikipedia](https://en.wikipedia.org/wiki/Advice_in_aspect-oriented_programming): Historical connection — CLOS method combinations predated and influenced AOP formalisation.

---

## Pattern 5: Hooks as Event-Driven Decoupling (Observer Pattern)

### The idea

Emacs hooks are a first-class observer pattern built into the runtime. A hook variable holds a list of functions. Any code can add to or remove from the list; the originating code calls `run-hooks` without knowing anything about what is registered. This is the standard mechanism for decoupling components that need to react to the same events.

The architectural principle: **components should communicate through hooks, not through direct function calls, wherever the relationship is one-to-many or where the relationship may be optional.**

```elisp
;; Define your own hooks for significant events in your subsystem
(defvar mercury-ide/before-compile-hook nil
  "Hook run before mercury-ide initiates a compile.
Each function is called with no arguments.")

(defvar mercury-ide/after-compile-hook nil
  "Hook run after mercury-ide completes a compile.
Each function is called with one argument: the exit code.")

;; Trigger points — run hooks at boundaries
(defun mercury-ide--do-compile (backend buffer)
  (run-hooks 'mercury-ide/before-compile-hook)
  (let ((exit-code (mercury-ide--invoke-compiler backend buffer)))
    (run-hook-with-args 'mercury-ide/after-compile-hook exit-code)
    exit-code))

;; Consumers register independently — no coupling back to the core
(add-hook 'mercury-ide/after-compile-hook #'mercury-ide/update-mode-line)
(add-hook 'mercury-ide/after-compile-hook #'mercury-ide/maybe-show-diagnostics)
```

### Hooks vs direct calls

| Direct call | Hook |
|---|---|
| Caller knows the callee | Caller knows nothing about who listens |
| Adding a new consumer requires modifying the caller | Adding a consumer is `add-hook` — zero changes to existing code |
| Removing a consumer requires modifying the caller | Removing is `remove-hook` |
| Testing the caller requires stubbing out the callee | Testing the caller requires only running it; hooks can be empty |

### Normal vs abnormal hooks

Normal hooks (name ends in `-hook`) call each function with no arguments. Abnormal hooks pass arguments and/or use return values. Name abnormal hooks accordingly and document the calling convention clearly in the variable's docstring.

> **Sources:**
> - [GNU Emacs Lisp Reference Manual — Hooks](https://www.gnu.org/software/emacs/manual/html_node/elisp/Hooks.html): Canonical definition and `add-hook`/`remove-hook` mechanics.
> - [Introduction to Emacs Hooks — Daniel Liden](https://www.danliden.com/posts/20231217-emacs-hooks.html): Practical patterns.
> - [The Observer Pattern in Event-Driven Architectures — Moments Log](https://www.momentslog.com/development/design-pattern/the-observer-pattern-in-event-driven-architectures): The Observer pattern this implements.

---

## Pattern 6: Buffer-Local State as Encapsulation Boundary (Mode as Object)

### The idea

In Emacs, the buffer is the natural unit of encapsulation for mode-specific state. Rather than global variables that track "the current project" or "the active backend," bind that state buffer-locally. Each buffer carries its own instance of the mode's state, and functions operate on `current-buffer` implicitly.

This is analogous to instance variables on an object — the buffer is the object, the major mode is the class, buffer-local variables are instance fields.

```elisp
;; Declare buffer-local variables — these are "instance fields"
(defvar-local mercury-ide/current-backend nil
  "The active Mercury backend for this buffer.")

(defvar-local mercury-ide/current-grade nil
  "The Mercury grade used to compile this buffer.")

(defvar-local mercury-ide/diagnostics nil
  "Current list of diagnostics for this buffer.")

;; Mode setup establishes the instance
(defun mercury-ide-mode-setup ()
  "Initialize mercury-ide state for the current buffer."
  (setq-local mercury-ide/current-backend
              (mercury-ide--make-backend (mercury-ide--detect-project-root)))
  (setq-local mercury-ide/current-grade
              (mercury-ide--detect-grade)))

;; Functions implicitly operate on current-buffer's state
(defun mercury-ide/recompile ()
  "Recompile the current buffer."
  (mercury-ide--do-compile mercury-ide/current-backend (current-buffer)))
```

### `defvar-local` vs `make-local-variable`

Prefer `defvar-local` (Emacs 24.3+) for declaring buffer-local variables at the top level. It is equivalent to `defvar` + `make-variable-buffer-local` but clearer in intent. Reserve `make-local-variable` for dynamically making an existing variable local in a specific buffer.

### Boundary between buffer-local and dynamic context

Buffer-local variables are always about *per-buffer* state — what is true about this particular buffer right now. Dynamic variables (Pattern 3) are about *execution context* — what is true during this particular operation, potentially spanning multiple buffers. Do not conflate them. If a value needs to be visible across buffer boundaries during one operation, it belongs in a dynamic variable. If it belongs to one buffer for its lifetime, it is buffer-local.

> **Sources:**
> - [GNU Emacs Lisp Reference Manual — Buffer-Local Variables](https://www.gnu.org/software/emacs/manual/html_node/elisp/Buffer_002dLocal-Variables.html)
> - [GNU Emacs Lisp Reference Manual — Major Mode Conventions](https://www.gnu.org/software/emacs/manual/html_node/elisp/Major-Mode-Conventions.html): Conventions for mode setup and buffer-local variable initialisation.
> - [GNU Emacs Lisp Reference Manual — Creating Buffer-Local Variables](https://www.gnu.org/software/emacs/manual/html_node/elisp/Creating-Buffer_002dLocal.html)

---

## Pattern 7: Condition System as Policy/Mechanism Separation

### The idea and the gap

Common Lisp's condition and restart system is the most powerful error-handling architecture in any mainstream language. Its key property: **the code that detects a problem can offer multiple recovery strategies (restarts) without committing to any of them; the code higher up the call stack that understands the policy can choose among those strategies without the stack having unwound.**

This is a genuine architectural pattern — separation of mechanism (how can we recover?) from policy (which recovery do we want here?) — with no equivalent in most other languages.

**Elisp does not have this.** `condition-case` exits the protected form entirely before the handler runs. There is no `invoke-restart`. The stack has unwound by the time you decide how to handle the condition.

### What to do instead in elisp

The practical substitute is **tagged return values** combined with `pcase` dispatch at the call site. This moves the policy decision to the caller, which is the right place for it, even if it lacks the elegance of restarts.

```elisp
;; Low-level function offers tagged outcomes instead of restarts
(defun mercury-ide--invoke-compiler (backend buffer)
  "Run compiler. Returns one of:
  (:ok output-string)
  (:compile-error exit-code output-string)
  (:process-error message)"
  (condition-case err
      (let ((result (mercury-ide--run-process backend buffer)))
        (if (zerop (car result))
            (list :ok (cdr result))
          (list :compile-error (car result) (cdr result))))
    (file-error  (list :process-error (error-message-string err)))
    (error       (list :process-error (error-message-string err)))))

;; Caller exercises policy — decides what each outcome means here
(defun mercury-ide/build-and-report ()
  (pcase (mercury-ide--invoke-compiler mercury-ide/current-backend (current-buffer))
    (`(:ok ,output)
     (mercury-ide--show-success output))
    (`(:compile-error ,code ,output)
     (mercury-ide--show-diagnostics output))
    (`(:process-error ,msg)
     (user-error "Mercury compiler could not be run: %s" msg))))
```

This is architecturally honest: the mechanism layer knows what went wrong and how; the policy layer decides what to do. The code is more verbose than CL restarts, but the separation of concerns is preserved.

### Know when this matters

For shallow, single-caller code this is overkill — just signal an error. The tagged-return pattern pays off when a low-level function is called from multiple places that have different recovery policies (one caller wants to skip the file, another wants to abort the whole operation, another wants to prompt the user).

> **Sources:**
> - [Practical Common Lisp Ch. 19 — Beyond Exception Handling (Seibel)](https://gigamonkeys.com/book/beyond-exception-handling-conditions-and-restarts): *"By allowing high-level code to dictate how lower-level code recovers from errors, condition handlers and restarts provide a better separation between the mechanism and policy of code."*
> - [Beyond Try-Catch: Common Lisp's Restart System — Ranga Krishnamurthy](https://www.rangakrish.com/index.php/2026/03/06/beyond-try-catch-common-lisps-restart-system/)
> - [Common Lisp Condition System — Wikibooks](https://en.wikibooks.org/wiki/Common_Lisp/Advanced_topics/Condition_System)
> - [GNU Emacs Lisp Reference Manual — Handling Errors](https://www.gnu.org/software/emacs/manual/html_node/elisp/Handling-Errors.html): *"The handler cannot resume execution at the point of the error."* — confirms the gap.

---

## Putting It Together: How the Patterns Compose

These patterns are not independent. Here is how they fit together in a non-trivial elisp subsystem:

```
┌─────────────────────────────────────────────┐
│  SHELL (Pattern 2)                          │
│  Hooks, commands, buffer setup              │
│  Pattern 5 (hooks) decouples consumers      │
│  Pattern 6 (buffer-local) holds instance    │
│  state per buffer                           │
├─────────────────────────────────────────────┤
│  CONTEXT BOUNDARY (Pattern 3)               │
│  Dynamic variables thread ambient config    │
│  through the call tree                      │
├─────────────────────────────────────────────┤
│  PROTOCOL LAYER (Pattern 1)                 │
│  defgeneric declarations — the abstract     │
│  algebra; consuming code lives here         │
│  Pattern 4 (method combinations) attaches  │
│  cross-cutting concerns at this layer       │
├─────────────────────────────────────────────┤
│  CORE (Pattern 2)                           │
│  Pure functions — parsing, transformation,  │
│  data assembly; no side effects             │
│  Pattern 7 (tagged returns) at boundaries  │
│  between core and protocol layer            │
└─────────────────────────────────────────────┘
```

**Top to bottom is the direction of dependencies.** The core knows nothing about the protocol layer or the shell. The protocol layer knows the core but not the shell. The shell knows everything but is kept thin. Dynamic variables thread vertically through all layers — they are the one intentional exception to strict layering, and they carry only ambient context, not data.

---

## Typed Language Analogue Map

For reference when translating intuitions from other paradigms:

| Typed language pattern | CL/elisp equivalent | Notes |
|---|---|---|
| Tagless final (Haskell/Scala) | `defgeneric` protocol + `defmethod` interpreters | Dynamic dispatch replaces typeclass instances |
| Cake pattern (Scala) | `defgeneric` + higher-order functions for DI | No type-level composition; injected at call sites |
| Reader monad (Haskell) | Dynamic variables + `let`-binding | Less safe — no type enforcement; `*earmuffs*` is the signal |
| State monad (Haskell) | Dynamic variables + `setq` within scope | Use sparingly; prefer returning new values |
| AOP / `@Around` advice (Java/Spring) | `:around` method combination | Native in CLOS/EIEIO; no framework needed |
| Observer / EventEmitter | Hooks (`add-hook`, `run-hooks`) | Built into Emacs; prefer for one-to-many events |
| Instance variables (OO) | Buffer-local variables | Buffer = object; mode = class |
| Condition/restart (CL only) | Tagged return values + `pcase` | The CL pattern doesn't exist in elisp; this is the honest substitute |
| Monad transformers (Haskell) | Nested `let` rebinding of dynamic variables | Partial analogy only; no composability guarantees |

---

## Master Reference List

### Core architectural sources

- [Generic Functions — GNU Emacs Lisp Reference Manual](https://www.gnu.org/software/emacs/manual/html_node/elisp/Generic-Functions.html): `cl-defgeneric`/`cl-defmethod` reference
- [Defining generic and mode-specific functions with cl-defmethod — Sacha Chua](https://sachachua.com/blog/2022/01/defining-generic-and-mode-specific-emacs-lisp-functions-with-cl-defmethod/): practical cl-generic patterns
- [EIEIO Manual — gnu.org](https://www.gnu.org/software/emacs/manual/html_mono/eieio.html): EIEIO classes and slots (built on cl-generic)
- [Tagless-Final Style — Oleg Kiselyov (okmij.org)](https://okmij.org/ftp/tagless-final/index.html)
- [Practical Common Lisp Ch. 16 — Generic Functions (Seibel)](https://gigamonkeys.com/book/object-reorientation-generic-functions.html)
- [Practical Common Lisp Ch. 19 — Conditions and Restarts (Seibel)](https://gigamonkeys.com/book/beyond-exception-handling-conditions-and-restarts)
- [Aartaka — Lisp Design Patterns](https://aartaka.me/lisp-design-patterns.html)
- [The Common Lisp Cookbook — Fundamentals of CLOS](https://lispcookbook.github.io/cl-cookbook/clos.html)
- [Common Lisp Object System — Wikipedia](https://en.wikipedia.org/wiki/Common_Lisp_Object_System)

### Functional core / imperative shell

- [Functional Core, Imperative Shell — functional-architecture.org](https://functional-architecture.org/functional_core_imperative_shell/)
- [Functional Core, Imperative Shell — Gary Bernhardt / Destroy All Software](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell)
- [Functional Core & Imperative Shell — Kong To / Medium](https://newlight77.medium.com/functional-core-imperative-shell-architecture-to-isolate-the-domain-2b60477b3bd1)

### Dynamic variables / Reader monad analogue

- [Why Monads Have Not Taken the Common Lisp World by Storm — Marijn Haverbeke](https://marijnhaverbeke.nl/monad.html)
- [Dynamic Scoping Is an Effect — Edward Yang (ezyang.com)](https://blog.ezyang.com/2020/08/dynamic-scoping-is-an-effect-implicit-parameters-are-a-coeffect/)
- [Reader Monad and Implicit Parameters — Edward Yang (ezyang.com)](http://blog.ezyang.com/2010/07/implicit-parameters-in-haskell/)
- [Monads and Fauxnads Part 1 — hyperthings.garden](https://hyperthings.garden/posts/2021-09-29/monads-and-fauxnads-:-part-1.html)
- [GNU Emacs Lisp Reference Manual — Dynamic Binding Tips](https://www.gnu.org/software/emacs/manual/html_node/elisp/Dynamic-Binding-Tips.html)

### Method combinations / AOP

- [Advice in Aspect-Oriented Programming — Wikipedia](https://en.wikipedia.org/wiki/Advice_in_aspect-oriented_programming)

### Hooks / observer pattern

- [GNU Emacs Lisp Reference Manual — Hooks](https://www.gnu.org/software/emacs/manual/html_node/elisp/Hooks.html)
- [Introduction to Emacs Hooks — Daniel Liden](https://www.danliden.com/posts/20231217-emacs-hooks.html)

### Buffer-local state

- [GNU Emacs Lisp Reference Manual — Buffer-Local Variables](https://www.gnu.org/software/emacs/manual/html_node/elisp/Buffer_002dLocal-Variables.html)
- [GNU Emacs Lisp Reference Manual — Major Mode Conventions](https://www.gnu.org/software/emacs/manual/html_node/elisp/Major-Mode-Conventions.html)
- [GNU Emacs Lisp Reference Manual — Creating Buffer-Local Variables](https://www.gnu.org/software/emacs/manual/html_node/elisp/Creating-Buffer_002dLocal.html)

### Condition system

- [Beyond Try-Catch: Common Lisp's Restart System — Ranga Krishnamurthy](https://www.rangakrish.com/index.php/2026/03/06/beyond-try-catch-common-lisps-restart-system/)
- [Common Lisp Condition System — Wikibooks](https://en.wikibooks.org/wiki/Common_Lisp/Advanced_topics/Condition_System)
- [GNU Emacs Lisp Reference Manual — Handling Errors](https://www.gnu.org/software/emacs/manual/html_node/elisp/Handling-Errors.html)
