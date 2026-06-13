# myvpc rule-sets

Source of truth for sing-box `remote` rule_sets used by the vpn topology.
Two parallel lists drive the routing inversion (default Tokyo-direct egress,
exceptions go via SJ; clients have their own bypass-direct list):

| File | Consumed by | Role |
|---|---|---|
| `upstream/category-ai-!cn.srs` | Tokyo | AI services (OpenAI / Anthropic / Google AI / …) → must egress US (SJ). |
| `upstream/paypal.srs` | Tokyo | PayPal → SJ. |
| `upstream/stripe.srs` | Tokyo | Stripe → SJ. |
| `us-required-extras.json` | Tokyo | Hand-curated US banks / brokerages / gov → SJ. |
| `upstream/{jsdelivr,cloudflare,akamai,jquery,gitbook}.srs` | vpn client devices | CDN / static — direct via China ISP. |
| `upstream/{github,gitlab,gitee,jetbrains,npmjs,python,ubuntu,docker,stackexchange,jfrog,archive}.srs` | vpn client devices | Developer tooling — direct. |
| `upstream/{mozilla,wikimedia,atlassian,freecodecamp}.srs` | vpn client devices | Documentation — direct. |
| `client-bypass.json` | vpn client devices | Hand-curated extras (`merriam-webster.com`, etc.) — direct. |

All upstream files are mirrored from `MetaCubeX/meta-rules-dat` (sing branch) by `update-upstream.sh`.

## How clients see them

Once this repo is pushed to a public GitHub repo (e.g. `https://github.com/<user>/myvpc-rule-sets`), every sing-box config (Tokyo, each vpn client device) declares them as `type: remote, update_interval: 24h` and fetches the raw URLs:

```
https://raw.githubusercontent.com/<user>/myvpc-rule-sets/main/upstream/category-ai-!cn.srs   (binary)
https://raw.githubusercontent.com/<user>/myvpc-rule-sets/main/upstream/paypal.srs            (binary)
https://raw.githubusercontent.com/<user>/myvpc-rule-sets/main/upstream/stripe.srs            (binary)
https://raw.githubusercontent.com/<user>/myvpc-rule-sets/main/us-required-extras.json        (source)
https://raw.githubusercontent.com/<user>/myvpc-rule-sets/main/client-bypass.json             (source)
```

`format: "binary"` for the upstream `.srs` files; `format: "source"` for the local `.json` files. Clients fetch via the VPN tunnel (`download_detour: "auto"` on clients, `"direct"` on Tokyo).

## Workflows

### Add a US-only site I just discovered (e.g. a new bank)

Edit `us-required-extras.json`, add the domain to the `domain_suffix` array, commit, push to GitHub. All clients pick it up within 24 h.

### Add a China-accessible foreign site to bypass the VPN

Edit `client-bypass.json`, add the domain, commit, push.

### Refresh upstream mirrors

**Automated**: a GitHub Action (`.github/workflows/refresh-upstream.yml`) runs `update-upstream.sh` daily at 04:00 UTC, commits + pushes if `upstream/` differs, otherwise exits silently. Clients see upstream changes within ~24 h via the sing-box `update_interval`. No manual action needed in steady state.

**Manual refresh** (e.g., right after adding a new entry to the `FILES` array):

```sh
./update-upstream.sh
git add upstream/ && git commit -m "refresh upstream rule sets"
git push
```

Or trigger the workflow from the GitHub Actions tab via "Run workflow".

### Add a new upstream `.srs` to mirror (end-to-end, automated)

Two helper scripts in `scripts/` do all the wiring (FILES edit + fetch + config update). Pick by role:

```sh
# Tokyo us-required (route via SJ): edits FILES, fetches, updates Tokyo live config
./scripts/add-tokyo-us-required.sh <service-name>     # e.g. square

# Client bypass (route direct via China ISP): edits FILES + both templates;
# user runs the existing apply scripts to push to each device afterward
./scripts/add-client-bypass.sh <service-name>          # e.g. notion
```

Both verify the file exists at MetaCubeX before changing anything, are idempotent on re-run, and don't auto-commit (review the diff and `git push` yourself).

### Manually adding a new upstream `.srs` (if the scripts don't fit)

Edit the `FILES` array in `update-upstream.sh`, commit, push. The daily workflow picks up the new entry on its next run. Then update each consuming sing-box config to actually reference it.

## Format rules

- Both local `.json` files use sing-box headless rule set source format v1.
- `domain_suffix` matches the bare domain AND all subdomains (so `chase.com` covers `chase.com`, `www.chase.com`, `secure.chase.com`, etc.).
- Sort entries by category, separated by blank lines, for review ease (sing-box doesn't care about order or whitespace).
