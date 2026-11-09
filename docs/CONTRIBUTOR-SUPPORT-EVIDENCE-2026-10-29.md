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

The retained remote branch, PR-head and release-tag refs listed above were rechecked with `git ls-remote` on 30 October and still match the earlier snapshot. Corrected main before today’s merge again showed only austugal/GitHub author and committer identities. Neither those retained refs nor released history were rewritten.

## Recheck — 31 October 2026

Main inspected at `275d9801dd5a6b9c833faa51a4ef12da758ee321`. At **13:24:16 UTC**, the Contributors REST response returned only `austugal`, **61 contributions**. The fully loaded live homepage again displayed **Contributors (2)**, `austugal` and `claude`. The display has not refreshed to match the corrected-main/API view. The legacy-ref evidence and exact support request above remain applicable; no ref, tag, access setting or released history was changed and no support message was sent. ChatGPT assistance remains separately credited in CONTRIBUTORS.md.

## Recheck — 1 November 2026

At **14:00:51 UTC**, the Contributors REST response listed only `austugal`, **62 contributions**, on main `e9bb535ebe7a36d882e8392ff065ae76aa6b529b` before today’s tool merge. The fully loaded live homepage still showed **Contributors (2)**, austugal and claude. The display remains inconsistent with the corrected-main/API view. Legacy refs and old releases listed above were preserved; none were deleted or rewritten. The exact support request remains prepared; no support message was sent and no removal is claimed.

## Recheck — 3 November 2026

At **13:47:02 UTC**, `GET https://api.github.com/repos/austugal/lantern/contributors?anon=1` listed only `austugal`, **81 contributions**, on main `33bf80c6ac1e151d418c33f12de6b32645fcdaef`. After the public repository homepage finished loading, its generated sidebar still displayed **Contributors (2)**, `austugal` and `claude`. The sidebar therefore remains inconsistent with the Contributors REST response and corrected default-branch attribution more than 24 hours after the 16 October correction.

The legacy branches, immutable pull-request refs and old release tags documented above remain the likely attribution inputs or cache sources; this is an inference, not a GitHub-confirmed cause. None were deleted or rewritten. The exact Support request above remains ready to send, but no support message was sent and no removal is claimed. `CONTRIBUTORS.md` continues to credit ChatGPT (OpenAI) separately as requested; that credit is unrelated to GitHub's generated account list.

## Recheck — 4 November 2026

At the start of this milestone, main was `db808fcebb75a0143ff42029a69b245348d364b1`; all main author identities were austugal. The Contributors REST response again listed only `austugal`, now 84 contributions. The connected Browser tool returned `Unknown tool browser.js`, so a fresh rendered sidebar observation could not be obtained. The last verified sidebar observation on 3 November still showed austugal and claude. Removal is not claimed. The exact Support request and legacy-ref evidence above remain prepared and unsent; released history is preserved.

## Recheck — 5 November 2026

- Main inspected: `ae9848085b46bb811deb093af1ef4b6e3ce03f46`. Its 85 commits list only `austugal` as author.
- At **13:20:28 UTC**, the [Contributors REST endpoint](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 and one result: `austugal`, **85 contributions**.
- The [public repository homepage](https://github.com/austugal/lantern) initially showed a contributor placeholder. Once loaded in a signed-out browser, its sidebar showed **Contributors (2)** with links for **@austugal** and **@claude**.

The sidebar still differs from the API and corrected main, 20 days after the 16 October correction. The cause remains unconfirmed. The exact Support request and retained-ref evidence above remain ready; nothing was sent and no history was rewritten.

## Recheck — 6 November 2026

- At **13:53:10 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **85 contributions**. At 13:53:15 UTC main was `ae9848085b46bb811deb093af1ef4b6e3ce03f46`; `git shortlog -sn` showed 85 commits, all by austugal.
- At **13:53:48 UTC** [PR #30](https://github.com/austugal/lantern/pull/30) merged as [68b3a323](https://github.com/austugal/lantern/commit/68b3a3233a49ef04d42a0ae27e46fd448fa103ff), authored by austugal and committed by GitHub. The preceding API count was taken before that merge.
- At approximately **13:54 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed 86 commits and **Contributors (2)** with separate links for `@austugal` and `@claude`. This browser was signed in. The unauthenticated homepage HTML returned HTTP 200 but contained only the loading placeholder. The last independently observed signed-out rendered sidebar was 5 November and showed the same two accounts.

The visible discrepancy persists 21 days after the 16 October correction. The exact Support request and retained refs above remain applicable. Its cause is unconfirmed; no request was sent or history rewritten.

## Recheck — 7 November 2026

- At **13:31:57 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with one entry: `austugal`, **86 contributions**. Main before today's merge was `68b3a3233a49ef04d42a0ae27e46fd448fa103ff`; `git shortlog -sn` listed 86 commits, all authored by austugal.
- [PR #31](https://github.com/austugal/lantern/pull/31) subsequently merged at **13:32:03 UTC** as `7ff14fe4777d0bcca20ccd764d9985e88bcf2fdc`, authored by austugal and committed by GitHub. The API count above predates that merge.
- At approximately **13:32 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) displayed 87 commits and **Contributors (2)** with separate `@austugal` and `@claude` links. This observation used the signed-in owner view; it is not a new signed-out observation.

The visible discrepancy persists 22 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent; no released history or access settings were changed.

## Recheck — 8 November 2026

- At **13:21:31 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **88 contributions**. The main branch response at **13:21:36 UTC** identified `a8d6ccd666a0382dbfcad8442e7c8c4517362b88`; local `git shortlog -sn` confirms all 88 commits are authored by austugal.
- At approximately **13:21 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed 88 commits and **Contributors (2)** with separate `@austugal` and `@claude` links. This was the signed-in owner view; no new signed-out rendered observation is claimed.

The visible discrepancy persists 23 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. No released history, branch, access setting or open PR was changed by this check.

## Recheck — 9 November 2026

- At **14:13:53 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **91 contributions**. The main branch response at **14:14:00 UTC** identified `59df59a4c1319a61ddff800ddbd38e368f153b74`; local `git shortlog -sn` confirms all 91 commits are authored by austugal.
- At approximately **14:14 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed 91 commits and **Contributors (2)** with separate `@austugal` and `@claude` links. This was the signed-in owner view; no new signed-out rendered observation is claimed.

The visible discrepancy persists 24 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. No released history, branch, access setting or open PR was changed by this check.
