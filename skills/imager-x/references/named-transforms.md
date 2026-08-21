# Named Transforms

Named transforms move transform definitions out of templates into
`config/imager-x-transforms.php`. They are also a hard prerequisite for automatic generation
and for GraphQL, so a project that wants either needs them.

## The config file

```php
<?php
// config/imager-x-transforms.php

return [
    'heroImage' => [
        'displayName' => 'Hero Image',
        'transforms' => [800, 2400, 16 / 9],
        'defaults' => ['jpegQuality' => 78],
    ],

    'cardThumbnail' => [
        'displayName' => 'Card Thumbnail',
        'transforms' => [400, 900, 4 / 3],
        'generateFlags' => ['dominantColor'],
    ],

    // Full syntax with configOverrides, for the rarer case where you want to pin
    // the step size rather than the number of transforms.
    'fixedStepBanner' => [
        'displayName' => 'Fixed Step Banner',
        'transforms' => [['width' => 800], ['width' => 2400]],
        'defaults' => ['ratio' => 21 / 9],
        'configOverrides' => ['fillTransforms' => true, 'fillInterval' => 400],
    ],
];
```

`heroImage` yields 800, 1200, 1600, 2000, 2400 — quick syntax fills the range on its own, so it
needs no `configOverrides` at all. `fixedStepBanner` produces the same widths the long way
round; reach for that form only when the step itself matters. See `transform-syntax.md`.

Use it from a template by passing the handle as a string:

```twig
{% set imgs = craft.imagerx.transformImage(image, 'heroImage') %}
{{ ppimg(image, 'heroImage', { sizes: '100vw' }) }}
```

## Definition keys

| Key | Type | Purpose |
|-----|------|---------|
| `transforms` | array / quick syntax / string / single object | The transforms. A string is a nested named transform handle |
| `defaults` | array | Merged into every transform, same as the 3rd argument of `transformImage()` |
| `configOverrides` | array | Imager X config settings for this transform, same as the 4th argument |
| `generateFlags` | array | `'blurhash'`, `'palette'`, `'dominantColor'` — precomputed during automatic generation only |
| `displayName` | string | Label in the CP utility and GraphQL. Ignored at transform time |

`transforms` accepts all four shapes:

```php
'transforms' => [['width' => 400], ['width' => 1200]],  // full syntax
'transforms' => [400, 1200, 16 / 9],                     // quick syntax
'transforms' => ['width' => 600],                        // one transform object
'transforms' => 'someOtherTransform',                    // nested named transform
```

Quick syntax inside a named transform behaves exactly as in a template, including the implicit
`fillTransforms: 'auto'`. See `transform-syntax.md`.

## Merge precedence — the caller wins

`defaults` and `configOverrides` are merged with `array_merge($namedTransform[...], $caller[...])`,
so template arguments override the config file:

```twig
{# heroImage's own ratio of 16/9 is replaced by 1/1 here #}
{% set imgs = craft.imagerx.transformImage(image, 'heroImage', { ratio: 1 }) %}
```

That makes named transforms a base to specialise from rather than a lock. It also means a
stray third argument at a call site can quietly change a transform everywhere it is reused —
prefer a nested named transform when the variation is a real, reusable case.

## Nesting

`transforms` may name another named transform. Imager follows the chain, merging `defaults`
and `configOverrides` at each hop, with the *outer* definition winning.

```php
<?php
// config/imager-x-transforms.php

return [
    'base' => [
        'transforms' => [['width' => 800], ['width' => 1600]],
        'configOverrides' => ['fillTransforms' => true, 'fillInterval' => 400],
    ],
    'baseLandscape' => [
        'transforms' => 'base',
        'defaults' => ['ratio' => 16 / 9],
    ],
    'baseLandscapeWebp' => [
        'transforms' => 'baseLandscape',
        'defaults' => ['format' => 'webp'],
    ],
];
```

This is the clean way to build a `<picture>` with format variants — one size ladder, three
handles, no duplication:

```twig
{{ pppicture([
    [image, 'baseLandscapeAvif', 'avif'],
    [image, 'baseLandscapeWebp', 'webp'],
    [image, 'baseLandscape'],
]) }}
```

A cyclic reference throws `ImagerException` — or returns `null` when `suppressExceptions` is
on. A handle that does not exist does the same, so a typo in a named transform fails loudly
by default and silently once exceptions are suppressed.

`craft.imagerx.hasNamedTransform(name)` and `craft.imagerx.getNamedTransform(name)` let a
template check first:

```twig
{% set handle = entry.imageTransform ?: 'heroImage' %}
{% if craft.imagerx.hasNamedTransform(handle) %}
    {{ ppimg(image, handle) }}
{% endif %}
```

## Closures for dynamic values

Any value may be a closure receiving the image. Useful for picking a ratio from the source
image's own shape:

```php
<?php
// config/imager-x-transforms.php

return [
    'articleImage' => [
        'transforms' => [600, 1200],
        'defaults' => [
            'ratio' => static function($image) {
                if ($image instanceof \craft\elements\Asset) {
                    $w = $image->getWidth();
                    $h = $image->getHeight();

                    if ($w && $h) {
                        return $w / $h > 1 ? 16 / 9 : 2 / 3;
                    }
                }

                return 16 / 9;
            },
            'jpegQuality' => 72,
        ],
    ],
];
```

Code defensively here. Closures also run inside queue jobs during automatic generation, where
an exception is far from the template that triggered it. A throwing closure is caught, logged,
and its key is dropped from the transform — so the failure shows up as a wrong-looking image,
not an error page. Guard against null dimensions and non-Asset inputs, as above.

## The filename-hash exclusion trap

Seven settings are applied but **not** included in the config-override string that feeds the
transform filename:

```
fillTransforms, fillInterval, fillAttribute, filenamePattern,
transformer, optimizeType, safeFileFormats
```

Two named transforms that differ *only* by one of these produce the same filename for the same
source and dimensions, so whichever ran first wins and the second reads the cached file.

❌ These two collide — same widths, same defaults, filenames identical:
```php
return [
    'thumbLocal'  => ['transforms' => [['width' => 400]], 'configOverrides' => ['transformer' => 'craft']],
    'thumbRemote' => ['transforms' => [['width' => 400]], 'configOverrides' => ['transformer' => 'imgix']],
];
```

✅ Add something that does affect the filename, or set the transformer globally per
environment instead:
```php
return [
    'thumbLocal'  => ['transforms' => [['width' => 400]], 'configOverrides' => ['transformer' => 'craft']],
    'thumbRemote' => ['transforms' => [['width' => 401]], 'configOverrides' => ['transformer' => 'imgix']],
];
```

In practice, mixing transformers per transform is rare — this mostly bites when someone tries
to override `filenamePattern` per transform for tidier filenames and finds transforms
overwriting each other.

## generateFlags

Only read by automatic generation. Each flag forces a computation while the generate job runs,
so the result is cached before a visitor needs it:

| Flag | Precomputes |
|------|-------------|
| `blurhash` | `transformedImage.getBlurhash()` |
| `palette` | The colour palette |
| `dominantColor` | The dominant colour |

Worth setting whenever a template uses a blurhash placeholder or a dominant-colour background,
since computing those at request time means decoding the image. Ignored entirely when the
transform is called from a template.

## Loading and reload

The file is read once at plugin init and registered into `ImagerService::$namedTransforms`.
It is a normal Craft config file, so it supports multi-environment arrays, `App::env()`, and
anything else PHP allows. It is not project config — changes take effect on the next request,
with no `project-config/apply` step.

The CP utility (Utilities → Imager X) lists every registered named transform with its
`displayName`, which is the quickest way to confirm a handle is loaded.
