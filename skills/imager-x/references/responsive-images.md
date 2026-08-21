# Responsive Images with the Power Pack

The Imager X Power Pack (`spacecatninja/imager-x-power-pack`) generates `<picture>` and
`<img>` markup with correct `srcset`, `sizes`, intrinsic dimensions, alt text, loading hints
and placeholders. It is the recommended way to write responsive images with Imager X, and it
works on both Lite and Pro.

It registers four **global Twig functions** — not `craft.*` methods:

```php
pppicture(array $sources, array $params = [], array $config = []): Markup
ppimg(Asset|string|null $image, array|string $transform, array $params = [], array $config = []): Markup
ppplaceholder(Asset|string|null $image, string $output = 'attr', string $type = 'dominantColor', ?array $config = null): string
pptransform(Asset|ImagerAdapterInterface|string|null $image, array|string $transforms, ?array $defaults = null, ?array $config = null): array|TransformedImageInterface|Asset|null
```

`ppimg` is `pppicture` with a single source and no wrapping `<picture>` element — same code
path, same parameters, same behaviour.

## ppimg — one image, one shape

```twig
{{ ppimg(entry.heroImage.one(), [800, 2000, 16/9], {
    sizes: '(min-width: 1024px) 66vw, 100vw',
    class: 'w-full h-auto',
    loading: 'eager',
    fetchpriority: 'high'
}) }}
```

Renders (verified output, srcset values elided):

```html
<img src="…800.jpg" srcset="…800.jpg 800w, …1200.jpg 1200w, …1600.jpg 1600w, …2000.jpg 2000w"
     sizes="(min-width: 1024px) 66vw, 100vw" width="800" height="450"
     alt="Sunrise over the fjord" class="w-full h-auto"
     loading="eager" fetchpriority="high" decoding="auto"
     style="object-position: 50% 50%;">
```

The second argument is anything `transformImage()` accepts — a transform object, an array of
them, quick syntax, or a named transform handle. See `transform-syntax.md`.

## pppicture — art direction and format negotiation

```twig
{{ pppicture([
    [entry.heroImage.one(),   'heroLarge', 768],
    [entry.heroMobile.one(),  'heroSmall'],
], {
    sizes: '(min-width: 768px) 100vw, 100vw'
}) }}
```

Each source is a positional array:

```
[image, transform, mediaQuery, format]
```

- **`image`** — Asset, transformed image, path, or URL.
- **`transform`** — anything `transformImage()` accepts.
- **`mediaQuery`** — becomes the `media` attribute. See the table below.
- **`format`** — sets `type="image/…"` **only**. It does not encode that format.

A single source can be passed unwrapped: `pppicture([image, 'heroLarge', 768])` works, because
the service wraps it when `$sources[0]` is not an array.

### Media query forms

| You write | Renders as |
|-----------|------------|
| `768` (int) | `media="(min-width: 768px)"` |
| `'(max-width: 767px)'` | passed through unchanged |
| `'(min-aspect-ratio: 16/9)'` | passed through unchanged |
| `'landscape'` / `'portrait'` | `media="(orientation: landscape)"` |
| omitted, or an explicit `null` | no `media` attribute — the source applies unconditionally |
| omitted, on the last source | nothing (it becomes the `<img>`) |

`[image, 'heroLarge', null, 'avif']` and `[image, 'heroLarge', 'avif']` are equivalent — slot 2
recognises `jpeg`, `jpg`, `gif`, `webp`, `avif` and `heic` and shifts them into the format slot.
The shorthand reads better; use it.

### Source order

**The last source becomes the `<img>`; every earlier one becomes a `<source>`.** The browser
uses the **first** `<source>` whose `media` and `type` both match — not the most specific one —
so ordering is what makes a `<picture>` correct.

Power Pack sorts for you, but only where it safely can:

| Your sources | Ordering |
|--------------|----------|
| Every media query is an integer | Sorted descending automatically — written order does not matter |
| Any source uses a full media-query string, including `'landscape'`/`'portrait'` | **Not sorted** — written order is used as-is |
| Sources sharing the same media query | Written order kept, so format variants hold their precedence |

Integer media queries are therefore the low-effort path, and the one to prefer.

The catch is the second row: **one raw media-query string turns sorting off for the entire
set**, integers included. That is deliberate — there is no meaningful way to order a
`max-width` or aspect-ratio query against a min-width one — but it means a mixed set silently
becomes your responsibility to order.

❌ Mixed set, ascending. The string disables sorting, so `(min-width: 500px)` stays first and
matches a 1400px viewport, and the 1000px source is unreachable:
```twig
{{ pppicture([
    [image, 'small',  '(min-width: 500px)'],
    [image, 'medium', 1000],
    [image, 'large'],
]) }}
```

✅ Either make them all integers and let it sort, or write largest-first:
```twig
{{ pppicture([
    [image, 'medium', 1000],
    [image, 'small',  500],
    [image, 'large'],
]) }}
```

Writing sources largest-first regardless is a good habit: it is required for mixed sets, and a
no-op for all-integer sets, so it is correct either way.

### Format variants

Sources sharing a media query keep their written order, which is what makes art direction and
format negotiation safe to combine — the AVIF source stays ahead of the fallback inside each
breakpoint:

```twig
{{ pppicture([
    [wide, 'bannerWideAvif', 768, 'avif'],
    [wide, 'bannerWide',     768],
    [tall, 'bannerTallAvif', 'avif'],
    [tall, 'bannerTall'],
]) }}
```

Note the format appears **twice** on purpose: inside the named transform (which actually
encodes AVIF) and in the source slot (which sets `type="image/avif"`). `jpg` is normalised to
`jpeg` for the MIME type.

### media and type are never emitted on the img

The last source renders as `<img>`, which never gets `media` or `type`. A media query or
format on the final source is silently dropped — correct, since the fallback must be
unconditional, but worth knowing when a source seems to be ignored.

## params — the second argument

| Key | Default | Effect |
|-----|---------|--------|
| `sizes` | `'100vw'` | The `sizes` attribute. Emitted only when a srcset exists |
| `defaults` | `[]` | Transform defaults, merged over `defaultTransformParams` |
| `imagerOverrides` | `[]` | Imager X config overrides for these transforms |
| `class` | — | String or array. Arrays may contain falsy entries, which are dropped |
| `style` | — | String or object. Placeholder styles are prepended |
| `alt` | Asset's alt field | Only auto-filled for Assets — see below |
| `loading` | `'lazy'` | `loading` attribute |
| `decoding` | `'auto'` | `decoding` attribute |
| `width` / `height` | derived | Supply **both** to suppress the derived intrinsic dimensions |
| anything else | — | Passed to `Html::modifyTagAttributes()` — full `attr` filter semantics |

Unrecognised keys go straight onto the `<img>` as attributes, so `fetchpriority`, `id`,
`data-*`, `aria-*` and `itemprop` all work:

```twig
{{ ppimg(image, 'heroImage', {
    fetchpriority: 'high',
    'data-flickity-lazyload-srcset': true,
    aria-hidden: 'true'
}) }}
```

`class` and `style` accept the same shapes Craft's `|attr` filter does:

```twig
{{ ppimg(image, 'card', {
    class: ['w-full', 'object-cover', entry.isFeatured ? 'ring-2'],
    style: { 'aspect-ratio': '16 / 9' }
}) }}
```

### Attributes land on the img only

`params` are applied to the `<img>`, never to the `<source>` elements or the `<picture>`. For
attributes on the `<picture>` itself, pipe the output through Craft's `|attr` filter:

```twig
{{ pppicture([...], { class: 'w-full' })|attr({ class: 'block relative' }) }}
```

### alt text

`alt` is read from the Asset's `alt` field (configurable via `altTextHandle`). Two gaps:

- **String images get no `alt` attribute at all** — not even `alt=""`. Verified:
  `ppimg('/uploads/images/logo.svg', { width: 120 })` renders
  `<img src="…" srcset="…" width="491" height="141" sizes="100vw" loading="lazy" decoding="auto">`
  with no `alt` whatsoever, which fails accessibility checks.
- Decorative images need an explicit empty alt.

✅ Always pass `alt` for string images and decorative images:
```twig
{{ ppimg('/uploads/site/logo.svg', { width: 180 }, { alt: 'Acme' }) }}
{{ ppimg(image, 'decorativeBackdrop', { alt: '' }) }}
```

### defaults vs imagerOverrides

`defaults` are transform parameters; `imagerOverrides` are Imager X config settings. They map
onto the 3rd and 4th arguments of `transformImage()`:

```twig
{{ ppimg(image, [600, 1800], {
    defaults: { effects: { sharpen: true }, jpegQuality: 72 },
    imagerOverrides: { transformer: 'craft', allowUpscale: false }
}) }}
```

## config — the third argument

A clone of the Power Pack settings model with your overrides applied, so **any** setting can
be changed per call:

```twig
{{ ppimg(image, 'heroImage', { sizes: '50vw' }, {
    placeholder: 'blurhash',
    lazysizes: true,
    transformSvgs: true
}) }}
```

Cloning means an override never leaks into other calls on the same request.

## sizes — the part that is usually wrong

`sizes` tells the browser how wide the image will *render*, so it can pick a candidate before
CSS is applied. Getting it wrong wastes bandwidth silently — the image still looks right.

The default `100vw` is correct only for full-bleed images.

❌ A three-column grid left on the default downloads roughly three times the pixels needed:
```twig
{{ ppimg(image, [400, 1200]) }}
```

✅ Describe the rendered width at each breakpoint, largest breakpoint first:
```twig
{{ ppimg(image, [400, 1200], {
    sizes: '(min-width: 1024px) 33vw, (min-width: 640px) 50vw, 100vw'
}) }}
```

Rules of thumb:

- Mirror the CSS. A `max-w-7xl` (1280px) container with 3 columns and `p-6` gutters is roughly
  `(min-width: 1280px) 400px, (min-width: 1024px) 33vw, (min-width: 640px) 50vw, 100vw`.
- Use `calc()` for fixed gutters: `calc(100vw - 3rem)`.
- Absolute lengths (`400px`) beat viewport units when the element has a fixed maximum.
- The last entry has no media condition and is the fallback.
- `sizes` is only emitted when there is a srcset — a single-transform image ignores it.

With `lazysizes: true` this all becomes `data-sizes="auto"` and lazySizes measures the element
at runtime. That is the one way to never think about `sizes` again.

## LCP, loading and CLS

**`loading` defaults to `'lazy'`.** Lazy-loading the largest above-the-fold image delays the
Largest Contentful Paint, which is the opposite of the intent.

✅ One eager, high-priority hero per page; everything else lazy:
```twig
{# Hero — above the fold #}
{{ ppimg(hero, 'heroImage', { loading: 'eager', fetchpriority: 'high', sizes: '100vw' }) }}

{# Everything below the fold keeps the lazy default #}
{{ ppimg(card, 'cardThumbnail', { sizes: '(min-width: 768px) 33vw, 100vw' }) }}
```

Never set `fetchpriority: 'high'` on more than one image — priorities are relative, so making
everything high priority makes nothing high priority.

**Intrinsic dimensions are emitted automatically**, from the **first** transform in the set —
usually the smallest. That is fine: the browser only needs the *ratio* to reserve space and
avoid layout shift. Pair them with CSS that lets the image scale:

```css
img { max-width: 100%; height: auto; }
```

Supplying **both** `width` and `height` in `params` suppresses the derived values. Supplying
only one leaves both derived values in place, which is almost never what someone intends.

❌ Half-overridden — `width` is ignored and the derived pair is emitted:
```twig
{{ ppimg(image, 'card', { width: 400 }) }}
```

✅ Override both, or neither:
```twig
{{ ppimg(image, 'card', { width: 400, height: 300 }) }}
```

## object-position and focal points

When `objectPosition` is on (default) and the image is an Asset, Craft's focal point is
written as an inline `object-position` style. Combined with `object-fit: cover` this keeps the
subject visible when the element's ratio differs from the image's:

```twig
<div class="aspect-[21/9] overflow-hidden">
    {{ ppimg(image, [800, 2400], { class: 'w-full h-full object-cover' }) }}
</div>
```

The `object-fit`/`object-cover` CSS is yours to add — the Power Pack only supplies the
position. Note the focal point and the alt text are read from the **first** source's image, so
in an art-directed `<picture>` they come from the desktop image even though the `<img>` is the
mobile one.

## Placeholders

Set `placeholder` to show something while the image loads. All three attach CSS to the `<img>`
via inline styles.

| Type | Produces | Cost |
|------|----------|------|
| `'dominantColor'` | `background-color: #hex` | One extra colour computation; no bytes in the document |
| `'blurup'` | `background: url(data:…) center center / cover` | A base64 image inline — grows the HTML |
| `'blurhash'` | Same, decoded from the stored blurhash | Same, plus a blurhash to compute |
| `''` (default) | Nothing | — |

```twig
{{ ppimg(image, 'heroImage', {}, { placeholder: 'blurup', placeholderSize: 24 }) }}
```

`placeholderSize` (default 16) is the width of the tiny image. Higher means a more detailed
placeholder and a bigger document. `blurupTransformParams` (default
`['effects' => ['blur' => true]]`) is merged into the placeholder transform.

Two constraints that catch people out:

- **Placeholders always use the `craft` transformer**, whatever the project is configured
  with. A project fully on imgix or Cloudflare still needs a writable `imagerSystemPath` and
  still does local image work for placeholders.
- **The placeholder transform divides by the source dimensions.** If the transformer cannot
  report width and height — imgix with `getExternalImageDimensions: false` — this raises a
  division error. See `transformers.md`.

Precompute with `generateFlags` so blurhashes and dominant colours are not calculated during a
page request; see `named-transforms.md`.

### ppplaceholder — placeholder on a wrapper

When the placeholder belongs on a container rather than the image — a ratio box the image is
absolutely positioned inside:

```twig
<div class="relative w-full aspect-video" {{ ppplaceholder(image, 'attr', 'blurup') }}>
    {{ ppimg(image, [1000, 2000, 16/9], { class: 'absolute inset-0 w-full h-full object-cover' }) }}
</div>
```

`output` is `'attr'` for a full `style="…"` attribute or `'style'` for the declarations alone.
Named arguments read better:

```twig
{{ ppplaceholder(image, type='blurhash') }}
```

Do not combine `ppplaceholder` with the `placeholder` config setting — you would get two
placeholders on the same image.

## lazysizes

Setting `lazysizes: true` restructures the markup for the
[lazySizes](https://github.com/aFarkas/lazysizes) library:

- `src` and `srcset` become a generated SVG placeholder at the intrinsic size
- the real srcset moves to `data-srcset`
- `data-sizes="auto"` replaces `sizes` — no more hand-written `sizes`
- `data-aspectratio` is added
- `lazysizesClass` (default `lazyload`) is appended to the classes
- a `<noscript>` fallback `<img>` is generated, with the lazysizes class stripped

| Setting | Default |
|---------|---------|
| `lazysizes` | `false` |
| `lazysizesClass` | `'lazyload'` |
| `autoloadLazysizes` | `false` |
| `lazysizesURL` | `'https://cdnjs.cloudflare.com/ajax/libs/lazysizes/5.3.2/lazysizes.min.js'` |

`autoloadLazysizes` registers the script with `async`. Bundling lazySizes yourself is better —
you control the version and avoid a third-party request.

Native `loading="lazy"` is the default recommendation now; it needs no JavaScript. Reach for
lazySizes when `data-sizes="auto"` is worth it — image widths that are hard to express in
`sizes`, or a layout where they change at runtime.

## SVGs and animated GIFs

By default neither is transformed (`transformSvgs: false`, `transformAnimatedGifs: false`).
They are emitted as-is, with `width`/`height` read from the file — via a real SVG parse for
SVGs, `getimagesize()` otherwise — and `srcset` set to `"$url {$width}w"`. **Placeholders are
skipped** for bypassed images.

Detection is by extension (`svg`; `gif` plus an animation check), for both Assets and strings.
`reduceSources()` collapses redundant sources when they all resolve to the same bypassed file,
so a `<picture>` with AVIF/WebP/fallback sources of one SVG does not emit three identical
sources.

String images resolve against `@webroot`, and `http://`, `https://`, `//` and `data:image/`
prefixes are left alone.

Turn transforming on per call when a specific SVG really should be rasterised:

```twig
{{ ppimg(logoSvg, { width: 240, format: 'png' }, {}, { transformSvgs: true }) }}
```

## pptransform

A thin wrapper around `craft.imagerx.transformImage()` that also honours `transformSvgs` and
`transformAnimatedGifs`:

```twig
{% set transforms = pptransform(image, [1000, 2000]) %}
<img srcset="{{ transforms|srcset }}" sizes="100vw" alt="{{ image.alt }}">
```

When it bypasses an SVG or animated GIF it returns the **Asset** (or `[Asset]` for an array
transform), not a transformed-image model. `|srcset` on that fails, and `.width`/`.url` work
only because Assets happen to have them.

✅ Guard when the source might be an SVG:
```twig
{% set transforms = pptransform(image, [1000, 2000]) %}
{% if transforms|first is instance of('spacecatninja\\imagerx\\models\\TransformedImageInterface') %}
    <img srcset="{{ transforms|srcset }}" sizes="100vw" alt="{{ image.alt }}">
{% else %}
    <img src="{{ image.url }}" width="{{ image.width }}" height="{{ image.height }}" alt="{{ image.alt }}">
{% endif %}
```

Simpler: use `ppimg`, which handles the bypass and the markup for you.

## Full config file

```php
<?php
// config/imager-x-power-pack.php

return [
    // Transform parameters merged into every transform the Power Pack makes.
    // NOT seen by automatic generation — repeat these in named transforms too.
    'defaultTransformParams' => [],

    // Asset field handle to read alt text from
    'altTextHandle' => 'alt',

    // '', 'dominantColor', 'blurup' or 'blurhash'
    'placeholder' => '',
    'placeholderSize' => 16,
    'blurupTransformParams' => ['effects' => ['blur' => true]],

    'loading' => 'lazy',
    'decoding' => 'auto',

    // Write Craft's focal point as an object-position style
    'objectPosition' => true,

    'transformSvgs' => false,
    'transformAnimatedGifs' => false,

    'lazysizes' => false,
    'lazysizesClass' => 'lazyload',
    'autoloadLazysizes' => false,
    'lazysizesURL' => 'https://cdnjs.cloudflare.com/ajax/libs/lazysizes/5.3.2/lazysizes.min.js',
];
```

`defaultTransformParams` is the one to be careful with. It applies only to Power Pack calls,
so automatic generation — which works from named transforms — produces different filenames and
every generated transform misses. If you use both, put the defaults in the named transforms.

## What the Power Pack does not do

- **No `x` / DPR descriptors.** srcset is always `w`-based. Use `w` plus a correct `sizes` and
  let the browser handle pixel density.
- **No attributes on `<picture>` or `<source>`.** Use `|attr()` on the output for `<picture>`.
- **No wrapper element.** Write your own ratio box.
- **No `fetchpriority` default.** Pass it explicitly on the LCP image.
- **No automatic `sizes` calculation** without lazySizes.
