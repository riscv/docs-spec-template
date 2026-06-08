# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**_NOTE:_** PROJECTS BUILT USING THE TEMPLATE SHOULD UPDATE THE BELOW SECTIONS AS-NEEDED.

## [Unreleased]

## [5.0.0] - 2026-06-08

### Added
- `antora.yml` — Antora component descriptor at the repository root. Authors must update `name` and `title` to match their specification.
- `modules/ROOT/nav.adoc` — Antora navigation file defining the sidebar structure for the documentation site.
- `modules/ROOT/images` — Symlink to `docs-resources/images` so Antora can locate shared images within the module tree.
- `modules/ROOT/pages/` — Antora-standard content directory. All AsciiDoc source files moved here from `src/`.
- `antora-playbook.yml` — Local Antora playbook for previewing the specification as a multi-page HTML site via `make antora`.
- `antora` Makefile target — Builds a local Antora site to `build/site/`. Uses system `antora` or falls back to `npx antora`.
- `node_modules/` and `.cache/` added to `.gitignore` for Antora build artifacts.

### Changed
- Moved all AsciiDoc source files and `example.bib` from `src/` to `modules/ROOT/pages/`.
- `Makefile` `SRC_DIR` updated from `src` to `modules/ROOT/pages`.
- `modules/ROOT/pages/spec-sample.adoc` — Updated `docs-resources` relative paths to reflect new depth within the Antora module tree, and updated `bibtex-file` path accordingly.

## [4.0.0] - 2004-01-27
- Workflow improvements
- Makefile refactoring
- Readme updates
