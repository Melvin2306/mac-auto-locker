#!/usr/bin/env bash
# Builds WordLock, installs it to /Applications and launches it.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build.sh
pkill -x WordLock 2>/dev/null || true
rm -rf /Applications/WordLock.app
cp -R build/WordLock.app /Applications/
# An ad-hoc signed rebuild has a new signature, so macOS treats it as a different app and the old
# Input Monitoring grant no longer applies. Clear it so the toggle in System Settings is accurate.
if [[ "${SIGN_IDENTITY:--}" == "-" ]]; then
  tccutil reset ListenEvent dev.wordlock.WordLock >/dev/null 2>&1 || true
fi
open /Applications/WordLock.app
echo "Installed /Applications/WordLock.app"
