# CI/CD

## Goal

A contributor should be able to implement, build, structurally validate, smoke-test and preview the Web game using GitHub without a local Godot/Node setup.

## Web workflow

`.github/workflows/web.yml` runs for pull requests and pushes to `master` or `main`, plus manual dispatch. Production deployment is restricted to the repository's actual default branch.

Pipeline:

1. resolve the exact revision under test;
2. checkout that SHA;
3. run repository, localization, provider-boundary and asset-provenance validation;
4. restore/download pinned Godot 4.7.2 and Web templates;
5. run headless import;
6. execute `tools/validate_core_contracts.gd` in real Godot;
7. export the release Web build;
8. inject build metadata and the debug provider;
9. upload `occ-web-build`;
10. serve that exact artifact on the runner;
11. run Chrome/Playwright smoke;
12. capture desktop, landscape-mobile and portrait-mobile screenshots;
13. compose GitHub Pages;
14. publish/update the single PR preview comment.

## Contract validation

`tools/validate_core_contracts.gd` instantiates committed scenes and asserts required runtime structure, including the service container and important Operations-screen contracts.

These are structural assertions, not string-only lint checks. A renamed/removed required service or UI contract must fail CI.

## Build contract

Web export is single-threaded:

- GL Compatibility renderer;
- thread support disabled;
- extension support disabled;
- PWA disabled;
- adaptive canvas resizing;
- Web VRAM texture compression copies disabled initially.

This intentionally avoids SharedArrayBuffer/cross-origin-isolation requirements that often conflict with publisher SDKs and embedded portal contexts.

## Preview URLs

Production is at the Pages root. Each open PR is preserved under:

`/pr-<number>/`

The composition script rebuilds one Pages artifact containing production plus recoverable open-PR artifacts, so deploying a new preview does not intentionally erase another open preview.

## PR comment

The workflow searches for `<!-- orbital-cleanup-preview -->` and updates the same comment on subsequent pushes.

## QA contract

Browser smoke checks:

- page loads;
- visible canvas exists;
- `[OCC] READY` is emitted;
- provider is `debug`;
- build metadata exists;
- no page/critical console or failed-resource error;
- screenshots succeed at target viewports.

Visual changes are additionally judged by the generated screenshots and playable preview. Avoid brittle pixel-perfect regression suites.
