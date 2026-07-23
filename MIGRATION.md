# Migration Guide — ARC PDF + Antora Site

**Who this is for:** Maintainers of any RISC-V specification repository under
`github.com/riscv/*` (ISA) or `github.com/riscv-non-isa/*` (non-ISA) that was
forked from `docs-spec-template` or shares its toolchain (Makefile +
`scripts/release-info.sh` + `.github/workflows/build-pdf.yml`).

**Why this exists:** the template now produces **two** artifacts from **one**
source tree, and a spec author needs both:

1. **The ARC submission PDF.** ARC rejects submissions that do not emit a PDF
   named `<short>-v<X.Y.Z>-<YYYYMMDD>.pdf` whose title page matches, using six
   canonical milestone IDs (`development-complete`, `stabilized`, `frozen`,
   `ratification-ready`, `publication`, `ratified`).
2. **The Antora HTML site.** Chapter content is consumed as a *content source*
   by the RISC-V central playbook and published on antora.riscv.org. The ARC
   Author Guide requires the site version to match the PDF version **exactly**.

Parts A and C below are the PDF; Part B is the site. **Do not stop after Part
A** — a repo that does gets a compliant PDF and no site.

**Related docs:** `ARC_SUBMISSION.md` is the ARC policy itself. `ANTORA.md`
explains *how* the dual build works and *why* it is designed this way — read its
"Dual-source technique" and "Production model" sections before Part B. This guide
is the sequence of actions; ANTORA.md is the rationale.

## Pre-flight

- [ ] Read `ARC_SUBMISSION.md` to understand what your repo must emit.
- [ ] Skim `ANTORA.md` §"The dual-source technique" and §"Production model".
- [ ] Confirm your repo's spec short name (e.g. `Zifoo`, `Server-Platform`,
      `RHTI`). This is the `<spec-short>` that appears in PDF filenames.
- [ ] Check the latest tag in your repo (`git tag --list 'v*' --sort=-version:refname | head -1`).
      Your next tag MUST be monotonically greater.
- [ ] **Do NOT rewrite or delete existing tags.** The policy is
      forward-looking; old artifacts stay as-is.

> **Scope warning.** This is no longer a "sync a few files" job. Part B moves
> your chapter sources on disk. Do it on a branch, and expect to touch
> `antora.yml`, `antora-playbook.yml`, `modules/ROOT/nav.adoc`, `package.json`,
> `docker-compose.yml`, `scripts/stamp-antora-version.sh`, and
> `.github/workflows/validate-content-source.yml` in addition to the PDF files.

---

# Choose your mode

This template runs in two modes (see `ANTORA.md` §"Template modes"), selected by
the committed `.docmode` file:

- **`spec` mode** (default) — ratified RISC-V specifications on the ARC/P&P
  process. Follow **all** of Parts A, B, and C below.
- **`doc` mode** — non-ratified documentation that still needs the PDF, the
  Makefile HTML, and the Antora site, but **no** ratification layer (no milestone
  phases, no "Document State" preface, no ARC submission). Example:
  [`riscv/docs-dev-guide`](https://github.com/riscv/docs-dev-guide).

Parts A and C are written for `spec` mode. **Doc-mode migrators**: use the
condensed checklist below instead of reading A/C top to bottom — the toolchain is
already mode-aware, so most of the work is the shared Antora layout in Part B.

## Doc-mode checklist

1. [ ] **Set the mode.** Add a `.docmode` file at the repo root containing
       `doc`. This single file makes `release-info.sh`, the `Makefile`, the stamp
       script, and CI all skip the ratification layer. (An admin creating a fresh
       repo from the template does this once; a migrating repo adds it here.) If a
       repo already has an `antora.yml`, prefer `make set-mode MODE=doc`, which
       flips `.docmode` **and** reconciles the descriptor's `page-phase*` block in
       one step; the mode is reversible either way.
2. [ ] **Sync the toolchain** (Part A, Steps 1–3): take the upstream
       `scripts/release-info.sh`, `Makefile`, and `.github/workflows/build-pdf.yml`.
       They read `.docmode` and neutralize the phase/milestone surface
       automatically — you do **not** need the ARC milestone semantics.
3. [ ] **Update your top-level `.adoc` assembler** (Part A, Step 5) to the
       dual-source form, **and** wrap the ratification-only bits in
       `ifndef::doc-mode[] … endif::[]`: the `[preface] == Document State` block
       and the `spec-state` `revremark` default (see `src/spec-sample.adoc` for
       the exact guards).
4. [ ] **Do the whole of Part B** (the Antora site): dual-source layout,
       `antora.yml`, `modules/ROOT/nav.adoc`, local preview tooling, central
       playbook registration, and the content-source CI gate. **One difference:**
       in `antora.yml`, omit the `page-phase`, `page-phase-display`, and
       `page-phase-notice` attributes — doc mode has no phase. The cover page and
       stamp script already tolerate their absence.
5. [ ] **Skip Part C** (ARC submission) and `SPEC_STATE.md` / `ARC_SUBMISSION.md`
       — they do not apply. Cut releases by tagging `vX.Y.Z`; the PDF and site
       version track the tag + build date, and version-bot does plain patch bumps
       (no milestone PRs).
6. [ ] **Verify** (Part B, Step 6 + the site steps): `make` produces a PDF with
       **no** "Document State" page; `npm run preview` renders a cover with no
       phase banner.

---

# Part A — ARC PDF compliance *(spec mode; doc mode: see the checklist above)*

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

This script is the single source of version/phase truth for **both** artifacts —
the PDF build and the Antora version stamp (Step 12) both call it. Sync it first.

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

> ⚠ **Do not copy the upstream Makefile wholesale into a flat-layout repo.**
> The template's Makefile assumes the Part B layout: it sets `SRC_DIR := src`
> and uses `vpath %.adoc $(SRC_DIR)` to find the assembler, and its
> `stamp-antora` target calls a script that only exists once you have
> `antora.yml`. Copying it before you do Part B gives you a build that hunts
> for sources in a `src/` directory you don't have. Either apply the changes
> below by hand now and copy wholesale after Part B, or do Part B first.

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
- [ ] This workflow also carries the site version stamp once you do Part B —
      see Step 12. Sync the whole upstream file if you can; it resolves
      `VERSION`/`DATE` once and shares them between the PDF build and the stamp
      so the two cannot drift apart by a date boundary.

## Step 4 — Update `.github/workflows/version-bot.yml` (if present)

- [ ] Replace `target_phase` enum values with the canonical IDs (same list
      as Step 3).
- [ ] No other changes required — the bot calls `release-info.sh` which
      already emits the new labels.

## Step 5 — Update your top-level spec `.adoc`

This is the file listed in the Makefile's `DOCS`. In a flat-layout repo it sits
at the repo root; after Part B it is the **PDF assembler** at
`src/<spec-short>.adoc` (in this template, `src/spec-sample.adoc`). The edits
are the same either way — only the path changes.

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

## Step 6 — Verify the PDF

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

---

# Part B — Antora site

Your chapter content becomes the single source for both artifacts. Read
`ANTORA.md` §"The dual-source technique" first if you haven't — the short version
is that chapters live once as standalone Antora pages with a level-0 `= Title`,
and the PDF assembler includes them with `leveloffset=+1` so those titles become
PDF chapters.

## Step 7 — Adopt the dual-source layout

Target layout (see `ANTORA.md` §"Repository layout"):

```
antora.yml                       # component descriptor (keep MINIMAL)
antora-playbook.yml              # LOCAL preview playbook only
modules/ROOT/
  nav.adoc                       # site navigation
  pages/                         # single source of chapter content
    index.adoc                   #   site landing/cover (NOT in the PDF)
    intro.adoc  chapter2.adoc  contributors.adoc  bibliography.adoc
  resources/<spec>.bib           # bibliography database
src/<spec-short>.adoc            # PDF assembler (Makefile DOCS target)
```

- [ ] Move each chapter `.adoc` to `modules/ROOT/pages/`. Each must start with
      a level-0 `= Title` and must be valid standalone (no reliance on
      attributes defined by the old master document).
- [ ] Move your master `.adoc` to `src/` and reduce it to an assembler: the
      document header, the prefaces, and `include::../modules/ROOT/pages/<page>.adoc[leveloffset=+1]`
      lines. Keep the Step 5 edits.
- [ ] Keep **PDF-only constructs in the assembler only** — never in a page:
      the `include::../docs-resources/global-config.adoc[]` cross-repo relative
      include (it breaks under Antora), the back-of-book `[index] == Index`
      macro, and `:title-logo-image:` / `:pdf-theme:` / `:pdf-fontsdir:` /
      `:doctype: book`.
- [ ] Add `SRC_DIR := src` and `vpath %.adoc $(SRC_DIR)` to the Makefile, and
      point `DOCS` at the assembler's basename.
- [ ] Create `modules/ROOT/pages/index.adoc` as the site landing/cover page. It
      is the Antora `start_page` and does **not** appear in the PDF. Build it on
      the ratified-spec cover pattern: logo, title, the version line
      `Version {page-revnumber}, {page-revdate}: {page-phase-display}`, and a
      phase banner linking to riscv.org/spec-state. Never hardcode a version —
      those attributes are stamped in Step 12.
- [ ] Confirm the boundary holds:
      ```bash
      grep -rn "docs-resources" modules/ && echo "LEAK: docs-resources referenced under modules/"
      ```
      This should print nothing.

## Step 8 — Add `antora.yml`

Copy the template's and edit `name`/`title`. **Keep it minimal.** The central
playbook supplies shared attributes and extensions uniformly to every spec;
anything you set here *overrides* the playbook and desyncs your spec from the
rest of the library — notably `sectnums`, which the central section-numbering
extension owns.

- [ ] `name`, `title` — yours.
- [ ] `version: v0.0.0` — placeholder; stamped at release (Step 12). Do not
      hand-edit thereafter.
- [ ] `nav:` → `- modules/ROOT/nav.adoc`.
- [ ] `asciidoc.attributes.asamBibliography: 'ROOT:resources/<spec>.bib'` if you
      use `cite:`/`bibliography::[]`. Without it the central ASAM extension
      no-ops and citations render as raw text. Note this is a *second*,
      independent pointer to the same bib — the assembler's `:bibtex-file:`
      serves the PDF. Both are required.
- [ ] Do **not** add rendering attributes (`sectnums`, `doctype`, `icons`,
      `xrefstyle`, `source-highlighter`, …). Preview-only rendering config goes
      in `antora-playbook.yml`.

## Step 9 — Add `modules/ROOT/nav.adoc`

- [ ] One `xref:` entry per page, in reading order, landing page first.
- [ ] Keep the header comment warning about line-number coupling (Step 11).

## Step 10 — Add local preview tooling

- [ ] `antora-playbook.yml` — the **local preview** playbook. It mirrors
      production's extensions and attributes so what you see locally matches the
      site. It is not what builds the real site.
- [ ] `package.json` — pins the preview toolchain as devDependencies rather than
      relying on a global `antora`. **Version constraint:** `asciidoctor-kroki`
      must be `0.18.1` (what the central playbook uses); `1.0.0` requires a newer
      Asciidoctor.js than Antora 3.1.x bundles and dies with
      `block.$!= is not a function`.
- [ ] `docker-compose.yml` — a local Kroki on `localhost:9870` (the port must
      match the playbook's `kroki-server-url`), so diagrams render without
      shipping source to a public Kroki instance.
- [ ] Verify the preview:
      ```bash
      npm install
      docker compose up -d kroki
      npm run preview            # antora --fetch antora-playbook.yml -> build/site/
      docker compose down
      ```
      Expect exit 0. A warning about an unresolved `common::` image is expected
      in bare local preview — that asset only resolves in the central build.

## Step 11 — Register with the central playbook

The canonical site is built **elsewhere**, by `riscv-admin/antora.riscv.org`
(dev mirror: `riscv-admin/antora-dev.riscv.org`). Your repo is a content source.
Nothing you do locally publishes anything.

- [ ] Push your branch first — Antora fetches from GitHub, not your worktree.
- [ ] Add your repo to `content.sources:` in the site playbook:
      ```yaml
        - url: https://github.com/riscv/<your-repo>.git
          branches: <your-branch>       # later: main, or release tags
          start_page: ROOT::index.adoc
          start_path: /
      ```
      No `nav:` key needed — `antora.yml` declares it.
- [ ] Add a `numbering_rules` entry, or your spec renders with wrong or missing
      chapter numbers. **The `chapters: {start, end}` values are line numbers in
      your `nav.adoc`, not chapter numbers** — the extension scans nav lines and
      each line in the range matching `^*+ xref:…[` becomes a chapter, numbered
      from 1:
      ```yaml
      - component: <your-component>
        module: ROOT
        branches: ['<your-branch>']
        chapters: {start: <first-chapter-line>, end: <last-chapter-line>}
      ```
      Exclude the landing page and any unnumbered front/back matter
      (contributors, bibliography) from the range.
- [ ] ⚠ **This rule is line-coupled.** Adding, removing, or reordering nav
      entries — or editing the nav header comments — shifts the line numbers and
      silently drifts site numbering. Update the central rule in lockstep, and
      update `branches:`/`tags:` whenever you change where the spec is consumed
      from. See `ANTORA.md` §"Section numbering".

## Step 12 — Add the version bridge

The site version must equal the PDF version exactly. Antora reads a **static**
`version:` from the committed `antora.yml` — the central playbook just fetches
your branch and never runs `release-info.sh` — so a release has to stamp that
file.

- [ ] Add `scripts/stamp-antora-version.sh` and the Makefile target:
      ```make
      stamp-antora:
      	./scripts/stamp-antora-version.sh "$(VERSION)" "$(DATE)"
      ```
      It writes `version:` plus the cover attributes (`page-revnumber`,
      `page-revdate`, `page-phase`, `page-phase-display`, `page-phase-notice`)
      from `release-info.sh` — the same source the PDF uses, so the two cannot
      diverge. It is idempotent and preserves comments and nav.
- [ ] Sync the upstream `build-pdf.yml` `stamp-site-version` job. On every real
      release (it skips PR previews and drafts) it stamps `antora.yml` and opens
      a **review PR** against `main` titled
      `Stamp Antora site version vX.Y.Z to match released PDF`. It is monotonic —
      it will not stamp `main` backwards when an older tag is rebuilt.
- [ ] **Merging that PR is part of cutting a release** (Step 14). Until it
      merges, the site version lags the released PDF. It deliberately opens a PR
      rather than pushing to `main` directly so it works whatever branch
      protection your repo has — a rejected push would leave the release green
      and the site silently stale.
- [ ] Verify:
      ```bash
      make stamp-antora VERSION=v0.8.0 DATE=2026-06-12
      git diff antora.yml     # version: v0.8.0, page-phase-display: 'Stabilized'
      ```
      Then restamp to your repo's real state before committing.

## Step 13 — Add the CI content-source gate

- [ ] Add `.github/workflows/validate-content-source.yml`. It builds **your
      component in isolation** via `antora-playbook.yml` on PRs, so broken
      AsciiDoc, unresolved intra-component xrefs/includes, and extension errors
      fail in your repo instead of stalling the shared central library build. It
      does **not** build or deploy the real site.
- [ ] Exception-list cross-component references (`common::risc-v_logo.svg`,
      xrefs into other specs). These resolve only in the central multi-source
      build and are *expected* to be unresolved here.

---

# Part C — Release and submit *(spec mode only; doc mode: tag `vX.Y.Z` and skip)*

## Step 14 — Cut your next release

When you're ready to advance to the next milestone:

- [ ] Open the `Create Specification Document` workflow → `Run workflow`.
- [ ] Pick the target milestone from `target_phase` (or leave on `auto-next`
      for an intermediate patch tag).
- [ ] Confirm the resulting release has a single PDF whose name matches the
      ARC convention.
- [ ] **Review and merge the site version stamp PR** the release opened
      (`Stamp Antora site version vX.Y.Z to match released PDF`). The site
      version does not track the PDF until you do. The values are generated from
      `release-info.sh`, so this wants a merge, not an edit.
- [ ] After it merges, confirm the site renders at `/<component>/<version>/` with
      a cover reading `Version vX.Y.Z, YYYY-MM-DD: <Display>` — identical to the
      PDF title page.
- [ ] **Releasing locally or offline?** The CI stamp doesn't run, so do it by
      hand or the site version silently lags the PDF:
      ```bash
      make stamp-antora VERSION=vX.Y.Z
      git add antora.yml && git commit -m "Stamp site version vX.Y.Z"
      ```
- [ ] If you changed `nav.adoc` this cycle, re-check the central
      `numbering_rules` entry (Step 11) — including its `branches:`/`tags:`.
- [ ] Use the **GitHub Release URL** (not a branch or commit URL) in the ARC
      review request.

## Step 15 — Confirm with ARC (one-time)

- [ ] Reply on the ARC mailing list / Jira ticket that your repo is compliant
      with `ARC_SUBMISSION.md`, citing the URL of your first ARC-conformant
      release.

## Common gotchas

### PDF

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
  cache once so the old un-renamed PDF doesn't ghost the renamed output.
- **Don't rewrite tags.** Push a new monotonically-greater tag if you need to
  reissue.
- **`:toc: macro` requires explicit placement.** If you switch from
  `:toc: left` to `:toc: macro` and forget the `toc::[]` line, the PDF will
  build without a Table of Contents. Always pair the attribute change with
  the macro placement in Step 5.
- **No theme/submodule edits required.** The PDF layout is achieved entirely
  through the assembler `.adoc`, the Makefile, and `release-info.sh`. Do not
  modify `docs-resources/themes/riscv-pdf.yml`.
- **Pre-existing in-body phase admonitions** (e.g. a `WARNING` block keyed
  on `{phase_display}`) MUST be removed when you add the `Document State`
  preface, or the phase notice will appear twice.

### Site

- **Don't copy the upstream Makefile into a flat-layout repo.** See the warning
  in Step 2.
- **Attributes in `antora.yml` override the central playbook.** This is the most
  common way to desync a spec from the library. `sectnums` is the classic
  offender. Preview-only config belongs in `antora-playbook.yml`.
- **`asciidoctor-kroki` must be `0.18.1`.** `1.0.0` throws
  `block.$!= is not a function` under Antora 3.1.x.
- **`modules/ROOT/examples/` is a reserved Antora family** — don't put your bib
  there. Use `modules/ROOT/resources/`.
- **The numbering rule is coupled to `nav.adoc` line numbers**, not chapter
  numbers, and lives in a *different repo*. Editing nav comments is enough to
  break it. See Step 11.
- **Local preview can't surface every bug.** Cross-component references, the
  ASAM bibliography extension, and central section numbering only resolve in the
  central build. Publish to the dev site (`antora-dev.riscv.org`) to check those.
- **Two independent bib pointers.** `:bibtex-file:` (assembler → PDF) and
  `asamBibliography` (antora.yml → site) both point at the same file and both
  must be set. Changing the bib path means changing both.
- **Never hand-edit `antora.yml`'s `version:` or `page-*` attributes.** They are
  stamped. Hand edits get overwritten and, worse, can ship a site version that
  disagrees with the PDF.

## Questions / help

`help@riscv.org` for ARC policy questions. Open an issue against
`riscv/docs-spec-template` for tooling/migration issues.
