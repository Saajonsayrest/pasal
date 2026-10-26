#!/bin/bash

# PASAL mobile: one script for the daily Flutter jobs, same shortcut style as the other Flutter projects
# (clean, get, pods, run, analyze, test, build). Run `./setup.sh` with no argument to see the list.

set -e

B='\033[1;34m'
G='\033[0;32m'
R='\033[0;31m'
N='\033[0m'

CONFIG_FILE="${CONFIG_FILE:-config.json}"
ENV_FILE="${ENV_FILE:-.env}"
DART_DEFINES=()
ANDROID_STUDIO_RUN_CONFIG_FILE=".idea/runConfigurations/main_dart.xml"
SHARED_RUN_CONFIG_FILE=".run/main.dart.run.xml"

msg() { echo -e "${B}==>${N} $1"; }
done_msg() { echo -e "${G}✔${N} $1"; }
err() { echo -e "${R}✘${N} $1"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "$1 is not installed or not on PATH."
}

load_env_file() {
  [[ -f "$ENV_FILE" ]] || return 0
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
}

json_value() {
  ruby -rjson -e 'value = JSON.parse(File.read(ARGV[0]))[ARGV[1]]; print value unless value.nil?' "$CONFIG_FILE" "$1"
}

# API_URL and APP_ENV come from config.json, or .env, or the shell. Nothing here is a secret.
prepare_dart_defines() {
  DART_DEFINES=()
  load_env_file
  local api_url="$API_URL" app_env="$APP_ENV"
  if [[ -f "$CONFIG_FILE" ]]; then
    api_url="$(json_value API_URL)"
    app_env="$(json_value APP_ENV)"
  fi
  [[ -n "$api_url" ]] && DART_DEFINES+=("--dart-define=API_URL=$api_url")
  [[ -n "$app_env" ]] && DART_DEFINES+=("--dart-define=APP_ENV=$app_env")
  return 0
}

ensure_local_config() {
  if [[ ! -f "$CONFIG_FILE" && ! -f "$ENV_FILE" && -z "$API_URL" ]]; then
    msg "No $CONFIG_FILE found. Using the default API address (Android emulator: 10.0.2.2:8000, iOS simulator: localhost:8000)."
    msg "A real phone needs: cp config.example.json config.json  and your computer's address in API_URL."
  fi
}

clean() {
  require_cmd flutter
  msg "Cleaning..."
  flutter clean >/dev/null || err "Clean failed"
  done_msg "Cleaned"
}

get() {
  require_cmd flutter
  msg "Getting dependencies..."
  flutter pub get || err "Pub get failed"
  done_msg "Dependencies ready"
}

pods() {
  [[ "$OSTYPE" != "darwin"* ]] && return
  require_cmd pod
  require_cmd flutter
  msg "Installing pods..."
  flutter build ios --config-only "${DART_DEFINES[@]}" >/dev/null 2>&1 || true
  # macOS can lock the default TMPDIR for Ruby, so CocoaPods gets a writable one inside the project.
  POD_TMPDIR="$(pwd)/ios/.pod_tmp"
  mkdir -p "$POD_TMPDIR"
  cd ios || err "Could not enter ios directory"
  TMPDIR="$POD_TMPDIR" pod install || { cd ..; rm -rf "$POD_TMPDIR"; err "Pod install failed"; }
  cd ..
  rm -rf "$POD_TMPDIR"
  done_msg "Pods ready"
}

analyze() {
  require_cmd flutter
  msg "Analyzing..."
  flutter analyze || err "Analyze failed"
  done_msg "Analyze passed"
}

test_unit() {
  require_cmd flutter
  msg "Running tests..."
  flutter test || err "Tests failed"
  done_msg "Tests passed"
}

open_xcode() {
  [[ "$OSTYPE" == "darwin"* ]] || err "Xcode is only available on macOS."
  msg "Opening Xcode..."
  open ios/Runner.xcworkspace || err "Failed to open Xcode"
}

resolve_flutter_device() {
  local requested="$1" platform
  case "$requested" in
    android) platform="android" ;;
    ios) platform="ios" ;;
    *) printf "%s" "$requested"; return ;;
  esac
  flutter devices --machine 2>/dev/null | ruby -rjson -e '
    devices = JSON.parse(STDIN.read)
    device = devices.find { |item| item["targetPlatform"].to_s.start_with?(ARGV[0]) }
    print device["id"] if device
  ' "$platform"
}

run_default() {
  require_cmd flutter
  ensure_local_config
  prepare_dart_defines
  msg "Launching Flutter..."
  flutter run "${DART_DEFINES[@]}"
}

run_device() {
  require_cmd flutter
  ensure_local_config
  prepare_dart_defines
  local requested="$1" resolved
  resolved="$(resolve_flutter_device "$requested")"
  [[ -z "$resolved" ]] && resolved="$requested"
  msg "Launching Flutter on $requested..."
  flutter run -d "$resolved" "${DART_DEFINES[@]}"
}

require_release_signing() {
  [[ -f "android/key.properties" ]] || err "android/key.properties not found. Release builds need a signing config (never commit it)."
}

build_debug_apk() {
  prepare_dart_defines
  get
  msg "Building debug APK..."
  flutter build apk --debug "${DART_DEFINES[@]}" || err "Debug APK build failed"
  done_msg "Debug APK: build/app/outputs/flutter-apk/app-debug.apk"
}

build_release_apk() {
  require_release_signing
  prepare_dart_defines
  clean
  get
  msg "Building release APK..."
  flutter build apk --release "${DART_DEFINES[@]}" || err "Release APK build failed"
  done_msg "Release APK: build/app/outputs/flutter-apk/app-release.apk"
}

build_release_bundle() {
  require_release_signing
  prepare_dart_defines
  clean
  get
  msg "Building release App Bundle..."
  flutter build appbundle --release "${DART_DEFINES[@]}" || err "App Bundle build failed"
  done_msg "App Bundle: build/app/outputs/bundle/release/app-release.aab"
}

build_ios() {
  prepare_dart_defines
  clean
  get
  pods
  msg "Building iOS..."
  flutter build ios --release "${DART_DEFINES[@]}" || err "iOS build failed"
  done_msg "iOS build ready"
}

build_ipa() {
  prepare_dart_defines
  clean
  get
  pods
  msg "Building IPA..."
  flutter build ipa --release "${DART_DEFINES[@]}" || err "IPA build failed"
  done_msg "IPA ready in build/ios/ipa"
}

write_flutter_run_config() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'XML'
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="main.dart" type="FlutterRunConfigurationType" factoryName="Flutter">
    <option name="additionalArgs" value="--dart-define=APP_ENV=development" />
    <option name="filePath" value="$PROJECT_DIR$/lib/main.dart" />
    <method v="2" />
  </configuration>
</component>
XML
}

android_studio() {
  msg "Preparing Android Studio run config..."
  write_flutter_run_config "$ANDROID_STUDIO_RUN_CONFIG_FILE"
  write_flutter_run_config "$SHARED_RUN_CONFIG_FILE"
  done_msg "Android Studio Play is ready"
}

usage() {
  echo -e "${B}COMBINABLE SHORTCUTS:${N}"
  echo "  c    - Clean"
  echo "  g    - Pub get"
  echo "  i    - Pod install on macOS"
  echo "  r    - Flutter run"
  echo "  o    - Open Xcode"
  echo "  an   - Flutter analyze"
  echo "  t    - Flutter test"
  echo
  echo -e "${B}EXAMPLES:${N}"
  echo "  ./setup.sh cgan       - Clean, get, analyze"
  echo "  ./setup.sh cgt        - Clean, get, test"
  echo "  ./setup.sh cga        - Clean, get, run on Android"
  echo "  ./setup.sh cgios      - Clean, get, pods, run on iOS"
  echo
  echo -e "${B}STANDALONE COMMANDS:${N}"
  echo "  ./setup.sh a          - Run on Android"
  echo "  ./setup.sh ios        - Run on iOS"
  echo "  ./setup.sh x          - Pods and open Xcode"
  echo "  ./setup.sh dapk       - Build debug APK"
  echo "  ./setup.sh apk        - Build release APK (needs android/key.properties)"
  echo "  ./setup.sh aab        - Build release App Bundle (needs android/key.properties)"
  echo "  ./setup.sh bios       - Build iOS"
  echo "  ./setup.sh ipa        - Build IPA"
  echo "  ./setup.sh as         - Write Android Studio run config"
  echo "  ./setup.sh s          - Pub get and pods (first setup)"
}

if [[ -z "$1" ]]; then
  usage
  exit 0
fi

case "$1" in
  an|analyze) analyze; exit 0 ;;
  t|test) test_unit; exit 0 ;;
  as) android_studio; exit 0 ;;
  a) run_device android; exit 0 ;;
  ios) run_device ios; exit 0 ;;
  cga) clean; get; run_device android; exit 0 ;;
  cgios) clean; get; pods; run_device ios; exit 0 ;;
  x) prepare_dart_defines; pods; open_xcode; exit 0 ;;
  dapk) build_debug_apk; exit 0 ;;
  apk) build_release_apk; exit 0 ;;
  aab) build_release_bundle; exit 0 ;;
  bios) build_ios; exit 0 ;;
  ipa) build_ipa; exit 0 ;;
  s) prepare_dart_defines; get; pods; exit 0 ;;
esac

input="$1"
while [[ -n "$input" ]]; do
  if [[ "$input" == an* ]]; then
    analyze
    input="${input#an}"
  else
    char="${input:0:1}"
    case "$char" in
      c) clean ;;
      g) get ;;
      i) prepare_dart_defines; pods ;;
      r) run_default ;;
      a) run_device android ;;
      o) open_xcode ;;
      t) test_unit ;;
      *) msg "Unknown shortcut: $char" ;;
    esac
    input="${input:1}"
  fi
done
