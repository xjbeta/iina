<p align="center">
<img height="256" src="https://github.com/iina/iina/raw/master/iina/Assets.xcassets/AppIcon.appiconset/1024-1.png" />
</p>

<h1 align="center">IINA - Fork - Danmaku</h1>

<p align="center">IINA is the <b>modern</b> video player for macOS.</p>

<p align=center>
<a href="https://iina.io">Website</a> ·
<a href="https://github.com/xjbeta/iina-danmaku/releases">Releases</a> ·
<a href="https://t.me/IINAUsers">Telegram Group</a>
</p>

---

## NEW Features

- [mpv 0.33.1 Intel Only](https://github.com/mpv-player/mpv)
- Fix some bugs [#3364](https://github.com/iina/iina/issues/3364)

## Building

1. IINA Danmaku uses [Carthage](https://github.com/Carthage/Carthage) for managing the installation of third-party libraries. If you don't already have it installed, here's how you can do so:

   ### [Installing Carthage](https://github.com/Carthage/Carthage/#installing-carthage)

2. Run the following command line in project's root directory.

   `carthage update --platform macOS --use-xcframeworks --new-resolver --cache-builds`

3. Obtain the mpv libraries.

   IINA uses mpv for media playback. To build IINA, you can either fetch copies of these libraries we have already built (using the instructions below) or build them yourself by skipping to [these instructions](#building-mpv-manually).

   ### Building mpv manually

   1. Build your own copy of mpv. If you're using a package manager to manage dependencies, the steps below outline the process.

      #### With Homebrew

      Use our tap as it passes in the correct flags to mpv's configure script:

      ```console
      $ brew tap xjbeta/homebrew-mpv-iina
      $ brew install mpv-iina
      ```

   2. Copy the latest [header files from mpv](https://github.com/mpv-player/mpv/tree/master/libmpv) (\*.h) into `deps/include/mpv/`.

   3. Run `other/parse_doc.rb`. This script will fetch the latest mpv documentation and generate `MPVOption.swift`, `MPVCommand.swift` and `MPVProperty.swift`. This is only needed when updating libmpv. Note that if the API changes, the player source code may also need to be changed.

   4. Run `other/change_lib_dependencies.rb`. This script will deploy the dependent libraries into `deps/lib`. If you're using a package manager to manage dependencies, invoke it like so:

      #### With Homebrew

      ```console
      $ other/change_lib_dependencies.rb "$(brew --prefix)" "$(brew --prefix mpv-iina)/lib/libmpv.dylib"
      ```

   5. Open iina.xcodeproj in the [latest public version of Xcode](https://itunes.apple.com/us/app/xcode/id497799835). _IINA may not build if you use any other version._

   6. Remove all of references to .dylib files from the Frameworks group in the sidebar and drag all the .dylib files in `deps/lib` to that group.

   7. Drag all the .dylib files in `deps/lib` into the "Embedded Binaries" section of the iina target.

   8. Build the project.
