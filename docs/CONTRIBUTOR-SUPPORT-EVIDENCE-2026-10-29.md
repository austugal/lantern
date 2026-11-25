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

## Recheck — 10 November 2026

- At **13:24:59 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **91 contributions**. The main branch response at **13:25:04 UTC** identified `59df59a4c1319a61ddff800ddbd38e368f153b74`; local `git shortlog -sn` confirms all 91 commits are authored by austugal.
- At approximately **13:25 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed 91 commits and **Contributors (2)** with separate `@austugal` and `@claude` links. This was the signed-in owner view; no new signed-out rendered observation is claimed.

The visible discrepancy persists 25 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. No released history, branch, access setting or open PR was changed by this check.

## Recheck — 11 November 2026

- At **13:55:41 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **92 contributions**. The main branch response at **13:55:47 UTC** identified `6d0a1d186fd6c6e81cecd8ff5e9c22c2cfca93f5`; local `git shortlog -sn` confirms all 92 commits are authored by austugal.
- At approximately **13:56 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed 92 commits and **Contributors (2)** with separate `@austugal` and `@claude` links. This was the signed-in owner view; no new signed-out rendered observation is claimed.

The visible discrepancy persists 26 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. No released history, branch, access setting or open PR was changed by this check.


## Recheck — 12 November 2026

- At **13:24:43 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **93 contributions**. The main branch response at **13:24:47 UTC** identified `0b73e672202f56eb065d9ee49f70c629cd115f4c`; local `git shortlog -sn` confirms all 93 commits are authored by austugal.
- At approximately **13:25 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed 93 commits and **Contributors (2)** with separate `@austugal` and `@claude` links. This was the signed-in owner view; no new signed-out rendered observation is claimed.

The visible discrepancy persists 27 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. No released history, branch, access setting or open PR was changed by this check.

## Recheck — 13 November 2026

- At **13:14:32 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **93 contributions**. The main branch response at **13:14:36 UTC** identified `0b73e672202f56eb065d9ee49f70c629cd115f4c`; local `git shortlog -sn` confirms all 93 commits are authored by austugal.
- At approximately **13:15 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed 93 commits and **Contributors (2)** with separate `@austugal` and `@claude` links. This was the signed-in owner view; no new signed-out rendered observation is claimed.

The visible discrepancy persists 28 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. No released history, branch, access setting or open PR was changed by this check.

## Recheck — 14 November 2026

- At **13:11:34 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **93 contributions**. The main branch response at **13:11:41 UTC** identified `0b73e672202f56eb065d9ee49f70c629cd115f4c`; local `git shortlog -sn` confirms all 93 commits are authored by austugal.
- At approximately **13:12 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed **94 commits**, following the intervening PR #37 merge, and **Contributors (2)** with separate `@austugal` and `@claude` links. The fetched `origin/main` then identified `97b11baacd4d7611a3ef707a18b029a053286695`; local `git shortlog -sn` confirms all 94 commits are authored by austugal. The API count above was observed before that merge and is not claimed as a post-merge count.
- The rendered observation was the signed-in owner view; no new signed-out rendered observation is claimed.

The visible discrepancy persists 29 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. This check changed no released history, branch, access setting or open PR.

## Recheck — 15 November 2026

- At **13:52:01 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **95 contributions**. The main branch response at **13:52:05 UTC** identified `256856940167481a131ff95bcc096390bd6eb52b`; local `git shortlog -sn` confirms all 95 commits are authored by austugal.
- At approximately **13:52 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed **95 commits** and **Contributors (2)** with separate `@austugal` and `@claude` links. This was a fresh **signed-out public view**, evidenced by the page's Sign in and Sign up links and sign-in requirements for notification/fork controls. No authentication action or session change was performed by this check.

The visible discrepancy persists 30 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. This check changed no released history, branch, access setting or open PR.

## Recheck — 16 November 2026

- At **13:22:33 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **95 contributions**.
- The [main branch API response](https://api.github.com/repos/austugal/lantern/branches/main) at **13:22:38 UTC** identified `621b32a185d964dca31c6ac2371e4e29c17087e7`, following PR #39. Local `git shortlog -sn` confirms all **96 commits** at that head are authored by austugal. The earlier contributor response's count of 95 is recorded as returned, not presented as a complete count for this newer head.
- At approximately **13:23 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed **96 commits** and **Contributors (2)** with separate `@austugal` and `@claude` links. This was a fresh **signed-out public view**, evidenced by Sign in and Sign up links and sign-in requirements for notification/fork controls. No authentication action or session change was performed by this check.

The visible discrepancy persists 31 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. This check changed no released history, branch, access setting or open PR.

## Recheck — 17 November 2026

- At **13:58:34 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **97 contributions**. The main branch response at **13:58:39 UTC** identified `ac8dd5b43619607259abdca2d2d695385eff50eb`; local `git shortlog -sn` confirms all 97 commits are authored by austugal.
- At approximately **13:59 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed **97 commits** and **Contributors (2)** with separate `@austugal` and `@claude` links. This was a fresh **signed-out public view**, evidenced by Sign in and Sign up links and sign-in requirements for notification/fork controls. No authentication action or session change was performed by this check.

The visible discrepancy persists 32 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. This check changed no released history, branch, access setting or open PR.

## Recheck — 18 November 2026

- At **13:09:12 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **98 contributions**. The main branch response at **13:09:17 UTC** identified `a5a05d992289c47a3392031c65ea8be188a4f21b`; local `git shortlog -sn` confirms all 98 commits are authored by austugal.
- At approximately **13:09 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed **98 commits** and **Contributors (2)** with separate `@austugal` and `@claude` links. This was a fresh **signed-out public view**, evidenced by Sign in and Sign up links and sign-in requirements for notification/fork controls. No authentication action or session change was performed by this check. Browser timing is approximate; the API times above are the exact response Date headers.

The visible discrepancy persists 33 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. This check changed no released history, branch, access setting or open PR.

## Recheck — 19 November 2026

- At **13:12:57 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **98 contributions**. The main branch response at **13:13:02 UTC** identified `a5a05d992289c47a3392031c65ea8be188a4f21b`; local `git shortlog -sn` confirms all 98 commits are authored by austugal.
- At approximately **13:13 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed **98 commits** and **Contributors (2)** with separate `@austugal` and `@claude` links. This was a fresh **signed-out public view**, evidenced by Sign in and Sign up links and sign-in requirements for notification/fork controls. No authentication action or session change was performed by this check. Browser timing is approximate; the API times above are the exact response Date headers.

The visible discrepancy persists 34 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. This check changed no released history, branch, access setting or open PR.

## Recheck — 20 November 2026

- At **13:17:31 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **100 contributions**. The main branch response at **13:17:35 UTC** identified `b490f9b3d19fcfa60ed9a1b8529377042cb99603`; local `git shortlog -sn` against that commit confirms all 100 commits are authored by austugal.
- At approximately **13:18 UTC**, the fully loaded [repository homepage](https://github.com/austugal/lantern) showed **100 commits** and **Contributors (2)** with separate `@austugal` and `@claude` links. This was a fresh **signed-out public view**, evidenced by Sign in and Sign up links. No authentication action or session change was performed by this check. Browser timing is approximate; the API times above are the exact response Date headers.

The visible discrepancy persists 35 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. This check changed no released history, branch, access setting or open PR. Main author attribution and the rendered public sidebar are separate observations; this evidence does not establish that Claude attribution has been removed everywhere.

## Recheck — 21 November 2026

- At **13:55:18 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **100 contributions**. The main branch response at **13:55:24 UTC** identified `b490f9b3d19fcfa60ed9a1b8529377042cb99603`; local `git shortlog -sn` against that commit confirms all 100 commits are authored by austugal. These API observations preceded the PR #44 merge.
- At approximately **13:55 UTC**, the loaded [repository homepage](https://github.com/austugal/lantern) showed the PR #44 merge, commit `008645e`, **101 commits**, and **Contributors (2)** with separate `@austugal` and `@claude` links. This was a fresh **signed-out public view**, evidenced by Sign in and Sign up links. No authentication action or session change was performed by this check.
- The local fetched `origin/main` was subsequently `008645ebcb65aa29dd86349045450234b2a033d7` (commit timestamp **13:55:32 UTC**). Its shortlog confirms all **101 commits** are authored by austugal. The public homepage's 101-commit observation is therefore a later snapshot than the API's 100-contribution response, not evidence of a same-snapshot count disagreement. Browser timing is approximate; API times are the exact response Date headers.

The visible stale-Claude discrepancy persists 36 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. This check changed no released history, branch, access setting or open PR. Main author attribution and the rendered public sidebar are separate observations; this evidence does not establish that Claude attribution has been removed everywhere.

## Recheck — 22 November 2026

- At **13:09:49 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **102 contributions**. The main branch response at **13:09:56 UTC** identified `294bf337a8b9f99ace303fbaef75ed76e16fe5bb`; local `git shortlog -sn` against that commit confirms all 102 commits are authored by austugal.
- At approximately **13:10 UTC**, the loaded [repository homepage](https://github.com/austugal/lantern) showed commit `294bf33`, **102 commits**, and **Contributors (2)** with separate `@austugal` and `@claude` links. This was a fresh **signed-out public view**, evidenced by Sign in and Sign up links. No authentication action or session change was performed by this check. Browser timing is approximate; the API times above are the exact response Date headers.

The visible discrepancy persists 37 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. This check changed no released history, branch, access setting or open PR. Main author attribution and the rendered public sidebar are separate observations; this evidence does not establish that Claude attribution has been removed everywhere.

## Recheck — 23 November 2026

- At **13:12:18 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **102 contributions**. The main branch response at **13:12:27 UTC** identified `294bf337a8b9f99ace303fbaef75ed76e16fe5bb`; local `git shortlog -sn` against that commit confirms all 102 commits are authored by austugal.
- At approximately **13:12 UTC**, the loaded [repository homepage](https://github.com/austugal/lantern) showed commit `294bf33`, **102 commits**, and **Contributors (2)** with separate `@austugal` and `@claude` links. This was a fresh **signed-out public view**, evidenced by Sign in and Sign up links. No authentication action or session change was performed by this check. Browser timing is approximate; the API times above are the exact response Date headers. These snapshots precede any later PR #46 merge.

The visible discrepancy persists 38 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. This check changed no released history, branch, access setting or open PR. Main author attribution and the rendered public sidebar are separate observations; this evidence does not establish that Claude attribution has been removed everywhere.

## Recheck — 24 November 2026

- At **13:41:14 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **104 contributions**. The main branch response at **13:41:24 UTC** identified `f5f5dcddbc2b19d9ffbc70e4a520c8d30077c569`; local `git shortlog -sn` against that commit confirms all 104 commits are authored by austugal.
- At approximately **13:41 UTC**, the loaded [repository homepage](https://github.com/austugal/lantern) showed commit `f5f5dcd`, **104 commits**, and **Contributors (2)** with separate `@austugal` and `@claude` links. This was a fresh **signed-out public view**, evidenced by Sign in and Sign up links. No authentication action or session change was performed by this check. Browser timing is approximate; the API times above are the exact response Date headers.

The visible discrepancy persists 39 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. This check changed no released history, branch, access setting or open PR. Main author attribution and the rendered public sidebar are separate observations; this evidence does not establish that Claude attribution has been removed everywhere.

## Recheck — 25 November 2026

- At **13:08:21 UTC**, an unauthenticated [Contributors REST request](https://api.github.com/repos/austugal/lantern/contributors?anon=1) returned HTTP 200 with exactly one entry: `austugal`, **105 contributions**. The main branch response at **13:08:28 UTC** identified `f73be8262559341aa095d6d0ad142809d06022b8`; local `git shortlog -sn` against that commit confirms all 105 commits are authored by austugal.
- At approximately **13:08 UTC**, the loaded [repository homepage](https://github.com/austugal/lantern) showed commit `f73be82`, **105 commits**, and **Contributors (2)** with separate `@austugal` and `@claude` links. This was a fresh **signed-out public view**, evidenced by Sign in and Sign up links. No authentication action or session change was performed by this check. Browser timing is approximate; the API times above are the exact response Date headers.

The visible discrepancy persists 40 days after the 16 October correction. Its cause remains unconfirmed. The exact Support request and retained-ref evidence above remain prepared and unsent. This check changed no released history, branch, access setting or open PR. Main author attribution and the rendered public sidebar are separate observations; this evidence does not establish that Claude attribution has been removed everywhere.
