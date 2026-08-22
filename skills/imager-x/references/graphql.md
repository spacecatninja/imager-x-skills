# GraphQL

**Pro only.** The whole GraphQL layer is registered inside an edition check, so on Lite there is
no `imagerTransform` query, no field on `AssetInterface`, and no directives — queries fail with
`Unknown directive "imagerTransform"` or `Cannot query field "imagerTransform"`, not with a
silent null. Check the edition first when a query 400s.

Everything Imager exposes is built on **named transforms** or a small fixed set of inline
arguments. There is no quick syntax, no `fillTransforms`, no Power Pack, and no way to reach a
transform parameter that is not in the argument list below.

## What's in the schema

| Entry point | Arguments | Returns |
|-------------|-----------|---------|
| `imagerTransform` query | `id`, `url`, `transform` | `[ImagerTransformedImageInterface]` |
| `imagerTransform` on `AssetInterface` | `transform` | `[ImagerTransformedImageInterface]` |
| `@imagerTransform` directive | `handle`, `width`, `height`, `mode`, `position`, `interlace`, `quality`, `format`, `return` | `String` |
| `@imagerSrcset` directive | `handle` | `String` |

The two object-returning entry points are the useful ones. The directives are for when you only
want a URL and cannot change the query shape.

## The `imagerTransform` query

Transforms an asset by `id`, or an external image by `url`, using a named transform.

```graphql
{
  hero: imagerTransform(id: 340, transform: "heroImage") {
    url
    width
    height
    size
    mimeType
  }
}
```

**The result is always a list**, because a named transform may define several sizes. A
single-size handle still comes back as a one-element array:

```json
{ "data": { "hero": [ { "url": "/imager/…/340_heroImage.jpg", "width": 1200, … } ] } }
```

`id` and `url` are mutually exclusive. Passing both is not an error — **`id` wins** and a message
is logged to the Craft log. The `id` lookup is constrained to `kind('image')`, so a non-image
asset id resolves to `null`.

`transform` is read unconditionally by the resolver while the argument itself is nullable, so
**always pass it**. Omitting it produces a PHP undefined-key error rather than a clean GraphQL
validation message.

The `url` form takes any external image the transformer can reach:

```graphql
{
  imagerTransform(url: "https://example.com/photo.jpg", transform: "thumb") { url width height }
}
```

Treat this as a public, unauthenticated image-fetching endpoint on your site. External URLs go
through Imager's URL validation (SSRF checks, redirects re-validated per hop, downloads limited
to http/https), and `skipExternalUrlValidation` turns all of that off — do not set it on a site
whose schema is public. Note also that the format gate below only applies to a URL whose path
carries a file extension.

## `imagerTransform` on `AssetInterface`

The same resolver, reached from an asset you already have in the query. It takes **only**
`transform` — no inline width or height.

```graphql
{
  entries(section: "news", limit: 10) {
    title
    ... on news_news_Entry {
      image {
        url
        imagerTransform(transform: "heroImage") {
          url
          width
          height
        }
      }
    }
  }
}
```

The field is added to `AssetInterface` itself, so it needs no `... on volume_Asset` fragment —
the fragment in the published documentation is unnecessary. The fragment on the *entry* type is
still required to reach a custom field, as with any Craft query.

This is the form to prefer for a front end: one round trip, real `width` and `height` for
layout, and it survives schema introspection.

## The `@imagerTransform` directive

Applies to a **`url` field only**. On any other field it silently returns the value untouched —
`title @imagerTransform(width: 100)` is a no-op that looks like a broken transform. Alias the
`url` field to request several transforms of one asset:

```graphql
{
  entries(section: "news") {
    ... on news_news_Entry {
      image {
        url
        thumb: url @imagerTransform(width: 400, height: 400, mode: "crop", format: "webp")
        card:  url @imagerTransform(handle: "cardImage")
        blur:  url @imagerTransform(width: 100, mode: "fit", format: "jpg", return: "blurhash")
      }
    }
  }
}
```

The inline arguments map to their transform parameters of the same name; see
`transform-parameters.md` for values. Nothing else is available — no `ratio`, `pad`, `letterbox`,
`trim`, `effects`, `watermark`, `frames` or `transformerParams`. When you need any of those, move
the transform into `imager-x-transforms.php` and pass `handle`. See `named-transforms.md`.

**`handle` overrides everything else.** The implementation uses the handle if present and
otherwise treats the whole argument set as the transform, so
`@imagerTransform(handle: "cardImage", width: 200)` silently ignores `width`. Pick one style per
field.

**A named transform with several sizes collapses to the first.** The directive returns a single
string, so only `transforms[0]` survives. Use `@imagerSrcset` or the query if you want the ladder.

### The `return` argument

The schema description advertises `url`, `base64` and `dataUri`. The implementation also handles
`blurhash` and `dominantColor`:

| `return` | Result |
|----------|--------|
| `url` (default) | Transformed image URL |
| `base64` | Base64-encoded file contents |
| `dataUri` | `data:image/…;base64,…` |
| `blurhash` | Blurhash string, cached and tagged to the source asset |
| `dominantColor` | Hex colour |

Keep transforms tiny for `base64` and `dataUri` — the encoded file goes into the JSON response.
A 20px-wide `fit` transform is a sensible placeholder; a 1200px one will wreck the payload.

`dominantColor` is the odd one out: it hands the transformed image to the colour service as a
*URL*, which fetches it back as an external source before sampling. The result is cached, but a
cold cache costs an HTTP round trip per image. If a page needs colours for many images, prefer a
pre-computed field on the element.

## The `@imagerSrcset` directive

`url` fields only, same as above, and **`handle` is required** — without it the field resolves to
`null`. It returns the plain `srcset` string for the named transform, exactly as `|srcset` would
in Twig, with `w` descriptors and no control over the format:

```graphql
{
  entries(section: "news") {
    ... on news_news_Entry {
      image {
        src: url
        srcset: url @imagerSrcset(handle: "heroImage")
      }
    }
  }
}
```

There is no `sizes` argument, and no descriptor switch — write `sizes` in the front end, where
the layout is known. Candidates that resolve to the same width are de-duplicated; see
`transform-syntax.md`.

## Fields on the returned type

`ImagerTransformedImageInterface` exposes exactly these:

| Field | Type | Notes |
|-------|------|-------|
| `url` | String | |
| `width`, `height` | Int | Use these for `width`/`height` attributes and CLS |
| `extension` | String | |
| `mimeType` | String | |
| `size` | Int | Bytes |
| `filename` | String | |
| `path` | String | **Server filesystem path.** Do not expose it through a public schema |
| `isNew` | Boolean | Whether this request generated the file |

Nothing else is exposed. No srcset, no placeholder, no data URI, no focal point, no ratio — for
those, use the directive's `return` argument or compute them in the front end.

**With any transformer other than `craft`, most of these are empty rather than null.** A service
transformer only fills in `url`, `width` and `height`; `path`, `filename`, `extension` and
`mimeType` come back as empty strings, `size` as `0`, and `isNew` as `false`. A consumer cannot
tell that apart from a genuinely empty value, so do not build logic on `size` or `isNew` unless
the project is on the `craft` transformer. The same degradation makes `return: "base64"`,
`"dataUri"` and `"blurhash"` return empty strings on a service transformer. See `transformers.md`.

## `safeFileFormats` gates every path

Default from source: `['jpg', 'jpeg', 'gif', 'png', 'webp']`.

Unlike Twig, where `transformImage()` accepts any format, **GraphQL refuses to transform a source
whose extension is not on this list** and returns `null`. This applies to the query, the
`AssetInterface` field and both directives. The reasoning is that a schema cannot easily
condition on format the way a template can.

The check is on the **source** extension, not the target `format`, so transforming a JPEG to AVIF
is fine. An AVIF or SVG source asset, however, resolves to `null` with nothing in the response to
say why. Any format your editors can upload and your front end will query needs to be listed:

```php
// config/imager-x.php
'safeFileFormats' => ['jpg', 'jpeg', 'gif', 'png', 'webp', 'avif'],
```

A `null` from an otherwise-correct query is nearly always this, an edition mismatch, or a handle
that does not exist. See `modern-formats.md`.

## Headless practice

**Transforms are generated inside the resolver.** The first query for a given transform does the
image work while the client waits, which on a cold cache and a listing query means dozens of
transforms in one request. Pre-generate so resolves are cache hits:

```php
// config/imager-x-generate.php
return [
    'volumes' => [
        'images' => ['heroImage', 'cardImage'],
    ],
];
```

Automatic generation is queue-based and Pro-only, and it works off named transform handles — one
more reason to prefer handles over inline directive arguments in a headless project. See
`auto-generate.md`.

**Two unrelated caches.** Craft's `enableGraphqlCaching` (default `true`) caches the GraphQL
*response*; Imager's transform cache holds the *files*. Clearing one does nothing to the other,
and `php craft cache/flush` does not touch Imager's. When a stale transform survives a config
change, clear both: `imager-x/clear-caches/transforms-cache` and Craft's caches. See
`configuration.md`.

**Directives are invisible to anything that reads the schema.** A directive changes the value of
a `String` field, so generated types, Gatsby-style source plugins and typed clients see a plain
string and have no idea a transform happened — no dimensions, and no indication that the URL
depends on the arguments. When a build step or code generation is involved, use the query or the
`AssetInterface` field.

**Ask for the sizes you will render.** There is no `sizes` or media-query logic server-side, so
the front end owns responsive selection. A practical pattern is one named transform per layout
slot, queried as an object so the client gets the full ladder with dimensions:

```graphql
{
  entries(section: "news") {
    ... on news_news_Entry {
      image {
        imagerTransform(transform: "cardImage") { url width height }
      }
    }
  }
}
```

Then build `srcset` from the array client-side, using `width` for each candidate's `w`
descriptor.

## Pitfalls

- **Nothing in the schema on Lite.** The whole layer is behind the Pro edition check.
- **Directives only apply to `url`.** On any other field they return the value unchanged, with no
  error.
- **`handle` silently wins over inline directive arguments.**
- **A directive on a multi-size named transform returns only the first URL.**
- **The query and field always return a list**, even for a single-size transform.
- **`transform` must be passed to the query** — it is read without a null check.
- **`id` and `url` together: `id` wins**, and only a log line says so.
- **`safeFileFormats` blocks AVIF and SVG sources by default**, returning `null` with no message.
- **Service transformers return empty strings and `0`, not null**, for `path`, `filename`,
  `extension`, `mimeType`, `size`, and for `base64`/`dataUri`/`blurhash`.
- **`path` is a server filesystem path** — don't ship it in a public schema.
- **`return` supports `blurhash` and `dominantColor`** even though the schema description omits
  them, and `dominantColor` refetches the image over HTTP on a cold cache.
- **No inline access to `ratio`, `pad`, `trim`, `effects`, `watermark`, `frames` or
  `transformerParams`** — those need a named transform.
