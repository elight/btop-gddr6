# AGENTS.md — btop-gddr6

This is a fork of [aristocratos/btop](https://github.com/aristocratos/btop) that
shows NVIDIA VRAM temperature (GDDR6/GDDR6X memory junction) in each GPU box,
next to the `vram` title: `├─┐vram 84°C┌───`. NVML does not expose that number,
so it comes from [gddr6](https://github.com/olealgoritme/gddr6), which reads the
card's registers and needs root.

Everything below is about keeping the fork's one change alive across btop
releases. Read it before you touch the branch.

## The shape of the fork

- **One commit on top of an upstream release tag.** Branch `gddr6` (the default
  branch) is `vX.Y.Z` plus a single commit, `btop-gddr6: show VRAM temperature
  from gddr6`. Keep it that way: an upgrade is a rebase of that one commit, never
  a merge, so `git log vX.Y.Z..gddr6` is always exactly the patch.
- **btop never runs as root.** `gddr6/gddr6-feed` runs as root under systemd,
  reads gddr6's output and writes `/run/gddr6/gpu<N>` (a plain integer, °C),
  where N is the NVML index — the number `nvidia-smi` shows. btop only reads
  those files and ignores one older than 5 seconds, so a stopped feed means the
  title quietly goes back to plain `vram`.

| File | What the fork changes |
|---|---|
| `src/btop_shared.hpp` | `gpu_info::vram_temp`, -1 when there is no reading |
| `src/linux/btop_collect.cpp` | `Gpu::collect` fills `vram_temp` for the first `Nvml::device_count` GPUs |
| `src/btop_draw.cpp` | `Gpu::draw` puts the temperature in the `vram` title and shortens the line after it to match |
| `gddr6/` | the feed, its systemd unit, and `install.sh` — new files, never conflict |
| `README.md` | a fork section prepended above upstream's README, which stays untouched below the `---` line; on conflict keep both |
| `AGENTS.md`, `CLAUDE.md` | this file; `CLAUDE.md` is a symlink to it |

Every hunk in `src/` carries a `btop-gddr6:` comment. `git grep btop-gddr6 src`
should find all three; if it finds fewer after a rebase, a hunk was lost.

## Upgrading to a new btop release

```bash
git fetch upstream --tags
git tag --sort=-v:refname | head -3          # pick the new release, e.g. v1.4.9
git rebase --onto v1.4.9 v1.4.8 gddr6        # replay the one commit
```

If the rebase conflicts, it will be in the three `src/` files above. Resolve by
re-applying the intent, not the old text:

1. **`gpu_info`** — add `long long vram_temp = -1;` next to `temp_max`.
2. **`Gpu::collect`** (the top-level one, returning `vector<gpu_info>&`) — after
   the vendor `collect` calls, loop `i` over `Nvml::device_count` and read
   `/run/gddr6/gpu{i}` into `gpus[i].vram_temp`, skipping a file older than 5 s.
   NVIDIA GPUs come first in `gpus`; if upstream ever changes that order, the
   index here must follow the NVML devices, wherever they now sit.
3. **`Gpu::draw`** — find where the `vram` section title is built (search for
   `"vram"`). Build the title as `vram` plus, when `vram_temp >= 0` and
   `check_temp` is on, a space and the temperature through `celsius_to` and
   coloured with `Theme::g("temp")` on `temp_max`. Whatever fill line follows
   the title must shrink by the extra visible width (`ulen` for the unit), or
   the box border drifts right.

Then build, check, and force-push the branch (it is the only branch that is
ever rewritten, and only by an upgrade):

```bash
make clean && make -j"$(nproc)" CXX=g++-14 GPU_SUPPORT=true   # btop needs C++23
git grep -c btop-gddr6 src                                      # 3 files
git log --oneline v1.4.9..gddr6                                 # exactly 1 commit
git push --force-with-lease origin gddr6
git tag gddr6-v1.4.9 && git push origin gddr6-v1.4.9
```

Update the tag numbers in this file and the `v1.4.8` in the README's fork section in the same commit (`git commit --amend`).

## Proving it works

A clean build is not proof. With the feed running (`systemctl status
gddr6-feed`, and `/run/gddr6/gpu0` updating every second):

```bash
tmux new-session -d -s t -x 200 -y 60 ./bin/btop; sleep 4
tmux capture-pane -p -t t | grep vram; tmux kill-session -t t
```

Every NVIDIA GPU box should read `vram NN°C`, and the `┐` after it should sit in
the same column as before the change. Stop the feed, wait 6 seconds, and run it
again: the title should be plain `vram` with the border unchanged.

## Installing

`gddr6/install.sh` builds, installs btop to `/usr/local/bin` (ahead of the
distro's `/usr/bin/btop` on `PATH`), installs and starts the feed, and prints
the current readings. It needs `/usr/local/bin/gddr6`, `nvidia-smi` and g++-14.

## Not in scope

- AMD and Intel GPUs: gddr6 only reads NVIDIA cards.
- Upstreaming: the reading needs root and an unofficial register map, which is
  not something btop would carry. Keep the patch small instead.
