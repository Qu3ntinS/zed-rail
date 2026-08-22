# ZedRail Fork Guide

## What is ZedRail?

ZedRail is an independent fork of [Zed](https://github.com/zed-industries/zed) that adds an optional activity bar. It is **not** affiliated with Zed Industries.

## Branch strategy

| Branch | Purpose |
|--------|---------|
| `main` | Mirrors upstream Zed (`zed-industries/zed`) |
| `zedrail` | Activity bar + ZedRail branding + release config |

Release tags use the format `v{zed_version}-rail.{patch}` (e.g. `v1.18.0-rail.1`).

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

The `sync-upstream.yml` workflow checks for new Zed stable releases every 6 hours. When a new release is detected:

1. `upstream/main` is merged into `main`
2. `zedrail` is rebased onto `main`
3. A new release tag is created and the release workflow runs

If the rebase fails, a GitHub issue is opened for manual resolution.

## Zed Cloud

ZedRail uses `https://zed.dev` for Collab, AI, and account services. Your Zed account works in ZedRail. Config and data are stored separately under `~/.config/zedrail/` (Linux) or equivalent paths.

## Contributing

- **ZedRail-only features**: open PRs against `zedrail`
- **Upstream bug fixes**: contribute to [zed-industries/zed](https://github.com/zed-industries/zed)
- Keep activity bar patches isolated in `crates/workspace/src/activity_bar.rs` when possible
