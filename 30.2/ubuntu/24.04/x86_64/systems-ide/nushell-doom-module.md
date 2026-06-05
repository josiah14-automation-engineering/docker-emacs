# Nushell Doom Module — Reference

Plan: develop and verify the module locally inside systems-ide first
(`$DOOMDIR/modules/lang/nushell/`), then port to the Doom repo layout and open a PR.

---

## Module file layout

```
modules/lang/nushell/
  packages.el    — package declarations (pinned)
  config.el      — use-package!, LSP wiring, keybindings
  autoload.el    — optional; only needed for M-x commands exposed under +nushell/
```

---

## Flags

| Flag | Meaning |
|---|---|
| `+lsp` | Wire `nu --lsp` via `lsp-register-client`; auto-start on file open |
| `+tree-sitter` | Use `nushell-ts-mode` instead of `nushell-mode` when Emacs 29+ treesit is available |

---

## Packages

| Package | Source | Notes |
|---|---|---|
| `nushell-mode` | `mrkkrp/nushell-mode` (MELPA) | Syntax highlighting; derives from `prog-mode`; no built-in LSP |
| `nushell-ts-mode` | `herbertjones/nushell-ts-mode` (MELPA) | Tree-sitter mode; requires grammar (see below) |

Both are on MELPA. Both must be pinned in `packages.el` (Doom requires pinned commits for
all packages in the repo — find the latest commit hash for each before opening the PR).

### packages.el shape

```elisp
;; -*- no-byte-compile: t; -*-
;;; lang/nushell/packages.el

(package! nushell-mode :pin "<commit>")

(when (and (modulep! +tree-sitter) (treesit-available-p))
  (package! nushell-ts-mode :pin "<commit>"))
```

---

## LSP

`nu --lsp` is Nushell's built-in language server. Available since Nu 0.85. No separate
binary — the `nu` binary itself is the LSP server.

`lsp-mode` does not ship a built-in client for Nushell. The client must be registered
manually. This registration goes inside `(when (modulep! +lsp) ...)` in `config.el`:

```elisp
(after! lsp-mode
  (add-to-list 'lsp-language-id-configuration '(nushell-mode . "nushell"))
  (lsp-register-client
   (make-lsp-client :new-connection (lsp-stdio-connection '("nu" "--lsp"))
                    :major-modes '(nushell-mode)
                    :server-id 'nushell-lsp)))
```

If `+tree-sitter` is also active, `nushell-ts-mode` needs its own entry in
`:major-modes` (or a second `lsp-register-client` call with a different `:server-id`).

---

## Tree-sitter grammar

- Grammar repo: https://github.com/nushell/tree-sitter-nu
- `nushell-ts-mode` does NOT bundle the grammar. Users must run
  `M-x treesit-install-language-grammar` and provide the URL above.
- In the Doom module, use `set-tree-sitter!` (Doom's helper) to register the grammar
  source so `doom doctor` can advise users on what to install.

```elisp
(set-tree-sitter! 'nushell-mode 'nushell-ts-mode
  '((nu :url "https://github.com/nushell/tree-sitter-nu")))
```

(Confirm the key name — `:lang nix` uses `nix`, `:lang zig` uses `zig`; likely `nu`.)

---

## config.el shape

Model: `:lang zig` (`modules/lang/zig/config.el`) — simplest full-LSP module in the
Doom repo. Key patterns extracted:

**Common-config helper** — apply to both regular and ts mode from one place:

```elisp
(defun +nushell-common-config (mode)
  (when (modulep! +lsp)
    (add-hook (intern (format "%s-local-vars-hook" mode)) #'lsp! 'append))
  (map! :localleader
        :map ,(intern (format "%s-map" mode))
        ;; keybindings go here
        ))
```

**Main mode** — registered via `use-package!`:

```elisp
(use-package! nushell-mode
  :mode "\\.nu\\'"
  :interpreter "nu"
  :config
  (+nushell-common-config 'nushell-mode))
```

**Tree-sitter mode** — conditional on flag:

```elisp
(use-package! nushell-ts-mode
  :when (modulep! +tree-sitter)
  :defer t
  :init
  (set-tree-sitter! 'nushell-mode 'nushell-ts-mode
    '((nu :url "https://github.com/nushell/tree-sitter-nu")))
  :config
  (+nushell-common-config 'nushell-ts-mode))
```

**LSP client registration** — inside the same `config.el`, guarded by flag:

```elisp
(when (modulep! +lsp)
  (after! lsp-mode
    (add-to-list 'lsp-language-id-configuration '(nushell-mode . "nushell"))
    (lsp-register-client
     (make-lsp-client :new-connection (lsp-stdio-connection '("nu" "--lsp"))
                      :major-modes '(nushell-mode nushell-ts-mode)
                      :server-id 'nushell-lsp))))
```

---

## Naming conventions (from contributing.org)

| Kind | Pattern |
|---|---|
| Public M-x commands | `+nushell/NAME` |
| Hook functions | `+nushell-NAME-h` |
| Advice functions | `+nushell-NAME-a` |
| Strategy/dispatch functions | `+nushell-NAME-fn` |

---

## Contributing requirements

- **Target branch:** `master` (never `develop`)
- **Do-not-PR list:** https://discourse.doomemacs.org/do-not-pr (requires Discourse login)
  — new language modules are NOT on this list; `:lang scad` (#7566) was submitted and
  accepted into the "modules backlog" milestone, confirming they are allowed
- **Package pinning:** every `(package! ...)` needs a `:pin "<commit>"` before the PR
- **Module documentation:** required alongside the module files; format TBD (contributing.org
  section on new modules is empty — ask on Doom Discord before opening the PR)
- **Style:** @bbatsov emacs-lisp style guide; `mapc` not `seq-do`; no hanging parens;
  `DEPRECATED` markers for anything deprecated
- **PR timeline:** `:lang scad` sat in "modules backlog" since Sept 2024 with no merge —
  expect slow review; this is normal for new language modules

---

## Open questions

1. **`nushell-mode-map` vs `nushell-ts-mode-map`** — `nushell-mode` does not define an
   explicit map (inherits `prog-mode-map`). `nushell-ts-mode` also does not define one
   (confirmed by reading source). The `(intern (format "%s-map" mode))` pattern in the
   common-config helper will resolve to `nushell-mode-map` or `nushell-ts-mode-map` at
   runtime — verify these are live after `use-package!` loads the mode.

2. **Formatter** — `nu fmt` exists but there is no `nushell-format-buffer` function in
   either mode package. Decide whether to expose formatting via `set-formatter!` with a
   shell-command or defer it.

3. **REPL** — Nu is an interactive shell; `M-x run-nu` / `set-repl-handler!` is possible.
   Decide whether to include.

4. **`nushell-ts-mode` stability** — the package has 34 commits and CI but is not a
   widely-used mode. Evaluate before including in the PR; it can always be added in a
   follow-up.

5. **`modulep!` vs `featurep!`** — Doom renamed `featurep!` to `modulep!` at some point.
   Confirm which is current at the pinned Doom commit (`4e0dbb9`) before using it.
