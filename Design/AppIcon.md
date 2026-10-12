# just alarm app icon

The user-selected pixel bird replaces the orange clock icon. `PixelBird.png` is the transparent source artwork created with built-in Imagegen from the user's bird reference.

The shipping asset is an opaque 1024 × 1024 PNG with a light mint background. Nearest-neighbor scaling preserves the pixel edges. iOS supplies the rounded corners.

To regenerate from the repository root:

```sh
swift Design/GenerateAppIcon.swift
```

Generation prompt: Convert the supplied bird into coarse 8-bit pixel art. Preserve the cream egg-shaped body, two large staring eyes, orange beak pointing right, tiny triangular wing at the lower left, and short dark legs. Use chunky square pixels, stepped dark outlines and a limited cream, black, white and orange palette. Preserve the awkward expression and transparent background; no accessories or text.
