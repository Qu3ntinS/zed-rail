# ZedRail Fork Guide

## What is ZedRail?

ZedRail is an independent fork of [Zed](https://github.com/zed-industries/zed) that adds an optional activity bar. It is **not** affiliated with Zed Industries.

## Branch strategy

| Branch | Purpose |
|--------|---------|
| `main` | Tracks the latest **stable** Zed release tag (same as [zed.dev](https://zed.dev) / GitHub Releases) |
| `zedrail` | Activity bar + ZedRail branding + release config |

Release tags use the format `v{stable_version}-rail.{patch}` (e.g. `v1.16.1-rail.1`).

`upstream/main` is development-only and is often ahead of stable (e.g. Cargo.toml `1.18.0` while stable is `1.16.1`). ZedRail follows stable so binaries match what zed.dev ships.

## Activity bar settings

| Setting | Default | Description |
|---------|---------|-------------|
| `activity_bar.enabled` | `false` | Show the vertical activity bar |
| `activity_bar.icon_size` | `medium` | `small`, `medium`, or `large` |
| `activity_bar.status_bar_buttons` | — | Panel keys to keep in the status bar |
| `activity_bar.button_order` | — | Custom button order |

Available panel keys include `ProjectPanel`, `GitPanel`, `search`, and others documented in the settings UI.

Example:

```json
{
  "activity_bar": {
    "enabled": true,
    "icon_size": "medium",
    "status_bar_buttons": ["search"]
  }
}
```

## Upstream sync

The `sync-upstream.yml` workflow polls [zed-industries/zed releases](https://github.com/zed-industries/zed/releases) every 6 hours (and supports manual dispatch). When a new **stable** release is published:

1. `main` is reset to that release tag (via `gh release list`, not `upstream/main`)
2. `.zedrail/upstream-stable` is updated with the version number
3. `main` is merged into `zedrail`
4. `Cargo.toml` is verified to match the stable version
5. A new `v{stable}-rail.{patch}` tag is created and `zedrail-release.yml` is invoked via `workflow_call`

Releases can also be rebuilt manually: **Actions → zedrail-release → Run workflow** with a tag (e.g. `v1.16.1-rail.4`).

If `zedrail` is still based on `upstream/main` (dev), the workflow stops and asks for a one-time migration:

```bash
./script/rebase-on-stable.sh
```

## Zed Cloud

ZedRail uses `https://zed.dev` for Collab, AI, and account services. Your Zed account works in ZedRail. Config and data are stored separately under `~/.config/zedrail/` (Linux) or equivalent paths.

## Contributing

- **ZedRail-only features**: open PRs against `zedrail`
- **Upstream bug fixes**: contribute to [zed-industries/zed](https://github.com/zed-industries/zed)
- Keep activity bar patches isolated in `crates/workspace/src/activity_bar.rs` when possible
