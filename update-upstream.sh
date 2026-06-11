#!/usr/bin/env bash
# update-upstream.sh — refresh the `./upstream/` mirror of pre-built sing-box
# rule sets from MetaCubeX/meta-rules-dat (sing branch).
#
# Why mirror instead of pointing clients directly at MetaCubeX:
#   1. Single update cadence we control (run this script when we want a refresh).
#   2. One repo URL for clients — easier to manage 10+ devices.
#   3. Insurance against upstream rename / move / DMCA.
#
# Re-runnable. Adding/removing files = edit the FILES array.
# After running, commit the changed bytes in ./upstream/ alongside the local
# us-required-extras.json / client-bypass.json edits, then push to the
# myvpc-rule-sets repo. Clients pick up the new content within 24 h
# (sing-box `remote` rule_set update_interval).
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
UP="$ROOT/upstream"
mkdir -p "$UP"

BASE='https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite'

# sing-box-format .srs files to mirror. Single-quoted to keep '!' literal.
# Grouped by role (Tokyo us-required vs. client bypass-direct) for clarity;
# sing-box doesn't care about the grouping, only the filenames.
FILES=(
  # ---- Tokyo us-required (route via SJ → US egress) -----------------------
  'category-ai-!cn.srs'    # All AI services (OpenAI, Anthropic, Google AI, …)
  'paypal.srs'
  'stripe.srs'

  # ---- Client bypass-direct (route via China ISP, skip VPN tunnel) --------
  # CDN / static
  'jsdelivr.srs'
  'cloudflare.srs'
  'akamai.srs'
  'jquery.srs'
  'gitbook.srs'
  # Developer tooling
  'github.srs'
  'jetbrains.srs'
  'npmjs.srs'
  'python.srs'
  'ubuntu.srs'
  'docker.srs'
  'gitlab.srs'
  'stackexchange.srs'
  'jfrog.srs'
  'gitee.srs'
  'archive.srs'
  # Documentation
  'mozilla.srs'
  'wikimedia.srs'
  'atlassian.srs'
  'freecodecamp.srs'
)

for f in "${FILES[@]}"; do
    echo -n "  $f ... "
    if curl -fsSL "$BASE/$f" -o "$UP/$f.new"; then
        mv "$UP/$f.new" "$UP/$f"
        echo "ok ($(stat -c%s "$UP/$f") bytes)"
    else
        rm -f "$UP/$f.new"
        echo "FAIL (kept previous, if any)"
        exit 1
    fi
done

echo
echo "Mirror state:"
ls -la "$UP"
