# Building MultiCoding

```sh
./build.sh
open /Applications/MultiCoding.app
```

`build.sh` builds a release binary, assembles `build/MultiCoding.app`, and installs it at `/Applications/MultiCoding.app`. It signs with the first "Apple Development" certificate in your keychain, or ad hoc if there is none.

```sh
./build.sh --beta
```

builds and installs **MultiCoding Beta** next to the release app instead, with its own bundle id, preferences and workspace. On its first launch it copies the release app's settings.

```sh
./build.sh --dist
```

builds a distributable release signed with a Developer ID certificate and the hardened runtime, then packages it as `build/MultiCoding-<version>.dmg` and `.zip`. Notarization is enabled by default and requires credentials stored with `xcrun notarytool store-credentials multicoding-notary`; `--no-notarize` skips notarization. The script does not publish releases or configure an update feed.

## Tests

```sh
swift test
```

The opt-in Codex integration checks are described in [codex.md](codex.md#checks).
