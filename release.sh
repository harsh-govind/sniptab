#!/bin/zsh
# Builds SnipTab.app and packages it as dist/SnipTab-<version>.dmg (drag-to-Applications installer).
set -e
cd "$(dirname "$0")"
export VERSION=${1:-1.0}
./build.sh
rm -rf dist
mkdir -p dist/stage
cp -R SnipTab.app dist/stage/
ln -s /Applications dist/stage/Applications
hdiutil create -quiet -volname SnipTab -srcfolder dist/stage -ov -format UDZO "dist/SnipTab-$VERSION.dmg"
rm -rf dist/stage
echo "Created $(pwd)/dist/SnipTab-$VERSION.dmg"
