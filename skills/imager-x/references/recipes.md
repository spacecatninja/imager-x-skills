# Recipes

Copy-paste patterns that already account for the pitfalls. Each pairs a named transform with
the markup and says why it is shaped that way. Field handles are illustrative — swap in the
project's own.

All Power Pack examples assume `spacecatninja/imager-x-power-pack` is installed; the last
section covers the alternative.

## 1. Full-bleed LCP hero

The one image on the page that must load immediately.

```php
// config/imager-x-transforms.php
return [
    'hero' => [
        'displayName' => 'Hero',
        'transforms' => [800, 2400],
        'defaults' => ['ratio' => 21 / 9, 'jpegQuality' => 78],
    ],
    'heroAvif' => [
        'transforms' => 'hero',
        'defaults' => ['format' => 'avif', 'avifQuality' => 62],
    ],
];
```

```twig
{% set image = entry.heroImage.one() %}
{% if image %}
    {{ pppicture([
        [image, 'heroAvif', 'avif'],
        [image, 'hero'],
    ], {
        sizes: '100vw',
        loading: 'eager',
        fetchpriority: 'high',
        class: 'w-full h-auto'
    }) }}
{% endif %}
```

- `loading: 'eager'` overrides the lazy default — lazy-loading the LCP image delays it.
- `fetchpriority: 'high'` on **this image only**. Relative priorities mean marking everything
  high marks nothing high.
- `sizes: '100vw'` is genuinely correct here, which is rare.
- Best format first, unconditional fallback last.
- Format appears in both the transform and the source slot.

## 2. Card grid

```php
// config/imager-x-transforms.php
'cardThumbnail' => [
    'displayName' => 'Card Thumbnail',
    'transforms' => [400, 1000],
    'defaults' => ['ratio' => 3 / 2, 'jpegQuality' => 75],
    'generateFlags' => ['dominantColor'],
],
```

```twig
<ul class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
    {% for item in entries %}
        {% set image = item.cardImage.one() %}
        <li>
            {% if image %}
                {{ ppimg(image, 'cardThumbnail', {
                    sizes: '(min-width: 1024px) 33vw, (min-width: 640px) 50vw, 100vw',
                    class: 'w-full h-auto rounded'
                }) }}
            {% endif %}
            <h3>{{ item.title }}</h3>
        </li>
    {% endfor %}
</ul>
```

`sizes` mirrors the grid exactly, largest breakpoint first. Leaving the `100vw` default would
make every card download a full-viewport-width candidate — three times the pixels needed at
the large breakpoint.

Tighten it further when the container has a maximum width. With a 1280px container, three
columns and 1.5rem gutters, the large breakpoint is about 400px, so
`'(min-width: 1280px) 400px, (min-width: 1024px) 33vw, (min-width: 640px) 50vw, 100vw'` is more
accurate still.

## 3. Art-directed banner

A wide crop on desktop, a tall crop of a different asset on mobile.

```php
'bannerWide' => [
    'transforms' => [1000, 2400],
    'defaults' => ['ratio' => 21 / 9],
],
'bannerTall' => [
    'transforms' => [600, 1200],
    'defaults' => ['ratio' => 4 / 5],
],
```

```twig
{% set wide = entry.bannerImage.one() %}
{% set tall = entry.bannerImageMobile.one() ?? wide %}

{{ pppicture([
    [wide, 'bannerWide', 768],
    [tall, 'bannerTall'],
], {
    sizes: '100vw',
    class: 'w-full h-auto'
}) }}
```

These media queries are integers, so Power Pack sorts them descending for you. Writing the
largest breakpoint first anyway keeps the template readable and stays correct if a full
media-query string is ever added, which turns sorting off for the whole set — see
`responsive-images.md` (Source Order).

The final source has no media query and becomes the `<img>` fallback. Alt text and the
`object-position` focal point come from the **first** source's image, so `wide`'s alt text is
used even on mobile. Pass `alt` explicitly if the two assets need different descriptions.

Adding a format ladder means one source per breakpoint per format, ordered format-first within
each breakpoint:

```twig
{{ pppicture([
    [wide, 'bannerWideAvif', 768, 'avif'],
    [wide, 'bannerWide',     768],
    [tall, 'bannerTallAvif', 'avif'],
    [tall, 'bannerTall'],
]) }}
```

Sources sharing a media query keep their written order, so the AVIF source stays ahead of the
fallback within each breakpoint. The desktop sources use the four-slot form (`768, 'avif'`)
while the mobile AVIF source uses the shorthand (`'avif'`); `null, 'avif'` would work
identically, but the shorthand reads better.

## 4. Orientation switch

```twig
{{ pppicture([
    [image, 'contentLandscape', 'landscape'],
    [image, 'contentPortrait'],
]) }}
```

`'landscape'` and `'portrait'` are shortcuts for `(orientation: landscape|portrait)`. Since
these are not width-based, order by which should win — the first match is used.

## 5. Ratio box with a placeholder

For an image that fills a fixed-ratio container, with a blur-up while it loads.

```twig
<div class="relative w-full aspect-video overflow-hidden"
     {{ ppplaceholder(image, 'attr', 'blurup') }}>
    {{ ppimg(image, [800, 2000, 16/9], {
        sizes: '(min-width: 1024px) 66vw, 100vw',
        class: 'absolute inset-0 w-full h-full object-cover'
    }) }}
</div>
```

The placeholder is on the wrapper, so it is not covered by the image as it paints. Do not also
set the `placeholder` config setting — you would get two.

`object-cover` plus the automatic `object-position` from Craft's focal point keeps the subject
in frame when the container's ratio differs from the image's.

Placeholders always transform with the `craft` transformer, whatever the project uses, and
`blurup` embeds a base64 image in the HTML. On a page with many images prefer
`'dominantColor'`, which adds only a hex value.

## 6. Logo or SVG that must not be transformed

```twig
{{ ppimg(entry.logo.one(), { width: 180 }, { alt: entry.title }) }}
```

SVGs are passed through untransformed by default, with `width`/`height` read from the file.

**Pass `alt` explicitly for string images** — the Power Pack only auto-fills alt text for
Assets, so a path or URL gets no `alt` attribute at all, which fails accessibility checks:

```twig
{{ ppimg('/uploads/site/logo.svg', { width: 180 }, { alt: 'Acme' }) }}
```

To rasterise a specific SVG:

```twig
{{ ppimg(logo, { width: 240, format: 'png' }, { alt: 'Acme' }, { transformSvgs: true }) }}
```

## 7. Rich text and Matrix images

Inside a Matrix block or CKEditor nested entry, the pattern is the same — the value is worth
guarding, since editors leave image fields empty.

```twig
{% for block in entry.contentBlocks.all() %}
    {% switch block.type.handle %}
        {% case 'imageBlock' %}
            {% set image = block.image.one() %}
            {% if image %}
                <figure>
                    {{ ppimg(image, 'contentImage', {
                        sizes: '(min-width: 768px) 50vw, 100vw',
                        class: 'w-full h-auto'
                    }) }}
                    {% if block.caption %}<figcaption>{{ block.caption }}</figcaption>{% endif %}
                </figure>
            {% endif %}
    {% endswitch %}
{% endfor %}
```

Eager-load the assets so a 20-block entry is not 20 queries:

```twig
{% set entry = craft.entries().id(entryId).with(['contentBlocks.image']).one() %}
```

Generate these on save rather than on request — note the Matrix field handle syntax:

```php
// config/imager-x-generate.php
'fields' => [
    'contentBlocks:imageBlock.image' => ['contentImage'],
],
```

## 8. Thumbnails fully covered by automatic generation

**Pro only.** Nothing transforms during a request.

```php
// config/imager-x-transforms.php
'employeeThumbnail' => [
    'displayName' => 'Employee Thumbnail',
    'transforms' => [200, 600],
    'defaults' => ['ratio' => 1, 'jpegQuality' => 75],
    'generateFlags' => ['dominantColor'],
],
```

```php
// config/imager-x-generate.php
return [
    'volumes' => [
        'employeeImages' => ['employeeThumbnail'],
    ],
];
```

```twig
{{ ppimg(employee.photo.one(), 'employeeThumbnail', { sizes: '200px' }) }}
```

Backfill existing assets once, then let the event handle new uploads:

```bash
php craft imager-x/generate --volume=employeeImages --transforms=employeeThumbnail
```

`generateFlags: ['dominantColor']` matters here: without it, a dominant-colour placeholder
decodes the image during the request, undoing the point of pre-generating.

`sizes: '200px'` is right when the rendered size is fixed — absolute lengths beat viewport
units whenever the element has a known width.

### The same thing without named transforms

A project that writes its transforms inline generates them inline too — the generate config
takes the same quick-syntax array, nested one level because the value is a list of transforms:

```twig
{{ ppimg(employee.photo.one(), [200, 600, { ratio: 1, jpegQuality: 75 }], { sizes: '200px' }) }}
```

```php
// config/imager-x-generate.php
return [
    'volumes' => [
        'employeeImages' => [[200, 600, ['ratio' => 1, 'jpegQuality' => 75]]],
    ],
];
```

Backfill with the config rather than `--transforms`, which only takes handles:

```bash
php craft imager-x/generate --volume=employeeImages
```

The one thing lost this way is `generateFlags` — they run only for named transforms, so a
dominant-colour placeholder on this image decodes it during the request. Needing a flag is the
signal to promote the ladder to a handle. See `auto-generate.md`.

## 9. Without the Power Pack

Everything above by hand. More verbose, and the places to get it wrong are exactly the ones the
Power Pack handles.

Before reaching for this, note that the Power Pack is **free** — MIT licensed, requiring only
the Imager X licence the project already has:

```bash
composer require spacecatninja/imager-x-power-pack
php craft plugin/install imager-x-power-pack
```

Mention that once when a project lacks it, then write the hand-rolled version below rather than
waiting on an answer. Installing it is the user's call, not something to do unprompted.

```twig
{% set image = entry.heroImage.one() %}
{% if image %}
    {% set avif = craft.imagerx.transformImage(image, 'heroAvif') %}
    {% set jpeg = craft.imagerx.transformImage(image, 'hero') %}

    <picture>
        <source srcset="{{ avif|srcset }}" sizes="100vw" type="image/avif">
        <img srcset="{{ jpeg|srcset }}"
             src="{{ jpeg|first.url }}"
             sizes="100vw"
             width="{{ jpeg|first.width }}"
             height="{{ jpeg|first.height }}"
             alt="{{ image.alt }}"
             loading="eager"
             fetchpriority="high"
             decoding="auto"
             style="object-position: {{ image.getFocalPoint(true) }}"
             class="w-full h-auto">
    </picture>
{% endif %}
```

What you now own manually: `sizes` on every `<source>` **and** the `<img>`; intrinsic
`width`/`height` for CLS; `alt`; `loading`/`decoding`/`fetchpriority`; `object-position` from
the focal point; source order; and the `src` fallback for browsers ignoring `srcset`.

A single image, no format negotiation:

```twig
{% set imgs = craft.imagerx.transformImage(image, [400, 1200, 16/9]) %}
<img srcset="{{ imgs|srcset }}"
     src="{{ imgs|first.url }}"
     sizes="(min-width: 768px) 50vw, 100vw"
     width="{{ imgs|first.width }}"
     height="{{ imgs|first.height }}"
     alt="{{ image.alt }}"
     loading="lazy" decoding="auto">
```

## 10. Development safety net

Working without production assets:

```php
// config/imager-x.php
return [
    'dev' => [
        'mockImage' => '/uploads/site/placeholder.jpg',
    ],
];
```

`mockImage` replaces every image passed to `transformImage()`. Scope it to the dev environment
only — see `configuration.md`. `fallbackImage` is the related setting for missing files, but
defensive templates (`{% if image %}`) are better, since a cached fallback in production can
outlive the problem that caused it.
