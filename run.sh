#!/bin/bash
set -e

cd ~/vcs/MeetingBar/

xcodebuild -scheme MeetingBar -configuration Debug \
  -derivedDataPath ./DerivedData build

exec ./DerivedData/Build/Products/Debug/MeetingBar.app/Contents/MacOS/MeetingBar
