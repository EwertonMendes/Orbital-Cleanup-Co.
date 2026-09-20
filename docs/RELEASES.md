# Releases

The commercial target is HTML5 first. Native desktop/mobile release packages are intentionally out of initial scope.

## Version semantics

Game version and CI attempt are different concepts. Rebuilding `0.1.0` multiple times does not create `0.1.1`; GitHub run IDs identify attempts.

Official tags are created only for intentionally published releases.

## Planned provider artifacts

The release workflow (scheduled for the Release Pipeline milestone) will generate:

```text
OrbitalCleanupCo-vX.Y.Z-generic-web.zip
OrbitalCleanupCo-vX.Y.Z-crazygames.zip
OrbitalCleanupCo-vX.Y.Z-gamepix.zip
OrbitalCleanupCo-vX.Y.Z-gamemonetize.zip
release-manifest.json
SHA256SUMS.txt
```

All packages use one source tree and provider-specific build configuration.

## Planned manual workflow inputs

- `version`
- `provider`: generic, crazygames, gamepix, gamemonetize, all
- `publish_release`
- `prerelease`

Release automation must not silently bump the version.
