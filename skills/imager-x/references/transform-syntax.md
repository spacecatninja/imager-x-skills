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
and values read out of JSON often arrive as strings. Cast them with Craft's `|integer` filter,
which is `intval()` and therefore produces a real int:

```twig
{% set imgs = craft.imagerx.transformImage(image, [minWidth|integer, maxWidth|integer]) %}
```

**`|round` is not a cast.** Twig's `round` filter returns a float — `is_int(400.0)` is false —
so `[minWidth|round, maxWidth|round]` still misses quick syntax. Chain them when the value may
have decimals: `minWidth|round|integer`.

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

It does work with `fillTransforms: true` next to it, though. The implicit overrides are merged
*under* yours — `array_merge(['fillTransforms' => 'auto'], $configOverrides)` — so anything set
explicitly wins, and quick syntax covers the fixed-step case too:

```twig
{# 400, 800, 1200 — a 400px step, however wide the range gets #}
{% set imgs = craft.imagerx.transformImage(image, [400, 1200], null,
    { fillTransforms: true, fillInterval: 400 }) %}
```

The lever in `'auto'` mode is `autoFillCount` — how many transforms to insert between the
anchors:

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

### Prefer quick syntax, and rewrite to it where it fits

Quick syntax is the default form for a width ladder, in templates, in named transforms, in
Power Pack transform arguments and in the generate config. **A transform list collapses when
its entries differ only in `width`.** Everything the entries share moves into slot 2.

| Full syntax | Quick syntax |
|-------------|--------------|
| `[{ width: 400 }, { width: 1200 }]` | `[400, 1200]` |
| `[{ width: 400 }, { width: 800 }, { width: 1200 }]` | `[400, 1200]` |
| `[{ width: 400, ratio: 16/9 }, { width: 1200, ratio: 16/9 }]` | `[400, 1200, 16/9]` |
| `[{ width: 400 }, { width: 1200 }]` + `{ ratio: 16/9 }` defaults | `[400, 1200, 16/9]` |
| `[{ width: 400, format: 'webp' }, { width: 1200, format: 'webp' }]` | `[400, 1200, 'webp']` |
| `[{ width: 400 }, { width: 1200 }]` + `{ ratio: 4/3, mode: 'crop', position: 'top-center', jpegQuality: 72 }` defaults | `[400, 1200, { ratio: 4/3, mode: 'crop', position: 'top-center', jpegQuality: 72 }]` |

The slot-2 object is the whole transform-defaults object, so `mode`, `position`, `effects`,
`watermark`, per-format quality and anything else in `transform-parameters.md` belongs there.

Only the two anchors carry over. Row two keeps 400 and 1200 and lets the auto ladder decide the
rest — 400, 600, 800, 1000, 1200, where the hand-written 800 happens to survive and a
hand-written 900 would not. That is the point of the collapse, but the resulting srcset is not
the one that was there before.

❌ Verbose, and the ladder is fixed at three candidates:
```twig
{% set imgs = craft.imagerx.transformImage(
    image,
    [{ width: 600 }, { width: 1200 }, { width: 1800 }],
    { ratio: 3/2, mode: 'crop', jpegQuality: 74 }
) %}
```

✅ Same intent, five candidates, one line:
```twig
{% set imgs = craft.imagerx.transformImage(image, [600, 1800, { ratio: 3/2, mode: 'crop', jpegQuality: 74 }]) %}
```

### What does not collapse

Leave these in full syntax rather than forcing them:

- **One fixed size.** Quick syntax needs two integers and always returns an array, so
  `{ width: 400 }` stays a transform object. `[400, 400]` is not the same thing — it is two
  identical transforms that `|srcset` collapses back into one candidate, wrapped in an array the
  template then has to index into.
- **Per-size differences** — its own `height` per width, a different `mode` or crop `position`
  per size, an effect on one size only, art-directed crops. That is exactly what full syntax is
  for.
- **`height`-driven ladders.** Quick syntax always steps `width`; a height ladder needs full
  syntax with `fillAttribute: 'height'`.
- **Widths that are not real integers.** `['400', '1200']`, or widths read from a field or JSON,
  fail `is_int()` and fall through to full syntax, where they throw or render nothing. Cast with
  `|integer` if you want the collapse (not `|round`, which returns a float), otherwise keep the
  objects.
- **Exact intermediate widths.** `[{width: 400}, {width: 900}, {width: 1200}]` is not
  `[400, 1200]` — the anchors survive, the 900 does not, and the auto ladder replaces it with
  600/800/1000. Collapse it only when the specific widths were arbitrary, which they usually
  were.

One gotcha specific to slot 2: it is merged **over** the anchor width
(`array_merge(['width' => …], $defaults)`), so a `width` key inside the slot-2 object overwrites
both anchors and every candidate comes out the same size.

❌ Both transforms are 800 wide, and `|srcset` de-duplicates them down to one candidate:
```twig
{% set imgs = craft.imagerx.transformImage(image, [400, 1200, { width: 800, ratio: 16/9 }]) %}
```

### What changes when you rewrite

The rewrite is a behaviour change, not a pure reformat. Say so when proposing it:

- **The candidate set grows.** Two widths become five (`autoFillCount` default 3). Usually an
  improvement — a denser srcset lets the browser pick a closer fit — but it is more files on
  disk and more work for the first request or the generate run. `{ fillTransforms: false }` in
  the config overrides keeps exactly the widths written.
- **The widths that survive keep their filenames.** Moving shared params from
  `transformDefaults` into slot 2 changes nothing on disk: transforms are `ksort`ed before the
  filename is built, so the same parameters hash the same however they got there. Only the
  filled-in widths are new files, and any hand-written middle width the ladder no longer
  contains is left behind as an orphan — `imager-x/clean` sweeps those.
- **`config/imager-x-generate.php` has to follow.** A generate entry still describing the old
  ladder keeps generating the old widths while the new ones transform on demand. See
  `auto-generate.md`.
- **GraphQL cannot express quick syntax.** A transform consumed by a headless front end needs a
  named transform; collapsing to an inline ladder in a template does not affect it, but do not
  move a GraphQL-facing definition out of `imager-x-transforms.php`. See `graphql.md`.

Rewrite the transforms you are already editing or reviewing. Sweeping every template in the
project is a separate, larger change — offer it, do not do it unasked.

## Full syntax

Use it whenever you need more than width/ratio/format — different heights per size, per-size
modes, effects, watermarks, or art-directed crops. If the entries differ only in width,
collapse them instead (see above).

```twig
{% set imgs = craft.imagerx.transformImage(
    image,
    [
        { width: 400, height: 400, position: 'top-center' },
        { width: 800, ratio: 4/3 },
        { width: 1600, ratio: 16/9 },
    ],
    { mode: 'crop', format: 'jpg', jpegQuality: 70 },
    { allowUpscale: false }
) %}
```

- **2nd argument** — the transforms. Each entry overrides the defaults.
- **3rd argument, `transformDefaults`** — merged into *every* transform.
- **4th argument, `configOverrides`** — Imager X config settings for this call only.

Every entry above varies its shape as well as its width, which is what keeps this out of quick
syntax. Drop the per-size ratios and it becomes `[400, 1600, { ratio: 16/9, mode: 'crop',
format: 'jpg', jpegQuality: 70 }]`.

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
