# Configuration

`config/imager-x.php` is a normal Craft config file, so it supports multi-environment arrays,
`App::env()`, and anything else PHP allows. Defaults below are taken from the plugin's
`Settings` model, which is authoritative — a few published defaults have drifted.

Related files, each covered in its own reference: `imager-x-transforms.php`
(`named-transforms.md`), `imager-x-generate.php` (`auto-generate.md`),
`imager-x-power-pack.php` (`responsive-images.md`), and per-transformer configs
(`transformers.md`).

## A starting point

```php
<?php
// config/imager-x.php

return [
    '*' => [
        'transformer' => 'craft',

        'imagerSystemPath' => '@webroot/imager/',
        'imagerUrl' => '/imager/',

        'jpegQuality' => 78,
        'webpQuality' => 78,
        'avifQuality' => 65,

        'interlace' => 'line',
        'allowUpscale' => false,
        'removeMetadata' => true,
    ],

    'dev' => [
        // Uncomment to work without the real assets
        // 'mockImage' => '/uploads/site/placeholder.jpg',
    ],
];
```

Format and quality are what actually move page weight. Serving AVIF or WebP at a sensible
quality does far more than any amount of post-processing, so get `modern-formats.md` right
before reaching for anything else.

## Paths and URLs

| Setting | Default | Notes |
|---------|---------|-------|
| `imagerSystemPath` | `'@webroot/imager/'` | Where transforms are written. Aliases and env vars are parsed |
| `imagerUrl` | `'/imager/'` | Public URL for that path. Can be an array keyed by site handle |

`imagerUrl` is localizable, so a multi-site install with per-site domains can give each site
its own transform URL. Both settings run through `App::parseEnv()`.

On an ephemeral filesystem — Craft Cloud, Servd, containers without a persistent volume —
`@webroot/imager/` does not survive a deploy. Either use a transformer that does the work
remotely, or an external storage, or accept regenerating after each release.

## Transformer

| Setting | Default | Notes |
|---------|---------|-------|
| `transformer` | `'craft'` | `craft` is the only one available on Lite |
| `transformerConfig` | `null` | Transformer-specific config, 6.x |

See `transformers.md` for the handles and their feature differences. Set this per environment
rather than per transform — overriding `transformer` in `configOverrides` does not change the
cache filename, so transforms from different transformers can collide.

## Format and quality

| Setting | Default | Notes |
|---------|---------|-------|
| `jpegQuality` | `80` | |
| `webpQuality` | `80` | |
| `avifQuality` | `80` | AVIF holds up at lower values — 60–70 is usually enough |
| `jxlQuality` | `80` | |
| `pngCompressionLevel` | `2` | |
| `webpImagickOptions` | `[]` | Passed to Imagick for WebP |
| `interlace` | `false` | `'line'`, `'plane'`, `'partition'`, or `true`. `plane`/`partition` need Imagick |
| `safeFileFormats` | `['jpg', 'jpeg', 'gif', 'png', 'webp']` | See below |
| `convertToRGB` | `false` | Force RGB output |
| `preserveColorProfiles` | `false` | Keep ICC profiles. Costs bytes |
| `removeMetadata` | `false` | Strip EXIF. Imagick only |
| `customEncoders` | `[]` | External encoders, e.g. for JPEG XL |

**`safeFileFormats` includes `webp` as of 6.0.0** — the published default is out of date. It
gates automatic generation and CP thumbnails only; you can still pass any format to
`transformImage()` directly. Add `avif` if AVIF sources need auto-generating.

See `modern-formats.md` for format strategy.

## Resizing

| Setting | Default | Notes |
|---------|---------|-------|
| `allowUpscale` | `true` | `false` clamps transforms to the source size — which silently shortens srcsets |
| `resizeFilter` | `'lanczos'` | Imagick only. Quality/speed trade-off |
| `smartResizeEnabled` | `false` | Imagick only |
| `position` | `'50% 50%'` | Default crop position when there is no focal point |
| `letterbox` | `['color' => '#000', 'opacity' => 0]` | Defaults for `mode: 'letterbox'` |
| `bgColor` | `''` | Fill colour for padding and transparency flattening |
| `instanceReuseEnabled` | `false` | Reuse the Imagine instance across transforms in one call |

`allowUpscale: false` is good practice — it stops a 600px source being blown up to 2400 — but
it means a `[400, 2400]` srcset against a small source may collapse to one or two candidates,
since `|srcset` de-duplicates by width. That is correct behaviour, not a bug.

## Filenames and paths

| Setting | Default | Notes |
|---------|---------|-------|
| `useFilenamePattern` | `true` | Use `filenamePattern` to build the name |
| `filenamePattern` | `'{basename}_{transformString|hash}.{extension}'` | See tokens below |
| `shortHashLength` | `10` | Length of truncated hashes |
| `hashPath` | `false` | Hash the directory path |
| `addVolumeToPath` | `true` | Include the volume handle in the path |
| `hashFilename` | `'postfix'` | **Deprecated** — use `filenamePattern` |
| `hashRemoteUrl` | `false` | `true` hashes the whole remote URL, `'host'` only the hostname |
| `useRemoteUrlQueryString` | `false` | Include the query string when identifying a remote file |
| `useRawExternalUrl` | `true` | Source value; the published default of `false` is stale |
| `skipExternalUrlValidation` | `false` | |

`filenamePattern` tokens: `{basename}`, `{extension}`, `{fullname}`, `{transformString}`,
`{transformName}`, `{timestamp}`. `{basename}`, `{fullname}` and `{transformString}` accept a
`|hash` or `|shorthash` filter.

Keep `addVolumeToPath` on. With it off, two volumes containing `photo.jpg` transformed the
same way write to the same file.

`filenamePattern` is excluded from the config-override filename hash, so overriding it per
transform can cause collisions — see `named-transforms.md`.

## Caching and cache clearing

| Setting | Default | Notes |
|---------|---------|-------|
| `cacheEnabled` | `true` | Off means every request re-transforms. Development only |
| `cacheDuration` | `false` | `false` means never expire |
| `cacheRemoteFiles` | `true` | Cache downloaded remote files |
| `cacheDurationRemoteFiles` | `1209600` | Two weeks |
| `cacheDurationExternalStorage` | `1209600` | Cache header on uploads to external storage |
| `cacheDurationNonOptimized` | `300` | Short TTL while an optimization job is pending |
| `clearKey` | `''` | Adds a controller action for clearing caches by key |
| `hideClearCachesForUserGroups` | `[]` | Hide the clear-cache paths from these groups |
| `removeTransformsOnAssetFileops` | `false` | Delete transforms when an asset file is moved or renamed |

**Imager's transform cache is files on disk, not a Craft cache component.** `php craft
cache/flush` does not touch it.

```bash
php craft imager-x/clear-caches/all
php craft imager-x/clear-caches/transforms-cache
php craft imager-x/clear-caches/runtime-cache
```

Utilities → Imager X does the same from the CP, and transforms are also removed automatically
when an asset is replaced.

If transforms appear to regenerate on every request, check in this order: `cacheEnabled` is
`true`; `cacheDuration` is not set to something short; nothing is passing `force`; the
`imagerSystemPath` is actually writable and persistent; and no per-call `configOverrides`
varies between requests, changing the filename each time.

## Optimizers

Off by default (`optimizers` is `[]`), and usually fine left that way. Optimizers were a much
bigger deal when JPEG and PNG were the only options — a lossless pass was the only lever left.
Now, choosing AVIF or WebP at the right quality saves multiples of what squeezing a JPEG does,
so treat these as a marginal gain on top of a good format strategy rather than a default part
of setup.

They still earn their place in two cases: you have to serve JPEG or PNG for reasons outside
your control, or you want lossy PNG quantization (`pngquant`) that the image driver won't do.

| Setting | Default | Notes |
|---------|---------|-------|
| `optimizers` | `[]` | Handles of enabled optimizers |
| `optimizeType` | `'job'` | `'job'` optimizes in a queue job after the response; `'runtime'` inline |
| `optimizerConfig` | per-optimizer | Paths, option strings and API keys |

Handles: `jpegoptim`, `jpegtran`, `mozjpeg`, `optipng`, `pngquant`, `gifsicle` (local
binaries, defaulting to `/usr/bin/<name>`), plus `tinify`, `kraken` and `imageoptim`
(services needing credentials — Kraken and Tinify are separate plugins).

```php
'optimizers' => ['jpegoptim', 'pngquant'],
'optimizerConfig' => [
    'jpegoptim' => ['extensions' => ['jpg'], 'path' => '/usr/local/bin/jpegoptim'],
    'tinify' => ['extensions' => ['png', 'jpg'], 'apiKey' => App::env('TINIFY_API_KEY')],
],
```

Three things to know before enabling them:

- **A missing binary is silent.** If the path is wrong, optimization simply does not happen —
  no error. This is the most common reason someone believes optimizers are running when they
  are not. `skipExecutableExistCheck` disables the existence check entirely.
- **`optimizeType: 'job'` means a queue job per transform**, and a window where unoptimized
  files are served. `cacheDurationNonOptimized` (300s) keeps those from being cached for long.
  Automatic generation forces `'runtime'` regardless of this setting.
- **API keys go in `.env`**, via `App::env()` or `getenv()` — never in the config file.

Remote transformers do their own optimization, so `optimizers` only applies to `craft` and
`imgixdownload`. See `transformers.md`.

## External storages

**Pro only.** Upload transforms to S3, Google Cloud Storage or DigitalOcean Spaces and serve
them from there.

```php
'storages' => ['aws'],
'storageConfig' => [
    'aws' => [
        'accessKey' => App::env('AWS_ACCESS_KEY'),
        'secretAccessKey' => App::env('AWS_SECRET_ACCESS_KEY'),
        // bucket, region, folder, cacheDuration, …
    ],
],
```

Each storage is a separate plugin. Storages are orthogonal to transformers: you can transform
locally with `craft` and store remotely.

## Fallback and mock images

| Setting | Default | Notes |
|---------|---------|-------|
| `fallbackImage` | `null` | Used when a transform fails. Asset ID, Asset, URL, or web-root-relative path |
| `mockImage` | `null` | Replaces **every** image passed to `transformImage()` |
| `suppressExceptions` | `false` | Return `null` instead of throwing |
| `noop` | `false` | Skip transforming; return the original |

`mockImage` is for working without the real assets. Scope both to your dev environment — a
`fallbackImage` in production can be cached in place long after the underlying problem is
fixed, hiding it. Defensive templates beat `fallbackImage`.

`suppressExceptions: true` makes templates quieter and problems much harder to find. Prefer it
in production only, with logs monitored.

## Craft integration

| Setting | Default | Notes |
|---------|---------|-------|
| `useForNativeTransforms` | `false` | `asset.getUrl({ width: 400 })` becomes an Imager transform |
| `useForCpThumbs` | `false` | CP thumbnails go through Imager |
| `runJobsImmediatelyOnAjaxRequests` | `true` | Run queue jobs inline on CP Ajax requests |
| `curlOptions` | `[]` | Options for remote fetches |

`useForNativeTransforms` is the pragmatic way to bring plugins that call Craft's native
transform API — and existing templates — onto Imager without rewriting them. `useForCpThumbs`
is mainly worth it on imgix; with the `craft` transformer it just adds local work.

## The image driver

Imager reads Craft's own `imageDriver` general config setting — it has no setting of its own.

```php
// config/general.php
'imageDriver' => 'imagick',
```

Imagick unlocks most effects, animated GIFs, `interlace` beyond `line`, `resizeFilter`,
`smartResizeEnabled`, `removeMetadata`, watermark opacity and blend modes, and `trim`. GD
supports a small subset silently. Check it before promising a feature:

```twig
{{ craft.app.config.general.imageDriver }}
```

## Multi-environment

```php
return [
    '*' => [
        'transformer' => 'craft',
        'jpegQuality' => 78,
    ],
    'dev' => [
        'suppressExceptions' => false,
    ],
    'staging' => [
        'transformer' => 'imgix',
    ],
    'production' => [
        'transformer' => 'imgix',
        'suppressExceptions' => true,
    ],
];
```

Environment keys match `CRAFT_ENVIRONMENT`. `'*'` applies everywhere and named keys are merged
over it.

Two things not to do: putting credentials in the config file rather than `.env`, and changing
`transformer` between environments while sharing a transform cache — the transformer is not
part of the filename hash, so a cache warmed on one transformer will be served on the other.
Use distinct `imagerSystemPath` values per environment, or clear the cache on switch.
