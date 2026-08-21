# Transform Syntax

How to call Imager X to produce transforms: the `transformImage()` signature, the quick
syntax and its exact parsing rules, the full syntax, the `fillTransforms` family, the
`|srcset` filter, and chaining. For the individual transform parameters see
`transform-parameters.md`; for markup see `responsive-images.md`.

## The one entry point

```php
craft.imagerx.transformImage(
    Asset|ImagerAdapterInterface|string|null $image,
    array|string $transforms,
    ?array $transformDefaults = null,
    ?array $configOverrides = null
): array|TransformedImageInterface|null
```

`craft.imagerx` and `craft.imager` are the same variable — both are registered. New code
should use `craft.imagerx`.

There is **no `|transform` filter** and **no `transformImages()` method**. The only Twig
filter Imager X registers is `|srcset`.

### What it returns

The return type depends on the shape of `$transforms`, not on how many images come back:

```twig
{# Single transform object → a single TransformedImage model #}
{% set img = craft.imagerx.transformImage(image, { width: 1000 }) %}
{{ img.url }}

{# Array of transform objects → an array of models #}
{% set imgs = craft.imagerx.transformImage(image, [{ width: 600 }, { width: 1200 }]) %}
{{ imgs|srcset }}
```

The rule in the source is `isset($transforms[0])`: an array with a `0` key is treated as a
list of transforms, anything else as one transform object. Quick syntax always produces two
entries, so it always returns an array.

❌ Assuming a single model when you passed a list:
```twig
{% set img = craft.imagerx.transformImage(image, [{ width: 1000 }]) %}
<img src="{{ img.url }}">   {# img is an array — this renders nothing useful #}
```

✅ Either drop the wrapping array, or index into the result:
```twig
{% set img = craft.imagerx.transformImage(image, { width: 1000 }) %}
<img src="{{ img.url }}">
```

## Quick syntax

The compact form for "a range of widths, optionally an aspect ratio and a format". Added in
4.3.0.

```twig
{% set imgs = craft.imagerx.transformImage(image, [400, 1200]) %}
{% set imgs = craft.imagerx.transformImage(image, [400, 1200, 16/9]) %}
{% set imgs = craft.imagerx.transformImage(image, [400, 1200, 'webp']) %}
{% set imgs = craft.imagerx.transformImage(image, [400, 1200, 16/9, 'jpg']) %}
{% set imgs = craft.imagerx.transformImage(image, [400, 1200, { ratio: 16/9, format: 'avif', avifQuality: 65 }]) %}
```

### Detection — it must be two real integers

```php
is_array($transforms)
  && count($transforms) >= 2
  && isset($transforms[0], $transforms[1])
  && is_int($transforms[0])
  && is_int($transforms[1])
```

❌ Quoted numbers are **not** quick syntax:
```twig
{% set imgs = craft.imagerx.transformImage(image, ['400', '1200']) %}
```
`is_int('400')` is false, so this falls through to full syntax, where `'400'` is not a valid
transform object. The result is an empty or broken srcset with no error. This is the single
most common cause of "my srcset is empty".

✅ Real integers:
```twig
{% set imgs = craft.imagerx.transformImage(image, [400, 1200]) %}
```

Watch for this when widths come from a variable or a config value — `entry.someNumberField`
and values read out of JSON often arrive as strings. Cast them:

```twig
{% set imgs = craft.imagerx.transformImage(image, [minWidth|round, maxWidth|round]) %}
```

### Parsing rules

Slots are `[width1, width2, defaults, format]`:

| Slot | Type | Becomes |
|------|------|---------|
| 0, 1 | int | `min()` is the first transform's width, `max()` the second — order does not matter |
| 2 | numeric | `{ ratio: <value> }` |
| 2 | string | `{ format: <value> }` |
| 2 | object/array | used verbatim as the transform defaults |
| 3 | string | sets/overwrites `format` in the defaults |

Both output transforms get the same defaults; only `width` differs. So `[400, 1200, 16/9]`
expands to:

```php
[
    ['width' => 400,  'ratio' => 1.7777777777778],
    ['width' => 1200, 'ratio' => 1.7777777777778],
]
```

Because slot 2 is tested with `is_numeric()` before `is_string()`, a *numeric string* like
`'2'` is read as a ratio, not a format. Pass real numbers for ratios and non-numeric strings
for formats and this never bites.

### Quick syntax fills the range for you

When quick syntax is detected, Imager merges these config overrides in — only if you have not
set them yourself:

```php
['fillTransforms' => 'auto', 'fillAttribute' => 'width']
```

So `[400, 1200]` does not produce two transforms; it produces two *anchors*, and the sizes in
between are filled in automatically:

```twig
{% set imgs = craft.imagerx.transformImage(image, [400, 1200]) %}
{# 400, 600, 800, 1000, 1200 #}
```

**You normally do not need to configure this at all.** The default inserts three transforms
between the anchors, giving five sizes, which is a sensible srcset for most ranges.

**`fillInterval` has no effect here.** Filling in `'auto'` mode derives its own interval from
`autoFillCount`, overwriting whatever `fillInterval` says. Setting it looks like it should work
and silently does nothing:

```twig
{# All three produce exactly 400, 600, 800, 1000, 1200 #}
craft.imagerx.transformImage(image, [400, 1200])
craft.imagerx.transformImage(image, [400, 1200], null, { fillInterval: 50 })
craft.imagerx.transformImage(image, [400, 1200], null, { fillInterval: 800 })
```

The lever is `autoFillCount` — how many transforms to insert between the anchors:

| Call | Result |
|------|--------|
| `[400, 1200]` | 400, 600, 800, 1000, 1200 |
| `[400, 1200]` + `autoFillCount: 1` | 400, 800, 1200 |
| `[400, 1200]` + `autoFillCount: 6` | 400, 515, 630, 745, 860, 975, 1090, 1200 |
| `[400, 2400]` | 400, 900, 1400, 1900, 2400 |
| `[400, 2400]` + `autoFillCount: 'auto'` | 400, 686, 972, 1258, 1544, 1830, 2116, 2400 |

Because the default is a fixed *count*, the step grows with the range — a `[400, 2400]` ladder
steps 500px at a time. Reach for `autoFillCount` only when that gets too coarse, either by
raising it or by setting it to `'auto'`, which targets a roughly fixed step instead and lets
the count grow with the range (capped at six insertions).

To get exactly the two sizes you wrote, turn filling off:

```twig
{% set imgs = craft.imagerx.transformImage(image, [400, 1200], null, { fillTransforms: false }) %}
```

## Full syntax

Use it whenever you need more than width/ratio/format — different heights per size, per-size
modes, effects, watermarks, or art-directed crops.

```twig
{% set imgs = craft.imagerx.transformImage(
    image,
    [
        { width: 400 },
        { width: 800 },
        { width: 1200 },
    ],
    { ratio: 16/9, format: 'jpg', jpegQuality: 70 },
    { fillTransforms: true, fillInterval: 200 }
) %}
```

- **2nd argument** — the transforms. Each entry overrides the defaults.
- **3rd argument, `transformDefaults`** — merged into *every* transform.
- **4th argument, `configOverrides`** — Imager X config settings for this call only.

Anything valid in `transformDefaults` is valid inside an individual transform, and vice
versa. Put what varies per size in the transforms, what is shared in the defaults.

### Closures for dynamic values

Any transform value may be a closure. It receives the image and is resolved before use.
Closures are resolved twice — once on the base transforms and once after defaults are merged
— so they work in either position. Most useful in named transforms; see
`named-transforms.md`.

## fillTransforms — generating the in-between sizes

Rather than writing eight widths, give the endpoints and let Imager fill the gaps.

| Setting | Default | Meaning |
|---------|---------|---------|
| `fillTransforms` | `false` | `true` fills using `fillInterval`; `'auto'` derives the interval from `autoFillCount` |
| `fillAttribute` | `'width'` | Which attribute to step along — `'width'` or `'height'` |
| `fillInterval` | `200` | Step size. **Only used when `fillTransforms` is `true`** — ignored in `'auto'` mode |
| `autoFillCount` | `3` | Transforms to insert between each pair in `'auto'` mode. `'auto'` derives it from the range |

The two modes answer different questions, which is why `fillInterval` and `autoFillCount` are
not interchangeable:

- **`fillTransforms: true`** — "step every N units." You control the step with `fillInterval`;
  the number of transforms follows from the range.
- **`fillTransforms: 'auto'`** — "insert N transforms." You control the count with
  `autoFillCount`; the step follows from the range. `fillInterval` is overwritten and ignored.
  This is the mode quick syntax uses.

With `autoFillCount: 'auto'` the count is derived too, targeting a roughly fixed step:

```
targetInterval = lastSize > 1000 ? 200 : 100
autoFillCount  = min(6, max(diff / targetInterval - 1, 0))
interval       = ceil(diff / (autoFillCount + 1))
```

For `[400, 1200]` that lands on the same ladder as the default: `diff` is 800, `lastSize` is
1200 so `targetInterval` is 200, giving `autoFillCount = min(6, 3) = 3` and an interval of 200
— widths 400, 600, 800, 1000, 1200. It only diverges from the default on wider ranges, where
the six-insertion cap starts to bite.

Two constraints worth knowing:

- **Filling needs at least two transforms.** The code checks `count($transforms) > 1`, so
  `fillTransforms` on a single transform does nothing.
- **Filling happens before `transformDefaults` are merged.** The fill attribute must be
  present in the transforms themselves.

❌ `width` lives only in the defaults, so there is nothing to step along:
```twig
{% set imgs = craft.imagerx.transformImage(image, [{ height: 300 }, { height: 900 }],
    { width: 1200 }, { fillTransforms: true, fillAttribute: 'width' }) %}
```

✅ Step along an attribute that is in the transforms:
```twig
{% set imgs = craft.imagerx.transformImage(image, [{ height: 300 }, { height: 900 }],
    { ratio: 16/9 }, { fillTransforms: true, fillAttribute: 'height', fillInterval: 200 }) %}
```

Order of operations inside `transformImage()`, which explains the above:

1. Resolve named transforms (string → definition, following nesting)
2. Expand quick syntax, adding the implicit `fillTransforms`/`fillAttribute` overrides
3. Decide array-vs-object return
4. Build the config model from `configOverrides`
5. Resolve closures in the base transforms
6. **Fill transforms**
7. **Merge `transformDefaults`**
8. Resolve closures again
9. Normalize (see `transform-parameters.md`)

## |srcset

```php
srcset(?array $images, string $descriptor = 'w'): string
```

Available as a filter and as a method:

```twig
{{ imgs|srcset }}
{{ imgs|srcset('h') }}
{{ craft.imagerx.srcset(imgs, 'w+h') }}
```

| Descriptor | Emits | Use for |
|------------|-------|---------|
| `'w'` | `url 400w, url 800w` | Normal responsive images. This is what `sizes` pairs with |
| `'h'` | `url 400h` | Rare; height-based candidate selection |
| `'w+h'` | `url 400x300` | Not a valid HTML srcset — for passing dimensions to JS libraries |

**It de-duplicates by descriptor value.** Two transforms that resolve to the same width
collapse into a single candidate silently. If a srcset has fewer entries than you expect,
check whether `allowUpscale: false` clamped several sizes to the source width.

Imager X does not emit `x` (pixel-density) descriptors. Use `w` plus a correct `sizes`
attribute and let the browser account for DPR — that is what it does with `w` candidates.

## Chaining — transform a transform

`transformImage()` accepts an already-transformed image, so expensive work can be done once
and reused:

```twig
{% set base = craft.imagerx.transformImage(image, {
    width: 1600,
    effects: { modulate: [110, 100, 100], gamma: 1.2 },
    jpegQuality: 95
}) %}

{% set imgs = craft.imagerx.transformImage(base, [400, 1200, 1]) %}
```

The effects run once on the 1600px base instead of once per output size. Worth it for
Imagick-heavy effect chains; unnecessary for plain resizes.

## External and local images

```twig
{# Remote URL #}
{% set imgs = craft.imagerx.transformImage('https://example.com/photo.jpg', [400, 1200]) %}

{# Path relative to the web root #}
{% set imgs = craft.imagerx.transformImage('/uploads/site/logo.png', { width: 200 }) %}
```

Remote files are downloaded into the runtime folder and cached for
`cacheDurationRemoteFiles` (default 1209600, two weeks). Set `cacheRemoteFiles: false` to
delete them at the end of the request. Related settings: `hashRemoteUrl`,
`useRemoteUrlQueryString`, `useRawExternalUrl`, `skipExternalUrlValidation`. See
`configuration.md`.

Remote transforms are a synchronous HTTP fetch on first request. Never do them in a loop on a
page that users wait for — pre-generate, or cache the markup.

## Missing images and nulls

`transformImage()` returns `null` when `$image` is null. With `suppressExceptions: true` it
also returns `null` instead of throwing on a bad named transform or a failed transform, which
makes templates quieter and failures harder to spot.

```twig
{% set imgs = craft.imagerx.transformImage(image, 'heroImage') %}
{% if imgs %}
    <img srcset="{{ imgs|srcset }}" sizes="100vw" alt="{{ image.alt }}">
{% endif %}
```

`fallbackImage` (used when an Asset's file is missing) and `mockImage` (replaces every image,
useful in local development) are config settings — see `configuration.md`.
