# Upgrading a Spec Repository to a Newer Template Version

**Short answer: yes.** A repository created from `docs-spec-template` can be
upgraded to a later version of the template, and can keep being upgraded
indefinitely. It is not a one-shot copy. But it is not `git pull` either — the
mechanism has to be set up deliberately, because GitHub's "Use this template"
severs the link.

**Who this is for:** Maintainers of a specification repository that was created
from `docs-spec-template` (via *Use this template* or a fork) and wants to pick
up later toolchain improvements — new workflows, fixed build scripts, ARC
compliance changes — without losing their specification content.

**How this differs from the other guides in this repo:**

| Guide | Question it answers |
| --- | --- |
| `MIGRATION.md` | "My repo predates the Antora dual build. How do I adopt the current toolchain once?" |
| **`UPGRADING.md`** (this) | "I'm already on the toolchain. How do I keep up with the template as it changes?" |
| `ANTORA.md` | "Why is the dual build designed this way?" |
| `ARC_SUBMISSION.md` | "What does the ARC actually require?" |

If you have never adopted the dual build, do `MIGRATION.md` first. This guide
assumes your repo already has `scripts/release-info.sh`, `modules/ROOT/`, and
the current workflows.

---

## 1. Why this needs a procedure at all

When you create a repository with GitHub's **Use this template**, GitHub copies
the file tree and starts a **brand-new history** — a single initial commit with
no ancestry shared with `docs-spec-template`. That is usually what you want (your
spec's history is its own), but it has one consequence:

> Git sees your repo and the template as two unrelated projects. There is no
> common ancestor, so there is no automatic three-way merge.

Everything below is about restoring enough of a relationship to make upgrades
mechanical instead of archaeological.

A second, subtler problem: **in your repo, `v*` tags mean *specification*
versions, not template versions.** `v0.62` is a milestone of your spec, maintained by
`version-bot.yml`. Nothing in a downstream repo records which template version it
was built from — so before you can upgrade, you have to establish a baseline and
write it down. Section 3 does that.

---

## 2. The file contract

Upgrades are tractable because the template has a clean split between files it
owns and files you own. Classify every path into one of three tiers **once**, and
every future upgrade becomes a mechanical application of those rules.

### Tier 1 — Template-owned: take upstream wholesale

These have no per-repository content. Overwrite them without reading the diff
closely; if you have edited one of these locally, that edit is a fork you will be
re-doing forever, and it belongs upstream instead.

```
scripts/release-info.sh
scripts/stamp-antora-version.sh
scripts/update-spec-state.sh
scripts/build-pages-site.sh
scripts/gen-pages-playbook.js
tests/release-info-test.sh
.github/workflows/build-pdf.yml
.github/workflows/version-bot.yml
.github/workflows/publish-site.yml
.github/workflows/validate-content-source.yml
.github/workflows/pre-commit.yml
.github/workflows/vale-linting.yml
.github/dependabot.yml
.pre-commit-config.yaml
.vale.ini
docker-compose.yml
ANTORA.md
MIGRATION.md
ARC_SUBMISSION.md
LICENSE
CODE_OF_CONDUCT.md
GOVERNANCE.md
```

`scripts/build-pages-site.sh` mentions `spec-sample`, but only in comments. It
reads `version:` from `antora.yml` at runtime, and the component name reaches it
via `start_page` in `antora-playbook.yml` (tier 2), so the script itself carries
nothing per-repository — genuinely tier 1.

`CONTRIBUTING.md` and `GOVERNANCE.md` are tier 1 *unless* your task group has
amended them; if so, move them to tier 2.

### Tier 2 — Shared: hand-merge, keep your values

These carry template structure **and** your customizations on the same lines.
Never overwrite; always diff and transplant.

| File | What is yours |
| --- | --- |
| `Makefile` | `DOCS` (your top-level `.adoc`), `SPEC_SHORT` |
| `antora.yml` | `name`, `title`, `asamBibliography`; `version`/`page-*` are **stamped**, never hand-edited |
| `antora-playbook.yml` | `start_page: <your-component>::index.adoc` |
| `package.json` | `name` field; devDependency **versions** are tier 1 |
| `README.adoc` | Almost entirely yours, but upstream adds sections (setup checklist, new build steps) worth harvesting |
| `CHANGELOG.md` | Yours; see §5 for how to log the upgrade itself |
| `.gitignore` | Usually identical; upstream adds entries as generated artifacts appear |
| `.gitmodules` | Usually identical — verify rather than assume |

### Tier 3 — Yours: never take upstream

```
modules/ROOT/pages/*.adoc      your chapters
modules/ROOT/nav.adoc          your site navigation
modules/ROOT/resources/*.bib   your bibliography
SPEC_STATE.md                  maintained by update-spec-state.sh
MAINTAINERS.md
```

### The one genuine exception: `src/<your-spec>.adoc`

Your PDF assembler is tier 3 by ownership — it names your chapters — but it is
**tier 1 by shape**. Everything around the `include::` lines is template
scaffolding that changes when ARC requirements change: the `[preface] ==
Document State` block, the `toc::[]` placement, the `list-of::` macros, the
`[index]` position before the bibliography, the `ifndef::` attribute defaults.

> **Diff `src/spec-sample.adoc` against your assembler on every upgrade, even
> though you never copy it wholesale.** This is the single most common source of
> a repo that upgrades cleanly and then fails ARC review, because the compliance
> requirements live in exactly the file the tiering says not to touch.

### Files to drop if you inherited them

`0001-Automate-Versioning.patch` is a historical artifact of the template. It has
no function in a spec repository — delete it.

---

## 3. One-time setup

Do this once, on a branch. It costs ten minutes and makes every subsequent
upgrade a routine operation.

### 3.1 Add the template as a remote

```shell
git remote add template https://github.com/riscv/docs-spec-template.git
git fetch template
```

Naming it `template` (not `upstream`) matters if your repo is also a fork of
something else.

### 3.2 Establish and record your baseline

Determine which template state your repo currently matches. If you know the
release you started from, use it. If you don't, find the closest match by
diffing tier 1 against candidate refs:

```shell
for ref in v4.0.0 v4.0.1 v4.0.2 v4.0.3 v4.0.4 template/main; do
  n=$(git diff --name-only "$ref" -- scripts .github/workflows 2>/dev/null | wc -l)
  printf '%-20s %s differing files\n' "$ref" "$n"
done
```

The ref with the fewest differences is your baseline.

Now record it. **This file does not exist in the template today — you are
introducing the convention**, and it is the piece that makes upgrades repeatable
rather than exploratory:

```shell
cat > .template-version <<'EOF'
# Which docs-spec-template release this repository's tooling tracks.
# Updated by the upgrade procedure in UPGRADING.md. Not a spec version --
# spec versions are the v* git tags minted by version-bot.yml.
template_ref: v4.0.4
template_sha: <full SHA of that ref>
upgraded_on: 2026-08-17
EOF
git add .template-version
```

Use `git rev-parse v4.0.4` to fill in the SHA. Recording the SHA as well as the
ref matters because the template's tag namespace is shared with its own version-bot
test tags (`vtest`, `v0.01`, `v1.0_rc1`), and tags can move; a SHA cannot.

### 3.3 Pinning when there is no suitable tag

The template's semver release line (`v1.0.0` → `v4.0.4`) currently lags `main`:
substantial work — the Antora dual build, the GitHub Pages publish, the PR
preview artifact — sits unreleased under `[Unreleased]` in `CHANGELOG.md`. If the
feature you need is not in a tag yet, **pin to a commit SHA** on `template/main`
and record that SHA. Do not track a moving `template/main`.

---

## 4. The upgrade procedure

### 4.1 Decide what you are taking

```shell
git fetch template
git log --oneline <your-recorded-sha>..template/main
git diff <your-recorded-sha>..template/main -- CHANGELOG.md
```

Read the changelog range first. The template's changelog is where breaking
toolchain changes are described in prose; the commit list tells you what moved,
the changelog tells you what it means for you.

### 4.2 Branch

```shell
git switch -c chore/template-upgrade-<target>
```

### 4.3 Take tier 1 wholesale

`git checkout` from a ref applies upstream's version of specific paths directly
into your working tree — no merge, no conflicts, no shared history required:

```shell
TARGET=template/main   # or a tag, or a pinned SHA

git checkout $TARGET -- \
  scripts/ tests/ \
  .github/workflows/ .github/dependabot.yml \
  .pre-commit-config.yaml .vale.ini docker-compose.yml \
  ANTORA.md MIGRATION.md ARC_SUBMISSION.md UPGRADING.md
```

Then review what you just staged — this is the check that catches a tier-1 file
you had quietly customized:

```shell
git diff --cached --stat
```

### 4.4 Hand-merge tier 2

For each tier 2 file, look at what changed upstream and transplant it:

```shell
git diff <your-recorded-sha>..$TARGET -- Makefile antora.yml antora-playbook.yml package.json
```

Apply upstream's changes to your copy by hand, preserving your values from the
table in §2. Concretely, on a `Makefile` upgrade you keep your `DOCS` and
`SPEC_SHORT` lines and take everything else.

For `package.json`, take upstream's `devDependencies` versions and keep your
`name`. Then regenerate the lockfile rather than merging it:

```shell
npm install --package-lock-only
```

### 4.5 Check the assembler

```shell
git diff <your-recorded-sha>..$TARGET -- src/
```

Apply any structural change (new preface block, changed `toc::[]` or `[index]`
placement, new `ifndef::` default) to your own `src/<your-spec>.adoc`, keeping
your `include::` lines. See the warning in §2.

### 4.6 Update the submodule

`docs-resources` upgrades on its own cadence — Dependabot proposes bumps
independently of template releases — but pick up the template's current pointer
during an upgrade so your build matches what upstream tested:

```shell
git checkout $TARGET -- docs-resources
git submodule update --init --recursive
```

### 4.7 Record the new baseline

Update `.template-version` with the new ref, SHA, and date. An upgrade that does
not update this file has made the next upgrade harder than it needed to be.

---

## 5. Verify before you merge

Run all of these. They are ordered cheapest-first.

```shell
# 1. Helper-script unit tests -- catches release-info.sh regressions
tests/release-info-test.sh          # exit 0 = all passed

# 2. Version metadata resolves
./scripts/release-info.sh version
./scripts/release-info.sh phase "$(./scripts/release-info.sh version)"

# 3. Full PDF build
make clean && make build
```

Then confirm the **ARC filename** is correct — this is the check that matters
most, because a wrong filename is an outright ARC rejection:

```shell
ls build/*.pdf
```

You must see `<SPEC_SHORT>-v<MAJOR>.<MINOR>-<YYYYMMDD>.pdf`. If you see a bare
`<name>.pdf`, your `SPEC_SHORT` did not survive the `Makefile` merge.

Open the PDF and check page 1 (title, version, date) and page 2 (the *Document
State* preface with the phase notice) against `ARC_SUBMISSION.md`.

Finally, the site:

```shell
npm install
docker compose up -d kroki
npm run preview                     # -> build/site/
```

Citations and the bibliography render as raw text in local preview — that is
expected, not a regression. The `cite:` and `bibliography::[]` macros are
resolved by the central playbook's ASAM extension, which is not bundled here.

To reproduce exactly what CI publishes to Pages:

```shell
NO_STAMP=1 ./scripts/build-pages-site.sh    # -> build/pages-site/
```

### Post-merge checks

CI on the PR exercises the rest: the PDF build, `pre-commit`, Vale, and the
Antora content-source gate — which now attaches the rendered site as a *Rendered
site (Antora)* artifact, so you can click through the upgraded site before
merging.

After merging, dispatch `version-bot.yml` **only when you actually intend to cut
a release**. A template upgrade is not a specification revision; merging to
`main` does not tag one, and it should not.

---

## 6. What upgrades tend to break

Ordered by how often they bite.

1. **`SPEC_SHORT` lost in a `Makefile` merge** → non-compliant PDF filename.
   Caught by §5's `ls build/*.pdf`.
2. **`antora.yml` overwritten wholesale** → your component `name` reverts to
   `spec-sample`, which silently changes the published site URL and orphans the
   central playbook's registration. Never `git checkout` this file from upstream.
3. **A stamped value hand-edited.** `version`, `page-revnumber`, `page-revdate`,
   and the `page-phase*` attributes in `antora.yml` come from
   `stamp-antora-version.sh`, which reads `release-info.sh` — the same source the
   PDF uses. Editing them by hand desyncs the site from the PDF, which the ARC
   Author Guide requires to match exactly. Run `make stamp-antora` instead.
4. **`nav.adoc` numbering rules.** Chapter numbering on the published central
   site is keyed to the **line numbers of the `xref` entries in
   `modules/ROOT/nav.adoc`**, via `numbering_rules` in the central playbook —
   not by anything in this repo. An upgrade that reorders your nav requires a
   matching update in `github.com/riscv-admin/antora.riscv.org`. See *Section
   numbering* in `ANTORA.md`.
5. **New workflows need new repository settings.** A workflow that arrives in an
   upgrade may need configuration that a running repo never had. Re-read the
   *Repository Setup Checklist* in `README.adoc` after every upgrade —
   particularly the `GHTOKEN` secret (without it, bot-opened PRs have all their
   checks stall in `action_required`) and *Settings → Pages → Source: GitHub
   Actions*, which a RISC-V org admin must set by hand because the org restricts
   Pages creation and the workflow's own token is refused.
6. **Submodule left uninitialized** after `git checkout template/main --
   docs-resources`. `make build` auto-initializes, but `npm run preview` and
   `build-pages-site.sh` will fail on the missing cover logo first.

---

## 7. Rolling back

Because tier 1 is applied by `git checkout` rather than merged, reverting is
clean — there is no merge commit to unpick:

```shell
git switch main            # abandon the upgrade branch entirely
```

Or, after the fact, revert the upgrade commit:

```shell
git revert --no-commit <upgrade-commit>
git submodule update --init --recursive
```

Then restore the previous values in `.template-version`.

---

## 8. Alternative strategies

The path-checkout approach in §4 is the recommended one: no shared history
required, no merge conflicts, and the tiering is enforced by which paths you
type. Two alternatives exist, both with real costs.

### Unrelated-histories merge

```shell
git merge template/main --allow-unrelated-histories
```

**Gains:** real three-way merges after the first one, so tier 2 files merge
semi-automatically and later upgrades know what you already took.

**Costs:** the first merge conflicts on essentially every tier 3 file at once —
Git has no common ancestor, so your chapters conflict with `spec-sample`'s. You
resolve a large conflict set by hand, and any mistake silently reverts spec
content. The template's history also becomes permanently interleaved with your
spec's, which makes `git log` on your own content noisier forever.

Worth it only if you expect to track the template closely and continuously.
Resolve that first merge with `git checkout --ours` on all of tier 3.

### Cherry-picking individual commits

```shell
git cherry-pick -x <template-commit>
```

Works when you want one specific upstream fix and nothing else. Fine for a
targeted hotfix; unworkable as a general strategy, because template changes
routinely span a workflow, a script, and a doc in separate commits, and picking a
subset produces states upstream never tested.

---

## 9. Cadence

- **Per upgrade:** log it in your `CHANGELOG.md` under `[Unreleased]`, naming the
  template ref you moved to. Your changelog is the only place a reader of your
  repo will find out that the toolchain moved.
- **Before any ARC submission:** upgrade first, then cut the release. ARC
  compliance requirements change in the template; submitting from a stale
  toolchain is the most common way to fail on format rather than content.
- **Otherwise:** on a milestone boundary (`v0.6`, `v0.8`, `v0.9`, `v0.99`,
  `v1.0`) is a natural rhythm — those are already governance checkpoints where
  the `SPEC_STATE.md` PR gets maintainer attention.

Do not upgrade between a `version-bot.yml` dispatch and the release build it
triggers.

---

## Questions

Open an issue on `github.com/riscv/docs-spec-template` — a tier 1 file that you
had to customize locally is a template bug, and worth reporting as one.
