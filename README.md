# Imager X skill for Claude Code

A Claude Code [skill](https://docs.claude.com/en/docs/claude-code/skills) for
[Imager X](https://imager-x.spacecat.ninja/), the image transform, optimization and
manipulation plugin for Craft CMS.

It teaches Claude how Imager X actually works — the quick transform syntax, named transforms,
automatic generation, and how to build responsive image markup with the Power Pack — so you
get correct transforms and correct `<picture>` markup instead of plausible-looking guesses.

Written from the plugin source. Verified against **Imager X 6.1.0** and **Power Pack 1.1.3**.

## Install

As a plugin, with updates through the marketplace:

```
/plugin marketplace add spacecatninja/imager-x-skills
/plugin install imager-x@imager-x-skills
```

Claude Code keeps auto-update off for third-party marketplaces, so pull new versions with
`/plugin marketplace update imager-x-skills`, or turn auto-update on under `/plugin` →
Marketplaces.

Or clone and symlink into `~/.claude/skills/`:

```bash
git clone https://github.com/spacecatninja/imager-x-skills.git
cd imager-x-skills
bash install.sh
```

Or just copy the skill folder — into `~/.claude/skills/` for every project, or a project's
`.claude/skills/` to commit it with the repo:

```bash
cp -R skills/imager-x ~/.claude/skills/
```

Start a new Claude Code session afterwards.

`uninstall.sh` removes symlinks created by `install.sh`, leaving anything else alone.

## Using it

Nothing to invoke. Claude loads the skill when a task involves Imager X — writing a transform,
building responsive markup, editing `config/imager-x.php`, or debugging why a srcset is empty.
Asking directly works too:

> Make the hero image on the homepage responsive, with AVIF and a JPEG fallback

> Why is this srcset empty? `craft.imagerx.transformImage(image, ['400', '1200'])`

> Set up automatic generation for the images volume

> Will `cropZoom` work if we switch to the AWS Serverless transformer?

## What it covers

| Reference | Scope |
|-----------|-------|
| `responsive-images.md` | The Power Pack in full — `pppicture`, `ppimg`, `ppplaceholder`, `pptransform`, source ordering, `sizes`, LCP and CLS, placeholders, lazysizes, SVG and animated GIF handling, every config setting |
| `transform-syntax.md` | `transformImage()`, the quick syntax parsing rules, full syntax, `fillTransforms`, `|srcset`, chaining, external images |
| `transform-parameters.md` | Every transform key, resize modes, watermarks, effects, and the normalization rules that silently drop parameters |
| `named-transforms.md` | `imager-x-transforms.php`, merge precedence, nesting, closures, the filename-hash exclusion trap |
| `auto-generate.md` | `imager-x-generate.php`, field handle syntax, event gating, queue behaviour, console commands |
| `configuration.md` | `imager-x.php` with real defaults, caching, filenames, optimizers, storages, multi-environment |
| `transformers.md` | Per-transformer feature matrix, and what each transformer silently drops |
| `modern-formats.md` | WebP, AVIF and JPEG XL — encoding them and delivering them without breaking your cache |
| `templating-api.md` | The complete `craft.imagerx` surface, transformed-image models, placeholders, colour utilities |
| `recipes.md` | Copy-paste patterns for heroes, card grids, art direction, ratio boxes, SVG logos, Matrix images |

The skill body itself is a short router plus a list of cross-cutting pitfalls; reference files
load only when the task needs them.

### Out of scope

The PHP extension API (custom transformers, effects, optimizers, storages, adapters), GraphQL,
and the PDF/Video/DALL·E adapters. The skill says so rather than guessing, and points at the
documentation.

## Editions

Imager X comes in Lite ($49) and Pro ($99). The skill knows which features are Pro-only —
every transformer except `craft`, automatic generation, the generate console command, external
storages, GraphQL — and flags it rather than writing config that will never fire.

## Versioning

- **Patch** — accuracy fixes to existing content.
- **Minor** — new reference files or substantial new coverage.
- **Major** — a new Imager X major version, or a restructure.

`.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` must agree with the git tag;
CI checks this on tag push.

## Contributing

Corrections are welcome, particularly anywhere the skill contradicts the plugin. Every claim
should be traceable to plugin source rather than to documentation, since published defaults
occasionally drift from the code. Please note the source file and line in the pull request.

## Links

- Imager X documentation: https://imager-x.spacecat.ninja/
- Imager X: https://github.com/spacecatninja/craft-imager-x
- Power Pack: https://github.com/spacecatninja/craft-imager-x-power-pack
- Plugin store: https://plugins.craftcms.com/imager-x

## License

MIT. Imager X itself is a commercial plugin.
