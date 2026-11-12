#!/bin/zsh
# Builds and publishes a release on GitHub.
# The release carries Snowhush.dmg, which the site's Download button and Sparkle both fetch, and
# appcast.xml, which the app reads from the latest release to find updates.
# Once it is published, GitHub Actions adds Snowhush-Setup.exe for Windows, whose app looks for it on the latest
# release to find updates, and the Linux packages: .github/workflows/release.yml.
# When the Homebrew tap repository exists (HOMEBREW_TAP, default memph11s/homebrew-tap), its cask follows along.
#
# Usage: ./release.sh <version> [notes]
# Needs: the Sparkle EdDSA key in the login keychain and gh signed in.
# With a "Developer ID Application" identity and a notarytool keychain profile (NOTARY_PROFILE, default "snowhush")
# the app is signed and notarized; without them it is signed ad hoc, and macOS asks to confirm its first launch.
set -euo pipefail
cd "$(dirname "$0")"

version=${1:?usage: ./release.sh <version> [notes]}
notes=${2:-"Snowhush $version"}
repository=memph11s/Snowhush
profile=${NOTARY_PROFILE:-snowhush}
sparkle_version=2.10.0
dmgbuild_version=1.6.7
tools=.build/sparkle-tools
dmgbuild=.build/dmgbuild/bin/dmgbuild
plist=Resources/Info.plist

export IDENTITY=${IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ { print $2; exit }')}
[[ -z "$(git status --porcelain)" ]] || { echo "Commit or stash your changes first." >&2; exit 1; }
if [[ -n "$IDENTITY" ]]; then
    xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1 \
        || { echo "No notarytool profile \"$profile\". Create it with: xcrun notarytool store-credentials $profile" >&2; exit 1; }
else
    echo "No Developer ID Application identity: the app is signed ad hoc and not notarized."
fi

if [[ ! -x "$dmgbuild" ]]; then
    # dmgbuild needs Python 3.10 or newer; the one macOS ships is older, so a Homebrew one is preferred.
    python=python3
    for candidate in /opt/homebrew/bin/python3 /usr/local/bin/python3 python3.14 python3.13 python3.12 python3.11 python3.10; do
        if command -v "$candidate" >/dev/null && "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then
            python=$candidate
            break
        fi
    done
    rm -rf .build/dmgbuild
    "$python" -m venv .build/dmgbuild
    .build/dmgbuild/bin/pip install -q "dmgbuild==$dmgbuild_version"
fi
if [[ ! -x "$tools/bin/generate_appcast" ]]; then
    mkdir -p "$tools"
    curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$sparkle_version/Sparkle-$sparkle_version.tar.xz" | tar -xJ -C "$tools"
fi

# Sparkle orders updates by CFBundleVersion, so every release gets a higher build number.
current=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
bumped=()
if [[ "$current" != "$version" ]]; then
    build=$((build + 1))
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" -c "Set :CFBundleVersion $build" "$plist"
    bumped+=("$plist")
fi
cargo_toml=windows/Cargo.toml
if [[ "$(sed -n 's/^version = "\(.*\)"$/\1/p' "$cargo_toml" | head -1)" != "$version" ]]; then
    sed -i '' "1,/^version = /s/^version = \".*\"/version = \"$version\"/" "$cargo_toml"
    perl -0pi -e "s/(name = \"snowhush\"\nversion = )\"[^\"]*\"/\${1}\"$version\"/" windows/Cargo.lock
    bumped+=("$cargo_toml" windows/Cargo.lock)
fi
if [[ "$(sed -n 's/^version = "\(.*\)"$/\1/p' linux/Cargo.toml | head -1)" != "$version" ]]; then
    sed -i '' "1,/^version = /s/^version = \".*\"/version = \"$version\"/" linux/Cargo.toml
    # The Linux app's dependencies needn't be on this Mac, so its lockfile is edited rather than resolved again.
    perl -0pi -e "s/(name = \"snowhush\"\nversion = )\"[^\"]*\"/\${1}\"$version\"/" linux/Cargo.lock
    sed -i '' "s/^pkgver=.*/pkgver=$version/" linux/packaging/PKGBUILD
    bumped+=(linux/Cargo.toml linux/Cargo.lock linux/packaging/PKGBUILD)
fi
(( ${#bumped} )) && git commit -qm "chore: release v$version" "${bumped[@]}"

./build.sh
app=build/Snowhush.app
dist=dist
rm -rf "$dist"
mkdir -p "$dist/appcast"

notarize() {
    xcrun notarytool submit "$1" --keychain-profile "$profile" --wait
}

if [[ -n "$IDENTITY" ]]; then
    echo "Notarizing the app…"
    ditto -c -k --keepParent "$app" "$dist/Snowhush.zip"
    notarize "$dist/Snowhush.zip"
    xcrun stapler staple "$app"
    rm "$dist/Snowhush.zip"
fi

echo "Packing the disk image…"
artwork=$(mktemp -d)
swift scripts/make-dmg-background.swift "$artwork/background.png" 1 >/dev/null
swift scripts/make-dmg-background.swift "$artwork/background@2x.png" 2 >/dev/null
tiffutil -cathidpicheck "$artwork/background.png" "$artwork/background@2x.png" -out "$artwork/background.tiff" 2>/dev/null
"$dmgbuild" -s scripts/dmg-settings.py -D app="$app" -D background="$artwork/background.tiff" Snowhush "$dist/Snowhush.dmg" 2>/dev/null
rm -rf "$artwork"
if [[ -n "$IDENTITY" ]]; then
    codesign --force --timestamp --sign "$IDENTITY" "$dist/Snowhush.dmg"
    notarize "$dist/Snowhush.dmg"
    xcrun stapler staple "$dist/Snowhush.dmg"
fi

echo "Writing the appcast…"
cp "$dist/Snowhush.dmg" "$dist/appcast/Snowhush.dmg"
print -r -- "<p>$notes</p>" > "$dist/appcast/Snowhush.html"
"$tools/bin/generate_appcast" \
    --download-url-prefix "https://github.com/$repository/releases/download/v$version/" \
    --embed-release-notes \
    --link "https://github.com/$repository" \
    "$dist/appcast"

echo "Publishing v$version…"
git push -q origin HEAD
# The tag goes on the commit just built, whichever branch it is on.
gh release create "v$version" "$dist/Snowhush.dmg" "$dist/appcast/appcast.xml" \
    --repo "$repository" --target "$(git rev-parse HEAD)" --title "Snowhush $version" --notes "$notes"
echo "Released https://github.com/$repository/releases/tag/v$version"
echo "GitHub Actions is adding the Windows installer and the Linux packages; once they are there, linux/packaging/aur/update.sh $version brings the AUR package along."

tap_repository=${HOMEBREW_TAP:-memph11s/homebrew-tap}
if gh repo view "$tap_repository" >/dev/null 2>&1; then
    echo "Updating the Homebrew cask…"
    tap=$(mktemp -d)
    gh repo clone "$tap_repository" "$tap" -- -q
    mkdir -p "$tap/Casks"
    scripts/make-cask.sh "$version" "$dist/Snowhush.dmg" > "$tap/Casks/snowhush.rb"
    git -C "$tap" add Casks/snowhush.rb
    git -C "$tap" commit -qm "snowhush $version"
    git -C "$tap" push -q
    rm -rf "$tap"
fi
