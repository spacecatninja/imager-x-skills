# Release Notes for the Imager X Claude skill

## 1.3.0

- Corrected the claim that external storages help on ephemeral filesystems. A storage is an additional place to serve transforms *from* — Imager still writes every transform to `imagerSystemPath` and still checks that local file to decide whether the transform exists, so wiping the path regenerates and re-uploads everything. Only a transformer that does the work off-server avoids that. Fixed in `references/configuration.md`, `references/transformers.md` and the cross-cutting pitfalls in `SKILL.md`.
- Audited the transformer feature matrix in `references/transformers.md` against the transformer plugins' source. `bunny` supports focal points fully — Bunny has no focal point parameter, so the transformer computes the crop rectangle from the focal point and the target ratio and sends `crop=w,h,x,y`. `cloudflareimages` supports focal points, as `gravity`, and `letterbox` with opacity. `imagekit` translates `croponly` but not `cropZoom`. `imageboss` does not resize at all in `stretch` and `croponly` modes rather than falling back. `awsserverless` supports `pad`, compensated. Watermarks cannot be passed at all on `bunny` and `cloudflareimages`, whose parameter whitelists have no overlay param. Added a `pad` row and split the resize-mode row so each mode's fallback is visible.
- Added a focal points section to `references/transformers.md` describing what each transformer does with the normalized `position` value — percentages, anchor keywords, a 3×3 grid, a computed crop rectangle — including `craftcloud`, which ignores `position` while Craft Cloud still honours the asset's own focal point.
- Noted that `bunny` and `cloudflareimages` prune the final parameter list against a whitelist, so `transformerParams` is not a free pass on those two, and that `cloudflareimages` computes `fit` after the merge, making `fit` the one param that cannot be overridden there.
- Added a "Combining transformers" section to `references/transformers.md`: overriding `transformer` per transform and feeding an already-transformed image back into `transformImage()` to get `craft`-only features on a remote transformer, and to transform external images on services that cannot fetch them. Covers which transformers accept a string source at all — `imageboss`, `awsserverless` and `craftcloud` do not — and the `imagerUrl` requirement, relative for `bunny`, absolute for imgix and Gumlet web proxy sources.
- Reversed the advice not to switch transformer per transform. It is a supported pattern, and the Power Pack itself forces `transformer: 'craft'` for placeholders.
- Corrected the filename-hash exclusion section in `references/named-transforms.md`. Most of the seven excluded settings cannot change what a single transform renders. `transformer` is excluded deliberately, so `craft` and `imgixdownload` write the same filenames and `imgixdownload` can be swapped in and out without regenerating; a remote transformer writes no local file and has nothing to collide with. The `filenamePattern` hazard is a pattern without `{transformString}`, not overriding it per transform. The same correction was applied to the multi-environment note in `references/configuration.md`.
- Added a table for overriding a transformer's profile per transform, which splits three ways: `transformerConfig` in `configOverrides` for imgix and imagekit, `transformerParams` for bunny and imageboss, either for gumlet. Passing it in the wrong one silently falls back to the default profile.
- Reframed "Choosing one" around constraints rather than recommendations. imgix, Gumlet and ImageKit are stated as close in feature coverage, with only the differences that surface in Imager's own syntax listed, and price named as the usual deciding factor without figures.
- Fixed one remaining `php craft cache/flush` reference in `references/configuration.md` that 1.2.1 missed.

## 1.2.1

- Fixed a reference to the non-existent `php craft cache/flush` console command in `SKILL.md`, `references/graphql.md` and `references/auto-generate.md`. Craft's command is `clear-caches/all`. The surrounding claim is unchanged and still correct: Imager X registers a CP utility rather than a Craft cache option, so clearing Craft's caches never touches the transform cache.

## 1.2.0

- Added the `gumlet` transformer to `references/transformers.md`: the handles table, the feature support matrix, a full per-transformer section covering profiles and sources, the `croponly` fallback, untranslated effects and watermarks, approximated `trim`, compensated `pad`, the `mode` collision with `transformerParams`, web proxy profiles for external URLs, signed URLs, `useCloudSourcePath`, purging and source ID resolution, plus an example config.
- Noted in `references/modern-formats.md` that Gumlet does `Accept` header format negotiation, with its own `format: 'auto'` param rather than imgix's `auto: 'format'`.
- Noted in `references/templating-api.md` that the Gumlet model also adds `getPalette()`.
- Added Gumlet triggers to the skill description.

## 1.1.1

- Fixed an incorrect claim in `references/modern-formats.md` that `optimizeType: 'job'` moves AVIF encoding into the queue. `optimizeType` governs optimizers, not encoding — with the `craft` transformer a transform is always encoded during the request that first asks for it, and automatic generation is the only way to move that work off the request.
- Added a pitfall in `references/configuration.md` stating the same, next to the `optimizeType` setting itself.

## 1.1.0

- Added `references/graphql.md`, covering the `imagerTransform` query and `AssetInterface` field, the `@imagerTransform` and `@imagerSrcset` directives with every argument and `return` value, the fields on `ImagerTransformedImageInterface`, per-transformer degradation, the `safeFileFormats` gate, and pre-warming and caching for headless projects.
- GraphQL is no longer out of scope for the skill. Added GraphQL triggers to the skill description so it loads for GraphQL tasks.
- Corrected `references/modern-formats.md`: `safeFileFormats` also gates every GraphQL path, not just automatic generation and CP thumbnails.

## 1.0.0

- Added the `imager-x` skill, covering Imager X templating, responsive images with the Power Pack, transform parameters, named transforms, automatic generation, configuration, and transformers.
- Added `install.sh` and `uninstall.sh` for installing the skill by symlink.
