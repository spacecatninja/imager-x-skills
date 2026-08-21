# Templating API

The complete `craft.imagerx` surface, the transformed-image model, placeholders, and the colour
utilities. Signatures are verbatim from the plugin — nothing here is inferred.

`craft.imagerx` and `craft.imager` are the same variable. Prefer `craft.imagerx`.

## Transforms

```php
transformImage(Asset|ImagerAdapterInterface|string|null $image, array|string $transforms,
               ?array $transformDefaults = null, ?array $configOverrides = null): array|TransformedImageInterface|null
srcset(?array $images, string $descriptor = 'w'): string
```

Covered in `transform-syntax.md`. `srcset` is also the only Twig filter Imager registers:
`{{ imgs|srcset }}`.

## Placeholders

```php
placeholder(?array $config = null): string
base64Pixel(int $width = 1, int $height = 1, string $color = 'transparent'): string  // deprecated
```

`base64Pixel()` is deprecated — use `placeholder()`.

`placeholder()` returns a data URI. Config keys, with defaults from the service:

| Key | Default | Applies to |
|-----|---------|-----------|
| `type` | `'svg'` | `'svg'`, `'gif'`, `'silhouette'`, `'blurhash'`. Anything else returns `''` |
| `width` | `1` | all (blurhash falls back to `4`) |
| `height` | `1` | all (blurhash falls back to `3`) |
| `color` | `null` → `transparent` | svg, gif; silhouette background, default `#fefefe` |
| `source` | `null` | silhouette — **required** |
| `fgColor` | `null` → `#e0e0e0` | silhouette |
| `size` | `1` | silhouette |
| `silhouetteType` | `''` | silhouette. `'curve'` is the other value |
| `hash` | — | blurhash — **required**, else returns `''` |
| `format` | `'png'` | blurhash. `png`, `gif`, `jpg` |
| `base64` | `false` | blurhash. `true` returns raw base64 with no data-URI prefix |

```twig
{# Transparent SVG at the right ratio — the cheapest possible placeholder #}
<img src="{{ craft.imagerx.placeholder({ width: 160, height: 90 }) }}"
     srcset="{{ imgs|srcset }}" sizes="100vw" alt="{{ image.alt }}">

{# Solid colour #}
{{ craft.imagerx.placeholder({ width: 16, height: 9, color: '#1b3a5c' }) }}

{# Blurhash #}
{{ craft.imagerx.placeholder({ type: 'blurhash', hash: imgs[0].blurhash, width: 32, height: 18 }) }}
```

A 1×1 transparent GIF is returned from a hardcoded constant, so the default `type: 'gif'` call
costs nothing.

## Transformed image model

Returned by `transformImage()`. Available on every transformer, though remote ones leave some
fields empty — see `transformers.md`.

```php
getUrl(): string
getPath(): string
getFilename(): string
getExtension(): string
getMimeType(): string
getWidth(): int
getHeight(): int
getSize(string $unit = 'b', int $precision = 2): float|int
getPlaceholder(array $settings = []): string
getIsNew(): bool
getDataUri(): string
getBase64Encoded(): string
getBlurhash(): string
__toString(): string
```

Twig's property syntax works for all of them: `img.url`, `img.width`, `img.isNew`. `getSize()`
needs its arguments: `img.getSize('k', 1)`.

```twig
{% set img = craft.imagerx.transformImage(image, { width: 1200, ratio: 16/9 }) %}
<img src="{{ img.url }}" width="{{ img.width }}" height="{{ img.height }}" alt="{{ image.alt }}">
```

`__toString()` returns the URL, so `{{ img }}` works — but be explicit and write `{{ img.url }}`.

**`getPlaceholder()` with no arguments does not inherit the image's dimensions.** Width and
height are only filled in when you pass a non-empty settings array, so a bare call returns a
1×1 SVG. Decoded output from a real 400×268 transform:

```
t.getPlaceholder()                        →  <svg … width='1'   height='1'   style='background:transparent'/>
t.getPlaceholder({ color: '#eeeeee' })    →  <svg … width='400' height='268' style='background:#eeeeee'/>
```

❌ 1×1 placeholder, wrong aspect ratio, layout shift:
```twig
<img src="{{ img.getPlaceholder() }}" srcset="{{ imgs|srcset }}">
```

✅ Pass something so the dimensions are filled from the transform:
```twig
<img src="{{ img.getPlaceholder({ color: '#eee' }) }}" srcset="{{ imgs|srcset }}">
```

`getIsNew()` tells you whether this request generated the file — useful for spotting cache
misses in development:

```twig
{% if craft.app.config.general.devMode and img.isNew %}
    {# this transform was just generated #}
{% endif %}
```

The imgix model adds `getPalette(string $format = 'json', int $numColors = 6, string $cssPrefix = '')`.

## Format and capability checks

```php
serverSupportsWebp(): bool
serverSupportsAvif(): bool
serverSupportsJxl(): bool
clientSupportsWebp(): bool
clientSupports(string $format): bool   // 'image/' prefixed if absent
isAnimated(Asset|string $asset): bool
imgixEnabled(): bool
transformer(): string
```

`imgixEnabled()` is a string comparison against `'imgix'`, so it is `false` for
`imgixdownload`. Use `transformer()` when you need the actual handle. See `modern-formats.md`
for how to use these without breaking caching.

## Named transform lookup

```php
hasNamedTransform(string $name): bool
getNamedTransform(string $name): ?array
```

```twig
{% set handle = block.imageTransform ?: 'contentImage' %}
{% if craft.imagerx.hasNamedTransform(handle) %}
    {{ ppimg(image, handle) }}
{% endif %}
```

Useful when a transform handle comes from content — a dropdown field, say — and a stale value
would otherwise throw. See `named-transforms.md`.

## Colours

```php
getDominantColor(Asset|string $image, int $quality = 10, string $colorValue = 'hex', ?array $area = null): string|array|bool|null
getColorPalette(Asset|string $image, int $colorCount = 8, int $quality = 10, string $colorValue = 'hex', ?array $area = null): ?array
```

`quality` is a sampling step — **lower is more accurate and slower**. `colorValue` is `'hex'`
or `'rgb'`. `area` restricts sampling to part of the image.

```twig
{% set bg = craft.imagerx.getDominantColor(image) %}
<section style="background-color: {{ bg }}">

{% set palette = craft.imagerx.getColorPalette(image, 5) %}
{% for color in palette %}<span style="background: {{ color }}"></span>{% endfor %}
```

Both decode the image, so they are not free. Pass a **transformed** image rather than the
original — sampling a 400px transform is far cheaper than a 5000px source — and precompute
with `generateFlags` where you can (see `named-transforms.md`).

❌ Samples the full-size original on every request:
```twig
{% set bg = craft.imagerx.getDominantColor(entry.heroImage.one()) %}
```

✅ Sample a small transform, which is also already cached:
```twig
{% set small = craft.imagerx.transformImage(entry.heroImage.one(), { width: 100 }) %}
{% set bg = craft.imagerx.getDominantColor(small) %}
```

### Colour utilities

```php
hex2rgb(string $color): array
rgb2hex(array $color): string

getBrightness(array|string $color): float
getHue(array|string $color): float
getLightness(array|string $color): float
getSaturation(array|string $color): float
getPercievedBrightness(array|string $color): float
getRelativeLuminance(array|string $color): float

getBrightnessDifference(array|string $color1, array|string $color2): float
getColorDifference(array|string $color1, array|string $color2): int
getContrastRatio(array|string $color1, array|string $color2): float

isBright(array|string $color, float $threshold = 127.5): bool
isLight(array|string $color, int $threshold = 50): bool
looksBright(array|string $color, float $threshold = 127.5): bool
```

`getPercievedBrightness` is spelled that way in the plugin. It is not a typo to fix in your
templates — that is the method name.

All of them take a hex string or an RGB array, so results from `getDominantColor()` feed
straight in.

Picking readable text over an image-derived background:

```twig
{% set small = craft.imagerx.transformImage(image, { width: 100 }) %}
{% set bg = craft.imagerx.getDominantColor(small) %}
{% set onDark = craft.imagerx.getContrastRatio(bg, '#ffffff') >= 4.5 %}

<div style="background-color: {{ bg }}" class="{{ onDark ? 'text-white' : 'text-black' }}">
```

`getContrastRatio()` returns the WCAG ratio, so `>= 4.5` is the AA threshold for body text and
`>= 3` for large text. Prefer it over `isBright`/`isLight`/`looksBright` when the requirement
is actual accessibility rather than a rough light/dark split.

The three brightness predicates differ in what they measure: `isBright` uses simple brightness,
`isLight` uses lightness (HSL), `looksBright` uses perceived brightness. `looksBright` matches
human perception best of the three.

## Not on the Twig variable

For completeness, so these are not invented:

- **No `transformImages()`** — `transformImage()` handles both.
- **No `getPlaceholder()` on `craft.imagerx`** — that is `placeholder()` on the variable, and
  `getPlaceholder()` on a transformed-image model.
- **No `|transform` filter** — `|srcset` is the only filter.
- **No `base64Pill()`** — `base64Pixel()`, deprecated.
- **No `clearCaches()`** — use the console commands or the CP utility.

PHP-side events (`EVENT_BEFORE_TRANSFORM_IMAGE`, `EVENT_REGISTER_TRANSFORMERS` and friends) are
outside this skill's scope; see https://imager-x.spacecat.ninja/extending.
