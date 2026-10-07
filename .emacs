;;; .emacs --- Personal Emacs configuration -*- lexical-binding: t; -*-

;; Author: Jacques Cretinon
;; Keywords: convenience
;; Package-Requires: ((emacs "30.1"))
;; Version: 1.2

;;; Commentary:
;;
;; Personal configuration: UI and fonts, tree-sitter grammars, Org, LSP and
;; Magit, the gptel LLM backends and the ECA assistant.

;;; Changelog:
;;
;; v1.2 applies the review findings and keeps README.org in sync
;; v1.1 closes the file-local eval hole, hardens the init and drops dead code
;; v0.1 is init of my .emacs.org, missing a lot of things and not fully tested

;;; Code:
;;
;;Overall, this code configures the package management system and ensures `use-package` is available for further configurations.
(require 'package)
(setq package-enable-at-startup nil)
(setq package-archives
      '(("elpa"         . "https://elpa.gnu.org/packages/")
        ("melpa-stable" . "https://stable.melpa.org/packages/")
        ("melpa"        . "https://melpa.org/packages/")
        ("nongnu"       . "https://elpa.nongnu.org/nongnu/"))
      package-archive-priorities
      '(("melpa-stable" . 10)
        ("elpa"         . 5)
        ("melpa"        . 1)
        ("nongnu"       . 0))
      package-check-signature 'allow-unsigned)
(package-initialize)
(require 'use-package)

;; if we need to call debbuger on specific call
;;(debug-on-entry 'package-initialize)

;; if we need to refresh melpa pkg list
;;(package-refresh-contents)

;; Load the custom file (redirected saves from `customize')
(setq custom-file "~/.emacs.custom")
(when (file-exists-p custom-file)
  (condition-case err
      (load custom-file 'noerror)
    (error (display-warning 'init (format "custom-file: %s" err) :warning))))

;; External programs this configuration relies on
(defvar my/required-programs
  '(("multimarkdown" "markdown preview and export")
    ("clangd" "C and C++ language server")
    ("bash-language-server" "shell script language server")
    ("gopls" "Go language server")
    ("pyright-langserver" "Python language server")
    ("shellcheck" "shell script linter")
    ("rg" "ripgrep search (M-s r)")
    ("aspell" "spell checking"))
  "External programs used by this configuration, with the feature they serve.")

(defun my/warn-missing-programs ()
  "Warn about the external programs of `my/required-programs' that are absent."
  (dolist (program my/required-programs)
    (unless (executable-find (car program))
      (display-warning 'init
                       (format "%s is missing: %s" (car program) (cadr program))
                       :warning))))

(add-hook 'after-init-hook #'my/warn-missing-programs)

;; Load and activate the Cyberpunk theme
(use-package cyberpunk-theme
  :ensure t
  :init
  (load-theme 'cyberpunk t)
  ;; Focus-based background transparency: the active frame is transparent
  ;; (80% opacity) and inactive frames are opaque (100%).
  ;; - Graphical frames: use the native `alpha' frame parameter
  ;;   (ACTIVE . INACTIVE) => (80 . 100), handled by Emacs/window manager.
  ;; - Terminal frames: Emacs cannot set an opacity level, so it switches the
  ;;   default face background between "unspecified-bg" (focused: the terminal
  ;;   emulator's own transparency shows through; set e.g. PuTTY opacity to
  ;;   80%) and the theme's opaque background (unfocused: 100%).  Tty focus
  ;;   detection relies on xterm focus events ("\e[I"/"\e[O"); note that
  ;;   PuTTY in SCO mode remaps those bytes to PgUp/F3, so focus reporting may
  ;;   be unavailable there.
  ;; See https://www.gnu.org/software/emacs/manual/html_node/emacs/Frame-Parameters.html
  (defvar my/opaque-terminal-bg nil
    "Opaque background applied to unfocused terminal frames.")
  (defun my/capture-opaque-background ()
    "Remember the current theme's opaque background color."
    (let ((bg (face-background 'default nil 'default)))
      (unless (member bg '(nil "unspecified-bg"))
        (setq my/opaque-terminal-bg bg))))
  (defun my/update-terminal-transparency ()
    "Set transparent background on focused tty frames, opaque on others."
    (dolist (f (frame-list))
      (unless (display-graphic-p f)
        (if (memq (frame-focus-state f) '(t unknown))
            (progn
              (set-face-background 'default "unspecified-bg" f)
              (set-frame-parameter f 'background-color "unspecified-bg"))
          (set-face-background 'default (or my/opaque-terminal-bg "black") f)
          (set-frame-parameter f 'background-color
                               (or my/opaque-terminal-bg "black"))))))
  (defun my/set-gui-frame-alpha (frame)
    "Set FRAME opacity to 90% when focused, 10% when not."
    (when (display-graphic-p frame)
      (set-frame-parameter frame 'alpha '(85 . 10))))
  (declare-function my/capture-opaque-background nil "")
  (declare-function my/update-terminal-transparency nil "")
  (declare-function my/set-gui-frame-alpha nil "(frame)")
  (add-hook 'after-load-theme-hook #'my/capture-opaque-background)
  (add-hook 'after-load-theme-hook #'my/update-terminal-transparency)
  (add-hook 'window-setup-hook #'my/update-terminal-transparency 90)
  (add-hook 'tty-setup-hook #'my/update-terminal-transparency 90)
  (add-function :after after-focus-change-function
                #'my/update-terminal-transparency)
  (add-hook 'after-make-frame-functions #'my/set-gui-frame-alpha)
  (my/capture-opaque-background)
  (my/update-terminal-transparency)
  (my/set-gui-frame-alpha (selected-frame)))

;; Disable unnecessary UI elements
(tool-bar-mode -1)   ;; Disable the tool bar
(scroll-bar-mode -1) ;; Disable the scroll bar
(menu-bar-mode 0)    ;; Disable the menu bar
(tab-line-mode 0)    ;; Disable the tab line
(global-visual-line-mode 1)
(transient-mark-mode 1) ;; Enable transient mark mode for visual feedback in selections
(setq-default inhibit-splash-screen t) ;; Prevent the splash screen from appearing at startup
;; (setq-default truncate-lines t)
;; (setq-default truncate-partial-width-windows t)
(fset 'yes-or-no-p 'y-or-n-p) ;; Replace yes/no prompts with y/n for convenience

;; Options of this configuration
(defgroup my nil
  "Personal configuration options."
  :group 'convenience)

;; Set reusable font name variables
(defcustom my/fixed-width-font "JetBrains Mono"
  "The font to use for monospaced (fixed width) text."
  :type 'string
  :group 'my)

(defcustom my/variable-width-font "Cascadia Code"
  "The font to use for variable-pitch (document) text."
  :type 'string
  :group 'my)

;; NOTE: These settings might not be ideal for your machine, tweak them as needed!
(set-face-attribute 'default nil :font my/fixed-width-font :weight 'light :height 180)
(set-face-attribute 'fixed-pitch nil :font my/fixed-width-font :weight 'light :height 1.0)
(set-face-attribute 'variable-pitch nil :font my/variable-width-font :weight 'light :height 1.3)

;; rezise both text and status bar when CTRL + mouse wheel
(setq frame-inhibit-implied-resize t)

(defun my/global-zoom (delta)
  "Adjust the font size globally without resizing the OS window."
  (interactive)
  (let* ((old-default-height (face-attribute 'default :height))
         (new-default-height (+ old-default-height delta))
         (old-ml-height (face-attribute 'mode-line :height))
         ;; A mode-line whose :height is unspecified (not a number) follows
         ;; the default face, so its effective height is the default's.
         ;; Anchoring on that value (instead of a guessed constant) keeps
         ;; zoom-out/zoom-in symmetric: after one C-wheel-down then one
         ;; C-wheel-up the status-bar text returns to its original size.
         (base-ml-height (if (numberp old-ml-height) old-ml-height old-default-height))
         (new-ml-height (+ base-ml-height delta))
         (new-pad (max 1 (/ new-ml-height 40))))

    ;; 1. Update the main font globally
    (set-face-attribute 'default nil :height new-default-height)

    ;; 2. Update the Mode Line
    (dolist (face '(mode-line mode-line-inactive))
      (set-face-attribute face nil
                          :height new-ml-height
                          :box `(:line-width ,new-pad :color ,(face-background 'mode-line))))

    (message "Font: %s | Mode-Line: %s" new-default-height new-ml-height)))

(defun my/global-zoom-in () (interactive) (my/global-zoom 10))
(defun my/global-zoom-out () (interactive) (my/global-zoom -10))

(keymap-global-set "C-<wheel-up>" 'my/global-zoom-in)
(keymap-global-set "C-<wheel-down>" 'my/global-zoom-out)

;; Enable global whitespace mode with preferred styles (show special char)
(setq-default whitespace-style '(face trailing tabs empty indentation::space))
(global-whitespace-mode 1)

(defun my/whitespace-off-in-excluded-buffers ()
  "Keep `whitespace-mode' off in chat, PDF and special buffers."
  (when (or (derived-mode-p 'eca-chat-mode)
            (derived-mode-p 'pdf-view-mode)
            (derived-mode-p 'special-mode))
    (whitespace-mode -1)))

(add-hook 'after-change-major-mode-hook #'my/whitespace-off-in-excluded-buffers 90)
;; Do not use tab for indentation
(setq-default indent-tabs-mode nil) ;; Use spaces instead of tabs for indentation

;; Use package management for managing plugins
(use-package all-the-icons
  :ensure t
  :defer t
  ;; Ensure icons are only loaded in a graphical environment
  :if (display-graphic-p))

(defun my/install-all-the-icons-fonts ()
  "Install the all-the-icons fonts when they are absent."
  (interactive)
  (require 'all-the-icons)
  (unless (member "all-the-icons" (font-family-list))
    (all-the-icons-install-fonts t)))

(use-package all-the-icons-completion
  :ensure t
  :defer
  ;; Setup all-the-icons for Marginalia
  :hook (marginalia-mode . #'all-the-icons-completion-marginalia-setup)
  :init
  ;; Enable the all-the-icons completion mode
  (all-the-icons-completion-mode))

(use-package treemacs
  :ensure t
  :bind ("<f5>" . treemacs)         ;; Bind F5 for toggling the Treemacs sidebar
  :custom
  (treemacs-width 35)               ;; Set window width for Treemacs
  (treemacs-show-hidden-files t)    ;; Show hidden files
  (treemacs-sorting 'alphabetic-case-insensitive-asc)  ;; Sort files and directories ignoring case
  :config
  (treemacs-follow-mode 1)          ;; Follow the file of the current buffer
  (treemacs-filewatch-mode 1))      ;; Auto-refresh the tree

;; Magit events (commits, staging) are reported to treemacs
(use-package treemacs-magit
  :ensure t
  :after treemacs)

;; Icons provided by all-the-icons instead of the default theme
(use-package treemacs-all-the-icons
  :ensure t
  :after treemacs
  :config
  (treemacs-load-theme "all-the-icons"))

;; Project roots are kept in insertion order: render them sorted by name
(defun my/treemacs-project-name< (a b)
  "Return non-nil when project A sorts before project B by name, ignoring case."
  (string< (downcase (treemacs-project->name a))
           (downcase (treemacs-project->name b))))

(defun my/treemacs-render-projects-sorted (render projects)
  "Render PROJECTS through RENDER, sorted by project name ignoring case."
  (funcall render (sort (copy-sequence projects) #'my/treemacs-project-name<)))

(defun my/treemacs-redraw-after-project-change (&rest _)
  "Redraw the treemacs buffers after a project was added or removed."
  (treemacs--consolidate-projects))

(with-eval-after-load 'treemacs
  (advice-add 'treemacs--render-projects :around #'my/treemacs-render-projects-sorted)
  (advice-add 'treemacs-do-add-project-to-workspace
              :after #'my/treemacs-redraw-after-project-change)
  (advice-add 'treemacs-do-remove-project-from-workspace
              :after #'my/treemacs-redraw-after-project-change))

;; Keep the git faces in sync when magit refreshes its buffers
(defun my/treemacs-refresh-all ()
  "Refresh every project of every treemacs buffer."
  (interactive)
  (treemacs-run-in-every-buffer
   (treemacs--do-refresh (current-buffer) 'all)))

(with-eval-after-load 'magit
  (add-hook 'magit-post-refresh-hook #'my/treemacs-refresh-all))

;; Highlight indentation levels for better code readability
(use-package indent-guide
  :ensure t
  :hook (prog-mode . indent-guide-mode))

;; Display line numbers in programming modes for easier navigation
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

;; PuTTY Configuration for Enhanced Key Mapping
;; Specific settings are required for using Emacs over PuTTY.
;; Ensure PuTTY is set to SCO mode and the terminal is configured as xterm-256color.
(defcustom my/terminal-escape-remap nil
  "Translate terminal escape sequences: ESC as Meta, \\e[I and \\e[O as keys.
Disabled by default: those bytes carry the focus events the terminal
transparency feature needs, and ESC as Meta removes ESC ESC ESC."
  :type 'boolean
  :group 'my)

(if (and my/terminal-escape-remap (eq system-uses-terminfo t))
    (progn
      ;; Redefine the Escape key as Meta
      (define-key key-translation-map [\e] [\M])

      ;; Map function keys and navigation keys for terminal compatibility
      (define-key input-decode-map "\e[H" [home])
      (define-key input-decode-map "\e[F" [end])
      ;; NOTE: do NOT remap "\e[A"/"\e[B"/"\e[C"/"\e[D" (plain Up/Down/Right/
      ;; Left in xterm/SCO mode) to S-up/S-down/S-right/S-left: with
      ;; `shift-select-mode' enabled (Emacs default) every arrow press then
      ;; acts as Shift+arrow, so moving the cursor extends the region and
      ;; text gets selected.  Emacs already maps these sequences to plain
      ;; arrows by default.  If you really need Shift+arrows from PuTTY,
      ;; the xterm sequences are "\e[1;2A" (S-up), "\e[1;2B" (S-down),
      ;; "\e[1;2C" (S-right), "\e[1;2D" (S-left).
      (define-key input-decode-map "\e[I" [prior])
      (define-key input-decode-map "\e[G" [next])
      (define-key input-decode-map "\e[M" [f1])
      (define-key input-decode-map "\e[Y" [S-f1])
      (define-key input-decode-map "\e[k" [C-f1])
      (define-key input-decode-map "\e\e[M" [M-f1])
      (define-key input-decode-map "\e[N" [f2])
      (define-key input-decode-map "\e[Z" [S-f2])
      (define-key input-decode-map "\e[l" [C-f2])
      (define-key input-decode-map "\e\e[N" [M-f2])
      (define-key input-decode-map "\e[O" [f3])
      (define-key input-decode-map "\e[a" [S-f3])
      (define-key input-decode-map "\e[m" [C-f3])
      (define-key input-decode-map "\e\e[O" [M-f3])
      (define-key input-decode-map "\e[P" [f4])
      (define-key input-decode-map "\e[b" [S-f4])
      (define-key input-decode-map "\e[n" [C-f4])
      (define-key input-decode-map "\e\e[P" [M-f4])
      (define-key input-decode-map "\e[Q" [f5])
      (define-key input-decode-map "\e[c" [S-f5])
      (define-key input-decode-map "\e[o" [C-f5])
      (define-key input-decode-map "\e\e[Q" [M-f5])
      (define-key input-decode-map "\e[R" [f6])
      (define-key input-decode-map "\e[d" [S-f6])
      (define-key input-decode-map "\e[p" [C-f6])
      (define-key input-decode-map "\e\e[R" [M-f6])
      (define-key input-decode-map "\e[S" [f7])
      (define-key input-decode-map "\e[e" [S-f7])
      (define-key input-decode-map "\e[q" [C-f7])
      (define-key input-decode-map "\e\e[S" [M-f7])
      (define-key input-decode-map "\e[T" [f8])
      (define-key input-decode-map "\e[f" [S-f8])
      (define-key input-decode-map "\e[r" [C-f8])
      (define-key input-decode-map "\e\e[T" [M-f8])
      (define-key input-decode-map "\e[U" [f9])
      (define-key input-decode-map "\e[g" [S-f9])
      (define-key input-decode-map "\e[s" [C-f9])
      (define-key input-decode-map "\e\e[U" [M-f9])
      (define-key input-decode-map "\e[V" [f10])
      (define-key input-decode-map "\e[h" [S-f10])
      (define-key input-decode-map "\e[_" [C-f10])
      (define-key input-decode-map "\e\e[V" [M-f10])
      (define-key input-decode-map "\e[W" [f11])
      (define-key input-decode-map "\e[i" [S-f11])
      (define-key input-decode-map "\e[u" [C-f11])
      (define-key input-decode-map "\e\e[W" [M-f11])
      (define-key input-decode-map "\e[X" [f12])
      (define-key input-decode-map "\e[j" [S-f12])
      (define-key input-decode-map "\e[v" [C-f12])
      (define-key input-decode-map "\e\e[X" [M-f12])))

;; M-arrow selection (terminal workaround)
;; PuTTY/SCO cannot distinguish Shift+arrow from plain arrow (both send
;; "\e[A"/"\e[B"/"\e[C"/"\e[D"), so Shift+arrow selection is unavailable
;; in the terminal.  Alt+arrow sends a distinct sequence (ESC + arrow),
;; which Emacs decodes as M-<left>/M-<right>/M-<up>/M-<down>.  Bind those
;; to selection commands: the first press activates the region at point,
;; subsequent presses move point so the region extends, mimicking the
;; Shift+arrow behaviour of `shift-select-mode'.  Word movement stays
;; available on C-<left>/C-<right> (or M-f/M-b).
;; See https://www.gnu.org/software/emacs/manual/html_node/emacs/Mark.html
(defun my/select-with-arrow (move-fn arg)
  "Move point with MOVE-FN, extending the active region if any."
  (unless (region-active-p)
    (push-mark (point) nil t))
  (funcall move-fn arg))
(declare-function my/select-with-arrow nil "(move-fn arg)")
(unless (display-graphic-p)
  (defun my/select-left (&optional arg)
    "Select one character to the left (repeat to extend)."
    (interactive "p")
    (my/select-with-arrow #'left-char arg))
  (defun my/select-right (&optional arg)
    "Select one character to the right (repeat to extend)."
    (interactive "p")
    (my/select-with-arrow #'right-char arg))
  (defun my/select-up (&optional arg)
    "Select one line upward (repeat to extend)."
    (interactive "p")
    (my/select-with-arrow #'previous-line arg))
  (defun my/select-down (&optional arg)
    "Select one line downward (repeat to extend)."
    (interactive "p")
    (my/select-with-arrow #'next-line arg))
  (keymap-global-set "M-<left>" 'my/select-left)
  (keymap-global-set "M-<right>" 'my/select-right)
  (keymap-global-set "M-<up>" 'my/select-up)
  (keymap-global-set "M-<down>" 'my/select-down))

;; Use xterm-color for proper ANSI color support in compilation buffers
(use-package xterm-color
  :ensure t
  :defer t)

;; Set the compilation environment to use xterm-256color
(setq compilation-environment '("TERM=xterm-256color"))

;; Enable mouse support in terminal
(xterm-mouse-mode t)

;; UTF-8 Configuration for comprehensive encoding support
(prefer-coding-system 'utf-8)
(setq default-process-coding-system '(utf-8-unix . utf-8-unix))

;; Manage Emacs directories for backups and temporary files
(let ((backup-dir "~/.emacs.d/backups")         ;; Backup directory
      (auto-saves-dir "~/.emacs.d/auto-saves/") ;; Auto-save directory
      (tmp-dir "~/.emacs.d/tmp/"))              ;; Temporary files directory
  ;; Create directories if they do not exist
  (dolist (dir (list backup-dir auto-saves-dir tmp-dir))
    (unless (file-directory-p dir)
      (make-directory dir t)))

  ;; Set Emacs to use the specified directories for backups and auto-saves
  (setq temporary-file-directory (expand-file-name tmp-dir)
        backup-directory-alist `(("." . ,backup-dir))
        auto-save-file-name-transforms `((".*" ,auto-saves-dir t))
        auto-save-list-file-prefix (concat auto-saves-dir ".saves-")))

(setq backup-by-copying t    ;; Don't delink hardlinks
      delete-old-versions t  ;; Clean up the backups
      version-control t      ;; Use version numbers on backups
      kept-new-versions 5    ;; Keep some new versions
      kept-old-versions 2)   ;; Keep some old versions

(defun my/delete-trailing-whitespace-before-save ()
  "Remove trailing whitespace before saving, except in prose modes."
  (unless (or (derived-mode-p 'org-mode)
              (derived-mode-p 'markdown-mode)
              (derived-mode-p 'gfm-mode))
    (delete-trailing-whitespace)))

;; Enable features for better usability
(save-place-mode 1)                     ;; Remember cursor position when closing files
(global-auto-revert-mode 1)             ;; Refresh buffer if modified on disk
(add-hook 'before-save-hook #'my/delete-trailing-whitespace-before-save)

;; Download and install tree sitter grammar
;; `treesit-ready-p' is not available until treesit.el is loaded (not dumped here)
(require 'treesit)
(setq treesit-language-source-alist
      '((bash       "https://github.com/tree-sitter/tree-sitter-bash" "v0.20.0")
        (json       "https://github.com/tree-sitter/tree-sitter-json" "v0.19.0")
        (yaml       "https://github.com/tree-sitter-grammars/tree-sitter-yaml" "v0.7.2")
        (go         "https://github.com/tree-sitter/tree-sitter-go" "v0.19.0")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "typescript/src")
        (tsx        "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "tsx/src")
        (dockerfile "https://github.com/camdencheek/tree-sitter-dockerfile" "v0.1.0")
        (c          "https://github.com/tree-sitter/tree-sitter-c" "v0.20.0")
        (python     "https://github.com/tree-sitter/tree-sitter-python" "v0.20.0")
        (awk        "https://github.com/Beaglefoot/tree-sitter-awk" "v0.7.2")))

(dolist (lang-info treesit-language-source-alist)
  (let ((lang (car lang-info)))
    (unless (treesit-ready-p lang t)
      (message "Tree-sitter : installing stable version for %s..." lang)
      (condition-case err
          (treesit-install-language-grammar lang)
        (error (display-warning 'init
                                (format "tree-sitter %s: %s" lang err)
                                :warning))))))

;; json, yaml and go have no third-party mode here: their extensions map
;; straight to the tree-sitter mode, and only when its grammar is usable
(dolist (entry '(("\\.json\\'" json-ts-mode json)
                 ("\\.yaml\\'" yaml-ts-mode yaml)
                 ("\\.go\\'"   go-ts-mode   go)))
  (when (treesit-ready-p (nth 2 entry) t)
    (add-to-list 'auto-mode-alist (cons (nth 0 entry) (nth 1 entry)))))

;; sh and python modes are built in: remap them when their grammar is usable
(dolist (remap '((sh-mode     bash-ts-mode   bash)
                 (python-mode python-ts-mode python)))
  (when (treesit-ready-p (nth 2 remap) t)
    (add-to-list 'major-mode-remap-alist (cons (nth 0 remap) (nth 1 remap)))))

;; TypeScript has no classic mode: the ts modes map .ts/.tsx once loaded
(when (treesit-language-available-p 'typescript)
  (condition-case err
      (require 'typescript-ts-mode)
    (error (display-warning 'init (format "typescript-ts-mode: %s" err) :warning))))

;; CSV mode configuration
(use-package csv-mode
  :ensure t
  :hook (
         (csv-mode . csv-guess-set-separator)  ;; Automatically set the separator
         (csv-mode . csv-align-mode)            ;; Align CSV data
         ))

;; Markdown mode configuration
(use-package markdown-mode
  :ensure t
  :mode ("\\.md\\'" . gfm-mode)  ;; Associate all .md files with gfm-mode
  :init
  (setq markdown-command "multimarkdown"
        markdown-fontify-code-blocks-natively t  ;; Syntax highlight fenced code blocks
        markdown-hide-markup t                   ;; Hide **bold**, *italic*, and `code` markup tags
        markdown-header-scaling t)               ;; Visually scale header font sizes
  :bind (:map markdown-mode-map
              ("C-c C-e" . markdown-do))) ;; Keybinding for markdown-do

;; Valign: draw GFM Markdown tables as aligned grids (hides raw | and - markup)
(use-package valign
  :ensure t
  :hook ((gfm-mode . valign-mode)
         (markdown-mode . valign-mode)))

;; English spell checking with aspell (flyspell)
(setq ispell-program-name "aspell"   ; spell backend
      ispell-dictionary "en_US")     ; always check English (even if LANG changes)

;; Check spelling on the fly in every text buffer (org, markdown, message, ...)
(add-hook 'text-mode-hook #'flyspell-mode)

;; Also check comments/strings/docstrings in code buffers
(add-hook 'prog-mode-hook #'flyspell-prog-mode)

;; In Org, skip links, timestamps, code blocks (Org's own predicate)
(add-hook 'org-mode-hook
          (lambda ()
            (setq-local flyspell-generic-check-word-predicate
                        #'org-mode-flyspell-verify)))

;; ECA chat buffers derive from gfm-mode (a text mode), so keep flyspell
;; (aspell) off while chatting with the assistant.
(defun my/eca-chat-disable-flyspell ()
  "Turn flyspell off when the current buffer is an ECA chat buffer."
  (when (derived-mode-p 'eca-chat-mode)
    (flyspell-mode -1)))
(add-hook 'eca-chat-mode-hook #'my/eca-chat-disable-flyspell)

;; Comments are rendered smaller and italic in every buffer
(set-face-attribute 'font-lock-comment-face nil :height 0.75 :slant 'italic)

;; Configure Org-mode core settings and rendering

;; The Org faces below are applied once Org is loaded
(with-eval-after-load 'org
  ;; Resize Org headings (scale factors mirror `markdown-header-scaling-values'
  ;; so Org level N matches Markdown level N)
  (dolist (face '((org-level-1 . 2.0)
                  (org-level-2 . 1.7)
                  (org-level-3 . 1.4)
                  (org-level-4 . 1.1)
                  (org-level-5 . 1.0)
                  (org-level-6 . 1.0)
                  (org-level-7 . 1.0)
                  (org-level-8 . 1.0)))
    (set-face-attribute (car face) nil :font my/variable-width-font :weight 'medium :height (cdr face)))

  ;; Make the document title a bit bigger
  (set-face-attribute 'org-document-title nil :font my/variable-width-font :weight 'bold :height 1.3)

  ;; Make sure certain org faces use the fixed-pitch face when variable-pitch-mode is on
  (set-face-attribute 'org-block nil :foreground nil :inherit 'fixed-pitch)
  (set-face-attribute 'org-table nil :inherit 'fixed-pitch)
  (set-face-attribute 'org-formula nil :inherit 'fixed-pitch)
  (set-face-attribute 'org-code nil :inherit '(shadow fixed-pitch))
  (set-face-attribute 'org-verbatim nil :inherit '(shadow fixed-pitch))
  (set-face-attribute 'org-special-keyword nil :inherit '(font-lock-comment-face fixed-pitch))
  (set-face-attribute 'org-meta-line nil :inherit '(font-lock-comment-face fixed-pitch))
  (set-face-attribute 'org-checkbox nil :inherit 'fixed-pitch))

;; Fold all drawers (PROPERTIES/LOGBOOK) when an Org buffer is opened,
;; and again after a save (org-make-toc may re-insert or reveal them)
(defun my/org-fold-drawers ()
  "Fold all drawers (PROPERTIES/LOGBOOK) in the current Org buffer."
  (org-cycle-hide-drawers 'all))
(defun my/org-fold-drawers-after-save ()
  "Re-fold drawers after a save in Org buffers."
  (when (derived-mode-p 'org-mode)
    (my/org-fold-drawers)))
(add-hook 'org-mode-hook #'my/org-fold-drawers)
(add-hook 'after-save-hook #'my/org-fold-drawers-after-save)

;; Render Org property drawers at half the default font size
;; (:PROPERTIES:/:END: delimiters and the :KEY: value lines between them)
(with-eval-after-load 'org
  (set-face-attribute 'org-drawer nil :height 0.5)
  (set-face-attribute 'org-special-keyword nil :height 0.5)
  (set-face-attribute 'org-property-value nil :height 0.5))

;;; Centering Org Documents --------------------------------

;; Install visual-fill-column
(use-package visual-fill-column
  :ensure t
  :defer t)

;; Configure fill width
(setq visual-fill-column-width 80
      visual-fill-column-center-text t)

;;; Org Present --------------------------------------------

;; Install org-present if needed
(use-package org-present
  :ensure t
  :defer t)

(defun my/org-present-prepare-slide (buffer-name heading)
  ;; Show only top-level headlines
  (org-overview)

  ;; Unfold the current entry
  (org-show-entry)

  ;; Show only direct subheadings of the slide but don't expand them
  (org-show-children))

(defvar-local my/org-present-remap-backup nil
  "Value of `face-remapping-alist' before a presentation started.")

(defun my/org-present-start ()
  (menu-bar-mode 0)
  (tool-bar-mode 0)
  (scroll-bar-mode 0)
  (tab-bar-mode 0)
  ;; Tweak font sizes
  (setq my/org-present-remap-backup face-remapping-alist)
  (setq-local face-remapping-alist '((default (:height 1.5) variable-pitch)
                                     (header-line (:height 4.0) variable-pitch)
                                     (org-document-title (:height 1.75) org-document-title)
                                     (org-code (:height 1.55) org-code)
                                     (org-verbatim (:height 1.55) org-verbatim)
                                     (org-block (:height 1.25) org-block)
                                     (org-block-begin-line (:height 0.7) org-block)))

  ;; Set a blank header line string to create blank space at the top
  (setq-local header-line-format " ")

  ;; Display inline images automatically
  (org-display-inline-images)

  ;; Center the presentation and wrap lines
  (visual-fill-column-mode 1)
  (visual-line-mode 1))

(defun my/org-present-end ()
  (tool-bar-mode -1)   ;; Disable the tool bar
  (scroll-bar-mode -1) ;; Disable the scroll bar
  (menu-bar-mode 0)    ;; Disable the menu bar
  (tab-bar-mode 0)
  (tab-line-mode 0)    ;; Disable the tab line
  (transient-mark-mode 1) ;; Enable transient mark mode for visual feedback in selections

  ;; Reset font customizations
  (setq-local face-remapping-alist (or my/org-present-remap-backup
                                       '((default variable-pitch default))))

  ;; Clear the header line string so that it isn't displayed
  (setq-local header-line-format nil)

  ;; Stop displaying inline images
  (org-remove-inline-images)

  ;; Stop centering the document
  (visual-fill-column-mode 0)
  (visual-line-mode 0))

;; Turn on variable pitch fonts in Org Mode buffers
(add-hook 'org-mode-hook 'variable-pitch-mode)

;; Register hooks with org-present
(add-hook 'org-present-mode-hook 'my/org-present-start)
(add-hook 'org-present-mode-quit-hook 'my/org-present-end)
(add-hook 'org-present-after-navigate-functions 'my/org-present-prepare-slide)

(setq org-hide-emphasis-markers t
      org-hide-leading-stars t)

(use-package org
  :defer t
  :config
  ;; Ensure code and verbatim text are distinct when markers are hidden
  (set-face-attribute 'org-code nil
                      :inherit 'fixed-pitch
                      :foreground "#ff79c6")
  (set-face-attribute 'org-verbatim nil
                      :inherit 'fixed-pitch
                      :foreground "#f1fa8c"))

;; to insert a new TOC : M-x org-make-toc-insert
;; to populate TOC : org-make-toc
;; to auto update toc : org-maketoc-mode
(use-package org-make-toc
  :ensure t
  :hook (org-mode . org-make-toc-mode)
  )
(setq org-support-shift-select t)

;; PDF tools configuration (commented out)
(use-package pdf-tools
  :ensure t
  :defer t
  :config
  (pdf-tools-install) ;; Install pdf-tools
  (add-hook 'pdf-isearch-minor-mode-hook (lambda () (ctrlf-local-mode -1)))
  (use-package org-pdftools
    :ensure t
    :hook (org-mode . org-pdftools-setup-link)))
(add-to-list 'auto-mode-alist '("\\.[pP][dD][fF]\\'" . pdf-view-mode)) ;; Associate PDF files with pdf-view-mode

;; w3m: browse URLs directly inside Emacs
;; Provided by the Debian `w3m-el' package (apt install w3m w3m-el w3m-img);
;; NOT available on MELPA, so no `:ensure t'.
(use-package w3m
  :if (locate-library "w3m")
  :init
  (setq browse-url-browser-function 'eww)
  :custom
  (w3m-use-cookies t)
  (w3m-default-display-inline-images t)
  :bind (("C-c w" . w3m-browse-url)))

;; PlantUML mode
;; prerequisite is to have downloaded plantuml.jar at https://github.com/plantuml/plantuml/releases/latest/download/plantuml.jar
(use-package plantuml-mode
  :ensure t  ; For syntax highlighting (optional)
  :mode "\\.\\(pu\\|uml\\|plantuml\\|pum\\|plu\\)\\'")

;; Enable Babel support
(with-eval-after-load 'org
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((plantuml . t))))

;; Reload images in org-mode when evaluating a block of code
(defun my/org-reload-images-after-babel-execute ()
  "Toggle inline images to force a refresh after evaluating an Org Babel block."
  (when (eq major-mode 'org-mode)
      (org-toggle-inline-images nil) ; Turn off
      (org-toggle-inline-images t)))  ; Turn on

(add-hook 'org-babel-after-execute-hook 'my/org-reload-images-after-babel-execute)

;; Set JAR path
(setq org-plantuml-jar-path "~/plantuml/plantuml.jar")

;; File-local variables: safe values only, plus the config's own eval forms
(defconst my/safe-local-eval-forms
  '((gptel-mode 1)
    (toggle-truncate-lines)
    (org-toggle-inline-images)
    (remove-hook 'before-save-hook #'org-make-toc t))
  "Local `eval:' forms written and accepted by this configuration.")

(setq enable-local-variables :safe
      enable-local-eval :safe
      safe-local-eval-forms (append my/safe-local-eval-forms
                                    safe-local-eval-forms))

;; General Emacs configuration for completion
(use-package emacs
  :custom
  (tab-always-indent 'complete)            ;; Always indent to complete
  (text-mode-ispell-word-completion nil)   ;; Disable Ispell word completion in text mode
  (read-extended-command-predicate #'command-completion-default-include-p) ;; Customize command completion
  (electric-pair-mode t))   ;; insert matching delimiters

;; Snippet management using yasnippet
(use-package yasnippet
  :ensure t
  :init
  (yas-global-mode 1) ;; Enable yasnippet globally
  (setq yas-snippet-dirs '("~/.emacs.d/snippets"))) ;; Specify the directory for snippets

;; Vertical interactive completion using vertico
(use-package vertico
  :ensure t
  :init
  (vertico-mode)) ;; Enable vertico mode for a vertical completion UI

;; Pop-up completion using corfu
(use-package corfu
  :ensure t
  :custom
  ;; Customize corfu behavior
  (corfu-cycle t)                ;; Enable cycling through candidates with `corfu-next/previous'
  (corfu-auto t)                 ;; Enable automatic completion
  (corfu-quit-at-boundary nil)   ;; Do not quit completion at boundaries
  (corfu-quit-no-match t)        ;; Do not quit even with no match
  (corfu-preview-current nil)    ;; Disable preview of the current candidate
  (corfu-preselect 'prompt)      ;; Preselect the prompt in the completion UI
  (corfu-on-exact-match 'insert) ;; Insert on exact match
  (corfu-auto-delay 0.2)         ;; Delay for auto completion
  (corfu-auto-prefix 3)          ;; Prefix length for auto completion
  :init
  (global-corfu-mode)            ;; Enable corfu globally
  (corfu-history-mode)           ;; Enable history mode for corfu
  (corfu-popupinfo-mode))        ;; Enable popup information

;; Use corfu in terminal as well
(use-package corfu-terminal
  :ensure t
  :defer t)
(unless (display-graphic-p)                ;; Enable corfu-terminal mode only if not in a graphical session
  (corfu-terminal-mode +1))

;; Dabbrev configuration for buffer completion
(use-package dabbrev
  :custom
  (dabbrev-upcase-means-case-search t)    ;; Treat case sensitivity with upcase characters
  (dabbrev-check-all-buffers t)            ;; Check all buffers for completion
  (dabbrev-check-other-buffers t)          ;; Check other buffers for completion
  (dabbrev-friend-buffer-function 'dabbrev--same-major-mode-p) ;; Limit searches to same major-mode buffers
  (dabbrev-ignored-buffer-regexps '("\\.\\(?:pdf\\|jpe?g\\|png\\)\\'"))) ;; Ignore specific file types

;; Autocompletion features using cape
(use-package cape
  :ensure t
  :bind ("<backtab>" . cape-dabbrev)      ;; Bind backtab to cape-dabbrev for completion
  :custom
  (cape-dict-case-replace nil)             ;; Disable case replacement for dictionary
  (cape-dabbrev-buffer-function 'cape-same-mode-buffers) ;; Use only buffers of the same mode for completion
  :init
  ;; Additional completion functions can be added here if needed
  ;; Uncomment the following to enable specific custom completion functions:
  ;; (add-to-list 'completion-at-point-functions #'cape-file)
  ;; (add-to-list 'completion-at-point-functions #'gopar/cape-yasnippet-keyword-dabbrev)
  ;; (add-to-list 'completion-at-point-functions #'gopar/cape-dict-only-in-strings)
  ;; (add-to-list 'completion-at-point-functions #'gopar/cape-dict-only-in-comments)
)

(use-package consult
  :ensure t
  ;; Replace bindings. Lazily loaded by `use-package'.
  :bind (
         ;; Custom key bindings for efficient access
         ("C-c m" . consult-man)                   ;; Man page lookup
         ("C-x b" . consult-buffer)                ;; Switch buffers
         ("C-x r b" . consult-bookmark)            ;; Jump to bookmark
         ("C-x p b" . consult-project-buffer)      ;; Switch to project buffer
         ("M-s d" . consult-find)                  ;; Find files
         ("M-s c" . consult-locate)                ;; Locate files
         ("M-s g" . consult-grep)                  ;; Grep search in current directory
         ("M-s G" . consult-git-grep)              ;; Grep search in Git repository
         ("M-s r" . consult-ripgrep)               ;; Ripgrep search
         ("M-s l" . consult-line)                  ;; Search in current buffer by line
         ("M-s L" . consult-line-multi)            ;; Multi-line search
         ("M-s k" . consult-keep-lines)            ;; Keep specific lines from search
         ("M-s u" . consult-focus-lines))          ;; Focus on selected lines
  :hook (completion-list-mode . consult-preview-at-point-mode)
  :init
  (advice-add #'register-preview :override #'consult-register-window)
  (setq register-preview-delay 0.5)
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
  :config
  (consult-customize
   consult-theme :preview-key '(:debounce 0.2 any)
   consult-ripgrep consult-git-grep consult-grep consult-man
   consult-bookmark consult-recent-file consult-xref
   consult--source-bookmark consult--source-file-register
   consult--source-recent-file consult--source-project-recent-file
   :preview-key '(:debounce 0.4 any))
  (setq consult-narrow-key "<") ;; "C-+"
)

;; Orderless: space separated, order independent matching in the minibuffer
(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

;; Language servers: lsp-mode is only the client side, each server is installed
;; separately and started automatically per project
(let* ((bin (expand-file-name "~/.local/bin"))
       (path (getenv "PATH")))
  (add-to-list 'exec-path bin)
  (unless (and path (string-match-p (regexp-quote bin) path))
    (setenv "PATH" (if path (concat bin ":" path) bin))))

;; ECA chat buffers derive from gfm-mode, they must not start a language server
(defun my/lsp-deferred-unless-chat ()
  "Start `lsp-deferred' unless the current buffer is an ECA chat buffer."
  (unless (derived-mode-p 'eca-chat-mode)
    (lsp-deferred)))

;; Shell script diagnostics stay with shellcheck, through flycheck
(defun my/lsp-shellcheck-owns-diagnostics ()
  "Keep flycheck (shellcheck) as the diagnostic source of shell buffers."
  (setq-local lsp-diagnostics-disabled-modes
              (cons major-mode
                    (and (boundp 'lsp-diagnostics-disabled-modes)
                         lsp-diagnostics-disabled-modes))))

;; pyright ships as an external client: `use-package lsp-pyright' below loads
;; it with lsp-mode, so the python hook is the shared one

;; The shell language server indexes a single workspace root; making the git
;; directory the project root is what lets the repositories resolve each other
(defvar my/git-umbrella-root
  (file-name-as-directory (file-truename (expand-file-name "~/git")))
  "Root directory shared by the repositories of this configuration.")

(defcustom my/git-umbrella-project-enabled t
  "When non-nil, every repository below `my/git-umbrella-root' forms one project."
  :type 'boolean
  :group 'my)

(defun my/git-umbrella-project (dir)
  "Return a project rooted at `my/git-umbrella-root' for any DIR below it."
  (when my/git-umbrella-project-enabled
    (let ((dir (file-name-as-directory (expand-file-name dir))))
      (when (string-prefix-p my/git-umbrella-root dir)
        (cons 'transient my/git-umbrella-root)))))

;; project.el must be loaded first: its defvar would otherwise discard
;; `project-try-vc' instead of completing the hook
(with-eval-after-load 'project
  (add-hook 'project-find-functions #'my/git-umbrella-project))

(use-package lsp-mode
  :ensure t
  :commands (lsp lsp-deferred)
  :init
  (setq lsp-keymap-prefix "C-c l")
  :custom
  (lsp-auto-guess-root t)
  (lsp-idle-delay 0.5)
  (lsp-log-io nil)
  (lsp-enable-file-watchers nil)
  (lsp-file-watch-threshold 4000)
  (lsp-enable-snippet t)
  (lsp-enable-on-type-formatting t)
  (lsp-format-buffer-on-save nil)
  (lsp-diagnostics-provider :flycheck)
  (lsp-headerline-breadcrumb-enable nil)
  (lsp-lens-enable t)
  (lsp-modeline-diagnostics-enable nil)
  (lsp-modeline-code-actions-enable t)
  (lsp-modeline-workspace-status-enable t)
  (lsp-enable-suggest-server-download t)
  (lsp-enable-dap-auto-configure nil)
  :hook
  ((prog-mode . my/lsp-deferred-unless-chat)
   ;; sh-base-mode covers sh-mode and bash-ts-mode, and runs before prog-mode-hook,
   ;; so shellcheck disables LSP diagnostics before the server starts
   (sh-base-mode . my/lsp-shellcheck-owns-diagnostics)
   ;; text-mode children: not covered by prog-mode-hook
   (markdown-mode . my/lsp-deferred-unless-chat)
   (gfm-mode . my/lsp-deferred-unless-chat)
   (yaml-ts-mode . my/lsp-deferred-unless-chat)))

(use-package lsp-ui
  :ensure t
  :commands lsp-ui-mode
  :hook (lsp-mode . lsp-ui-mode)
  :custom
  (lsp-ui-sideline-enable t)
  (lsp-ui-sideline-show-diagnostics nil)
  (lsp-ui-sideline-show-hover nil)
  (lsp-ui-sideline-show-code-actions t)
  (lsp-ui-doc-enable t)
  (lsp-ui-doc-show-with-mouse t)
  (lsp-ui-doc-show-with-cursor nil)
  (lsp-ui-peek-enable nil)
  (lsp-ui-sideline-show-symbol nil))

(use-package lsp-treemacs
  :ensure t
  :after lsp-mode
  :commands (lsp-treemacs-symbols lsp-treemacs-errors-list
                                  lsp-treemacs-call-hierarchy lsp-treemacs-type-hierarchy))

(use-package dap-mode
  :ensure t
  :after lsp-mode
  :commands (dap-mode dap-debug dap-hydra))

(use-package consult-lsp
  :ensure t
  :after (lsp-mode consult))

(with-eval-after-load 'lsp-mode
  (keymap-set lsp-command-map "g s" #'consult-lsp-symbols)
  (keymap-set lsp-command-map "g f" #'consult-lsp-file-symbols)
  (keymap-set lsp-command-map "g p" #'consult-lsp-diagnostics))

(use-package lsp-pyright
  :ensure t
  :after lsp-mode
  :custom
  (lsp-pyright-diagnostic-mode "openFilesOnly")
  (lsp-pyright-auto-import-completions t))

(use-package terraform-mode
  :ensure t
  :mode "\\.t\\(f\\(vars\\)?\\|ofu\\)\\'")

(use-package awk-ts-mode
  :ensure t
  :if (treesit-language-available-p 'awk)
  :mode "\\.[mg]?awk\\'")

;; Clients bundled with lsp-mode: no :ensure, they load with lsp-mode
(use-package lsp-go
  :ensure nil
  :after lsp-mode
  :custom
  (lsp-go-symbol-scope "workspace"))

(use-package lsp-clangd
  :ensure nil
  :after lsp-mode
  :custom
  (lsp-clients-clangd-args '("--header-insertion=never" "--header-insertion-decorators=0")))

(use-package lsp-bash
  :ensure nil
  :after lsp-mode
  :config
  (lsp-register-custom-settings
   '(("bashIde.includeAllWorkspaceSymbols" t t)
     ("bashIde.backgroundAnalysisMaxFiles" 3000))))

;; Window ratios used by `my/magit-display-buffer'
(defcustom my/magit-status-height-ratio 0.8
  "Ratio of frame height for the Magit status window."
  :type 'number
  :group 'my)

(defcustom my/magit-process-width-ratio 0.5
  "Ratio of Magit status window width for the Magit process window."
  :type 'number
  :group 'my)

;; Magit configuration for Git integration
(use-package magit
  :ensure t  ;; Ensure the package is installed
  :commands magit-get-current-branch  ;; Lazy load command to get the current branch
  :defer ;; Deferring loading until it's necessary
  :bind ("C-x g" . magit-status)  ;; Bind the key sequence C-x g to invoke magit-status
  :hook (magit-mode . magit-wip-mode)  ;; Enable work-in-progress mode within Magit buffers
  :custom
  (magit-diff-refine-hunk 'all)  ;; Highlight all changes in diffs
  (magit-process-finish-apply-ansi-colors t)  ;; Apply ANSI colors in Magit processes
  (magit-format-file-function #'magit-format-file-all-the-icons)  ;; Use all-the-icons when formatting file listings
  :config
  ;; Buffer display customizations for better navigation
  (defun my/magit-display-buffer (buffer)
    "Custom display function for Magit buffers."
    (let ((mode (with-current-buffer buffer major-mode)))  ;; Get the major mode of the current buffer
      (cond
       ;; Handle Magit process mode
       ((eq mode 'magit-process-mode)
        (let ((process-window (get-window-with-predicate
                               (lambda (w)
                                 (with-current-buffer (window-buffer w)
                                   (eq major-mode 'magit-process-mode)))))
              (status-window (get-window-with-predicate
                              (lambda (w)
                                (with-current-buffer (window-buffer w)
                                  (eq major-mode 'magit-status-mode))))))
          (cond
           ;; Reuse existing process window if available
           ((and process-window (window-live-p process-window))
            (set-window-buffer process-window buffer)
            process-window)
           ;; Split from status window if status window is available
           ((and status-window (window-live-p status-window))
            (let* ((status-width (window-total-width status-window))
                   (new-width (floor (* my/magit-process-width-ratio status-width)))
                   (new-window (split-window status-window new-width 'right)))  ;; Split window to the right
              (set-window-buffer new-window buffer)
              new-window))
           ;; Fallback to traditional display
           (t
            (magit-display-buffer-traditional buffer)))))

       ;; Handle Magit status mode
       ((eq mode 'magit-status-mode)
        (let ((status-window (get-window-with-predicate
                              (lambda (w)
                                (with-current-buffer (window-buffer w)
                                  (eq major-mode 'magit-status-mode))))))
          (if (and status-window (window-live-p status-window))
              ;; Reuse existing status window
              (progn
                (set-window-buffer status-window buffer)
                status-window)
            ;; Create a new large window for the status buffer
            (let* ((frame-height (window-total-height (frame-root-window)))
                   (new-height (floor (* my/magit-status-height-ratio frame-height)))
                   (new-window (split-window (frame-root-window) new-height 'below)))  ;; Split window below
              (set-window-buffer new-window buffer)
              new-window))))

       ;; Default handling for other Magit buffers
       (t
        (magit-display-buffer-traditional buffer)))))

  (setq magit-display-buffer-function #'my/magit-display-buffer))  ;; Set the custom display function for Magit buffers

;; Git commit configuration for better commit message management
(use-package git-commit
  :ensure nil  ;; Do not ensure git-commit as it's part of Magit
  :after magit  ;; Load after Magit is available
  :custom
  (git-commit-summary-max-length 80)  ;; Set maximum length for commit summary
  :init)

;; Git gutter configuration for showing diffs in the fringe
(use-package git-gutter
  :ensure t  ;; Ensure git-gutter is installed
  :hook (after-init . global-git-gutter-mode))  ;; Enable git-gutter mode after initialization

(defun my/git-gutter-refresh-after-push (&rest _)
  (git-gutter:update-all-windows))
(advice-add 'magit-push :after #'my/git-gutter-refresh-after-push)

;; Refresh the Magit status buffer whenever the tree changes on disk
(use-package magit-filenotify
  :ensure t
  :hook (magit-status-mode . magit-filenotify-mode))

;; Key binding to toggle Magit status view
(defun my/magit-toggle ()
  "Toggle the Magit status buffer.
If a Magit status buffer is visible, delete its window(s);
otherwise open Magit status with `magit-status'."
  (interactive)
  (let ((buf nil))
    (dolist (b (buffer-list))
      (when (and (null buf)
                 (with-current-buffer b
                   (derived-mode-p 'magit-status-mode)))
        (setq buf b)))
    (if (and buf (get-buffer-window buf t))
        ;; Delete the Magit status window(s) so the window layout is
        ;; fully restored; `quit-windows-on' would only bury the buffer
        ;; and leave the window open showing the previous buffer.
        (let ((windows (get-buffer-window-list buf nil t)))
          (dolist (w windows)
            (when (> (length (window-list (window-frame w))) 1)
              (delete-window w))))
      (magit-status))))
(keymap-global-set "<f6>" 'my/magit-toggle)  ;; Bind F6 to toggle Magit

;; Allow Magit to search in authinfo for user/password
(add-hook 'magit-process-find-password-functions
          'magit-process-password-auth-source)

;; Forge integration for enhanced Magit functionality (commented out due to installation issues)
(use-package forge
  :ensure t
  :defer t)

;; check syntax
(use-package flycheck
  :ensure t
  :hook (after-init . global-flycheck-mode))

;; gptel loads on first use: <f8>, M-x gptel or gptel-mode
(use-package gptel
  :ensure t
  :defer t)

(with-eval-after-load 'gptel
  (condition-case err
      (require 'gptel-org)
    (error (display-warning 'init (format "gptel-org: %s" err) :warning)))

  (setq gptel-default-mode 'org-mode
        gptel-prompt-prefix-alist '((markdown-mode . "# ") (org-mode . "* ") (text-mode . "🤖: "))
        gptel-response-prefix-alist '((markdown-mode . "# ") (org-mode . "** ") (text-mode . "🤖: ")))

  (setq gptel-openai-backend
        (gptel-make-openai "OpenAI"
          :key #'gptel-api-key-from-auth-source
          :host "api.openai.com"
          :models '("gpt-4o-mini" "gpt-4.1" "o4-mini")))

  (setq gptel-gemini-backend
        (gptel-make-gemini "Gemini"
          :key #'gptel-api-key-from-auth-source
          :stream t
          :host "generativelanguage.googleapis.com"
          :models '("gemini-3.5-flash")))

  (setq gptel-copilot-backend
        (gptel-make-gh-copilot "Copilot Chat"))

  (setq gptel-mistral-backend
        (gptel-make-openai "Mistral"
          :key #'gptel-api-key-from-auth-source
          :host "api.mistral.ai"
          :models '("mistral-large-latest")))

  (setq gptel-deepseek-backend
        (gptel-make-openai "DeepSeek"
          :key #'gptel-api-key-from-auth-source
          :host "api.deepseek.com"
          :models '("deepseek-chat" "deepseek-reasoner"))))

(defvar my/gptel-backends
  '(("OpenAI" . gptel-openai-backend)
    ("Gemini" . gptel-gemini-backend)
    ("Mistral" . gptel-mistral-backend)
    ("DeepSeek" . gptel-deepseek-backend)
    ("Copilot" . gptel-copilot-backend))
  "Backends selectable with `my/gptel-with-backend-selection'.")

(defvar-local my/gptel-backend-name nil
  "Name of the gptel backend persisted as a file-local variable.")

(put 'my/gptel-backend-name 'safe-local-variable #'stringp)
(put 'gptel-model 'safe-local-variable #'stringp)

(defun my/gptel-apply-local-backend ()
  "Apply the gptel backend named by `my/gptel-backend-name' to this buffer."
  (when-let ((name my/gptel-backend-name)
             (backend-sym (alist-get name my/gptel-backends nil nil #'string=)))
    (require 'gptel)
    (when (boundp backend-sym)
      (setq-local gptel-backend (symbol-value backend-sym)))))

(add-hook 'hack-local-variables-hook #'my/gptel-apply-local-backend)

(defun my/gptel-ensure-local-variables (backend-name model)
  "Ensure standard Org/gptel local variables exist at the end of the buffer."
  (save-excursion
    (goto-char (point-max))
    (unless (save-excursion (search-backward "Local Variables:" nil t))
      (goto-char (point-max))
      (unless (bolp) (insert "\n"))
      (insert "\n# Local Variables:\n"
              (format "# my/gptel-backend-name: \"%s\"\n" backend-name)
              (format "# gptel-model: \"%s\"\n" model)
              "# eval: (gptel-mode 1)\n"
              "# eval: (toggle-truncate-lines)\n"
              "# eval: (org-toggle-inline-images)\n"
              "# eval: (remove-hook 'before-save-hook #'org-make-toc t)\n"
              "# End:\n"))))

(defun my/gptel-with-backend-selection ()
  "Start gptel-mode after opening/creating a file and prompting for backend selection."
  (interactive)
  (require 'gptel)
  ;; Prompt for a file first so the session is tied to a persistent buffer
  (find-file (read-file-name "File to open or create: "))
  (let* ((choices my/gptel-backends)
         (selected-name (completing-read "Select AI Backend: " choices nil t))
         (backend-sym (cdr (assoc selected-name choices)))
         (backend-obj (symbol-value backend-sym))
         (model (car (gptel-backend-models backend-obj))))
    (setq-local gptel-backend backend-obj)
    (setq-local gptel-model model)
    (my/gptel-ensure-local-variables selected-name model)
    (gptel-mode 1)))
(keymap-global-set "<f8>" 'my/gptel-with-backend-selection)  ;; Bind F8 to gptel backend selection

(setq gptel-directives
      '((default . "You are a large language model living in Emacs and a helpful assistant. Respond concisely. Always answer in English even if I ask questions in French. If sources for answers are more than one year old, always warn me with this text 'WARNING OLD SOURCES' at the beginning of the answer. When providing a bash shell script, always split script into smart functions and add an additional BATS script in order to test functions. Always add at least one link to documentation referring to your answer.")))

;; eca
(require 'auth-source)

(defun my/get-eca-api-key ()
  "Fetch API key from .authinfo.gpg only when ECA start."
  ;;  (interactive)
  (unless (getenv "GOOGLE_API_KEY")
    (let ((match (car (auth-source-search :host "fakeurlforpaidgoogletier.googleapis.com" :user "apikey"))))
      (when match
        (let ((secret (plist-get match :secret)))
          (setenv "GOOGLE_API_KEY" (if (functionp secret)
                                          (funcall secret)
                                        secret))))))
  (unless (getenv "DEEPSEEK_API_KEY")
    (let ((match (car (auth-source-search :host "api.deepseek.com" :user "apikey"))))
      (when match
        (let ((secret (plist-get match :secret)))
          (setenv "DEEPSEEK_API_KEY" (if (functionp secret)
                                            (funcall secret)
                                          secret)))))))

;; The keys must be in the environment before the ECA server process starts
(defun my/eca-process-setup-keys (&rest _)
  "Prepare the API keys before the ECA server process starts."
  (my/get-eca-api-key))

(with-eval-after-load 'eca
  (advice-add 'eca-process-start :before #'my/eca-process-setup-keys))

;; Define additional workspace paths you want to include
(defcustom my/eca-extra-workspaces
  '("~/git/mcp/"
    "~/git/agents/"
    "~/git/ma-emacs/"
    "~/git/shell/"
    "~/git/storm/"
    "~/git/tofu"
    "~/git/docker"
    "~/git/linux-ha"
    "~/.config/eca/"
    "~/.emacs.d/")
  "List of additional workspace directories to attach to ECA sessions."
  :type '(repeat directory)
  :group 'my)

(defun my/eca-attach-extra-workspaces ()
  "Attach `my/eca-extra-workspaces' to the current ECA session."
  (when (and (fboundp 'eca-session)
             (fboundp 'eca--session-add-workspace-folder))
    (when-let ((session (eca-session)))
      (dolist (dir my/eca-extra-workspaces)
        (let ((expanded-dir (expand-file-name dir)))
          (when (file-directory-p expanded-dir)
            (eca--session-add-workspace-folder session expanded-dir)))))))

;; Wrap the interactive command so decrypt happens BEFORE eca command executes
(defun my/eca ()
  "Decrypt authinfo key first, then launch ECA."
  (interactive)
  (my/get-eca-api-key)
  (call-interactively 'eca)
  (my/eca-attach-extra-workspaces))

;; Key binding to toggle ECA chat view
(defun my/eca-toggle ()
  "Toggle the ECA chat buffer visibility.
If an ECA chat buffer is visible, delete its window(s);
otherwise invoke `my/eca' to start or switch to the ECA session."
  (interactive)
  (let ((buf nil))
    (dolist (b (buffer-list))
      (when (and (null buf)
                 (string-prefix-p "<eca-chat[" (buffer-name b))
                 (not (string-suffix-p ":closed>" (buffer-name b))))
        (setq buf b)))
    (if (and buf (get-buffer-window buf t))
        (quit-windows-on buf)
      (my/eca))))

(keymap-global-set "<f7>" 'my/eca-toggle)  ;; Bind F7 to toggle ECA

;; `:vc' syntax depends on the Emacs version:
;; - Emacs >= 30: native use-package `:vc' takes a plain plist
;; - Emacs <  30: vc-use-package expects (PACKAGE :url ... :rev ...)
;; below code working @home
 (use-package eca
   :vc (:url "https://github.com/editor-code-assistant/eca-emacs" :rev :newest))
;; below code working @work
;; (use-package eca
;;   :vc (:fetcher github :repo "editor-code-assistant/eca-emacs" :rev :newest))

(defun my/reload-init-file ()
  "Reload the init file."
  (interactive)
  (load-file user-init-file))

(defun my/yank-or-scroll-up ()
  "Yank in a writable buffer, scroll up in a read-only one."
  (interactive)
  (if (or buffer-read-only (derived-mode-p 'special-mode))
      (scroll-up-command)
    (call-interactively #'yank)))

(keymap-global-set "C-c C-l" 'my/reload-init-file)
(keymap-global-set "C-c ;"   'comment-region)
(keymap-global-set "C-c ."   'uncomment-region)
(keymap-global-set "C-c SPC" 'copy-region-as-kill)
(keymap-global-set "C-c r"   'rectangle-mark-mode)
(keymap-global-set "C-v" 'my/yank-or-scroll-up)
(keymap-global-set "C-x SPC" 'kill-region)
(keymap-global-set "C-c t" 'toggle-truncate-lines)

(use-package marginalia
  :ensure t
  :init
  (marginalia-mode))

;; if needed https://github.com/cretinon/ma-cgr
(condition-case err
    (load "~/git/ma-cgr/ma-cgr.el" 'noerror)
  (error (display-warning 'init (format "ma-cgr: %s" err) :warning)))

;;; .emacs ends here
