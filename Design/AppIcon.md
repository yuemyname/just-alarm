# just alarm app icon

The current icon uses the user's original `bird.png`, preserved as `Design/Bird.png`. It is no longer the pixel-art variant. The shipping asset has a white background to match the supplied GIF and is an opaque 1024 × 1024 PNG. iOS applies rounded corners.

Regenerate from the repository root:

```sh
swift Design/GenerateAppIcon.swift
```

The original transparent PNG is kept unchanged. The script only sizes and composites it for the app icon. `Design/PixelBird.png` is a previous design reference, not the shipping icon.

`JustAlarm/bird.gif` is the user's original animation, copied unchanged into the app bundle. `StartupView.swift` decodes its frames and timing with ImageIO and plays one cycle after launch. No image generation was used for these supplied assets.
