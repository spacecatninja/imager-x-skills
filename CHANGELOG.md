# Release Notes for the Imager X Claude skill

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
