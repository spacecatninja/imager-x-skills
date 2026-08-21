---
name: imager-x
description: "Imager X — the image transform, optimization and manipulation plugin for Craft CMS, by SpaceCat Ninja. Covers responsive image markup with the Power Pack (pppicture/ppimg/ppplaceholder/pptransform), the quick transform syntax, named transforms, automatic generation of transforms, the full transform parameter set, srcset and sizes best practices, modern formats (WebP/AVIF/JPEG XL), placeholders and colors, imager-x config files, and the feature differences between transformers. ALWAYS load when writing, editing, reviewing or debugging image transforms or responsive image markup in a Craft project that has Imager X installed. Triggers on: craft.imagerx, craft.imager, transformImage, pppicture, ppimg, ppplaceholder, pptransform, |srcset, imager-x.php, imager-x-transforms.php, imager-x-generate.php, imager-x-power-pack.php, named transform, quick syntax, fillTransforms, fillInterval, fillAttribute, autoFillCount, transformDefaults, configOverrides, generateFlags, displayName, blurhash, blurup, dominantColor, silhouette, lazysizes, lazysizesClass, imagerSystemPath, imagerUrl, safeFileFormats, optimizeType, optimizers, filenamePattern, hashPath, addVolumeToPath, allowUpscale, resizeFilter, smartResizeEnabled, transformerParams, adapterParams, imgixParams, customEncoderOptions, croponly, letterbox, cropZoom, preEffects, effects, watermark, trim, pad, frames, getDominantColor, getColorPalette, getPercievedBrightness, serverSupportsWebp, serverSupportsAvif, clientSupports, isAnimated, base64Pixel, imager-x/generate, imager-x/clear-caches, imager-x/clean, imgix transformer, imagekit transformer, imageboss transformer, cloudflareimages transformer, awsserverless transformer, bunny transformer, imgixdownload, responsive images, srcset, sizes attribute, art direction, picture element, LCP image, fetchpriority, CLS, focal point, object-position, image placeholder, plus verbatim symptoms: 'transform returns null', 'srcset is empty', 'foreach() argument must be of type array|object, string given', 'Unsupported operand types: string / int', 'position has no effect', 'quality is ignored', 'webp quality not applied', 'placeholder division by zero', 'auto generation is not generating', 'transforms regenerate on every request', 'wrong source is picked', 'sources are in the wrong order', 'ratio is ignored', 'getPath returns empty', 'getSize returns empty'. Do NOT trigger for Craft's native asset transforms (asset.getUrl({width}), craft\\elements\\Asset transforms, imageTransforms in project config) when Imager X is not installed, or for ImageOptimize."
---

# Imager X — Transforms and Responsive Images for Craft CMS

Imager X does image transforms, optimization and manipulation in Craft CMS. Transforms are
file-based, so no database queries and no transform indexes. It transforms Assets (local or
cloud), local paths, external URLs, and already-transformed images, and it can hand the work
off to a third-party service instead of doing it locally.

Two companion plugins matter most for front-end work:

- **Imager X Power Pack** — template functions that generate correct `<picture>` and `<img>`
  markup. This is the recommended way to write responsive images. Everything about it is in
  `references/responsive-images.md`.
- **Transformer plugins** (imgix, ImageKit, Cloudflare Images, AWS Serverless, ImageBoss,
  Bunny.net) — offload transforms to a service. They do *not* all support the same features;
  see `references/transformers.md` before promising a parameter will work.

Verified against **Imager X 6.1.0** and **Power Pack 1.1.3** (August 2026).

## Scope

This skill owns: Imager X transforms and transform parameters, responsive image markup,
named transforms, automatic generation, Imager X config files, and transformer selection.

It does not own general Craft template architecture, Twig style conventions, or asset
volume and filesystem setup. Follow the project's existing conventions for those, and the
Craft docs at https://craftcms.com/docs/5.x/ for Craft itself.

Also out of scope, and worth saying so rather than guessing: the PHP extension API
(`EVENT_REGISTER_TRANSFORMERS`, writing custom transformers, effects, optimizers, storages
or adapters), implementing `TransformedImageInterface`, GraphQL transforms, and the
PDF/Video adapters. `WebFetch` https://imager-x.spacecat.ninja/extending or
https://imager-x.spacecat.ninja/usage/graphql for those.

## Documentation

- Overview and editions: https://imager-x.spacecat.ninja/overview
- Usage and quick syntax: https://imager-x.spacecat.ninja/usage/
- Templating reference: https://imager-x.spacecat.ninja/templating
- Transform parameters: https://imager-x.spacecat.ninja/transform-parameters
- Configuration: https://imager-x.spacecat.ninja/configuration
- Named transforms: https://imager-x.spacecat.ninja/usage/named-transforms
- Automatic generation: https://imager-x.spacecat.ninja/usage/generate
- Effects: https://imager-x.spacecat.ninja/effects
- Models: https://imager-x.spacecat.ninja/models
- Troubleshooting: https://imager-x.spacecat.ninja/troubleshooting
- Power Pack README: https://github.com/spacecatninja/craft-imager-x-power-pack
- Core repo: https://github.com/spacecatninja/craft-imager-x

`WebFetch` a specific documentation page when a reference file here doesn't go deep enough.

Console commands in the reference files are written as `php craft imager-x/…`. Match whatever
invocation the project already uses — `ddev craft`, `nitro craft`, `./craft`, or a Docker exec
wrapper.

## Editions — check this before recommending a feature

Imager X ships as **Lite** ($49) and **Pro** ($99). These are Pro-only:

| Pro-only feature | Consequence if the project is on Lite |
|------------------|----------------------------------------|
| Every transformer except `craft` | imgix/ImageKit/Cloudflare/AWS/ImageBoss/Bunny all throw `ImagerException` |
| Automatic generation of transforms | `config/imager-x-generate.php` is inert |
| `imager-x/generate` console command | Exits with "Console commands are only available in Imager X Pro" |
| External storages (S3, GCS, DO Spaces) | `storages` config is inert |
| GraphQL transform support | No Imager fields in the schema |

Everything else — transforms, the Power Pack, quick syntax, named transforms, optimizers,
placeholders, colors, WebP/AVIF/JXL — works on Lite. When a task needs a Pro feature, say so
instead of silently writing config that will never fire.

## Which helper do I reach for?

| Need | Use | Reference |
|------|-----|-----------|
| One responsive image, one aspect ratio | `ppimg(image, transform, params, config)` | `responsive-images.md` |
| Art direction, or WebP/AVIF negotiation | `pppicture(sources, params, config)` | `responsive-images.md` |
| Placeholder on a wrapper element, not the `img` | `ppplaceholder(image, output, type, config)` | `responsive-images.md` |
| The transform objects themselves | `pptransform()` or `craft.imagerx.transformImage()` | `transform-syntax.md` |
| Power Pack is not installed | `craft.imagerx.transformImage()` + `|srcset`, hand-written markup | `transform-syntax.md`, `recipes.md` |
| Just a URL for one fixed size | `craft.imagerx.transformImage(image, { width: 400 }).url` | `transform-syntax.md` |

### Is the Power Pack installed?

Worth checking before writing responsive image markup, because it changes the whole approach:

```bash
grep imager-x-power-pack composer.json
```

Templates already calling `pppicture` or `ppimg` are proof enough on their own.

**If it is installed, prefer it.** Hand-rolled `<picture>` markup is where `sizes`, intrinsic
dimensions, `alt`, focal points and source ordering get quietly wrong.

**If it is not**, still write what was asked using `transformImage()` and `|srcset` —
`recipes.md` §9 has hand-written equivalents — and mention once that the Power Pack would
collapse most of it. It is **free**: MIT licensed, needing only the Imager X licence the
project already has.

```bash
composer require spacecatninja/imager-x-power-pack
php craft plugin/install imager-x-power-pack
```

Suggest it, do not act on it — installing a plugin is the user's decision. Say it once, and
drop it if they decline or say nothing.

## Common Pitfalls (Cross-Cutting)

- **There is no `|transform` filter, and no `'400x300'` string syntax.** The only Twig filter
  Imager X adds is `|srcset`. A *string* second argument to `transformImage()` is always a
  named transform handle. See `transform-syntax.md`.
- **`transformImages()` does not exist.** It is always `transformImage()`; it returns a single
  model for a single transform object and an array for an array of them. See `templating-api.md`.
- **Quick syntax needs real integers.** `isQuickSyntax()` checks `is_int()` on the first two
  elements, so `['400', '1200']` is not quick syntax — it is misread as a list of transforms and
  **throws** `foreach() argument must be of type array|object, string given` from
  `TransformHelpers`. `[400, 1200]` works. Cast values that may arrive as strings. See
  `transform-syntax.md`.
- **One full media-query string turns off source sorting for the whole set.** All-integer
  media queries are sorted descending for you; as soon as any source uses a media-query string
  (or `'landscape'`/`'portrait'`), ordering becomes yours and the browser takes the *first*
  matching `<source>`. Writing sources largest-first is correct either way.
  See `responsive-images.md` (Source Order).
- **`format` in a source slot only sets `type="image/…"`.** It does not encode that format.
  Put the format in the transform as well. See `responsive-images.md`.
- **`media` and `type` are never emitted on the `<img>`.** The last source becomes the `<img>`
  fallback, so a media query or format on it is silently dropped. See `responsive-images.md`.
- **`position` is silently dropped** unless `mode` is `crop` or `croponly`. Setting a position
  on a `fit` transform does nothing. See `transform-parameters.md`.
- **Craft position keywords are hyphenated, and a wrong one throws.** `'top-center'` is valid;
  `'top center'` is not recognised, falls through untranslated, and raises `Unsupported operand
  types: string / int`. The nine valid keywords are `top-`/`center-`/`bottom-` × `left`/`center`/`right`.
  See `transform-parameters.md` (position).
- **`quality` only maps to `jpegQuality`.** It does nothing for WebP, AVIF or JPEG XL — set
  `webpQuality` / `avifQuality` / `jxlQuality` explicitly. See `transform-parameters.md`.
- **`ratio` is consumed only when one dimension is missing.** With both `width` and `height`
  set it does not change the output, but it stays in the transform and changes the cache
  filename. See `transform-parameters.md`.
- **`sizes` defaults to `100vw`.** Correct only for full-bleed images; anywhere else it makes
  the browser download a needlessly large candidate. See `responsive-images.md` (sizes).
- **`loading` defaults to `lazy`.** Lazy-loading the LCP image delays it. Set
  `loading: 'eager'` and `fetchpriority: 'high'` on the one above-the-fold hero.
  See `responsive-images.md` (LCP).
- **Placeholders always force `transformer: 'craft'`.** A project on imgix or Cloudflare still
  generates local transforms for its placeholders, and needs a writable `imagerSystemPath`.
  See `responsive-images.md` (Placeholders).
- **imgix with `getExternalImageDimensions: false` breaks *external* images.** Assets are
  unaffected — their dimensions come from Craft. For URL and path sources the transformer
  reports `0 × 0`, and both imgix's own target-size maths and Power Pack's placeholder divide
  by that. See `transformers.md` (imgix).
- **`fillTransforms`, `fillInterval`, `fillAttribute`, `filenamePattern`, `transformer`,
  `optimizeType` and `safeFileFormats` are excluded from the config-override filename hash.**
  Passed via `configOverrides` they take effect but do not change the cache key, so two
  different overrides can collide on one cached file. See `named-transforms.md`.
- **Power Pack's `defaultTransformParams` is invisible to automatic generation.** Generation
  works off named transforms directly, so defaults applied only in the Power Pack config
  produce a cache miss at request time. Repeat them in the named transform. See
  `auto-generate.md`.
- **`--transforms` on the console command only accepts named transform handles.** It is a
  comma-separated string, so quick-syntax arrays cannot be passed on the CLI. See
  `auto-generate.md`.
- **Automatic generation is queue-based.** With a cron-driven queue runner the front end still
  transforms on demand until the job runs; use a daemon. The draft and revision guards apply
  only to `elements` and `fields` generation — `volumes` generation runs before them and skips
  only propagating saves. See `auto-generate.md`.
- **Non-`craft` transformers degrade silently.** On imgix, `getPath()`, `getExtension()`,
  `getMimeType()`, `getSize()`, `getDataUri()` and `getBase64Encoded()` return empty strings
  rather than failing. See `transformers.md`.
- **`|srcset` de-duplicates by descriptor.** Two transforms that resolve to the same width
  collapse into one candidate with no warning. See `transform-syntax.md`.
- **Imager's transform cache is not Craft's cache.** `php craft cache/flush` does not clear it;
  use `imager-x/clear-caches/transforms-cache` or the CP utility. See `configuration.md`.

## Reference Files

Read the reference file for the task. More than one often applies.

**Task examples:**

- "Make this hero image responsive" → `responsive-images.md` + `recipes.md`
- "Add WebP and AVIF support to this image" → `modern-formats.md` + `responsive-images.md`
- "Write a `<picture>` with a different crop on mobile" → `responsive-images.md` (Art Direction) + `recipes.md`
- "The wrong source is being picked" / "sources are in the wrong order" → `responsive-images.md` (Source Order)
- "My srcset is empty" → `transform-syntax.md` (Quick Syntax)
- "What does `[400, 1200, 16/9]` actually produce?" → `transform-syntax.md` (Quick Syntax)
- "Generate more intermediate sizes" → `transform-syntax.md` (fillTransforms)
- "Set up named transforms for this project" → `named-transforms.md`
- "Reuse a transform but change the ratio" → `named-transforms.md` (Nesting)
- "Why isn't my transform generated on upload?" → `auto-generate.md` (Events and Gating)
- "Pre-generate transforms for a volume" → `auto-generate.md` (Console Commands)
- "Generate transforms for one Matrix field only" → `auto-generate.md` (Field Handle Syntax)
- "`position` has no effect" / "the crop is off-centre" → `transform-parameters.md` (Normalization)
- "Add a watermark" / "apply a blur" → `transform-parameters.md` (Watermark, Effects)
- "Set up Imager X in a new project" → `configuration.md`
- "Transforms regenerate on every request" → `configuration.md` (Caching)
- "Switch this project to imgix" / "will `cropZoom` work on AWS Serverless?" → `transformers.md`
- "`getSize()` returns nothing" → `transformers.md` (Silent Degradation)
- "Add a blurhash placeholder" → `templating-api.md` (placeholder) + `responsive-images.md` (Placeholders)
- "Get the dominant colour for a background" → `templating-api.md` (Colors)
- "Pick a text colour with enough contrast" → `templating-api.md` (Colors)

| Reference | Scope | ~Lines |
|-----------|-------|-------:|
| `references/responsive-images.md` | Power Pack in full: `pppicture`, `ppimg`, `ppplaceholder`, `pptransform`, source tuples, media queries and source ordering, every `params` key, `sizes` and LCP best practice, placeholders, lazysizes, SVG/GIF bypass, all 14 config settings | 497 |
| `references/transform-syntax.md` | `transformImage()`, quick syntax parsing rules, full syntax, `fillTransforms` family, `|srcset` and descriptors, transform chaining, external images, closures | 350 |
| `references/transform-parameters.md` | Every transform key, resize modes, `position`, `ratio`, `pad`, `trim`, `frames`, `watermark`, `letterbox`, effects and preEffects, `transformerParams`, and the full normalization gotcha list | 308 |
| `references/named-transforms.md` | `imager-x-transforms.php`, `transforms`/`defaults`/`configOverrides`/`generateFlags`/`displayName`, merge precedence, nesting, closures, the filename-hash exclusion trap | 227 |
| `references/auto-generate.md` | `imager-x-generate.php`, `volumes`/`fields`/`elements`, field handle syntax, event gating, queue behaviour, console commands and flags, element action, strategy | 299 |
| `references/configuration.md` | `imager-x.php` settings with defaults, paths and URLs, quality per format, filenames and hashing, caching and cache clearing, optimizers, fallback/mock images, multi-environment | 299 |
| `references/transformers.md` | Per-transformer feature matrix and what each one silently drops, `transformerParams` escape hatch, storages and optimizers, choosing a transformer | 225 |
| `references/modern-formats.md` | WebP, AVIF, JPEG XL; `<picture>` negotiation vs transformer `auto=format`; support detection; `safeFileFormats`; animated GIFs; format ladders | 204 |
| `references/templating-api.md` | The complete `craft.imagerx` surface with verbatim signatures, `placeholder()` config, transformed-image model methods, colors and contrast utilities | 246 |
| `references/recipes.md` | Copy-paste patterns: LCP hero, card grid, art-directed banner, orientation switch, background image, SVG logo, rich-text images, auto-generated thumbnails, no-Power-Pack equivalents | 349 |
