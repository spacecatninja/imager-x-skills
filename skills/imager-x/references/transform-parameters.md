# Transform Parameters

Every key that can go inside a transform object, plus the normalization rules Imager X
applies before transforming — which is where most surprises come from. For how to pass these
see `transform-syntax.md`.

## Sizing

| Key | Type | Notes |
|-----|------|-------|
| `width` | int | Target width in pixels |
| `height` | int | Target height in pixels |
| `ratio` | int/float | Computes the missing dimension. `16/9` in Twig is fine — it evaluates to a float |
| `mode` | string | `crop` (default), `fit`, `stretch`, `croponly`, `letterbox` |
| `position` | string/array | Crop focus. **Only honoured by `crop` and `croponly`** |
| `cropZoom` | float | Default 1. Resize larger before cropping, so the crop shows less of the frame |
| `pad` | int/array | Padding, CSS-style. Colour comes from `bgColor` |

### Resize modes

- **`crop`** — fills the box, cropping the overflow. The default and usually what you want.
- **`fit`** — scales to fit inside the box, keeping the aspect ratio. Output dimensions can be
  smaller than requested in one axis.
- **`stretch`** — forces the exact box, distorting the image.
- **`croponly`** — crops without resizing. **Craft transformer only.**
- **`letterbox`** — like `fit`, then pads out to the full box using the `letterbox` parameter.

```twig
{% set img = craft.imagerx.transformImage(image, {
    width: 600, height: 600,
    mode: 'letterbox',
    letterbox: { color: '#000000', opacity: 1 }
}) %}
```

`mode` is lowercased for you, so `'Crop'` works.

### position

Accepts a percentage pair like `'50% 50%'`, one of Craft's **hyphenated** keywords, or
`{ x: 0.5, y: 0.5 }`. Keywords and `{x, y}` objects are converted to percentages, and `%` signs
are stripped.

The nine accepted keywords are exactly:

```
top-left      top-center      top-right
center-left   center-center   center-right
bottom-left   bottom-center   bottom-right
```

**Anything else throws.** An unrecognised string is passed through untranslated and later used
in arithmetic, producing `Unsupported operand types: string / int` from `ImagerService`. The
space-separated forms are the easy mistake, because they look like CSS.

❌ Throws `Unsupported operand types: string / int`:
```twig
{% set img = craft.imagerx.transformImage(image, { width: 600, height: 400, mode: 'crop', position: 'top center' }) %}
```

✅ Hyphenated keyword, or an explicit percentage pair:
```twig
{% set img = craft.imagerx.transformImage(image, { width: 600, height: 400, mode: 'crop', position: 'top-center' }) %}
{% set img = craft.imagerx.transformImage(image, { width: 600, height: 400, mode: 'crop', position: '50% 20%' }) %}
```

Two behaviours to know:

- **Asset focal points are applied automatically.** If the image is an Asset with a focal
  point set and you have not passed `position`, the focal point becomes the position. Editors
  setting focal points in the CP works with no template changes.
- **`position` is deleted when the mode is not `crop` or `croponly`** — and because the focal
  point step runs *after* that deletion, the Asset's focal point is then substituted in. So a
  `fit` transform still carries a position in its cache filename; it just is not the one you
  wrote. Verified on a real transform:

  ```
  { width: 300, height: 200, mode: 'fit',  position: 'top-center' }  →  …_W300_H200_Mfit_P49-48.jpeg
  { width: 300, height: 200, mode: 'crop', position: 'top-center' }  →  …_W300_H200_Mcrop_P50-0.jpeg
  ```

  The `fit` transform shows `P49-48`, the asset's focal point, not the `50% 0%` that
  `top-center` maps to. Neither mode uses position for anything but cropping, so on `fit` this
  is cosmetic — but it does mean changing an asset's focal point invalidates its `fit`
  transforms too.

❌ Position on a `fit` transform — silently dropped, no warning:
```twig
{% set img = craft.imagerx.transformImage(image, { width: 600, height: 400, mode: 'fit', position: 'top-center' }) %}
```

✅ Position needs a cropping mode:
```twig
{% set img = craft.imagerx.transformImage(image, { width: 600, height: 400, mode: 'crop', position: 'top-center' }) %}
```

### ratio

`ratio` computes whichever of `width`/`height` is missing, then removes itself from the
transform.

```twig
{# 1200 × 675 #}
{% set img = craft.imagerx.transformImage(image, { width: 1200, ratio: 16/9 }) %}

{# 1067 × 600 #}
{% set img = craft.imagerx.transformImage(image, { height: 600, ratio: 16/9 }) %}
```

If **both** `width` and `height` are set, `ratio` computes nothing — but it stays in the
transform, so it still contributes to the cache filename. Two transforms that differ only by an
unused `ratio` produce two byte-identical files under different names. Measured:

```
{ width: 600, ratio: 16/9 }              →  600×338  …_W600_H338_P49-48.jpeg
{ width: 600, height: 338, ratio: 16/9 } →  600×338  …_W600_H338_P49-48_ratio1-7777777777778.jpeg
```

❌ Redundant and cache-wasteful:
```twig
{% set img = craft.imagerx.transformImage(image, { width: 1200, height: 675, ratio: 16/9 }) %}
```

✅ Pick one way of expressing the shape:
```twig
{% set img = craft.imagerx.transformImage(image, { width: 1200, ratio: 16/9 }) %}
```

### pad

```twig
{% set a = craft.imagerx.transformImage(image, { width: 300, pad: 10 }) %}          {# all sides #}
{% set b = craft.imagerx.transformImage(image, { width: 300, pad: [20, 10] }) %}     {# y, x #}
{% set c = craft.imagerx.transformImage(image, { width: 300, pad: [20, 10, 0, 6] }) %} {# t, r, b, l #}
```

Accepts an int, a string with a `px` suffix, or a 1–4 element array. Set `bgColor` for the
padding colour.

## Format and quality

| Key | Type | Notes |
|-----|------|-------|
| `format` | string | `jpg`, `png`, `gif`, `webp`, `avif`, `jxl`. Omit to keep the source format |
| `jpegQuality` | int | Default 80 |
| `webpQuality` | int | Default 80 |
| `avifQuality` | int | Default 80 |
| `jxlQuality` | int | Default 80 |
| `pngCompressionLevel` | int | Default 2 |
| `interlace` | bool/string | Progressive encoding. `false`, `'line'`, `'plane'`, `'partition'`, or `true` |
| `customEncoderOptions` | array | Overrides options for a `customEncoder`, merged over its defaults |

**`quality` is not a real parameter.** If present it is moved to `jpegQuality` (and only if
`jpegQuality` is not already set), then removed.

❌ Expecting `quality` to apply to WebP:
```twig
{% set img = craft.imagerx.transformImage(image, { width: 1200, format: 'webp', quality: 60 }) %}
```
This encodes WebP at the default `webpQuality` of 80, and sets a `jpegQuality` that nothing
uses. Measured on the same source at width 300:

```
{ format: 'webp', quality: 30 }       →  …_W300_Q30_P49-48.webp     9 kB
{ format: 'webp', webpQuality: 30 }   →  …_W300_P49-48_WQ30.webp    3 kB
```

Note the first filename records `Q30`, so the transform looks like it was honoured — the file
is simply three times the size.

✅ Name the format's own quality setting:
```twig
{% set img = craft.imagerx.transformImage(image, { width: 1200, format: 'webp', webpQuality: 60 }) %}
```

See `modern-formats.md` for choosing formats and qualities.

## Effects

`effects` runs after the resize; `preEffects` runs before it. `preEffects` gives better
results for some adjustments (blurs and sharpens especially) at a performance cost, since it
works on the full-size image. Effects are applied in the order the keys appear.

```twig
{% set img = craft.imagerx.transformImage(image, {
    width: 1200,
    preEffects: { unsharpmask: [2, 1, 1, 0.05] },
    effects: { grayscale: true, gamma: 1.5 }
}) %}
```

**GD and Imagick:** `blur`, `brightness`, `colorize`, `gamma`, `grayscale`, `negative`,
`sharpen`.

**Imagick only:** `adaptiveBlur`, `adaptiveSharpen`, `clut`, `colorBlend`, `contrast`,
`contrastStretch`, `despeckle`, `enhance`, `equalize`, `floodfillpaint`, `levels`, `modulate`,
`motionBlur`, `normalize`, `oilPaint`, `opacity`, `posterize`, `quantize`, `radialBlur`,
`sepia`, `tint`, `transparentpaint`, `unsharpmask`.

The active driver comes from Craft's own `imageDriver` general config setting, not from
Imager X. On GD, Imagick-only effects are ignored. Check the driver before promising an
effect will work:

```twig
{{ craft.app.config.general.imageDriver }}
```

Effect plugins add more keys — the Rounded Corners effect plugin, for instance. Argument
shapes for each effect are in https://imager-x.spacecat.ninja/effects.

## Watermark

```twig
{% set logo = craft.assets().volume('brand').filename('logo.png').one() %}
{% set img = craft.imagerx.transformImage(image, {
    width: 1200,
    watermark: {
        image: logo,
        width: 80,
        height: 80,
        position: { right: 30, bottom: 30 },
        opacity: 0.75,
        blendMode: 'multiply'
    }
}) %}
```

`image` takes the same things `transformImage()` does — an Asset, a previously transformed
image, or a URL. `position` is an offsets object using `left`/`right` and `top`/`bottom`.
`opacity` and `blendMode` are **Imagick only**; `blendMode` accepts `blend`, `darken`,
`lighten`, `modulate`, `multiply`, `overlay`, `screen`.

Most third-party transformers do not translate watermarks at all — see `transformers.md`.

## Animated GIFs

`frames` extracts a subset, as `'startFrame-endFrame@interval'`:

```twig
{% set first    = craft.imagerx.transformImage(gif, { width: 300, frames: '0' }) %}
{% set firstTen = craft.imagerx.transformImage(gif, { width: 300, frames: '0-9' }) %}
{% set every5   = craft.imagerx.transformImage(gif, { width: 300, frames: '0-40@5' }) %}
{% set toEnd    = craft.imagerx.transformImage(gif, { width: 300, frames: '0-*@5' }) %}
```

`craft.imagerx.isAnimated(asset)` tests whether an image is animated. Animated GIF transforms
need Imagick. The Power Pack skips animated GIFs entirely by default — see
`responsive-images.md`.

## Other

| Key | Type | Notes |
|-----|------|-------|
| `trim` | float | Imagick `trimImage` fuzz, 0–1. 0.2–0.5 is the useful range |
| `letterbox` | object | `{ color, opacity }` for `mode: 'letterbox'`. Default `{ color: '#000', opacity: 0 }` |
| `transformerParams` | object | Passed straight to the active transformer. The escape hatch for service-specific options |
| `imgixParams` | object | **Gone in 6.x** — silently ignored, not merely deprecated. Use `transformerParams` |
| `adapterParams` | object | Passed to the file adapter (PDF, video) |

The Craft 5 imgix transformer reads **only** `transformerParams` — `imgixParams` is not
referenced anywhere in the 6.x codebase. A template still passing it gets no error and no imgix
parameters; the key just contributes to the cache filename. Grep for it when upgrading from
Imager X 5.x.

❌ Silently does nothing on 6.x:
```twig
{% set img = craft.imagerx.transformImage(image, { width: 1200, imgixParams: { sharp: 10 } }) %}
```

✅
```twig
{% set img = craft.imagerx.transformImage(image, { width: 1200, transformerParams: { sharp: 10 } }) %}
```

## Config settings usable per transform

Beyond the keys above, most Imager X config settings can be set on an individual transform,
because the config model resolves `$transform[$key] ?? $this[$key]`. Commonly useful:

`allowUpscale`, `resizeFilter`, `smartResizeEnabled`, `removeMetadata`,
`preserveColorProfiles`, `bgColor`, `convertToRGB`, `instanceReuseEnabled`, `hashFilename`,
`hashPath`, `addVolumeToPath`, `cacheDuration`, `noop`, `webpImagickOptions`.

```twig
{# Never upscale this one transform, whatever the global setting is #}
{% set img = craft.imagerx.transformImage(image, { width: 2400, allowUpscale: false }) %}
```

`filenamePattern` is a special case: it works per transform, but it is excluded from the
filename hash — see `named-transforms.md`. Full setting list in `configuration.md`.

## Normalization order

`normalizeTransform()` runs on each transform right before transforming, in this order:

1. `mode` is lowercased.
2. `position` is removed unless `mode` is `crop` or `croponly`.
3. `quality` is moved to `jpegQuality` (if unset) and removed.
4. `ratio` computes the missing dimension, then removes itself. No-op if both are set.
5. The Asset focal point fills `position` if it is still unset.
6. `position` is converted from Craft keywords or `{x, y}` to percentages, `%` stripped.
7. `pad` is normalized to a four-element array.
8. Keys are sorted, then `width`, `height`, `mode` are moved to the front and `preEffects`,
   `effects`, `watermark` to the back — purely so the generated filename reads sensibly.

Every remaining key contributes to the transform's filename, which is how Imager decides
whether a cached file already exists. Adding a key that changes nothing visually still forces
a regeneration of every transform using it.
