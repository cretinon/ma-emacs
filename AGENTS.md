# AI Agent Guidelines - ma-emacs

Personal Emacs configuration maintained as a literate programming setup.

## Project Structure & Architecture
- **`.emacs`**: Primary initialization file loaded by Emacs. Must stay in sync with `README.org`.
- **`README.org`**: Literate source of truth for `.emacs`. Code blocks are tangled to form the configuration.
- **`gemini.org`**, **`mistral.org`**, **`openai.org`**: Dedicated Org buffers for `gptel` interactions with file-local backend/model settings.
- **`plantuml.org`**: Guide for PlantUML Deployment and Network diagrams.

## Critical Gotchas & Constraints
- **Keep `.emacs` and `README.org` in Sync**: Any additions, removals, or edits inside `.emacs` must be meticulously mirrored and documented in `README.org`.
- **Code Block Headers**: Org Babel blocks in `README.org` intended for Emacs configuration must use `#+BEGIN_SRC emacs-lisp` (not `elisp`, which is ignored by tangle settings).
- **Lexical Binding**: First line of `.emacs` must be `;; -*- lexical-binding: t; -*-`. All Elisp code must support lexical binding.
- **Custom File**: Redirected to `~/.emacs.custom` (`(setq custom-file "~/.emacs.custom")`). Never write custom-set variables or faces into `.emacs`.

## Verification & Tangle Commands
To tangle `README.org` and check synchronization with `.emacs`:
```bash
# Tangle README.org to temporary file and check diff with .emacs
cp README.org /tmp/README.org
sed -i 's/#+PROPERTY: header-args:emacs-lisp :results output :exports both/#+PROPERTY: header-args:emacs-lisp :results output :exports both :tangle yes/g' /tmp/README.org
emacs --batch -l org --eval '(org-babel-tangle-file "/tmp/README.org")'
tail -n +18 .emacs > /tmp/dot_emacs_stripped.el
diff -u /tmp/README.el /tmp/dot_emacs_stripped.el
```

## Formatting & Style Rules
- **Indentation**: Strictly 2 spaces. No tabs (`(setq-default indent-tabs-mode nil)`).
- **Trailing Whitespace**: Automatically stripped on save except in `org-mode`, `markdown-mode`, and `gfm-mode`.
- **Table of Contents**: Update Org TOCs with `M-x org-make-toc` or `org-make-toc-mode`.

### Documenting Sections in `README.org`
Every level-3 heading (`***`) in `README.org` must include:
- **`- *Purpose*:`** Brief description of why this package/config is needed (max 2 lines).
- **`- *Functionality*:`** Bulleted summary of what the code does (max 2 lines per item).
- **`- *Usage*:`** Specific keybindings or triggers (max 2 lines per item).

*Example:*
```org
*** Go mode
:PROPERTIES:
:CUSTOM_ID: go-mode
:END:
- *Purpose*: Provides programming-mode support for the Go language.
- *Functionality*:
  - Configures `go-mode` with syntax highlighting and file association.
- *Usage*: Opens automatically when loading files with a `.go` extension.
```

## LLM & gptel Directives
When generating code or responding in this repository:
- **Conciseness**: Keep responses as concise as possible.
- **Language**: Always answer in English, even if queried in French.
- **Source Freshness**: If referencing sources older than 1 year, prepend `"WARNING OLD SOURCES"`.
- **Bash Scripts**: Divide bash scripts into modular functions and provide an accompanying BATS test script.
- **Documentation**: Always include at least one official documentation link.

## Search & Research Order Directive
When searching information or solving tasks, follow this search order:
1. **Local Documentation**: First, search through local documentation files (`*.org`, `*.md`, `README.org`).
2. **Web Documentation**: Second, search external/web documentation using available tools.
3. **Codebase**: Third, search source code files across the repository.

### Custom Code Review (`my/gptel-review-code`) Format:
- Use strict Org-mode syntax starting with a Table of Contents.
- Perform function-by-function analysis (bugs, security, performance).
- Provide correcting code examples in `#+BEGIN_SRC <language>` blocks for every bug found.
