fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac screenshots

```sh
[bundle exec] fastlane mac screenshots
```

Take screenshots for App Store

### mac build

```sh
[bundle exec] fastlane mac build
```

Build and sign the app

### mac beta

```sh
[bundle exec] fastlane mac beta
```

Upload to TestFlight

### mac release

```sh
[bundle exec] fastlane mac release
```

Upload a new build to App Store Connect

### mac metadata

```sh
[bundle exec] fastlane mac metadata
```

Upload metadata and screenshots to App Store Connect

### mac download_metadata

```sh
[bundle exec] fastlane mac download_metadata
```

Download metadata from App Store Connect

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
