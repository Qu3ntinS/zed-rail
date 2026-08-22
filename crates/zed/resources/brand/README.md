# ZedRail brand assets

ZedRail icons are derived from the official [Zed brand assets](https://zed.dev/brand) with an activity-bar motif added for fork identity.

## Official reference files (`zed-official/`)

Downloaded from https://zed.dev/brand for use as the generation source:

| File | Source |
|------|--------|
| `stable-app-logo.png` | Stable app icon on the brand page |
| `logomark.svg` | Logomark SVG (copy from brand page) |
| `logo-white.png` | White logomark + wordmark |
| `logo-black.png` | Black logomark + wordmark |

## Regenerating app icons

```bash
python3 script/generate-zedrail-icons.py
```

This writes:

- `crates/zed/resources/app-icon.png` (512×512)
- `crates/zed/resources/app-icon@2x.png` (1024×1024)
- `crates/zed/resources/windows/app-icon.ico`
- `crates/zed/resources/brand/zedrail-app-icon-preview.png` (256×256)

Requires `python3`, `Pillow`, `rsvg-convert` (librsvg), and `magick` (ImageMagick).

## Trademark

The Zed name and logos are trademarks of Zed Industries, Inc. ZedRail is an independent community fork and is not affiliated with or endorsed by Zed Industries. The ZedRail icon evolves the official stable app icon with a distinct activity-bar element rather than copying the wordmark or implying official status.
