;;; go-keybindings.el --- Go mode keybindings -*- lexical-binding: t; -*-

;;; Commentary:
;; All keybindings active in go-mode buffers.
;;
;; GLOBAL — LSP / flycheck (from :tools lsp and config.el):
;;   g d           go to definition              (lsp / xref)
;;   g D           find references               (lsp / xref)
;;   K             hover documentation           (lsp)
;;   ] d / [ d     next / prev diagnostic        (flycheck)
;;   SPC c a       code actions                  (lsp)
;;   SPC c r       rename symbol                 (lsp-rename)
;;   SPC b c       flycheck buffer               (config.el global)
;;
;; LOCAL-LEADER — Doom's (go +lsp) module (SPC m ...):
;;
;;   Misc
;;   SPC m e       send buffer/region to play.golang.org
;;   SPC m i       jump to import block
;;   SPC m h .     LSP hover docs — remapped from godoc-at-point; godef is a dead project
;;                 (last release 2020, golang.org/x/tools frozen pre-1.21, panics on Go 1.26+)
;;
;;   Struct tags
;;   SPC m a       add struct tag
;;   SPC m d       remove struct tag
;;
;;   Build
;;   SPC m b r     go run .
;;   SPC m b b     go build
;;   SPC m b c     go clean
;;
;;   Generate
;;   SPC m g f     go generate (current file)
;;   SPC m g d     go generate (current dir)
;;   SPC m g a     go generate ./...
;;
;;   Test
;;   SPC m t t     rerun last test
;;   SPC m t a     go test ./...
;;   SPC m t s     test at point
;;   SPC m t n     test + subtests at point
;;   SPC m t f     test current file
;;   SPC m t g     generate test stub for symbol at point
;;   SPC m t G     generate tests for all exported symbols
;;   SPC m t e     generate tests for exported symbols
;;
;;   Benchmarks — shadowed; see SPC m p below
;;   SPC m t b s   [shadowed → SPC m p s]  bench at point
;;   SPC m t b a   [shadowed → SPC m p a]  bench all
;;
;;   Import — shadowed; see SPC m I below
;;   SPC m r i a   [shadowed → SPC m I]    add import

;;; Code:

;; flycheck-elisp byte-compiles this file outside Doom's load context and
;; flags the (:prefix (KEY . DESC) ...) form as "wrong type argument:
;; proper-list-p". This is a false positive: Doom's `map!` macro treats a
;; cons cell as a (key . which-key-label) pair, which is valid DSL - not a
;; function argument that must be a proper list. The file is intentionally
;; not byte-compiled standalone (see local variables, below).
;;
;;flycheck-disable-checker: emacs-lisp

(defun +go/playground-yank ()
  "Send buffer or region to play.golang.org and copy the URL to the kill ring."
  (interactive) ;; enable calling this fxn as a command in M-x menu
  (let ((browse-url-browser-function ;; temp replace of browser-open logic
         (lambda (url &rest _)
           (kill-new url) ;; push the URL onto the Emacs clipboard (kill ring)
           (message "Playground URL: %s" url)))) ;; prints to bottom minibuffer
    (call-interactively #'+go/playground)))

;; This whole block needs to happen in an after! block because go-mode's own
;; default localleader bindings (e, I, h ., ...) are wired inside
;; `+go-common-config`, called from `use-package! go-mode :config`, which
;; runs lazily when a .go file is first opened. A plain map! call here loads
;; before that lazy config fires, so anything it also binds by default gets
;; silently overwritten right after this file loads.
;;
;; Note: K is kept by convention — it is the default LSP hover key in Doom.
;; k (lowercase) is also bound here as an easier-to-type alias; go-mode's
;; localleader map leaves k unbound, though note that k retains its normal-mode
;; evil meaning (cursor up) outside the localleader context.
(after! go-mode
  (map! :map go-mode-map
        :localleader
        (:prefix ("h" . "help")
         :desc "Hover docs" "." #'lsp-describe-thing-at-point)
        :desc "Playground (copy url)"  "e" #'+go/playground-yank
        :desc "Add import"            "I" #'go-import-add
        :desc "Hover docs"            "k" #'lsp-describe-thing-at-point
        :desc "Hover docs"            "K" #'lsp-describe-thing-at-point
        :desc "Lint package"          "l" (cmd! (compile "golangci-lint run ."))
        :desc "Lint all"              "L" (cmd! (compile "golangci-lint run ./..."))
        (:prefix ("p" . "profile")
         :desc "Bench at point"       "s" #'+go/bench-single
         :desc "Bench all"            "a" #'+go/bench-all)
        ;; gorepl-mode is a third-party package whose autoload stubs don't carry
        ;; the (interactive) declaration.  Doom generates correct stubs for its
        ;; own module functions (hence #'+go/bench-single works), but for
        ;; third-party packages the stub exists without interactive metadata, so
        ;; commandp returns nil and map! rejects a bare #'symbol.  cmd! wraps
        ;; each call in a (lambda () (interactive) ...) that satisfies commandp
        ;; and triggers the real autoload on first invocation.
        ;;
        ;; gorepl-run additionally has no autoload cookie at all, so calling it
        ;; cold raises void-function.  The (require 'gorepl-mode) before it loads
        ;; the package explicitly; require is a no-op once the package is loaded.
        (:prefix ("r" . "repl")
         :desc "Run REPL"            "r" (cmd! (require 'gorepl-mode) (gorepl-run))
         :desc "Run REPL, load file" "R" (cmd! (gorepl-run-load-current-file))
         :desc "Eval line"           "e" (cmd! (gorepl-eval-line))
         :desc "Eval line, advance"  "n" (cmd! (gorepl-eval-line-goto-next-line))
         :desc "Eval region"         "E" (cmd! (call-interactively #'gorepl-eval-region)))))

;; Local Variables:
;; no-byte-compile: t
;; End:

(provide 'go-keybindings)
;;; go-keybindings.el ends here
