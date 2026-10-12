#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
sources=(AppLanguage AlarmRecord AlarmActions AlarmEditOperation AlarmSkipPlan)
files=()
for source in "${sources[@]}"; do files+=("$repo_dir/JustAlarm/$source.swift"); done
for test in "$repo_dir"/Tests/*Tests.swift; do
    name="$(basename "$test" .swift)"
    bundle="$test_dir/$name.app"
    mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
    cp -R "$repo_dir/JustAlarm/en.lproj" "$repo_dir/JustAlarm/ko.lproj" "$bundle/Contents/Resources/"
    cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>$name</string><key>CFBundleIdentifier</key><string>local.justalarm.$name</string><key>CFBundleDevelopmentRegion</key><string>ko</string></dict></plist>
PLIST
    swiftc -module-cache-path "$test_dir/cache" "${files[@]}" "$test" -o "$bundle/Contents/MacOS/$name"
    "$bundle/Contents/MacOS/$name"
done
