#!/usr/bin/env bash
# Fetches RayDesk's two build dependencies that aren't in the repo:
#  - RayNeo's Mercury SDK (sdk/mercury-release.aar), from RayNeo's developer docs
#  - Moonlight's streaming core (moonlight-core/src), from moonlight-android plus its
#    moonlight-common-c submodule; built as a library by moonlight-core/build.gradle
# Safe to rerun; existing downloads are kept.
set -euo pipefail
cd "$(dirname "$0")/.."

MOONLIGHT_TAG="v12.1"  # current Moonlight release when RayDesk was written (Feb 2026)
MERCURY_URL="https://1105412697-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2Fb2gO457cPlXbg9GrRxvn%2Fuploads%2FnP1mdfz8a0e3HKFRzBRd%2FMercuryAndroidSDK-v0.2.6-20260310143142_94a01a90.aar?alt=media&token=0e2a9744-0fdc-4f75-8087-95c4a853fe3e"
MERCURY_SHA256="5d408e2c5d80e8ae746c42abbda50012b50617005adfeb397661bec9c9be2676"

mkdir -p sdk
if [ ! -f sdk/mercury-release.aar ]; then
  echo "Downloading Mercury SDK"
  curl -fsSL --retry 3 -o sdk/mercury-release.aar "$MERCURY_URL"
fi
echo "$MERCURY_SHA256  sdk/mercury-release.aar" | sha256sum -c -

if [ ! -d moonlight-core/src/main/java ]; then
  echo "Fetching moonlight-android $MOONLIGHT_TAG"
  tmp="$(mktemp -d)"
  git clone --depth 1 --branch "$MOONLIGHT_TAG" --recurse-submodules --shallow-submodules \
    https://github.com/moonlight-stream/moonlight-android "$tmp/moonlight"
  mkdir -p moonlight-core/src/main
  cp -r "$tmp/moonlight/app/src/main/java" "$tmp/moonlight/app/src/main/res" \
    "$tmp/moonlight/app/src/main/jni" moonlight-core/src/main/
  rm -rf "$tmp"
fi

# RayDesk's Moonlight core had a factory for stream settings without Moonlight's settings screen
python3 - <<'PY2'
import pathlib
path = pathlib.Path("moonlight-core/src/main/java/com/limelight/preferences/PreferenceConfiguration.java")
source = path.read_text(encoding="utf-8")
if "createForStreaming" not in source:
    anchor = "    public static PreferenceConfiguration readPreferences(Context context) {"
    assert anchor in source, "readPreferences not found"
    factory = """    // RayDesk: settings for a stream, with Moonlight's defaults for everything else
    public static PreferenceConfiguration createForStreaming(int width, int height, int fps, int bitrate) {
        PreferenceConfiguration config = new PreferenceConfiguration();
        config.width = width;
        config.height = height;
        config.fps = fps;
        config.bitrate = bitrate;
        config.videoFormat = FormatOption.AUTO;
        config.audioConfiguration = MoonBridge.AUDIO_CONFIGURATION_STEREO;
        config.framePacing = FRAME_PACING_BALANCED;
        config.language = DEFAULT_LANGUAGE;
        config.enableSops = true;
        config.playHostAudio = false;
        return config;
    }

"""
    path.write_text(source.replace(anchor, factory + anchor), encoding="utf-8")
    print("Added PreferenceConfiguration.createForStreaming")
PY2

# Moonlight's own manifest (its launcher, activities, app settings) would merge into RayDesk's;
# RayDesk declares the Moonlight services it uses itself.
cat > moonlight-core/src/main/AndroidManifest.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" />
XML
echo "Dependencies ready"
