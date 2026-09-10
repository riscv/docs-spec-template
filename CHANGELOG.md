# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**_NOTE:_** PROJECTS BUILT USING THE TEMPLATE SHOULD UPDATE THE BELOW SECTIONS AS-NEEDED.

## [Unreleased]
- Ship a working `.vale.ini`. It was committed as a 0-byte file, so Vale ran on
  every pull request and linted nothing — and because `UPGRADING.md` listed it as
  template-owned ("overwrite without reading the diff"), a repo following the
  upgrade procedure silently wiped its own Vale config. `.vale.ini` is now a
  **shared** file: `StylesPath`/`Packages` are template-owned, `BasedOnStyles`,
  `Vocab` and rule disables are yours.
- Fix `tests/release-info-test.sh` reporting 23 failures in a doc-mode repository.
  The phase assertions ran against the repo root, so they inherited its mode and
  compared spec-mode expectations against doc mode's (correct) empty strings. The
  suite now drives a copy of the script from a scratch repo with no `.docmode`,
  so it passes 78/78 in either mode.
- Correct `MIGRATION.md`'s doc-mode checklist, which told the reader to hand-edit
  `version-bot.yml` to add a `mode` output and gate `milestone-pr` on it. Both
  landed on `main` in #150; the instruction invited re-applying an edit that is
  already there.
- Keep the Antora site that the PR gate already builds, as a *Rendered site
  (Antora)* artifact, so reviewers can see a content change rendered
  (`validate-content-source.yml`). The cover logo is now staged from
  `docs-resources` for that build, so the start page renders standalone — which
  also means the gate validates the cover image macro instead of exception-listing
  it. Both build workflows now write a direct artifact link into the run summary.
- Publish the Antora HTML site to the repository's own GitHub Pages site on each
  `v*` release tag, alongside the release PDF (`publish-site.yml`,
  `scripts/build-pages-site.sh`). Requires a one-time *Settings > Pages >
  Source: GitHub Actions* by a repository admin. Does not replace the central
  docs.riscv.org site.

## [4.0.0] - 2004-01-27
- Workflow improvements
- Makefile refactoring
- Readme updates
