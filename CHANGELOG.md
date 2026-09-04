# Release Notes for the Imager X Claude skill

## 1.4.0

- Added a "Prefer quick syntax" section to `SKILL.md` and a rewrite guide to `references/transform-syntax.md`. Quick syntax is now the stated default for a width ladder — in templates, in named transforms, in Power Pack transform arguments and in the generate config — with a collapse table, the list of what does not collapse (a single fixed size, per-size differences, height-driven ladders, non-integer widths, exact intermediate widths), and what actually changes when a full-syntax list is collapsed. The rewrite is scoped to the transforms being edited or reviewed; sweeping a project is offered, not done.
- Corrected the advice on casting widths in `references/transform-syntax.md`. Twig's `round` filter returns a float, so `[minWidth|round, maxWidth|round]` fails `isQuickSyntax()`'s `is_int()` check and silently falls through to full syntax — the exact failure the surrounding section warns about. Craft's `|integer` filter is `intval()` and is the cast to use, chained as `|round|integer` when the value has decimals.
- Documented that quick syntax works with explicit fill settings. The implicit `fillTransforms: 'auto'` and `fillAttribute: 'width'` overrides are merged *under* the caller's, so `fillTransforms: true` with a `fillInterval` restores fixed-step filling. The `fixedStepBanner` example in `references/named-transforms.md` is now quick syntax rather than the long form, as are the nesting and `filenamePattern` examples.
- Noted that transforms are `ksort`ed before the filename is built, so the same parameters hash the same whether they arrived in the transform, in slot 2 or through `transformDefaults`. Collapsing a list to quick syntax therefore keeps the surviving widths' files; only the filled-in widths are new, and a dropped hand-written width is left as an orphan for `imager-x/clean`.
- Documented that a `width` key inside the slot-2 object overwrites both anchors — `array_merge(['width' => …], $defaults)` — so every candidate comes out the same size and `|srcset` collapses them into one.
- Replaced the full-syntax example in `references/transform-syntax.md`, which was a plain width ladder that should have been quick syntax, with one whose entries differ in shape.
- Added a "Mirror what templates render" section to `references/auto-generate.md`. Generation is set up in whichever style the project already uses: named handles, or the same quick-syntax arrays copied verbatim, which expand identically because generation runs them through the same `transformImage()` call. Includes a table of what has to match, the two things generation adds on its own (`optimizeType: 'runtime'`, which is excluded from the filename hash, and a `null` `transformDefaults`), and when a ladder should be promoted to a named transform.
- Noted that call-site transform `defaults` can be folded into the slot-2 object of a generate entry, but `imagerOverrides` cannot — config overrides are a separate string in the filename with no equivalent in a bare quick-syntax entry, and are the one case that forces a handle on both sides.
- Documented that `generateFlags` never fire for quick syntax. The flags run only on generation's named-transform branch, so `blurhash`, `palette` and `dominantColor` are not precomputed for an inline quick-syntax entry.
- Documented the nesting level of quick syntax in the generate config. Every value is a list of transforms, so `'images' => [400, 1200, 16 / 9]` is iterated entry by entry and logs `Unknown transform type “400” could not be found` three times; it needs `[[400, 1200, 16 / 9]]`. The same applies to `fields` values and to `transforms` inside an `elements` entry.
- Corrected the `--transforms` note in `references/auto-generate.md`. Quick syntax still cannot be passed on the command line, but omitting the flag falls back to the volume's or field's config, quick syntax included, so it is not a reason to wrap a ladder in a named transform. Added a verification step comparing a rendered image URL against the generated filenames.
- Added a "same thing without named transforms" variant to recipe 8 in `references/recipes.md`, pairing an inline quick-syntax call site with its generate config, and a preference note to the `ppimg` transform argument in `references/responsive-images.md`.

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
