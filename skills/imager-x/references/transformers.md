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
| `imagekit` | `imager-x-imagekit-transformer` | ImageKit |
| `imageboss` | `imager-x-imageboss-transformer` | ImageBoss |
| `cloudflareimages` | `imager-x-cloudflare-images-transformer` | Cloudflare Images |
| `awsserverless` | `imager-x-aws-serverless-transformer` | AWS Serverless Image Handler |
| `bunny` | `imager-x-bunny-transformer` | Bunny.net |
| `craftcloud` | `imager-x-craft-cloud-transformer` | Craft Cloud's edge transforms |

Each has its own config file — `imager-x-imgix-transformer.php`,
`imager-x-imagekit-transformer.php`, and so on — usually with a `profiles` array and a
`defaultProfile`.

## Feature support

`craft` is the reference implementation. Everything else supports a subset.

| Feature | craft | imgix | imagekit | imageboss | cloudflare | awsserverless | bunny |
|---------|:-----:|:-----:|:--------:|:---------:|:----------:|:-------------:|:-----:|
| `crop`, `fit`, `stretch` | ✅ | ✅ | ✅ | `stretch` ✗ | crop modes only | ✅ | `crop`/`fit` only |
| `croponly` | ✅ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `letterbox` | ✅ | ✅ | ✅ | no opacity | ✗ | ✅ | ✗ |
| `cropZoom` | ✅ | ✅ | ✅ | ✅ | ✗ | ✗ | ✗ |
| Focal points | ✅ | ✅ | anchors only | ✅ | ✗ | edge positions only | ✗ |
| `effects` | all | via params | via params | 4 only | via params | 5 only | via params |
| `preEffects` | ✅ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `watermark` | ✅ | via params | via params | via params | via params | via params | via params |
| `frames` | ✅ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| `trim` | ✅ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| External URLs | ✅ | ✅ | ✅ | **✗** | ✅ | **✗** | **✗** |
| Optimizers | ✅ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |

Where a cell says "via params", use the `transformerParams` transform parameter to pass the
service's own options — Imager does not translate the Imager-syntax equivalent for you.

```twig
{% set imgs = craft.imagerx.transformImage(asset, [400, 1200, 2/1], {
    transformerParams: { sharp: 10 }
}) %}
```

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

- **Two breaking changes in 6.x.** Overriding the profile from a template changed shape —
  `{ imgixProfile: 'someprofile' }` is now
  `{ transformerConfig: { profile: 'someprofile' } }`. And `imgixParams` is gone entirely: the
  transformer reads only `transformerParams`, so an old `imgixParams` object is silently
  ignored. Grep for both when upgrading.
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

### imagekit

Basic transform parameters translate. Three real gaps:

- Focal points become **anchor keywords** (`top`, `left`, `center`, …), not percentages. A
  focal point at 20%/65% snaps to the nearest anchor.
- **Watermarks are not translated.** Pass ImageKit's own watermark options through
  `transformerParams`.
- **No effects are converted at all.**

Config: `imager-x-imagekit-transformer.php` — `signUrls`, `signedUrlsExpireSeconds`,
`stripUrlQueryString`, `profiles`, `defaultProfile`.

### imageboss

- **Assets only.** External images need the `craft` transformer for those transforms.
- `croponly` and `stretch` unsupported.
- `letterbox` opacity unsupported.
- Only `grayscale`, `sharpen`, `blur` and `gamma` effects are converted.
- Watermarks not translated.

### cloudflareimages

Optimizes any publicly reachable image via a Cloudflare zone. **It does not store images** —
the source must stay publicly available, and the zone needs the source configured.

- Crop modes, width, height, ratio, quality and format translate. Everything else goes through
  `transformerParams`.
- No `cropZoom`, no focal points, no `letterbox`.
- Composes nicely with `craft`: do an unsupported transform locally, then let Cloudflare resize
  the result, since Cloudflare only cares that the URL is on the zone.

### awsserverless

Fronts the AWS Serverless Image Handler.

- **AWS-bucket assets only.**
- **Percentage focal points unsupported** — snapped to edge positions like `top`/`left`.
- `croponly` and `cropZoom` unsupported.
- `frames` and `preEffects` not applicable.
- Effects converted: `grayscale`, `negative`, `normalize`, `sharpen`, `blur`.
- `transformerParams` reaches the underlying sharp.js options.
- The generated URLs are long and unfriendly.

### bunny

The most limited. Essentially `crop` and `fit` resizing plus width, height, ratio, quality and
format. Everything else via `transformerParams`.

### craftcloud

Craft Cloud's edge transforms. Only relevant when hosting on Craft Cloud — check the plugin
supports your Craft major version before planning around it.

## Choosing one

| Situation | Reach for |
|-----------|-----------|
| Ordinary site, persistent disk, effects/watermarks needed | `craft` with Imagick |
| Large library, want CDN delivery and format negotiation | `imgix` |
| Ephemeral filesystem (containers, Cloud, Servd) | A remote transformer, or an external storage with `craft` |
| Already on Cloudflare, only need resize/quality/format | `cloudflareimages` |
| Want imgix quality but images served from your domain | `imgixdownload` |
| Already on AWS with images in S3 | `awsserverless` |

Do not switch transformer *per transform*. `transformer` is excluded from the config-override
filename hash, so two transforms differing only by transformer produce the same filename and
collide — see `named-transforms.md`. Switch per environment instead, and give each environment
its own `imagerSystemPath` or clear the cache on switch.

A practical development pattern: `craft` locally, the remote transformer in staging and
production.

```php
// config/imager-x.php
return [
    '*'          => ['transformer' => 'craft'],
    'production' => ['transformer' => 'imgix'],
];
```

## Storages and optimizers

Orthogonal to transformers, both Pro.

**External storages** upload transforms produced by `craft` (or `imgixdownload`) to S3, Google
Cloud Storage or DigitalOcean Spaces, each a separate plugin. Configured via `storages` and
`storageConfig` — see `configuration.md`. This is how you keep `craft`'s full feature set on an
ephemeral filesystem.

**Optimizers** post-process transformed files, and need a local file, so they only apply to
`craft` and `imgixdownload` — remote transformers do their own optimization. Off by default,
and a marginal gain next to serving a modern format; see `configuration.md` for when they are
still worth enabling.

**Adapters** let non-image files be transformed: the PDF adapter and the Video adapter (via
ffmpeg). Pass options with `adapterParams`.
