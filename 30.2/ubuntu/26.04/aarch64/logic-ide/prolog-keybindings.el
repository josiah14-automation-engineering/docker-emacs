;;; prolog-keybindings.el --- Keybindings for sweeprolog -*- lexical-binding: t; -*-

;;; Commentary:

;; GLOBAL — sweeprolog's own bindings (from `sweeprolog-mode-map', baked into
;; the package itself; see SWI-Prolog/packages-sweep's sweeprolog.el,
;; lines ~459-488 — unchanged, active regardless of anything below):
;;
;;   C-c C-l          load/consult buffer
;;   C-c C-t          top-level (REPL)
;;   C-c C-q          send goal to top-level
;;   C-c C-&          async goal
;;   C-c C-c          analyze buffer (re-run semantic highlighting + diagnostics)
;;   C-c C-u          update dependencies
;;   C-c C-r          rename variable
;;   C-c C-e          export predicate
;;   C-c C-d          document predicate at point
;;   C-c C-s          term search
;;   C-c C-S-s        query-replace term
;;   C-c C-o          find file at point
;;   C-c C-b          set breakpoint
;;   C-c C-`          show diagnostics
;;   C-c C-+ / C-c C-- increment / decrement numbered variables
;;   C-c C-_          replace with anonymous variable
;;   C-c TAB / C-c <backtab>  forward / backward hole
;;   C-M-m            insert term (DWIM)
;;   M-n / M-p        forward / backward predicate
;;   M-h              mark predicate
;;
;;   `sweeprolog-forward-hole-on-tab-mode' (enabled via :hook in prolog.el,
;;   not a keybinding here) additionally binds plain TAB to jump-to-next-hole
;;   when the current line is already indented.
;;
;; LOCAL-LEADER (SPC m ...) — added here. Unlike community `:lang' modules
;; such as Doom's (go +lsp) (see systems-ide/go-keybindings.el), sweeprolog
;; is a plain third-party package with no Doom localleader scheme of its
;; own — everything under SPC m below is new, not an override of a default.
;;
;;   Quick actions — parallel metal-mercury-mode's compile/runner convention
;;   in mercury-keybindings.el
;;   SPC m c        load/consult buffer          (= C-c C-l)
;;   SPC m r        top-level (REPL)             (= C-c C-t)
;;   SPC m u        update dependencies          (= C-c C-u)
;;
;;   Top-level      SPC m t ...
;;   q              send goal to top-level
;;   &              async goal
;;   l              list top-levels
;;
;;   Goto           SPC m g ...
;;   m              find module
;;   p              find predicate
;;   f              find file at point
;;   n / N          forward / backward predicate
;;   h              mark predicate
;;
;;   Help/docs      SPC m h ...
;;   m              describe module
;;   p              describe predicate
;;   e              view messages
;;   n              view news
;;   i              info manual
;;
;;   Refactor       SPC m R ...  (capital R — lowercase r is the top-level/REPL quick action above)
;;   r              rename variable
;;   a              replace with anonymous variable
;;   + / -          increment / decrement numbered variables
;;   e              export predicate
;;   x              extract region to predicate
;;   d              document predicate at point
;;   s              query-replace term
;;   /              term search
;;
;;   Breakpoints    SPC m b ...
;;   b              set breakpoint
;;   d              delete breakpoint at point
;;   c              set breakpoint condition
;;   l              list breakpoints
;;
;;   Diagnostics    SPC m d ...
;;   d              show diagnostics (flymake itself runs continuously
;;                  regardless; this just opens the diagnostics buffer)

;;; Code:

(map! :map sweeprolog-mode-map
      :localleader
      "c" #'sweeprolog-load-buffer
      "r" #'sweeprolog-top-level
      "u" #'sweeprolog-update-dependencies

      (:prefix ("t" . "top-level")
       "q" #'sweeprolog-top-level-send-goal
       "&" #'sweeprolog-async-goal
       "l" #'sweeprolog-list-top-levels)

      (:prefix ("g" . "goto")
       "m" #'sweeprolog-find-module
       "p" #'sweeprolog-find-predicate
       "f" #'sweeprolog-find-file-at-point
       "n" #'sweeprolog-forward-predicate
       "N" #'sweeprolog-backward-predicate
       "h" #'sweeprolog-mark-predicate)

      (:prefix ("h" . "help/docs")
       "m" #'sweeprolog-describe-module
       "p" #'sweeprolog-describe-predicate
       "e" #'sweeprolog-view-messages
       "n" #'sweeprolog-view-news
       "i" #'sweeprolog-info-manual)

      (:prefix ("R" . "refactor")
       "r" #'sweeprolog-rename-variable
       "a" #'sweeprolog-replace-with-anonymous-variable
       "+" #'sweeprolog-increment-numbered-variables
       "-" #'sweeprolog-decrement-numbered-variables
       "e" #'sweeprolog-export-predicate
       "x" #'sweeprolog-extract-region-to-predicate
       "d" #'sweeprolog-document-predicate-at-point
       "s" #'sweeprolog-query-replace-term
       "/" #'sweeprolog-term-search)

      (:prefix ("b" . "breakpoints")
       "b" #'sweeprolog-set-breakpoint
       "d" #'sweeprolog-delete-breakpoint-at-point
       "c" #'sweeprolog-set-breakpoint-condition
       "l" #'sweeprolog-list-breakpoints)

      (:prefix ("d" . "diagnostics")
       "d" #'sweeprolog-show-diagnostics))

(provide 'prolog-keybindings)
;;; prolog-keybindings.el ends here
