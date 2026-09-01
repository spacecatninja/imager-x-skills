# Transformers

A transformer decides *where* the transform happens. `craft` does it locally with GD or
Imagick; the others hand a URL to a third-party service.

**`craft` is the only transformer available on Lite.** Every other handle requires Pro and its
own companion plugin; setting one without Pro throws `ImagerException` naming the Pro
requirement.

```php
// config/imager-x.php
'transformer' => 'craft',
```

## Handles

| Handle | Plugin | Does the work |
|--------|--------|---------------|
| `craft` | built in | Locally, GD or Imagick |
| `imgix` | `imager-x-imgix-transformer` | imgix, served from their CDN |
| `imgixdownload` | `imager-x-imgix-download-transformer` | imgix, then downloaded and served locally |
| `gumlet` | `imager-x-gumlet-transformer` | Gumlet |
| `imagekit` | `imager-x-imagekit-transformer` | ImageKit |
| `imageboss` | `imager-x-imageboss-transformer` | ImageBoss |
| `cloudflareimages` | `imager-x-cloudflare-images-transformer` | Cloudflare Images |
| `awsserverless` | `imager-x-aws-serverless-transformer` | AWS Serverless Image Handler |
| `bunny` | `imager-x-bunny-transformer` | Bunny.net |
| `craftcloud` | `imager-x-craft-cloud-transformer` | Craft Cloud's edge transforms |

Each has its own config file — `imager-x-imgix-transformer.php`,
`imager-x-imagekit-transformer.php`, and so on — most with a `profiles` array and a
`defaultProfile`. `cloudflareimages` and `craftcloud` have no profiles: one zone, one set of
defaults.

### Overriding the profile per transform

Which argument the override goes in differs by transformer, and passing it in the wrong one
fails silently — you get the default profile. `transformerConfig` is an Imager **config
setting**, so it belongs in `configOverrides`, the fourth argument; `transformerParams` is a
**transform parameter**, so it belongs in the transform or its defaults.

| Transformer | How to override |
|-------------|-----------------|
| `imgix`, `imgixdownload` | `configOverrides: { transformerConfig: { profile: 'x' } }`, or the transform param `imgixProfile: 'x'` — still honoured as a fallback |
| `gumlet` | Either `configOverrides: { transformerConfig: { profile: 'x' } }` or `transformerParams: { profile: 'x' }` |
| `imagekit` | `configOverrides: { transformerConfig: { profile: 'x' } }` only |
| `bunny`, `imageboss` | `transformerParams: { profile: 'x' }` only |

```twig
{% set imgs = craft.imagerx.transformImage(asset, [400, 1200], {}, {
    transformerConfig: { profile: 'proxy' }
}) %}
```

## Feature support

`craft` is the reference implementation. Everything else supports a subset, and what a
transformer cannot express it drops without complaining.

| Feature | craft | imgix | gumlet | imagekit | imageboss | cloudflare | awsserverless | bunny |
|---------|:-----:|:-----:|:------:|:--------:|:---------:|:----------:|:-------------:|:-----:|
| `crop`, `fit` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `stretch` | ✅ | ✅ | ✅ | ✅ | no resize | → `crop` | ✅ | → `fit` |
| `croponly` | ✅ | → `fit` | → `fit` | ✅ | no resize | → `crop` | → `crop` | → `fit` |
| `letterbox` | ✅ | ✅ | no opacity | ✅ | no opacity | ✅ | ✅ | ✗ |
| `pad` | ✅ | ✗ | ✅ | ✗ | ✗ | ✗ | ✅ | ✗ |
| `cropZoom` | ✅ | ✅ | ✅ | ✗ | ✅ | ✗ | ✗ | ✗ |
| Focal point / `position` | ✅ | ✅ | ✅ | anchors only | ✅ | ✅ | 3×3 grid | ✅ |
| `effects` | all | via params | via params | via params | 4 only | fixed set | 5 + via params | fixed set |
| `preEffects` | ✅ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `watermark` | ✅ | via params | via params | via params | via `options` | ✗ | via params | ✗ |
| `frames` | ✅ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `trim` | ✅ | ✗ | approximated | ✗ | ✗ | ✗ | ✗ | ✗ |
| External URLs | ✅ | via webproxy profile | via webproxy profile | passed through | ✗ | ✅ | ✗ | ✗ |
| Optimizers | ✅ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |

`imgixdownload` takes the `imgix` column, plus optimizers and external storages, since the file
ends up local. `craftcloud` translates modes, dimensions, quality, format and `letterbox` only;
see its section below.

Nothing in this table is a hard limit — anything `craft` can do can be done first and handed to
the service afterwards. See *Combining transformers*.

### transformerParams

Where a cell says "via params", the transformer does not translate Imager's syntax into the
service's. Pass the service's own options through the `transformerParams` transform parameter
instead:

```twig
{% set imgs = craft.imagerx.transformImage(asset, [400, 1200, 2/1], {
    transformerParams: { sharp: 10 }
}) %}
```

`transformerParams` is applied **last**, so it also overrides what Imager worked out — that is
how you reach a service's own resize modes. The exception is `cloudflareimages`, which computes
`fit` from `mode` *after* the merge, so `fit` is the one param you cannot override there.

Two transformers do not pass it through verbatim: **`bunny` and `cloudflareimages` prune the
final parameter list against a whitelist** of the params their transformer knows about. An
option the service supports but the transformer does not list is dropped silently. `imgix`,
`gumlet`, `imagekit` and `awsserverless` forward whatever you give them — and on `imgix` and
`gumlet`, any unrecognised key left in the *transform* object is forwarded as a service param
too.

### Focal points

Normalization resolves the asset's focal point into a `position` string (`"x y"` in percent)
before the transformer sees it, so "supports focal points" means "does something sensible with
`position`". Every transformer does something, but not the same thing:

- **`imgix`, `gumlet`** — `crop=focalpoint` with `fp-x`/`fp-y`, plus `fp-z` for `cropZoom`.
- **`imageboss`** — `fp-x`/`fp-y` options, `fp-z` for `cropZoom`.
- **`cloudflareimages`** — `gravity=<x>x<y>`. With `autoGravityWhenNoFocalPoint: true`, an asset
  without a focal point gets Cloudflare's `gravity=auto` rather than the `position` default.
- **`bunny`** — Bunny's API has no focal point parameter, so the transformer computes the crop
  rectangle itself from the focal point and the target ratio, and sends `crop=w,h,x,y`. The
  result is equivalent to `craft`'s. It needs **both `width` and `height`**, mode `crop`, and
  known source dimensions; with a string source it falls back to the `position` config setting.
- **`imagekit`** — snapped to an anchor keyword at 30/70% thresholds, so 20%/65% becomes `left`.
- **`awsserverless`** — snapped to the nearest of nine sharp.js positions.
- **`craftcloud`** — Imager passes no position at all. Craft Cloud reads the asset's focal point
  itself, so focal points work, but a per-transform `position` is ignored.

## Silent degradation

This is the part that costs debugging time. Third-party transformers return a
`TransformedImage` model whose file-level getters are **empty strings and zeros**, not errors.

On imgix the model is constructed with:

```php
$this->path = '';
$this->extension = '';
$this->mimeType = '';
$this->size = 0;
```

So anything reading those degrades quietly:

❌ Works on `craft`, silently outputs nothing on imgix:
```twig
<img src="{{ img.url }}" data-size="{{ img.getSize('k') }}kB" type="{{ img.mimeType }}">
{% if img.extension == 'webp' %}…{% endif %}
```

✅ Only depend on `url`, `width` and `height` in transformer-agnostic templates:
```twig
<img src="{{ img.url }}" width="{{ img.width }}" height="{{ img.height }}">
```

`getDataUri()` and `getBase64Encoded()` need the file on disk, so blur-up placeholders built
from them do not work on remote transformers either. This is why the Power Pack forces
`transformer: 'craft'` for placeholders — see `responsive-images.md`.

`craft.imagerx.transformer()` returns the active handle if a template genuinely needs to
branch. Note `craft.imagerx.imgixEnabled()` compares against `'imgix'` exactly, so it returns
`false` for `imgixdownload`.

## Per-transformer notes

### imgix

The most complete of the remote transformers. Width, height, ratio, quality, format, focal
points and `letterbox` all translate. Adds `getPalette($format, $numColors, $cssPrefix)`.

- **`imgixParams` is gone in 6.x.** The transformer reads only `transformerParams`, so an old
  `imgixParams` object is silently ignored. Grep for it when upgrading. The old
  `imgixProfile` transform param still works, but the current form is
  `configOverrides: { transformerConfig: { profile: 'x' } }` — see above.
- **`getExternalImageDimensions`** (default `true`) — for **Assets** the dimensions always come
  from Craft, so this setting is irrelevant. For **external URLs and paths** it controls
  whether imgix downloads a local copy to measure the source. With it `false`, dimensions
  report `0 × 0`, and both the transformer's own target-size calculation and any
  width/height-dependent code divide by zero. Keep it `true` if you transform external images;
  turning it off means giving up dimensions for them.
- Set `imgixApiKey` for purging; `imgixEnableAutoPurging` and
  `imgixEnablePurgeElementAction` control when.

### imgixdownload

Transforms via imgix, then stores the result locally and serves it from your own domain. Use
it to get imgix's transform quality without imgix serving the traffic, or to keep images on
your domain.

- **`auto: format` stops working** — imgix's format negotiation depends on imgix serving the
  request and reading the `Accept` header. Serve formats explicitly with `<picture>` and
  `type`; see `modern-formats.md`.
- External storages and optimizers work as they do with `craft`, since the file ends up local.
- Requires the imgix transformer plugin as well.

### gumlet

The newest of the remote transformers, Imager X 6 only, and the most complete after imgix:
width, height, ratio, quality, format, percentage focal points, `cropZoom`, `letterbox`, `pad`
and `trim` all translate. Adds `getPalette($format, $numColors, $cssPrefix)`, cached, the way
imgix does.

Profiles map one-to-one onto Gumlet **sources**. A profile's `domain` is the source's delivery
domain (`mysource.gumlet.io`, or your custom domain) and is required — a profile without one
throws `ImagerException`.

- **`croponly` silently falls back to `fit`.** `preEffects`, `frames`, `resizeFilter` and
  `customEncoderOptions` are dropped.
- **No effects or watermarks are converted.** Gumlet has plenty of both — `blur`, `sharp`,
  `greyscale`, `gamma`, `contrast`, `brightness`, `saturation`, `hue`, `invert`, `tint`, and
  `overlay` for watermarks — you just pass them yourself through `transformerParams`.
- `letterbox` opacity is ignored; Gumlet's `fill-color` has no alpha channel.
- **`trim` is approximated, not translated.** Imager's `trim` is a `0.0`–`1.0` fuzz factor
  applied *before* resizing; Gumlet's is a `1`–`99` percentage similarity to the top left pixel
  applied *after*. The value is converted for you, but the result differs from `craft`. Pass
  `trim-color` through `transformerParams` to trim a specific colour instead.
- **`pad` is compensated for.** Imager counts padding as part of `width`/`height`, Gumlet pads
  after resizing, so the transformer shrinks the resize target. The output is the size you
  asked for.
- **Gumlet's own resize param is also called `mode`**, and `transformerParams` is applied last,
  so `transformerParams: { mode: 'max' }` overrides the mode worked out from Imager's `mode`.
  That is how you reach Gumlet's `min`, `max` and `fillmax`.
- **External URLs need a web proxy profile** — `sourceIsWebProxy: true`, which sends the full
  URL behind a `fetch/` segment. Hand an absolute URL to a normal profile and you get a warning
  in the log and a URL that does not resolve. Web proxy profiles are never purged.
- **`signKey` is required if the source has "Secure URLs" enabled** — Gumlet answers `403` to
  every unsigned URL on such a source. Leave `signedUrlsExpireSeconds` at `0` unless you
  genuinely need expiry: expiring URLs change on every request, so they cache badly.
- `useCloudSourcePath` (default `true`) prepends the filesystem's path to the asset path, so one
  Gumlet source can cover several Craft filesystems in the same bucket. It only does anything on
  filesystems that have a subfolder setting — S3 and GCS do, local ones do not. `addPath` is the
  manual equivalent, and takes a volume-handle-keyed array.
- `getExternalImageDimensions` behaves exactly as it does on imgix (see above).
- Format negotiation works: `transformerParams: { format: 'auto' }` picks AVIF/WebP/JPEG from
  the `Accept` header. See `modern-formats.md`.

**Purging matters more here than elsewhere.** Gumlet caches your *original* images for up to
three months, so replacing a file at the same path keeps serving the old one until it is purged.
Set `apiKey` (top level, or per profile) and `autoPurge: true`; a "Purge from Gumlet" element
action is on by default. Purging is by source path and takes every derivative with it, so
transforms are not purged individually. Purging is **skipped silently** for a profile with no API
key — including when the key points at an environment variable that is not set, which resolves to
an empty string rather than staying literal. The purge endpoint needs the source's 24-character
`sourceId`, which the plugin resolves from `domain` via the sources API and caches for 24 hours;
set it explicitly to skip the lookup, or when a custom domain stops the lookup from matching.

Config: `imager-x-gumlet-transformer.php` — `profiles`, `defaultProfile`, `apiKey`, `autoPurge`,
`purgeElementAction`. Per profile: `domain`, `useHttps`, `signKey`, `signedUrlsExpireSeconds`,
`sourceId`, `apiKey`, `sourceIsWebProxy`, `useCloudSourcePath`, `addPath`,
`getExternalImageDimensions`, `defaultParams`, `excludeFromPurge`.

```php
// config/imager-x-gumlet-transformer.php
return [
    'defaultProfile' => 'default',
    'apiKey' => '$GUMLET_API_KEY',
    'autoPurge' => true,
    'profiles' => [
        'default' => [
            'domain' => 'mysource.gumlet.io',
            'useCloudSourcePath' => true,
        ],
        'proxy' => [
            'domain' => 'myproxysource.gumlet.io',
            'sourceIsWebProxy' => true,
        ],
    ],
];
```

### imagekit

More complete than it looks: every resize mode translates, **`croponly`** included — it maps to
ImageKit's `cropMode: extract` — and `letterbox` keeps its opacity. The gaps:

- Focal points become **anchor keywords** (`top`, `left`, `top_left`, …), not percentages. The
  thresholds are 30% and 70%, so a focal point at 20%/65% lands on `left`.
- **`cropZoom` is not translated.**
- **No effects and no watermarks are converted.** Pass ImageKit's own transformation params
  through `transformerParams` — they are merged in last and win over anything Imager set.
- `useCloudSourcePath` and `addPath` work as they do on imgix. A profile with
  `isWebProxy: true` sends the asset's full URL instead of a path.

Config: `imager-x-imagekit-transformer.php` — `publicKey`, `privateKey`, `signUrls`,
`signedUrlsExpireSeconds`, `stripUrlQueryString`, `defaultParams`, `profiles`,
`defaultProfile`. Per profile: `urlEndpoint`, `isWebProxy`, `useCloudSourcePath`, `addPath`,
`defaultParams`.

### imageboss

- **Assets only.** The transform method is typed to `Asset`, so a URL, a path or an
  already-transformed image raises a `TypeError` that surfaces as an `ImagerException`.
  External images have to be done by `craft` outright — override `transformer` for those
  transforms; they cannot be handed to ImageBoss afterwards either.
- **`stretch` and `croponly` do not fall back, they skip resizing entirely.** Neither mode adds
  a size segment to the URL, so you get the source image at full size with only the option
  string applied. This is the one to watch for: it looks like the transform ran.
- `letterbox` works, opacity is ignored.
- Focal points and `cropZoom` both translate, as `fp-x`/`fp-y`/`fp-z`. `transformerParams`
  accepts `coverMode` to reach ImageBoss's other cover modes; `coverMode: 'face'` plus
  `cropZoom` gives face detection with zoom.
- Only `grayscale`, `sharpen`, `blur` and `gamma` effects are converted. Everything else,
  watermarks included, goes through `transformerParams: { options: '…' }`, appended to the
  option string raw.
- The profile is overridden with `transformerParams: { profile: 'other' }` here, **not**
  `transformerConfig` — this transformer predates that convention.

### cloudflareimages

Optimizes any image the zone can reach, through `/cdn-cgi/image/`. **It does not store images**
— the source must stay publicly available, and the zone needs image transformations enabled.

- Modes, dimensions, quality, format, **`letterbox`** (as `fit: pad` plus a `background`, with
  opacity) and **focal points** (as `gravity=<x>x<y>`) all translate. `stretch` silently becomes
  `crop`; `croponly` logs an error and reverts to `crop`.
- `autoGravityWhenNoFocalPoint: true` hands assets without a focal point to Cloudflare's own
  `gravity=auto` instead of using the `position` default.
- **No `cropZoom`** — Cloudflare's own `zoom` is available through `transformerParams`.
- **No watermark.** Cloudflare's `draw` overlays are not in the transformer's whitelist, so
  they cannot even be passed manually.
- Effects only via `transformerParams`, and only from the whitelist: `anim`, `background`,
  `blur`, `border`, `brightness`, `compression`, `contrast`, `dpr`, `fit`, `flip`, `gamma`,
  `gravity`, `metadata`, `onerror`, `rotate`, `saturation`, `sharpen`,
  `slow-connection-quality`, `zoom`.
- **No profiles.** A single `zoneDomain`, plus `defaultParams` and
  `autoGravityWhenNoFocalPoint`.
- **`fit` cannot be overridden through `transformerParams`** — it is computed from `mode` after
  the params are merged. `gravity` and `background` can be, since those are only filled in when
  absent.
- An absolute URL on the zone's own domain is rewritten to a path; anything else is passed
  through whole for Cloudflare to fetch.
- Composes nicely with `craft`: do an unsupported transform locally, then let Cloudflare resize
  the result, since Cloudflare only cares that the URL is one the zone can reach.

### awsserverless

Fronts the AWS Serverless Image Handler.

- **AWS-bucket assets only.** The bucket is read from the asset's S3 filesystem, falling back
  to `defaultBucket`; a string source raises a `TypeError`.
- **Percentage focal points unsupported** — snapped to a 3×3 grid of sharp.js positions.
- `croponly` falls back to `crop`; `cropZoom` is unsupported.
- **`pad` works**, as sharp's `extend`, and is compensated for: the padding is subtracted from
  the resize target so the output is the size you asked for. `bgColor` fills it.
- `letterbox` works, opacity included.
- `frames` and `preEffects` not applicable.
- Effects converted: `grayscale`, `negative`, `normalize`, `sharpen`, `blur`.
- `transformerParams` is merged into the sharp.js `edits` object last, so anything the Image
  Handler supports is reachable — `overlayWith` for watermarks included.
- **GIF output throws** unless `autoConvertGif` is set; the Image Handler cannot encode GIF.
- The generated URLs are long and unfriendly (base64-encoded JSON).

### bunny

The narrowest API of the set, but it covers more of Imager's syntax than its parameter list
suggests. Width, height, ratio, quality and format translate, `crop` and `fit` both work, and
**focal points are fully supported**: Bunny has no focal point parameter, so the transformer
computes the crop rectangle from the focal point (or an explicit `position`) and the target
ratio, and sends `crop=w,h,x,y`. The framing matches what `craft` would produce.

- Focal-point cropping needs **both `width` and `height`**, and mode `crop` (the default). With
  one dimension there is nothing to crop and no `crop` param is sent.
- `stretch` and `croponly` are not translated — you get Bunny's plain, aspect-preserving
  resize, the same as `fit`.
- `letterbox`, `pad`, `cropZoom`, `trim`, `frames`, effects and watermarks are not translated.
- **Params are pruned to a whitelist**: `width`, `height`, `aspect_ratio`, `quality`,
  `sharpen`, `blur`, `crop`, `crop_gravity`, `flip`, `flop`, `brightness`, `saturation`, `hue`,
  `contrast`, `auto_optimize`, `sepia`, `class`, `format`. Anything else passed through
  `transformerParams` is dropped silently.
- **A string source is treated as a path inside the pull zone**, not as an external URL — it is
  appended to the zone hostname verbatim. That is why `bunny` cannot fetch an external image,
  and also what makes the recipe in *Combining transformers* work.
- Profiles map to pull zones: `hostname` (required), `addPath`, `useCloudSourcePath`,
  `defaultParams`, `apiKey`, `excludeFromPurge`.

Config: `imager-x-bunny-transformer.php` — `profiles`, `defaultProfile`, `apiKey`.

### craftcloud

Craft Cloud's edge transforms. Only relevant when hosting on Craft Cloud — check the plugin
supports your Craft major version before planning around it.

It builds the URL by handing parameters to Craft's own `Asset::getUrl()`, so it translates
width, height, format, quality, `mode` (with `croponly` logged and reverted to `crop`),
`letterbox` fill, `allowUpscale` and `interlace`, and nothing else.

- **Assets only**, and unusually loud about it: a URL or path throws an `ImagerException`
  naming the limitation rather than degrading.
- **Focal points work, `position` does not.** Imager passes no position; Craft Cloud reads the
  asset's own focal point when cropping, so an overridden `position` in a transform is ignored.
- `transformerParams` is not read at all.

## Choosing one

Most of the choice is made by constraints rather than preference:

| Constraint | What it forces |
|------------|----------------|
| Imager X Lite | `craft`, nothing else |
| No persistent disk (containers, Craft Cloud, Servd) | Anything but `craft` — an external storage does *not* fix this |
| Images must be served from your own domain | `craft`, `imgixdownload`, or a CDN in front of your own site |
| `croponly`, `preEffects`, `frames`, `trim`, watermarks, the full effect list | `craft` — or `craft` first and the service after, see *Combining transformers* |
| Sources are external URLs rather than Craft assets | `craft`, `imgix`/`gumlet` with a web proxy source, `imagekit`, `cloudflareimages` — or `craft` first, then anything |
| Already on Cloudflare | `cloudflareimages`, if resize, quality, format, `letterbox` and focal point cover it |
| Already on Bunny.net | `bunny` |
| Already on AWS with images in S3 | `awsserverless` |
| Hosting on Craft Cloud | `craftcloud` |

With none of those in play, `imgix`, `gumlet` and `imagekit` are the general-purpose CDN
transformers and they cover close to the same ground. What separates them *in Imager terms* is
narrow:

- `gumlet` adds `pad` and an approximated `trim`; neither of the others has them.
- `imgix` and `gumlet` translate percentage focal points and `cropZoom`. `imagekit` snaps focal
  points to anchor keywords and ignores `cropZoom`.
- `imagekit` is the only one of the three that translates `croponly`.
- `imgix` and `gumlet` add `getPalette()`; all three do format negotiation and forward
  arbitrary service params.

Past that the deciding factor is usually price rather than features — `gumlet` and `imagekit`
generally undercut `imgix` — along with delivery network and whichever account already exists.
Pricing moves; check the vendors, not this file.

The transformer is normally set per environment. A practical development pattern is `craft`
locally, the remote transformer in staging and production:

```php
// config/imager-x.php
return [
    '*'          => ['transformer' => 'craft'],
    'production' => ['transformer' => 'imgix'],
];
```

Only `craft` and `imgixdownload` write local files, so a shared transform cache is only a
problem when switching between those two — there, clear the cache or give each environment its
own `imagerSystemPath`. Moving to a remote transformer needs neither.

## Combining transformers

Setting the transformer *per transform* is legitimate and useful — it is how you fill the gaps
in the table above, and the Power Pack does it internally to force `craft` for placeholders.
Two facts make it work:

1. `transformer` is a config setting, so it can be overridden per transform —
   `transformImage()`'s fourth argument, `imagerOverrides` in the Power Pack's `params`, or
   `configOverrides` on a named transform.
2. `transformImage()` accepts an already-transformed image as its source (see
   `transform-syntax.md`, Chaining).

So: do the part the service cannot do locally, then hand the result to the service.

```twig
{% set base = craft.imagerx.transformImage(asset, {
    width: 2000,
    effects: { grayscale: true, colorBlend: ['#ffcc33', 0.3] },
    jpegQuality: 95
}, {}, { transformer: 'craft' }) %}

{% set imgs = craft.imagerx.transformImage(base, [400, 1200, 16/9], {}, {
    transformer: 'bunny'
}) %}
```

The first call writes one local file with the effects baked in; the second hands that file to
Bunny, which resizes and delivers. Every `craft`-only feature — `preEffects`, `croponly`,
`frames`, `trim`, watermarks, the full effect list — becomes available on any transformer this
way, for the cost of one extra local file per source image.

**It is also how you transform an external image on a service that cannot fetch one.** `bunny`
only addresses files inside its pull zone; `craft` can fetch any URL. So transform the remote
image locally first, and let the service work on your own file:

```twig
{% set local = craft.imagerx.transformImage('https://example.com/photo.jpg', {
    width: 2400
}, {}, { transformer: 'craft' }) %}

{% set imgs = craft.imagerx.transformImage(local, [400, 1200], {}, { transformer: 'bunny' }) %}
```

Rules of the road:

- **Only transformers that accept a string source can be chained into**: `craft`, `imgix`,
  `imgixdownload`, `gumlet`, `imagekit`, `cloudflareimages` and `bunny`. `imageboss`,
  `awsserverless` and `craftcloud` take an Asset and nothing else — they raise a `TypeError` or
  an `ImagerException` on anything else, so neither external images nor chained transforms work
  on them at all.
- **The service must be able to reach the intermediate file.** It is served from `imagerUrl` on
  your own domain, so the source has to point there: a Bunny pull zone with your site as
  origin, an imgix or Gumlet **web proxy** source, a Cloudflare zone in front of your site.
- **`imagerUrl` decides whether the hand-off resolves.** `bunny` treats a string source as a
  path *inside the pull zone*, so it needs `imagerUrl` relative (`/imager/`) — a full URL gets
  appended to the zone hostname and 404s. imgix and Gumlet web proxy sources need the opposite,
  an absolute URL, so set `imagerUrl` to a full URL from an environment variable when that is
  the pairing. Cloudflare takes either.
- **Do the expensive work once, at the largest size you need.** One base transform feeding a
  whole srcset is the point; one base per output size is not.
- **`craft` still runs**, so this does not avoid local transforms on an ephemeral filesystem —
  the base image is regenerated whenever `imagerSystemPath` is wiped.
- The base transform is a normal cached transform, so `imager-x/clear-caches` and automatic
  generation treat it like any other.

The one caveat on overriding `transformer` per transform: it is excluded from the
config-override filename hash, so two transforms differing *only* by transformer produce the
same filename. That only bites between the two transformers that write local files, `craft` and
`imgixdownload`, where the second reads the first's cached file — and there it is deliberate,
so `imgixdownload` can be swapped in and out without regenerating. See `named-transforms.md`.

## Storages and optimizers

Orthogonal to transformers, both Pro.

**External storages** upload transforms produced by `craft` (or `imgixdownload`) to S3, Google
Cloud Storage or DigitalOcean Spaces, each a separate plugin. Configured via `storages` and
`storageConfig` — see `configuration.md`. They add a delivery location; the local file in
`imagerSystemPath` is still the cache Imager checks before transforming. A storage therefore
does **not** make `craft` viable on an ephemeral filesystem: wipe the local path and every
transform is generated and uploaded all over again.

**Optimizers** post-process transformed files, and need a local file, so they only apply to
`craft` and `imgixdownload` — remote transformers do their own optimization. Off by default,
and a marginal gain next to serving a modern format; see `configuration.md` for when they are
still worth enabling.

**Adapters** let non-image files be transformed: the PDF adapter and the Video adapter (via
ffmpeg). Pass options with `adapterParams`.
