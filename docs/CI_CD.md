# CI/CD

## Goal

A contributor should be able to implement, build, smoke-test and preview the Web game using GitHub without a local Godot/Node setup.

## Web workflow

`.github/workflows/web.yml` runs for pull requests and pushes to `master` or `main`, plus manual dispatch. Production deployment is restricted to the repository's actual default branch.

Pipeline:

1. resolve the exact revision under test;
2. checkout that SHA;
3. run fast repository validation;
4. restore/download pinned Godot 4.7.2 and Web templates;
5. run headless import;
6. export release Web build;
7. inject build metadata and the debug provider;
8. upload `occ-web-build`;
9. serve the artifact locally on the runner;
10. run Chrome/Playwright smoke;
11. capture desktop, landscape-mobile and portrait-mobile screenshots;
12. compose GitHub Pages;
13. publish/update a single PR preview comment.

## Build contract

Web export is single-threaded:

- GL Compatibility renderer;
- thread support disabled;
- extension support disabled;
- PWA disabled;
- adaptive canvas resizing;
- Web VRAM texture compression copies disabled initially (no ETC2/ASTC requirement); revisit only if measured asset/runtime needs justify it.

This intentionally avoids SharedArrayBuffer/cross-origin-isolation requirements that often conflict with publisher SDKs and embedded portal contexts.

## Preview URLs

Production is at the Pages root. Each open PR is preserved under:

`/pr-<number>/`

The composition script rebuilds one Pages artifact containing production plus every recoverable open-PR artifact, so deploying PR #42 does not erase PR #41.

For the very first bootstrap PR, if the default branch has never produced a Web artifact, the root intentionally displays a "production not published yet" page while the PR remains available at its preview path.

## PR comment

The workflow searches for the marker:

`<!-- orbital-cleanup-preview -->`

and updates the same comment on subsequent pushes instead of spamming the PR conversation.

## QA contract

Browser smoke checks:

- page loads;
- visible canvas exists;
- `[OCC] READY` is emitted;
- provider is `debug`;
- build metadata exists;
- no page/critical console error;
- screenshots succeed at target viewports.

Gameplay-specific smoke will grow only when a feature needs a stable, high-value check. Avoid brittle pixel-perfect regression suites.
