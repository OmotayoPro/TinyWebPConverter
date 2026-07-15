# Tiny WebP Converter

A free, offline, native macOS app that converts PNG, JPEG, HEIC, TIFF, GIF, and BMP images to
WebP. No accounts, no network calls, no subscriptions. See [`tiny-webp-converter-prd.md`](../MD%20Files/tiny-webp-converter-prd.md)
for the full product spec.

## Status

Early: the core conversion pipeline (`TinyWebPCore`) is implemented and tested as a standalone
Swift package, independent of any UI. The SwiftUI app target hasn't been added yet.

## Architecture

- **Decode, resize, and metadata extraction** use ImageIO/CoreGraphics (system frameworks).
- **WebP encoding** uses [libwebp](https://github.com/webmproject/libwebp) (via the
  [libwebp-Xcode](https://github.com/SDWebImage/libwebp-Xcode) Swift package), because ImageIO
  can *decode* WebP but has never supported *encoding* it — confirmed empirically via
  `CGImageDestinationCopyTypeIdentifiers()`, which omits WebP from the list of encodable formats
  on every current macOS version. This is the one dependency in an otherwise dependency-free,
  system-framework-only pipeline.

The pipeline: validate → decode → transform (resize, metadata) → encode as WebP → write. The
same encode step will back both the real conversion and the in-memory before/after preview.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.10+

## Development

```
swift build
swift test
```

## License

MIT — see [`LICENSE`](LICENSE).
