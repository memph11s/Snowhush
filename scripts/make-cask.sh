#!/bin/zsh
# Prints the Homebrew cask for a published release: ./scripts/make-cask.sh <version> <path to Snowhush.dmg>
set -euo pipefail
version=${1:?usage: make-cask.sh <version> <dmg>}
sha=$(shasum -a 256 "${2:?usage: make-cask.sh <version> <dmg>}" | cut -d' ' -f1)
cat <<CASK
cask "snowhush" do
  version "$version"
  sha256 "$sha"

  url "https://github.com/memph11s/Snowhush/releases/download/v#{version}/Snowhush.dmg"
  name "Snowhush"
  desc "Soft snow that falls, drifts and settles on the desktop"
  homepage "https://github.com/memph11s/Snowhush"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :sonoma

  app "Snowhush.app"

  uninstall quit: "com.memph11s.Snowhush"

  zap trash: [
    "~/Library/Caches/com.memph11s.Snowhush",
    "~/Library/HTTPStorages/com.memph11s.Snowhush",
    "~/Library/HTTPStorages/com.memph11s.Snowhush.binarycookies",
    "~/Library/Preferences/com.memph11s.Snowhush.plist",
  ]
end
CASK
