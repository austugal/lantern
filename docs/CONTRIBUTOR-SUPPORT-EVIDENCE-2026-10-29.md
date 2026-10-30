# Contributor display evidence — 29 October 2026

Repository: https://github.com/austugal/lantern

## Current verified facts

- Main inspected at `3b9a0e88899008b7e72fa0f69b617b49c5a1e5c0` before today's CI-only merge. Its author/committer identities are only `austugal <forevertiago@gmail.com>` and `GitHub <noreply@github.com>`.
- On 29 October, `GET https://api.github.com/repos/austugal/lantern/contributors?anon=1` returned only `austugal`, with 55 contributions at the time checked.
- The live sidebar was observed on 28 October displaying both austugal and claude, despite the API/graph disagreement. On 29 October, the public HTML contained only a loading skeleton for Contributors. The connected Browser tool was unavailable (`Unknown tool browser.js`), so a refreshed visible sidebar could not be verified. No claim is made that it has refreshed or that Claude is removed.
- Today's request does not authorize rewriting released history. Current field-tools release `mobile-preview-3b9a0e888990` and its desktop counterpart use the corrected main history.
- `CONTRIBUTORS.md` separately credits ChatGPT (OpenAI) as AI assistance at Tiago's request. This is not a GitHub account identity.

## Retained history, confirmed against remote refs on 29 October

`e1114fb1e461632ff6d8809201ea6212a67ca31c` is Claude-authored/committed and reachable from:

- Branches `build/core-consent-engine`, `feat/mesh-sos-offline-nav`, `feat/mobile-app`, `finish/desktop-release`.
- GitHub-managed `refs/pull/1/head`, `refs/pull/2/head`, `refs/pull/3/head`, `refs/pull/4/head`.
- Old release tags `desktop-preview-928a3c3c4bed`, `desktop-preview-cf580a9580e5`, `mobile-preview-928a3c3c4bed`.

`624073cca81c48397e8eb49c9352228f78a24fcb` has the same attribution and is reachable from all those refs except `build/core-consent-engine` and `refs/pull/1/head`.

Both contain a Claude co-author trailer and session marker. These commits are absent from current main and the current field-tools releases. They have not been removed from all repository history. Old released tags and retained branches were preserved; GitHub-managed pull refs cannot be edited by the owner.

## Exact request for GitHub Support

Please confirm which refs feed the repository homepage Contributors sidebar. If it is intended to reflect the default branch, please rebuild its contributor data to match corrected main and the Contributors REST response. If old release tags, retained branches or immutable pull-request refs intentionally contribute, please explain the supported remediation that preserves released history. The legacy refs above are disclosed for a complete diagnosis; cache invalidation alone may not resolve the entry.

This evidence is prepared for review. No support request or public message was sent.

## Recheck — 30 October 2026

- Current main before this milestone: `44fe19a1e358b945680b54057fa63d8f9f14369a`.
- At **13:42:30 UTC**, `GET https://api.github.com/repos/austugal/lantern/contributors?anon=1` returned only `austugal`, **58 contributions**.
- The fully loaded repository homepage at `https://github.com/austugal/lantern` independently displayed **Contributors (2)**, **austugal** and **claude** in its sidebar. The observation used the live browser after the initial loading skeleton resolved. The sidebar has not refreshed to match the API/default-branch attribution. More than 24 hours have passed since the 16 October correction.
- The old branches, immutable PR refs and release tags listed above remain disclosed. This run did not delete or rewrite them. No assertion is made that Claude is absent from all retained history.
- The exact support request above remains ready to submit; no support message was sent. GitHub controls the generated sidebar; repository credits cannot force a refresh.
