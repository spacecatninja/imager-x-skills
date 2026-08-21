# Automatic Generation of Transforms

**Pro only.** Generating transforms is expensive, and doing it during a page request is the
slowest possible moment. Automatic generation creates them when an asset is uploaded or an
element is saved, plus console commands and an element action for batch runs.

Generation works off **named transforms** or quick syntax — see `named-transforms.md`.

## The config file

```php
<?php
// config/imager-x-generate.php

return [
    // Only generate for live elements (elements generation only)
    'generateOnlyForLiveElements' => false,

    // Also generate when a draft is saved (elements and fields generation only)
    'generateForDrafts' => false,

    // Volume handle => transforms. Runs on every asset saved in the volume.
    'volumes' => [
        'employeeImages' => ['employeeThumbnail', 'employeePoster'],
        'images' => ['listImage', 'seoOpenGraph'],
    ],

    // Field handle => transforms. Runs when an element with that field is saved.
    'fields' => [
        'heroImage' => ['heroImage'],
        'articleBlocks:imageBlock.image' => ['articleImage'],
    ],

    // Element-scoped, the most precise option.
    'elements' => [
        [
            'elementType' => \craft\elements\Entry::class,
            'criteria' => ['section' => 'events'],
            'fields' => ['heroImage'],
            'transforms' => ['eventHeroImage'],
        ],
    ],
];
```

**If this file does not exist, no event listeners are registered at all.** An empty config is
not the same as a missing one.

Transforms may be named handles or quick syntax anywhere a transform list is accepted:

```php
'volumes' => [
    'images' => ['listImage', [400, 1200, 16 / 9]],
],
```

Every generated transform is forced to `optimizeType: 'runtime'`, so optimization happens
inline in the job rather than spawning a second queue job per image.

## Choosing volumes, fields or elements

| Setting | Fires on | Use when |
|---------|----------|----------|
| `volumes` | Any asset saved in the volume | Every image in the volume needs the same transforms |
| `fields` | Any element saved that has the field | A transform belongs to a field regardless of section |
| `elements` | Element saves matching an element query | A transform is used in one section, or one template |

Start with `volumes` for genuinely global transforms, then move anything section-specific into
`elements`. The cost of over-generating is real: transforms nothing renders still consume
build time, queue time and disk.

❌ Every image in a shared volume gets every transform in the project:
```php
'volumes' => [
    'images' => ['hero', 'listImage', 'eventHero', 'productGallery', 'seoOpenGraph', 'seoTwitter'],
],
```

✅ Global ones by volume, specific ones scoped to where they are used:
```php
'volumes' => [
    'images' => ['listImage', 'seoOpenGraph'],
],
'elements' => [
    [
        'elementType' => \craft\elements\Entry::class,
        'criteria' => ['section' => 'events'],
        'fields' => ['heroImage'],
        'transforms' => ['eventHero'],
    ],
    [
        'elementType' => \craft\elements\Entry::class,
        'criteria' => ['section' => ['news', 'articles']],
        'fields' => ['heroImage', 'articleBlocks:imageBlock.image'],
        'transforms' => ['articleImage'],
    ],
],
```

### elements entries

| Key | Meaning |
|-----|---------|
| `elementType` | Fully qualified class, e.g. `\craft\elements\Entry::class` |
| `criteria` | Passed straight to the element query — same parameters as any Craft query |
| `fields` | Field handles to pull assets from |
| `transforms` | Named handles or quick syntax |
| `limit` | Cap on assets processed per run |

`criteria` gets `id` set to the saved element, `status` set to `null` unless
`generateOnlyForLiveElements` is on, `drafts` enabled when `generateForDrafts` is on, and
`siteId` defaulted to the element's site if you have not specified `siteId` or `site`.

## Field handle syntax

| Form | Matches |
|------|---------|
| `heroImage` | An assets field directly on the element |
| `myMatrix:blockTypeHandle.imageField` | An assets field inside one Matrix entry type |
| `myMatrix:*.imageField` | That field in **every** entry type of the Matrix |
| `contentBlockField.imageField` | A field inside a content block (Craft 5.2.0+) |
| `heroImage[2]` | Skip the first 2 related assets |
| `heroImage[:3]` | First 3 only |
| `heroImage[1:3]` | Skip 1, then take 3 |

The offset/limit suffix is how you avoid generating a large transform for every image in a
50-image gallery when only the first is ever rendered big:

```php
'fields' => [
    'galleryImages[:1]' => ['galleryHero'],
    'galleryImages' => ['galleryThumbnail'],
],
```

An invalid handle logs a message naming the accepted formats rather than throwing.

## Event gating — why it did not generate

Generation hangs off `Elements::EVENT_AFTER_SAVE_ELEMENT`. In order:

1. **Not Pro, or no config file** → no listeners registered at all.
2. **Asset saved with `Asset::SCENARIO_INDEX`** → skipped entirely. Re-indexing a volume does
   not generate transforms; that is what the console command is for.
3. **`volumes` generation** runs next, skipped only when `$element->propagating` (so a
   multi-site propagation save does not generate the same transforms once per site).
4. **Revisions** → return. Nothing below this point runs.
5. **Drafts** → return, unless `generateForDrafts` is on.
6. **`elements` generation**, then **`fields` generation**.

Note the ordering: the draft and revision guards sit *after* volume generation, so `volumes`
generation is not affected by them.

7. Finally, every candidate asset must pass `shouldTransformElement()` — it must be an Asset
   whose extension is in `safeFileFormats` (default `jpg`, `jpeg`, `gif`, `png`, `webp`).

That last one is the quiet one. **An AVIF or SVG source is skipped** unless you add its
extension to `safeFileFormats`.

## It all goes through the queue

Generation pushes `TransformJob`s rather than transforming inline, so uploads and saves stay
fast. Jobs are de-duplicated within a request by `assetId:md5(transforms):force`, so saving an
element that references the same asset from three fields queues one job.

**Run a queue daemon.** With Craft's default cron-driven runner there is a window between the
save and the job during which the front end still transforms on demand — exactly the latency
automatic generation exists to remove. `runJobsImmediatelyOnAjaxRequests` (default `true`)
covers CP saves but not the front end.

## Console commands

All Pro-only; `imager-x/generate` exits with an "only available in Imager X Pro" message
otherwise.

```bash
# Generate the transforms configured for a volume
php craft imager-x/generate --volume=images

# Specific named transforms, queued rather than inline
php craft imager-x/generate --volume=images --transforms=heroImage,listImage --queue

# One folder, recursing into children
php craft imager-x/generate --volume=images --folderId=12 --recursive

# By field instead of volume
php craft imager-x/generate --field=heroImage --transforms=heroImage

# Re-create transforms that already exist
php craft imager-x/generate --volume=images --transforms=heroImage --force

# Chunk a large volume
php craft imager-x/generate --volume=images --limit=500 --offset=1000
```

| Option | Alias | Notes |
|--------|-------|-------|
| `--volume` | `-v` | Volume handle. Mutually exclusive with `--field` |
| `--field` | `-f` | Field handle. Mutually exclusive with `--volume` |
| `--folderId` | `-fid` | Restrict to a folder |
| `--recursive` | `-r` | Recurse into subfolders |
| `--transforms` | `-t` | Comma-separated named transform handles |
| `--force` | — | Regenerate even if the file exists and has not expired |
| `--queue` | `-q` | Push jobs instead of transforming inline |
| `--limit` | `-l` | Number of assets to process |
| `--offset` | `-o` | Where to start |

Behaviours worth knowing:

- **`--transforms` only accepts named transform handles.** It is a comma-separated string, so
  quick-syntax arrays cannot be passed on the command line. Wrap the quick syntax in a named
  transform if you need to generate it from the CLI.
- **Omitting `--transforms` falls back to the config** for that volume or field.
- **Specifying both `--volume` and `--field` is an error**, as is specifying neither.
- Without `--queue` the command transforms inline, which is what you usually want in a deploy
  script — you get real progress output and a meaningful exit code.
- Assets failing `shouldTransformElement()` print `skipped`.

Long runs on large volumes are memory-hungry with the `craft` transformer. Chunk with
`--limit`/`--offset`, or use `--queue` and let the daemon work through it.

### Clearing and cleaning

```bash
# Everything Imager X caches
php craft imager-x/clear-caches/all

# Just the generated transforms
php craft imager-x/clear-caches/transforms-cache

# Just downloaded remote files and other runtime data
php craft imager-x/clear-caches/runtime-cache

# Remove transforms older than a duration
php craft imager-x/clean --volume=images --duration=P1M
php craft imager-x/clean --runtimeCache
php craft imager-x/clean --volume=images --exclude=logos
```

`php craft cache/flush` does **not** clear Imager X transforms — they are files, not cache
entries. See `configuration.md`.

## The element action

With a non-empty `volumes` config on Pro, a **Generate Transforms** action appears in the
Assets element index. Useful for regenerating a handful of images after changing a named
transform, without a full volume run.

## generateFlags

Named transforms can precompute derived data during generation, so a request never pays for it:

```php
'cardThumbnail' => [
    'transforms' => [400, 900, 4 / 3],
    'generateFlags' => ['dominantColor', 'blurhash'],
],
```

`'blurhash'`, `'palette'` and `'dominantColor'` are the accepted flags. Set them whenever
templates use a blurhash or dominant-colour placeholder — both otherwise decode the image
during the request. Ignored when the transform is called from a template.

## The defaultTransformParams trap

The Power Pack's `defaultTransformParams` applies only to Power Pack calls. Generation
transforms the named transform directly, so any default set only in the Power Pack config is
absent from the generated transform, the filename differs, and every request misses the cache
and transforms on demand.

❌ Defaults in one place, generation in another — generation produces files nothing reads:
```php
// config/imager-x-power-pack.php
return ['defaultTransformParams' => ['jpegQuality' => 72]];

// config/imager-x-transforms.php
return ['heroImage' => ['transforms' => [800, 2400, 16 / 9]]];
```

✅ Put the defaults where both paths see them:
```php
// config/imager-x-transforms.php
return [
    'heroImage' => [
        'transforms' => [800, 2400, 16 / 9],
        'defaults' => ['jpegQuality' => 72],
    ],
];
```

## Verifying it works

1. Confirm the edition — the CP plugin page, or check that `imager-x/generate` does not refuse.
2. Confirm `config/imager-x-generate.php` exists and the handles in it resolve (Utilities →
   Imager X lists registered named transforms).
3. Save an asset, then check the queue: `php craft queue/info`.
4. Run the queue and look for the files under `imagerSystemPath` (default `@webroot/imager/`).
5. Check the logs for `Unknown transform type` — that is a handle in the generate config with
   no matching named transform.
