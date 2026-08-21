# About this fork

This fork exists purely to let Claude manage the author's personal **Vox Populi + EUI**
modding workflow — not to develop or contribute upstream. Direct, pragmatic changes are
fine; there's no need to preserve upstream conventions for their own sake. The one thing
that does matter: every commit should be one atomic, self-contained tweak (one balance
change, one bugfix, one feature), so any of them can be isolated, dropped, or modified
later without disturbing the others.

The deploy workflow (`.claude/skills/sync-voxpopuli/`) is Claude-owned too — the user does
not run it by hand. When asked to sync/deploy/test in-game, invoke that skill directly.

## Branch strategy: lead branch

Each `my-<version>-build` branch is a snapshot forked from an upstream `Release-<version>`
tag, carrying the author's personal commits on top (custom UA tweaks, balance changes,
build tooling, etc). Only ONE of these is actively worked on at any time — the **lead
branch**:

**Lead branch: `my-5.4.4-build`**

Update the line above whenever the lead branch changes. Older `my-x.x.x-build` branches
(e.g. `my-5.2.7-build`, `my-5.4.1-build`) are frozen historical snapshots — do not try to
propagate new changes to them; that's deliberate, not an oversight. Assume the user means
the lead branch unless they explicitly name another one.

**Moving the lead branch forward** (when the user wants to adopt a newer upstream release):
1. `git fetch upstream` (remote `upstream` = `LoneGazebo/Community-Patch-DLL`), confirm the
   target `Release-<version>` tag exists.
2. `git checkout -b my-<new-version>-build Release-<new-version>`
3. List the personal commits on the current lead branch since its own base tag
   (`git log --oneline --reverse Release-<old-version>..my-<old-version>-build`), then
   `git cherry-pick` them in order onto the new branch. Even if `CvPlayer.cpp` etc. have
   diverged a lot between versions, this usually applies clean via git's context-based
   3-way merge — don't assume conflicts, but do verify: after each risky pick, check that
   every symbol/function/column the change touches still exists with the same signature
   in the new codebase (grep for it), and build the DLL before trusting a clean pick.
4. Update the "Lead branch" line above to the new branch name.

This is a copy, not a destructive rewrite — the old lead branch is left untouched and
becomes one of the frozen historical branches.

## Amending a non-HEAD commit without `-i`

`git rebase -i` and other `-i` flags are off-limits. To edit an older commit's content
in place while keeping later commits stacked on top:
```
git branch tmp-amend <commit-to-amend>
git checkout tmp-amend
# make the edits, then:
git add -A && git commit --amend --no-edit   # (or with a new message)
git rebase --onto tmp-amend <commit-to-amend> <original-branch>
git branch -D tmp-amend
```
`rebase --onto` replays every commit after `<commit-to-amend>` on top of the amended
version and moves `<original-branch>` to the new tip — no interactive editor involved.
Force-push with `--force-with-lease` afterward if the branch was already pushed.

## Personal SQL/XML overrides (Vox Populi)

Small personal balance/data tweaks (as opposed to bigger feature rewrites like a custom
UA, which just edit the relevant file in place) go in their own file under
`(2) Vox Populi\Database Changes\Personal\<Name>.sql` — one tweak per file, so it stays
its own atomic, easily-revertible commit.

A new file there is invisible to the game until it's registered — the `.modinfo` is a
generated manifest, not hand-maintained. To add one:
1. Add a `<Content Include="Database Changes\Personal\<Name>.sql">` entry to
   `(2) Vox Populi\Vox Populi.civ5proj` (copy the shape from any existing
   `Database Changes\Units\*.sql` entry).
2. Add a matching `<Action><Set>OnModActivated</Set><Type>UpdateDatabase</Type>
   <FileName>Database Changes/Personal/<Name>.sql</FileName></Action>` — append it near
   the END of the `<ModActions>` block (right before `</ModActions>`), so it runs after,
   and can override, all of VP's own SQL.
3. Regenerate the actual `.modinfo`: `python scripts/generate_modinfo.py "(2) Vox Populi"`.
   This also refreshes every file's MD5 hash in the manifest — if a VP-owned SQL/XML file
   was edited in a previous session without a regen afterward, expect its hash to change
   too as a side effect. That's a stale-hash fix, not a regression.

## Build notes

### Clang build (alternative to Visual Studio)

`build_vp_clang.py` / `build_vp_clang_sdk.py` build `CvGameCore_Expansion2.dll` via `clang-cl.exe` + `lld-link.exe` instead of MSBuild/devenv. Output goes to `clang-output\{Release,Debug}\`, not `BuildOutput\`.

Requirements: Python (stdlib only, no venv), VS2008 installed (`VS90COMNTOOLS`), and LLVM for Windows (`winget install LLVM.LLVM`, adds `clang-cl`/`lld-link`) on PATH.

Usage: `python build_vp_clang.py --config debug` (or `release`).

**Known local fix applied**: both scripts called `subprocess.run('update_commit_id.bat', ...)` with a bare filename, which fails on machines with `NoDefaultCurrentDirectoryInExePath=1` set (disables implicit current-dir search — common on managed/work machines). Fixed by using `.\update_commit_id.bat` instead. Works fine on CI since that setting isn't present there.

### Deploying to test in-game

Use the `sync-voxpopuli` skill (`.claude/skills/sync-voxpopuli/`) rather than running its
script by hand — see that skill's `SKILL.md` for what it does and when to build first.
