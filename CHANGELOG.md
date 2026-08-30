# Release Notes for the Imager X Claude skill

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
