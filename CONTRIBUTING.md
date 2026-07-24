# Contribution Guidelines

As an open-source project, we appreciate and encourage community members to submit patches directly to the project. To maintain a well-organized development environment, we have established standards and methods for submitting changes. This document outlines the process for submitting patches to the project, ensuring that your contribution is swiftly incorporated into the codebase.

# Version and State Automation

Specification version/state metadata is managed by CI.

- Pushes to `main` that modify `src/**` trigger the version bot workflow.
- Versions are two-digit `vMAJOR.MINOR` as a fixed-point decimal (`v0.6` = 0.60, `v0.72` = 0.72, `v1.0` = 1.00). Ordering is decimal, not semver: `v0.8` (0.80) is greater than `v0.61`.
- The bot advances the revision by `0.01` (`v0.61` -> `v0.62`) from the latest existing `v*` tag.
- Tag creation triggers the document build workflow, which sets `:revnumber:` and `:revdate:` during build.
- Phase/state text (`:phase:`, `:phase_display:`, `:phase_notice:`, and `:revremark:`) is derived from the version via `scripts/release-info.sh`.
- Milestone gates (`v0.6`, `v0.8`, `v0.9`, `v0.99`, `v1.0`) are cut **manually** — the bot never auto-advances onto a gate. When the auto band is exhausted (for example at `v0.79`), a maintainer cuts the next milestone.
- Manual force-jump is available via `workflow_dispatch` in `.github/workflows/version-bot.yml`.
- Use `target_phase` to jump to a milestone floor (for example `Frozen` -> `v0.9`).
- Use `release_version` to set a specific version directly (this overrides `target_phase`).
- Manual runs must target `main`.
- Backward jumps are blocked by default; use `allow_non_monotonic=true` only when intentionally overriding this safety check.
- Official release policy: only `v0.6`, `v0.8`, `v0.9`, `v0.99`, and `v1.0` are published as official (`prerelease=false`).
- Every other version is published as a prerelease (`prerelease=true`).

Milestone boundaries are:

- `v0.6`: Developed (revisions `v0.61`–`v0.79`)
- `v0.8`: Stable (revisions `v0.81`–`v0.89`)
- `v0.9`: Frozen (revisions `v0.91`–`v0.98`)
- `v0.99`: Ratification-Ready
- `v1.0`: Ratified

When a new version crosses a milestone boundary, CI opens a PR that updates `SPEC_STATE.md` for maintainer review.

# Licensing

Licensing is crucial for open-source projects, as it guarantees that the software remains available under the conditions specified by the author.

This project employs the Creative Commons Attribution 4.0 International license, which can be found in the LICENSE file within the project's repository.

Licensing defines the rights granted to you as an author by the copyright holder. It is essential for contributors to fully understand and accept these licensing rights. In some cases, the copyright holder may not be the contributor, such as when the contributor is working on behalf of a company.

# Developer Certificate of Origin (DCO)
To uphold licensing criteria and demonstrate good faith, this project mandates adherence to the Developer Certificate of Origin (DCO) process.

The DCO is an attestation appended to every contribution from each author. In the commit message of the contribution (explained in greater detail later in this document), the author adds a Signed-off-by statement, thereby accepting the DCO.

When an author submits a patch, they affirm that they possess the right to submit the patch under the designated license. The DCO agreement is displayed below and at https://developercertificate.org.


Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b), or (c), and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.

# DCO Sign-Off Methods
The DCO necessitates the inclusion of a sign-off message in the following format for each commit within the pull request:
```
Signed-off-by: Stephano Cetola <scetola@linuxfoundation.org>
```
Please use your real name in the sign-off message.

1) Manual method

   You can manually add the DCO text to your commit body or include either -s or --signoff in your standard Git commit commands. If you forget to incorporate the sign-off, you can also
   amend a previous commit with the sign-off by executing git commit --amend -s. If you have already pushed your changes to GitHub, you will need to force push your branch afterward
   using git push -f.

2) Automated Template method (easier)

   Create a template file.  Save a file (e.g., ~/.gitmessage) containing:
    Signed-off-by: Your Name <your.email@example.com>

   Configure Git to use it.  Run the following command:
    git config --global commit.template ~/.gitmessage  

Note:

Ensure that the name and email address associated with your GitHub account match the name and email address in the Signed-off-by line of your commit message.
