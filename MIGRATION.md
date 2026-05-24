# Migration Guide — ARC Submission Compliance

**Who this is for:** Maintainers of any RISC-V specification repository under
`github.com/riscv/*` (ISA) or `github.com/riscv-non-isa/*` (non-ISA) that was
forked from `docs-spec-template` or shares its toolchain (Makefile +
`scripts/release-info.sh` + `.github/workflows/build-pdf.yml`).

**Why this exists:** ARC will reject specification submissions that do not
emit a PDF named `<short>-v<X.Y.Z>-<YYYYMMDD>.pdf` whose title page matches.
The upstream `docs-spec-template` now produces that format automatically,
and uses six canonical milestone IDs (`development-complete`, `stabilized`,
`frozen`, `ratification-ready`, `publication`, `ratified`). Downstream repos
need to pick up these changes — usually by syncing the same five files.

See `ARC_SUBMISSION.md` in this template repo for the policy itself.

## Pre-flight

- [ ] Read `ARC_SUBMISSION.md` to understand what your repo must emit.
- [ ] Confirm your repo's spec short name (e.g. `Zifoo`, `Server-Platform`,
      `RHTI`). This is the `<spec-short>` that appears in PDF filenames.
- [ ] Check the latest tag in your repo (`git tag --list 'v*' --sort=-version:refname | head -1`).
      Your next tag MUST be monotonically greater.
- [ ] **Do NOT rewrite or delete existing tags.** The policy is
      forward-looking; old artifacts stay as-is.

## Step 1 — Sync `scripts/release-info.sh`

Replace your script with the upstream version, or apply the following changes:

- [ ] Phase IDs switched from `Developed`/`Stable`/`Frozen`/`Ratification-Ready`/`Ratified`
      to the canonical (lowercase, hyphenated) IDs
      `development-complete`/`stabilized`/`frozen`/`ratification-ready`/`publication`/`ratified`.
- [ ] New `publication` band added at `v0.99.1+` (between `ratification-ready`
      at `v0.99.0` and `ratified` at `v1.0.0`).
- [ ] New helper `phase_display_for_phase` returns the title-case display
      label (e.g. `Stabilized`, `Ratification-Ready`) used on the title page.
- [ ] `revremark_for_phase` is now a thin wrapper that returns just the
      display label (e.g. `"Ratified"`), so asciidoctor-pdf renders
      `Version vX.Y.Z, YYYY-MM-DD: <Label>` on the title page.
- [ ] `display` CLI command returns the display label (title-case), not the
      canonical ID.
- [ ] `notice_for_phase`, `phase_floor_version`, `milestone_for_phase` all
      keyed on the new canonical IDs.
- [ ] `DEFAULT_PHASE` is `draft-and-development` (was `"Draft and Development"`).

Smoke test:
```bash
for v in v0.5.0 v0.6.0 v0.7.3 v0.8.0 v0.9.0 v0.99.0 v0.99.1 v1.0.0; do
  printf "%-10s phase=%-22s display=%s\n" "$v" \
    "$(./scripts/release-info.sh phase $v)" \
    "$(./scripts/release-info.sh display $v)"
done
```
Expected:
```
v0.5.0     phase=draft-and-development  display=Draft and Development
v0.6.0     phase=development-complete   display=Development Complete
v0.7.3     phase=development-complete   display=Development Complete
v0.8.0     phase=stabilized             display=Stabilized
v0.9.0     phase=frozen                 display=Frozen
v0.99.0    phase=ratification-ready     display=Ratification-Ready
v0.99.1    phase=publication            display=Publication
v1.0.0     phase=ratified               display=Ratified
```

## Step 2 — Update `Makefile`

- [ ] Set `SPEC_SHORT` near the top of the file. If your `DOCS` list has one
      `.adoc`, you can use:
      ```make
      SPEC_SHORT ?= $(basename $(firstword $(DOCS)))
      ```
      For repos where the spec short name differs from the .adoc basename,
      hard-code it:
      ```make
      SPEC_SHORT := Zifoo
      ```
- [ ] Add these variables:
      ```make
      DATE_STAMP := $(subst -,,$(DATE))
      VERSION_NUM := $(patsubst v%,%,$(VERSION))
      MILESTONE_ID ?= $(PHASE)
      ```
- [ ] Add `milestone_id` and `spec_short` attributes to the AsciiDoctor
      `OPTIONS` list:
      ```make
      -a milestone_id='${MILESTONE_ID}' \
      -a spec_short='${SPEC_SHORT}' \
      ```
- [ ] Add the `arc-rename` target and make `build-docs` depend on it:
      ```make
      .PHONY: ... arc-rename

      build-docs: $(DOCS_PDF) $(DOCS_HTML) arc-rename

      arc-rename: $(DOCS_PDF)
      	@for pdf in $(DOCS_PDF); do \
      		base=$$(basename $$pdf .pdf); \
      		dest="$$base-v$(VERSION_NUM)-$(DATE_STAMP).pdf"; \
      		if [ -f build/$$pdf ]; then \
      			mv build/$$pdf build/$$dest; \
      			echo "ARC submission PDF: build/$$dest"; \
      		fi; \
      	done
      ```

Smoke test (no Docker required):
```bash
make -n SKIP_DOCKER=true VERSION=v0.8.0 DATE=2026-06-12 | grep -E "(asciidoctor|ARC|dest=)"
```
Should show `dest="<short>-v0.8.0-20260612.pdf"`.

## Step 3 — Update `.github/workflows/build-pdf.yml`

- [ ] Replace `target_phase` enum values with the canonical IDs:
      ```yaml
      options:
        - auto-next
        - draft-and-development
        - development-complete
        - stabilized
        - frozen
        - ratification-ready
        - publication
        - ratified
      ```
- [ ] Add `v0.99.1` to the `OFFICIAL_RELEASE` case statement so entry into
      publication is treated as an official release:
      ```yaml
      case "${VERSION}" in
        v0.6.0|v0.8.0|v0.9.0|v0.99.0|v0.99.1|v1.0.0)
          echo "OFFICIAL_RELEASE=true" >> "$GITHUB_ENV" ;;
        *)
          echo "OFFICIAL_RELEASE=false" >> "$GITHUB_ENV" ;;
      esac
      ```
- [ ] Export `VERSION` and `DATE` in the build step so the Makefile picks
      them up:
      ```yaml
      - name: Build Files
        run: |
          set -euo pipefail
          export VERSION="${VERSION}"
          export DATE="$(date +%Y-%m-%d)"
          echo "Building ${VERSION} (${DATE})"
          make
      ```
- [ ] **No change needed** to upload globs — `path: build/*.pdf` and
      `files: build/*.pdf` will pick up the ARC-named PDF automatically.

## Step 4 — Update `.github/workflows/version-bot.yml` (if present)

- [ ] Replace `target_phase` enum values with the canonical IDs (same list
      as Step 3).
- [ ] No other changes required — the bot calls `release-info.sh` which
      already emits the new labels.

## Step 5 — Update your spec source `.adoc` files

- [ ] Update the `ifndef::phase[]` default to `draft-and-development`:
      ```adoc
      ifndef::phase[:phase: draft-and-development]
      ```
- [ ] Add defaults for the new attributes:
      ```adoc
      ifndef::milestone_id[:milestone_id: {phase}]
      ifndef::spec_short[:spec_short: <your-spec-short>]
      ```
- [ ] Switch the TOC to a macro placement so we can position it manually
      (so the Document State preface lands on page 2, TOC on page 3):
      ```adoc
      :toc: macro
      :toclevels: 4
      :toc-title: Table of Contents
      ```
      (Replaces `:toc: left` or `:toc: auto`.)
- [ ] Add a `Document State` preface as the FIRST preface, immediately
      followed by the explicit `toc::[]` placement. Remove any previous
      `WARNING`/`NOTE` admonition that surfaced the phase notice — its job
      is now done by this block:
      ```adoc
      [preface]
      == Document State
      *Note:* {phase_notice}

      toc::[]

      [preface]
      == List of figures
      list-of::image[hide_empty_section=true, enhanced_rendering=true]

      ...   // other prefaces follow as before
      ```
- [ ] **Do not** add a `WARNING` admonition for the phase notice anywhere
      else. The title-page revision line shows the milestone label
      automatically (via the new `revremark`); the `Document State` preface
      shows the full notice. Anything more is duplication.

## Step 6 — Verify

Build locally and inspect the output:
```bash
make VERSION=v0.8.0 DATE=2026-06-12
ls build/
```
You should see exactly one PDF named `<short>-v0.8.0-20260612.pdf`. Open it
and confirm:

- [ ] **Filename** contains short name, `v0.8.0`, and `20260612`.
- [ ] **Page 1 (title page)** ends with the line:
      `Version v0.8.0, 2026-06-12: Stabilized`.
- [ ] **Page 2** is a preface titled `Document State` whose only content is
      a `Note:` paragraph with the phase notice.
- [ ] **Page 3** is the Table of Contents (and includes `Document State`
      as its first entry).
- [ ] Page 4+ are the list-of-X prefaces and body content.

## Step 7 — Cut your next release

When you're ready to advance to the next milestone:

- [ ] Open the `Create Specification Document` workflow → `Run workflow`.
- [ ] Pick the target milestone from `target_phase` (or leave on `auto-next`
      for an intermediate patch tag).
- [ ] Confirm the resulting release has a single PDF whose name matches the
      ARC convention.
- [ ] Use the **GitHub Release URL** (not a branch or commit URL) in the ARC
      review request.

## Step 8 — Confirm with ARC (one-time)

- [ ] Reply on the ARC mailing list / Jira ticket that your repo is compliant
      with `ARC_SUBMISSION.md`, citing the URL of your first ARC-conformant
      release.

## Common gotchas

- **Existing pre-`v0.6.0` tags:** the script labels them `draft-and-development`,
  which is fine. No action needed.
- **Repos that don't use this template's Makefile:** you still need to emit a
  PDF named per §3.2 of `ARC_SUBMISSION.md` and a title page per §3.3.
  Adopting the template Makefile is the easiest way; otherwise replicate the
  naming logic in whatever build system you use.
- **Multi-document repos:** the `arc-rename` target loops over every PDF in
  `$(DOCS_PDF)`, so each gets renamed with its own basename + version + date.
  If two docs in one repo need to be ARC-submitted independently, the
  `SPEC_SHORT` heuristic uses the .adoc basename — verify that's the short
  name ARC expects.
- **GitHub Actions caching:** if you cache `build/` between runs, clear the
  cache once so the old `spec-sample.pdf` doesn't ghost the renamed output.
- **Don't rewrite tags.** Push a new monotonically-greater tag if you need to
  reissue.
- **`:toc: macro` requires explicit placement.** If you switch from
  `:toc: left` to `:toc: macro` and forget the `toc::[]` line, the PDF will
  build without a Table of Contents. Always pair the attribute change with
  the macro placement in Step 5.
- **No theme/submodule edits required.** The new layout is achieved entirely
  through the spec `.adoc`, the Makefile, and `release-info.sh`. Do not
  modify `docs-resources/themes/riscv-pdf.yml` — earlier drafts of this
  guide suggested editing the theme; the final approach does not.
- **Pre-existing in-body phase admonitions** (e.g. a `WARNING` block keyed
  on `{phase_display}`) MUST be removed when you add the `Document State`
  preface, or the phase notice will appear twice.

## Questions / help

`help@riscv.org` for ARC policy questions. Open an issue against
`riscv/docs-spec-template` for tooling/migration issues.
