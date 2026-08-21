# WebP, AVIF and JPEG XL

Imager X can encode WebP, AVIF and JPEG XL through GD/Imagick where the driver supports them,
and through external command-line encoders where it does not.

## Getting a format encoded

```twig
{% set imgs = craft.imagerx.transformImage(image, [600, 1800, 16/9, 'webp']) %}
{% set imgs = craft.imagerx.transformImage(image, [600, 1800], { format: 'avif', avifQuality: 65 }) %}
```

Quality is per format — `jpegQuality`, `webpQuality`, `avifQuality`, `jxlQuality`, all
defaulting to 80. The generic `quality` key maps only to `jpegQuality`; see
`transform-parameters.md`.

AVIF holds up at noticeably lower quality than JPEG. 60–70 is usually indistinguishable and
much smaller. WebP behaves more like JPEG; 75–80 is a reasonable target.

### Checking support

```twig
{{ craft.imagerx.serverSupportsWebp() }}   {# can this server encode it? #}
{{ craft.imagerx.serverSupportsAvif() }}
{{ craft.imagerx.serverSupportsJxl() }}

{{ craft.imagerx.clientSupportsWebp() }}   {# does this request's Accept header say so? #}
{{ craft.imagerx.clientSupports('avif') }} {# 'image/' is prefixed for you #}
```

Server support depends on the image driver's build. It is worth guarding a format behind
`serverSupports*` when the same templates run across environments with different builds — a
production box with a newer Imagick may support AVIF where a local one does not.

### customEncoders

When the driver cannot encode a format, point Imager at a command-line tool. Imager transforms
to a temporary file at maximum quality in the original format, then shells out to convert.

```php
// config/imager-x.php
'customEncoders' => [
    'webp' => [
        'path' => '/usr/local/bin/cwebp',
        'options' => ['quality' => 80, 'effort' => 4],
        'paramsString' => '-q {quality} -m {effort} {src} -o {dest}',
    ],
    'avif' => [
        'path' => '/usr/local/bin/cavif',
        'options' => ['quality' => 65, 'speed' => 7],
        'paramsString' => '--quality {quality} --speed {speed} --overwrite -o {dest} {src}',
    ],
],
```

Trade-offs: the image is processed twice, so it is slower, and compressing an
already-compressed intermediate costs a little quality. Results are still good from a
high-quality source. Override options per transform with `customEncoderOptions`:

```twig
{% set img = craft.imagerx.transformImage(image, { width: 1200, format: 'avif', customEncoderOptions: { quality: 55 } }) %}
```

This mechanism works for any format — anything with a converter binary can be added.

## Delivering them: use `<picture>`

Not every browser supports every format. The standards-compliant answer is one `<source>` per
format, letting the browser pick by `type`.

**Every visitor gets the same markup**, which keeps full-page caching, CDNs and static caching
straightforward.

With the Power Pack:

```twig
{{ pppicture([
    [image, [600, 1800, 16/9, 'avif'], 'avif'],
    [image, [600, 1800, 16/9, 'webp'], 'webp'],
    [image, [600, 1800, 16/9]],
], {
    sizes: '(min-width: 1024px) 66vw, 100vw'
}) }}
```

Order matters: **best format first**, unconditional fallback last. The browser takes the first
`<source>` whose `type` it understands. Note the format appears twice per source — in the
transform (which encodes it) and in the source slot (which sets `type`). See
`responsive-images.md`.

By hand:

```twig
{% set avif = craft.imagerx.transformImage(image, 'heroAvif') %}
{% set webp = craft.imagerx.transformImage(image, 'heroWebp') %}
{% set jpeg = craft.imagerx.transformImage(image, 'hero') %}

<picture>
    <source srcset="{{ avif|srcset }}" sizes="100vw" type="image/avif">
    <source srcset="{{ webp|srcset }}" sizes="100vw" type="image/webp">
    <img srcset="{{ jpeg|srcset }}" src="{{ jpeg[0].url }}" sizes="100vw"
         width="{{ jpeg[0].width }}" height="{{ jpeg[0].height }}"
         alt="{{ image.alt }}" loading="lazy" decoding="auto">
</picture>
```

Nested named transforms keep the three ladders in sync — one definition, three format
variants. See `named-transforms.md`.

### Content negotiation instead

imgix and ImageKit can pick the format from the `Accept` header, so one URL serves AVIF, WebP
or JPEG depending on the browser:

```twig
{% set imgs = craft.imagerx.transformImage(image, [600, 1800, 16/9], {
    transformerParams: { auto: 'format' }
}) %}
```

Simpler markup, fewer transforms. Two constraints: it only works when the service serves the
request, and it makes responses vary by `Accept`, so any cache in front must vary on that
header too.

**This is exactly what `imgixdownload` cannot do** — the file ends up on your server, so imgix
never sees the request. On `imgixdownload`, use `<picture>`.

### Branching in Twig — usually the wrong answer

```twig
{% if craft.imagerx.clientSupports('avif') %}
    {% set imgs = craft.imagerx.transformImage(image, 'heroAvif') %}
{% else %}
    {% set imgs = craft.imagerx.transformImage(image, 'hero') %}
{% endif %}
```

This emits **different markup to different visitors**, which breaks any cache that is not
keyed on the `Accept` header — Blitz, Servd static caching, a CDN, Craft's own template
caching. Reach for it only when you control caching precisely, and prefer `<picture>`.

## safeFileFormats

Default from source: `['jpg', 'jpeg', 'gif', 'png', 'webp']`. `webp` was added in 6.0.0; some
published documentation still omits it.

It gates **automatic generation and CP thumbnails only** — `transformImage()` accepts any
format regardless. So an AVIF *source* asset is skipped by automatic generation unless you add
it:

```php
'safeFileFormats' => ['jpg', 'jpeg', 'gif', 'png', 'webp', 'avif'],
```

Outputting AVIF from a JPEG source needs no change — this is about the source extension.

## Animated GIFs

Animated GIF transforms need Imagick. `frames` extracts a subset; see
`transform-parameters.md`.

```twig
{% if craft.imagerx.isAnimated(asset) %}…{% endif %}
```

The Power Pack skips animated GIFs by default (`transformAnimatedGifs: false`), emitting them
as-is with dimensions read from the file. Converting an animated GIF to a video format is
outside Imager's scope — but doing it is almost always the right call for large GIFs.

## Picking a ladder

- **Two formats, not three.** AVIF plus a JPEG fallback covers essentially all traffic now.
  Adding WebP in the middle triples the transforms for a small slice of browsers that support
  WebP but not AVIF.
- **AVIF encoding is slow.** With `optimizeType: 'job'` this lands in the queue, but a cold
  cache on a large page is still a real cost. Pre-generate with automatic generation — see
  `auto-generate.md`.
- **Do not convert PNGs with transparency to JPEG** by putting `format: 'jpg'` in shared
  defaults. WebP and AVIF both handle alpha; JPEG does not, and `bgColor` will flatten it.
- **Leave the format off entirely** to keep the source format. Often the right choice for
  logos and screenshots.

A reasonable default for a content image:

```php
// config/imager-x-transforms.php
return [
    'contentImage' => [
        'transforms' => [600, 1800],
        'defaults' => ['ratio' => 16 / 9, 'jpegQuality' => 78],
    ],
    'contentImageAvif' => [
        'transforms' => 'contentImage',
        'defaults' => ['format' => 'avif', 'avifQuality' => 62],
    ],
];
```

```twig
{{ pppicture([
    [image, 'contentImageAvif', 'avif'],
    [image, 'contentImage'],
], { sizes: '(min-width: 768px) 50vw, 100vw' }) }}
```
