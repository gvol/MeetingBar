#!/bin/bash
set -e

# Log in to apple developer account
# Accept the new PLA (there is one every few days it seems)
# Reopen xcode
# It will complain to register the device -- do so
# It works... hopefully

cd ~/vcs/MeetingBar/

xcodebuild -scheme MeetingBar -configuration Debug \
  -derivedDataPath ./DerivedData \
  -allowProvisioningUpdates build

exec ./DerivedData/Build/Products/Debug/MeetingBar.app/Contents/MacOS/MeetingBar
