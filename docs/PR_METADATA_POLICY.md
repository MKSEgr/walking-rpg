# Pull request issue-link policy

GitHub scans pull-request bodies for issue-closing keywords when a PR reaches
the default branch. Negating a keyword does not neutralize it: boundary text
such as `does not close #123` can still complete issue `#123` at merge time.

## Canonical completion reference

Use exactly one standalone line for each issue whose full acceptance is
delivered by the PR:

```text
Closes #123
```

Do not put that line in a quote, code fence, list item, sentence or PR title.
Do not use other GitHub completion variants. Repeating the same completion
reference is invalid.

## Non-completing relationships

Use wording without a closing keyword:

```text
Relates to #123
Keeps #123 open
External gate #123 remains OWNER_ACTION_REQUIRED.
```

This rule applies especially to repository tooling that prepares an external
device, signing, store, deployment, restore, incident or participant evidence
contract. Merging that tooling is `CODE_COMPLETE`; it cannot mark the external
gate `VALIDATED`.

`scripts/ci/verify_pr_closing_references.py` reads the GitHub pull-request
event and fails closed on ambiguous completion syntax. The release finalizer
runs the check on PR open, edit, synchronization, reopen and ready-for-review
events. Focused tests retain the regression cases discovered in the
2026-09-04 external-gate audit.

If a PR was merged with an unintended completion reference, reopen the
affected issue, leave an audit comment linking the repository-only PR, and
keep it open until its actual acceptance evidence is approved.
