;;; .emacs --- Create GitHub repos safely from Emacs (auth-source) -*- lexical-binding: t; -*-

;; Author: Jacques Cretinon
;; Keywords: git, tools
;; Package-Requires: ((emacs "26.1"))
;; Version: 1.0

;;; Commentary:
;;
;; v1.0 include some snippets, miss some LLM and doc (.authinfo) but is usable

;;; Changelog:
;;
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
        ("nongnu"       . 0)))
(package-initialize)
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
 (package-install 'use-package))
(require 'use-package)

;; if we need to call debbuger on specific call
;;(debug-on-entry 'package-initialize)

;; if we need to refresh melpa pkg list
;;(package-refresh-contents)

;; Load and activate the Cyberpunk theme
(setq custom-file "~/.emacs.custom")
(load custom-file)

;; Load and activate the Cyberpunk theme
(use-package cyberpunk-theme
  :ensure t
  :init
  (load-theme 'cyberpunk t))

;; Disable unnecessary UI elements
(tool-bar-mode -1)   ;; Disable the tool bar
(scroll-bar-mode -1) ;; Disable the scroll bar
(menu-bar-mode 1)    ;; Enable the menu bar
(tab-line-mode 1)    ;; Enable the tab line
(transient-mark-mode 1) ;; Enable transient mark mode for visual feedback in selections
(setq-default inhibit-splash-screen t) ;; Prevent the splash screen from appearing at startup
(fset 'yes-or-no-p 'y-or-n-p) ;; Replace yes/no prompts with y/n for convenience

;; Enable global whitespace mode with preferred styles (shwo special char)
(require 'whitespace)
(setq-default whitespace-style '(face trailing tabs empty indentation::space))
(global-whitespace-mode 1)
;; Do not use tab for indentation
(setq-default indent-tabs-mode nil) ;; Use spaces instead of tabs for indentation

;; Use package management for managing plugins
(use-package all-the-icons
  :ensure t
  :defer
  ;; Ensure icons are only loaded in a graphical environment
  :if (display-graphic-p)
  :init
  ;; Install the all-the-icons fonts if not already installed
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

(use-package neotree
  :ensure t
  :bind ("<f5>" . neotree-toggle)  ;; Bind F5 for toggling NeoTree
  :hook (emacs-startup . neotree)  ;; Open NeoTree on startup
  :custom
  (neo-theme 'icons)                ;; Use icon theme for NeoTree
  (neo-smart-open t)                ;; Smart open behavior
  (neo-autorefresh t)               ;; Auto-refresh the tree
  (neo-window-width 35)             ;; Set window width for NeoTree
  (neo-toggle-window-keep-p t)      ;; Keep window position after toggling
  (neo-show-hidden-files t)         ;; Show hidden files

  ;; Performance configuration - disable VC integration if slow
  ;; (neo-vc-integration '(face char))

  ;; Custom display function for the NeoTree buffer
  (neo-display-action '(gopar/neo-display-fn))
  :init
  (defun gopar/neo-display-fn (buffer _alist)
    ;; Display NeoTree buffer in a side window
    (let ((window-pos (if (eq neo-window-position 'left) 'left 'right)))
      (display-buffer-in-side-window buffer `((side . ,window-pos)
                                              (inhibit-same-window . t)
                                              (dedicated . t)
                                              (window-parameters
                                               (no-delete-other-windows . t)
                                               (no-other-window . t)))))))

;; Configure the tab bar appearance and behavior
(setq tab-bar-close-button-show nil
      tab-bar-separator "|"
      tab-bar-format '(tab-bar-format-tabs-groups
                       tab-bar-separator
                       tab-bar-format-align-right
                       tab-bar-format-global))

(defun my/sync-tab-bar-to-theme ()
  "Synchronize tab-bar faces with the current theme."
  (interactive)
  (let ((default-bg (face-background 'default))
        (default-fg (face-foreground 'default))
        (inactive-fg (face-foreground 'mode-line-inactive)))
    (custom-set-faces
     `(tab-bar ((t (:inherit default :background ,default-bg :foreground ,default-fg))))
     `(tab-bar-tab ((t (:inherit default :background ,default-fg :foreground ,default-bg))))
     `(tab-bar-tab-inactive ((t (:inherit default :background ,default-bg :foreground ,inactive-fg)))))))

;; Activate the tab bar mode and sync its appearance with the theme
(my/sync-tab-bar-to-theme)
(tab-bar-mode 1)

;; Bind keys for navigating tabs easily
(global-set-key (kbd "<f3>") 'tab-previous)
(global-set-key (kbd "<f4>") 'tab-next)

;; Highlight indentation levels for better code readability
(use-package indent-guide
  :ensure t
  :init
  ;; Enable indent guide globally
  (indent-guide-global-mode t))

;; Display line numbers in programming modes for easier navigation
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

;; PuTTY Configuration for Enhanced Key Mapping
;; Specific settings are required for using Emacs over PuTTY.
;; Ensure PuTTY is set to SCO mode and the terminal is configured as xterm-256color.
(if (eq system-uses-terminfo t)
    (progn
      ;; Redefine the Escape key as Meta
      (define-key key-translation-map [\e] [\M])

      ;; Map function keys and navigation keys for terminal compatibility
      (define-key input-decode-map "\e[H" [home])
      (define-key input-decode-map "\e[F" [end])
      (define-key input-decode-map "\e[D" [S-left])
      (define-key input-decode-map "\e[C" [S-right])
      (define-key input-decode-map "\e[A" [S-up])
      (define-key input-decode-map "\e[B" [S-down])
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

;; Use xterm-color for proper ANSI color support in compilation buffers
(use-package xterm-color
  :ensure t)

;; Set the compilation environment to use xterm-256color
(setq compilation-environment '("TERM=xterm-256color"))

;; Enable mouse support in terminal
(xterm-mouse-mode t)

;; UTF-8 Configuration for comprehensive encoding support
(define-coding-system-alias 'UTF-8 'utf-8)
(set-charset-priority 'unicode)
(setq locale-coding-system 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(set-selection-coding-system 'utf-8)
(prefer-coding-system 'utf-8)
(setq default-process-coding-system '(utf-8-unix . utf-8-unix))

;; Manage Emacs directories for backups and temporary files
(let ((backup-dir "~/.emacs.d/backups")           ;; Backup directory
      (auto-saves-dir "~/.emacs.d/auto-saves/")   ;; Auto-save directory
      (temporary-file-directory "~/.emacs.d/tmp/")) ;; Temporary files directory
  ;; Create directories if they do not exist
  (dolist (dir (list backup-dir auto-saves-dir temporary-file-directory))
    (unless (file-directory-p dir)
      (make-directory dir t)))

  ;; Set Emacs to use the specified directories for backups and auto-saves
  (setq backup-directory-alist `(("." . ,backup-dir))
        auto-save-file-name-transforms `((".*" ,auto-saves-dir t))
        auto-save-list-file-prefix (concat auto-saves-dir ".saves-")
        tramp-backup-directory-alist `((".*" . ,backup-dir))
        tramp-auto-save-directory auto-saves-dir))

(setq backup-by-copying t    ;; Don't delink hardlinks
      delete-old-versions t  ;; Clean up the backups
      version-control t      ;; Use version numbers on backups
      kept-new-versions 5    ;; Keep some new versions
      kept-old-versions 2)   ;; Keep some old versions

;; Enable features for better usability
(save-place-mode 1)                     ;; Remember cursor position when closing files
(global-auto-revert-mode 1)             ;; Refresh buffer if modified on disk
(add-hook 'before-save-hook 'delete-trailing-whitespace) ;; Remove trailing whitespace before saving

;; JSON mode configuration
(use-package json-mode
  :ensure t
  :init)
(add-to-list 'auto-mode-alist '("\\.json\\'" . json-mode)) ;; Associate .json files with json-mode

;; YAML mode configuration
(use-package yaml-mode
  :ensure t
  :init)
(add-to-list 'auto-mode-alist '("\\.yaml\\'" . yaml-mode)) ;; Associate .yaml files with yaml-mode

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
  :mode ("README\\.md\\'" . gfm-mode)  ;; Associate README.md with gfm-mode
  :init (setq markdown-command "multimarkdown") ;; Set the markdown command
  :bind (:map markdown-mode-map
              ("C-c C-e" . markdown-do))) ;; Keybinding for markdown-do

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
  :init
  (pdf-tools-install) ;; Install pdf-tools
  :config
  (add-hook 'pdf-isearch-minor-mode-hook (lambda () (ctrlf-local-mode -1)))
  (use-package org-pdftools
    :ensure t
    :hook (org-mode . org-pdftools-setup-link)))
(add-to-list 'auto-mode-alist '("\\.[pP][dD][fF]\\'" . pdf-view-mode)) ;; Associate PDF files with pdf-view-mode

;; PlantUML mode
;; prerequisite is to have downloaded plantuml.jar at https://github.com/plantuml/plantuml/releases/latest/download/plantuml.jar
(use-package plantuml-mode
  :ensure t)  ; For syntax highlighting (optional)

;; Enable Babel support
(org-babel-do-load-languages
 'org-babel-load-languages
 '((plantuml . t)))

;; Set JAR path
(setq org-plantuml-jar-path "~/plantuml/plantuml.jar")

;; Allow local emacs variable to be set in the file
(setq enable-local-variables :all
      enable-local-eval t)

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
  (setq yas-snippet-dir "~/.emacs.d/snippets")) ;; Specify the directory for snippets

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
  :ensure t)
(unless (display-graphic-p)                ;; Enable corfu-terminal mode only if not in a graphical session
  (corfu-terminal-mode +1))

;; Dabbrev configuration for buffer completion
(use-package dabbrev
  :ensure t
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
  :init
  (defun magit/undo-last-commit (number-of-commits)
    "Undoes the latest commit(s) without losing changes."
    (interactive "P")  ;; Prompt for the number of commits to undo
    (let ((num (if (numberp number-of-commits)
                   number-of-commits
                 1)))  ;; Default to 1 if not specified
      (magit-reset-soft (format "HEAD^%d" num))))  ;; Perform a soft reset to undo commits
  :config
  (require 'magit)  ;; Ensure Magit is loaded

  ;; Buffer display customizations for better navigation
  (defvar my/magit-status-height-ratio 0.8
    "Ratio of frame height for Magit status window.")  ;; Height ratio for status window

  (defvar my/magit-process-width-ratio 0.5
    "Ratio of Magit status window width for Magit process window.")  ;; Width ratio for process window

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
  ;; Uncomment below to automatically insert Jira ticket numbers
  ;; :hook (git-commit-setup . gopar/auto-insert-jira-ticket-in-commit-msg)
  :custom
  (git-commit-summary-max-length 80)  ;; Set maximum length for commit summary
  :init)

;; Git gutter configuration for showing diffs in the fringe
(use-package git-gutter
  :ensure t  ;; Ensure git-gutter is installed
  :hook (after-init . global-git-gutter-mode))  ;; Enable git-gutter mode after initialization

;; Key binding for quick access to Magit status
(global-set-key (kbd "<f6>") 'magit)  ;; Bind F6 to invoke Magit

;; Allow Magit to search in authinfo for user/password
(add-hook 'magit-process-find-password-functions
          'magit-process-password-auth-source)

;; Forge integration for enhanced Magit functionality (commented out due to installation issues)
(use-package forge
  :ensure t
  :init)

;; check syntax
(use-package flycheck
  :ensure t
  :config
  (add-hook 'after-init-hook 'global-flycheck-mode))

;; gptel
(use-package gptel
  :ensure t
  :init)

(require 'gptel-org) ;; Ensure gptel-org module is loaded

(setq gptel-default-mode 'org-mode)

(setq gptel-openai-backend
      (gptel-make-openai "OpenAI"
        :host "api.openai.com"
        :models '("gpt-4o-mini" "gpt-4.1" "o4-mini")))

(setq gptel-gemini-backend
      (gptel-make-gemini "Gemini"
        :key #'gptel-api-key-from-auth-source
        :stream t
        :host "generativelanguage.googleapis.com"
        :models '("gemini-2.5-flash")))

(setq gptel-copilot-backend
      (gptel-make-gh-copilot "Copilot Chat"))


(setq gptel-mistral-backend
      (gptel-make-openai "Mistral"
        :key #'gptel-api-key-from-auth-source
        :host "api.mistral.ai"
        :models '("mistral-medium" "mistral-large")))

(defun reload-init-file ()
  (interactive)
  (load-file user-init-file))

(global-set-key (kbd "C-c C-l") 'reload-init-file)
(global-set-key (kbd "C-c ;")   'comment-region)
(global-set-key (kbd "C-c .")   'uncomment-region)
(global-set-key (kbd "C-c SPC") 'copy-region-as-kill)
(global-set-key (kbd "C-v") 'yank)
(global-set-key (kbd "C-x SPC") 'kill-region)
(global-set-key (kbd "C-c t") 'toggle-truncate-lines)

(use-package marginalia
  :ensure t
  :init
  (marginalia-mode))

(provide '.emacs)
