# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**_NOTE:_** PROJECTS BUILT USING THE TEMPLATE SHOULD UPDATE THE BELOW SECTIONS AS-NEEDED.

## [Unreleased]
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
