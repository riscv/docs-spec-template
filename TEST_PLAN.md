# Test Plan — Antora dual-build migration

Validates the PR that makes `docs-spec-template` feed **both** the ARC submission
PDF and the Antora HTML site from one source tree, keeps the two versions in
exact lockstep, and adds a local Antora preview + a CI validation gate — **without
breaking the existing ARC/PDF release flow.**

**How to use:** work top to bottom. Parts A–C run locally against a clone of the
PR branch. Part D exercises the GitHub Actions release automation on a **throwaway
sandbox repo** so nothing touches the real template or any spec repo. Tick each
box; every "Expected" must hold for sign-off.

Throughout, the example component is `spec-sample` (from `antora.yml` `name:`) and
the ARC short name is `spec-sample` (Makefile `SPEC_SHORT`). A real new spec
renames both (Part A); substitute your names where you see `spec-sample`.

---

## 0. Prerequisites

- [ ] Docker running (PDF build + local Kroki).
- [ ] Node.js ≥ 18 and npm (local Antora preview).
- [ ] `git`, `make`, `bash`.
- [ ] A GitHub account able to create a repo (Part D).

---

## Part A — New repository from the template

**Goal:** a repo seeded from the template builds an ARC PDF out of the box, on a
default `main` branch.

1. [ ] On GitHub, use **Use this template → Create a new repository** (default
   branch is `main`). Then clone with submodules:
   ```shell
   git clone --recurse-submodules https://github.com/<you>/<new-repo>.git
   cd <new-repo>
   ```
   **Expected:** `docs-resources/` is populated (submodule checked out).

2. [ ] (Real spec only) Rename identifiers:
   - `Makefile`: set `SPEC_SHORT := <Short>` (e.g. `Zifoo`).
   - `antora.yml`: set `name:` and `title:` to your spec.
   - `nav.adoc` / page titles as desired.

   For pure migration testing you may keep the `spec-sample` defaults.

3. [ ] First build:
   ```shell
   make
   ```
   **Expected:** exit 0; a file `build/<SPEC_SHORT>-v0.0.0-<YYYYMMDD>.pdf` is
   produced (no tags yet ⇒ default `v0.0.0`), and the log ends with
   `ARC submission PDF: build/<SPEC_SHORT>-v0.0.0-<date>.pdf`.

---

## Part B — Local Antora HTML preview

**Goal:** the same chapter sources render as an HTML site locally.

1. [ ] Install preview tooling and start the diagram server:
   ```shell
   npm install
   docker compose up -d kroki
   ```
   **Expected:** `npm install` completes; `curl -s localhost:9870/health` returns
   `"status":"pass"`.

2. [ ] Build the site:
   ```shell
   npm run preview        # = antora --fetch antora-playbook.yml
   ```
   **Expected:** exit 0. Output under `build/site/spec-sample/…`. The only logged
   error is `target of image not found: common::risc-v_logo.svg` — this is
   **expected** (the shared logo only resolves in the central multi-source build).

3. [ ] Open `build/site/spec-sample/<version>/index.html` and spot-check:
   - [ ] Cover shows the RISC-V logo placeholder, the title, and a revision line
     `Version v0.0.0, <date>: Draft and Development`, plus a phase banner.
   - [ ] `intro.html`: the WaveDrom diagram renders as an **SVG image** (not raw
     `[wavedrom]` text).
   - [ ] `chapter2.html`: the `latexmath` equation renders as math (not raw
     `latexmath:[…]`).
   - [ ] `bibliography.html`: `bibliography::[]` appears as **raw text**, and
     `intro.html` citations show as raw `cite:[…]`. **This is expected** — the
     ASAM bibliography extension is central-only (see README warning).

4. [ ] Stop the server when done:
   ```shell
   docker compose down
   ```

---

## Part C — PDF ⇄ HTML version lockstep (local)

**Goal:** prove the PDF and the HTML site derive the **same** version/phase from
the **same** source, with no hand-entered version.

> The authoritative version comes from the latest `v*` git **tag** (via
> `scripts/release-info.sh`). We create a local tag to exercise the real path.

1. [ ] Create a milestone tag and confirm derivation:
   ```shell
   git tag v0.8.0
   ./scripts/release-info.sh version    # -> v0.8.0
   ./scripts/release-info.sh display    # -> Stabilized
   ```

2. [ ] Build the PDF from the tag (no VERSION override):
   ```shell
   make
   ```
   **Expected:** `build/spec-sample-v0.8.0-<YYYYMMDD>.pdf`; title page reads
   `Version v0.8.0, <date>: Stabilized`.

3. [ ] Stamp + build the HTML from the **same** tag:
   ```shell
   make stamp-antora        # no args -> uses release-info.sh (v0.8.0) + today
   grep '^version:' antora.yml               # -> version: v0.8.0
   docker compose up -d kroki && npm run preview
   ```
   **Expected:**
   - `antora.yml` `version:` and `page-*` attrs are stamped to `v0.8.0` /
     `Stabilized` / today.
   - Site is emitted under `build/site/spec-sample/**v0.8.0**/`.
   - Cover revision line reads `Version v0.8.0, <date>: Stabilized` — **identical
     to the PDF title page.**

4. [ ] **Lockstep assertion:** PDF filename version, PDF title-page version, and
   the HTML `version:` / site path / cover line are all `v0.8.0`. ✅

5. [ ] Milestone mapping spot-check (optional):
   | Tag | Expected display |
   |-----|------------------|
   | `v0.6.0` | Development Complete |
   | `v0.8.0` | Stabilized |
   | `v0.9.0` | Frozen |
   | `v0.99.0` | Ratification-Ready |
   | `v0.99.1` | Publication |
   | `v1.0.0` | Ratified |

6. [ ] Clean up the local tag and restamp back:
   ```shell
   git tag -d v0.8.0
   make stamp-antora                # restamp to real state (v0.0.0)
   git checkout -- antora.yml       # or keep if this is the sandbox
   docker compose down
   ```

---

## Part D — ARC release automation in CI (sandbox repo)

**Goal:** confirm the release workflows still produce ARC-compliant Releases
**and** that the new `stamp-site-version` job keeps `main`'s `antora.yml` in sync
— without risking the real repos.

### D0. Stand up a sandbox

1. [ ] Create a **new empty private GitHub repo** (e.g. `antora-migration-test`).
2. [ ] Push the PR branch content as `main`:
   ```shell
   git clone --recurse-submodules https://github.com/riscv/docs-spec-template.git sandbox
   cd sandbox && git checkout <PR-branch>
   git remote add sandbox https://github.com/<you>/antora-migration-test.git
   git push sandbox HEAD:main
   ```
3. [ ] In the sandbox repo settings, leave `main` **unprotected** (the default) so
   the stamp job's push succeeds with the built-in token. (If you protect it, the
   job needs a bypass token or a PR — see ANTORA.md Phase 6.)

### D1. PR validation gate

4. [ ] Open a trivial PR in the sandbox (edit a page). **Expected:** the
   **Validate Antora content source** check runs and **passes**; the
   `stamp-site-version` job does **not** run (PR event).
5. [ ] Push a PR commit with a deliberately broken xref
   (`xref:nope.adoc[x]`). **Expected:** the validation check **fails**. Revert.

### D2. Official milestone release (author's ARC path — Option A)

6. [ ] Actions → **Create Specification Document** → **Run workflow** on `main`
   with `target_phase = stabilized`, `draft = false`.
   **Expected:**
   - [ ] Workflow succeeds; a **GitHub Release `v0.8.0`** is created, marked
     **not** prerelease (official milestone), with asset
     `spec-sample-v0.8.0-<YYYYMMDD>.pdf`.
   - [ ] The `stamp-site-version` job runs and pushes a commit to `main`:
     `chore(site): stamp Antora version v0.8.0 to match PDF`.
   - [ ] On `main`, `antora.yml` now has `version: v0.8.0` and the stamped
     `page-*` attributes; its `page-revdate` equals the PDF's `<YYYYMMDD>` date
     (same run ⇒ same date).

7. [ ] (Optional) Build the site from `main` locally (Part B) → renders under
   `spec-sample/v0.8.0/`, cover matches the released PDF.

### D3. version-bot auto-tagging

8. [ ] Push a commit touching `src/**` to `main`.
   **Expected:** **Version Bot** runs and creates the next tag. From `v0.8.0` the
   next auto tag is `v0.8.1` (patch bump; `.99` rolls the minor).
9. [ ] Because `v0.8.1` crosses no milestone boundary, **no** `SPEC_STATE.md` PR
   is opened. (Cross a boundary to see the milestone PR, if desired.)

### D4. Guardrails on the stamp job

10. [ ] Re-run **Create Specification Document** with `draft = true`.
    **Expected:** PDF builds, draft Release created, but `stamp-site-version` is
    **skipped** (draft) — `main`'s `antora.yml` is unchanged.
11. [ ] Monotonic check: dispatch with `release_version = v0.7.0` (older than
    `main`'s current `v0.8.x`).
    **Expected:** the stamp job runs but **skips the commit**
    (`main is already at … (>= v0.7.0); skipping stamp`) — the site version is
    **not** regressed.

---

## Part E — Regression checklist ("nothing broke")

- [ ] `make` still exits 0 and emits `build/<short>-v<ver>-<YYYYMMDD>.pdf`.
- [ ] ARC name wiring intact (no Docker needed):
  ```shell
  make -n SKIP_DOCKER=true VERSION=v0.8.0 DATE=2026-06-12 | grep 'dest='
  # -> dest="$base-v0.8.0-20260612.pdf"
  ```
- [ ] PDF still renders **bibliography + citations** (asciidoctor-bibtex),
  **math** (asciidoctor-mathematical), and the **wavedrom** diagram — the moved
  bib (`modules/ROOT/resources/riscv-spec.bib`) and the new `latexmath` demo did
  not break the PDF.
- [ ] `antora.yml` stays minimal (only `page-group`, `asamBibliography`, and the
  stamped `version`/`page-*` release metadata) — no shared-rendering overrides.
- [ ] `git status` after a full build/preview is clean apart from ignored
  artifacts (`build/`, `node_modules/`, `.cache/`, `_images/`, `src/images/`).
- [ ] `version-bot.yml` behavior unchanged: still tags only on `src/**` pushes;
  the stamp commit (touches `antora.yml`, not `src/**`) does **not** retrigger it.

---

## Sign-off

- [ ] Parts A–C pass locally on the PR branch.
- [ ] Part D passes on the sandbox repo (Release + stamp + guardrails).
- [ ] Part E regression checklist clean.
- [ ] Delete the sandbox repo.
