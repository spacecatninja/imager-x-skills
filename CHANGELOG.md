# Release Notes for the Imager X Claude skill

## 1.1.0

- Added `references/graphql.md`, covering the `imagerTransform` query and `AssetInterface` field, the `@imagerTransform` and `@imagerSrcset` directives with every argument and `return` value, the fields on `ImagerTransformedImageInterface`, per-transformer degradation, the `safeFileFormats` gate, and pre-warming and caching for headless projects.
- GraphQL is no longer out of scope for the skill. Added GraphQL triggers to the skill description so it loads for GraphQL tasks.
- Corrected `references/modern-formats.md`: `safeFileFormats` also gates every GraphQL path, not just automatic generation and CP thumbnails.

## 1.0.0

- Added the `imager-x` skill, covering Imager X templating, responsive images with the Power Pack, transform parameters, named transforms, automatic generation, configuration, and transformers.
- Added `install.sh` and `uninstall.sh` for installing the skill by symlink.
