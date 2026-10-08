#!/bin/sh
# Runs the engine's tests (swift test), naming the SDK, which xcrun can't
# find by itself on this Mac (BUILDING.md).
set -eu
cd "$(dirname "$0")/.."
SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export SDKROOT
swift test "$@"
