#!/bin/bash

# Copyright (C) 2025, Arghyadeep Mondal <github.com/arghya339>

CreateAppIcon() {
  source="$apkdl/apkdl.png"
  [ ! -f "$source" ] && curl -L --progress-bar -C - -o "$source" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/.Icon/apkdl.png"  # https://gitlab.com/AuroraOSS/AuroraStore/-/raw/master/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png
  PointSizeNames=("16x16" "16x16@2x" "32x32" "32x32@2x" "128x128" "128x128@2x" "256x256" "256x256@2x" "512x512" "512x512@2x")
  PixelResolutions=("16" "32" "32" "64" "128" "256" "256" "512" "512" "1024")
  iconset="$apkdl/apkdl.iconset"
  mkdir -p $iconset
  for ((i=0; i<${#PointSizeNames[@]}; i++)); do
    [ ${PixelResolutions[i]} -eq 1024 ] && cp $source $iconset/icon_${PointSizeNames[i]}.png || sips -z ${PixelResolutions[i]} ${PixelResolutions[i]} $source --out $iconset/icon_${PointSizeNames[i]}.png
  done
  iconutil -c icns $iconset -o $apkdl/apkdl.icns && rm -rf $iconset
}
CreateScriptLaunchpadShortcuts() {
  shortcutLabel=${1}
  scriptPath=${2}
  Interactive=${3:-true}
  [ ! -f "$apkdl/apkdl.icns" ] && CreateAppIcon
  mkdir -p "/Applications/${shortcutLabel}.app/Contents/Resources"
  cp "$apkdl/apkdl.icns" "/Applications/${shortcutLabel}.app/Contents/Resources/apkdl.icns"
  mkdir -p "/Applications/${shortcutLabel}.app/Contents/MacOS"
  [ $Interactive == true ] && echo -e "#!/bin/bash\nosascript -e 'tell application \"Terminal\" to do script \"bash ${scriptPath}\"'\nosascript -e 'tell application \"System Events\" to set frontmost of process \"Terminal\" to true'" > "/Applications/${shortcutLabel}.app/Contents/MacOS/launcher" || echo -e "#!/bin/bash\nexport PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"\nsource ${scriptPath}" > "/Applications/${shortcutLabel}.app/Contents/MacOS/launcher"
  chmod +x "/Applications/${shortcutLabel}.app/Contents/MacOS/launcher"
  cat > "/Applications/${shortcutLabel}.app/Contents/Info.plist" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIconFile</key>
    <string>apkdl</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
EOL
  touch /Applications/${shortcutLabel}.app
  killall Dock
}
[ ! -d "/Applications/apkdl.app/" ] && CreateScriptLaunchpadShortcuts "apkdl" "$HOME/.apkdl.sh"

[ -f "$apkdlJson" ] && AutoUpdatesDependencies=$(jq -r '.AutoUpdatesDependencies' "$apkdlJson" 2>/dev/null) || AutoUpdatesDependencies=true
[ $(uname -m) == "x86_64" ] && Arch=amd64 || Arch=arm64
USER_AGENT="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$crVersion Mobile Safari/537.36"

formulaeUpdate() {
  formulae=$1
  if echo "$outdatedFormulae" | grep -q "^$formulae" 2>/dev/null; then
    echo -e "$running Upgrading $formulae formulae.."
    brew upgrade "$formulae" > /dev/null 2>&1
  fi
}

formulaeInstall() {
  formulae=$1
  if echo "$formulaeList" | grep -q "$formulae" 2>/dev/null; then
    formulaeUpdate "$formulae"
  else
    echo -e "$running Installing $formulae formulae.."
    brew install "$formulae" > /dev/null 2>&1
  fi
}

formulaeUninstall() {
  formulaeList=$(brew list 2>/dev/null)
  formulae=$1
  if echo "$formulaeList" | grep -q "$formulae" 2>/dev/null; then
    echo -e "$running Uninstalling $formulae formulae.."
    brew uninstall "$formulae" > /dev/null 2>&1
  fi
}

dependencies() {
  brew --version >/dev/null 2>&1 && brew update > /dev/null 2>&1 || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  formulaeList=$(brew list 2>/dev/null)
  outdatedFormulae=$(brew outdated 2>/dev/null)

  formulaeInstall "bash"  # bash update
  formulaeInstall "grep"  # grep update
  formulaeInstall "curl"  # curl update
  formulaeInstall "aria2"  # aria2 install/update
  formulaeInstall "ca-certificate"  # ca-certificate update
  formulaeInstall "jq"  # jq install/update
  formulaeInstall "pv"  # pv install/update
  if [ "$(pup --version 2>/dev/null)" != "0.4.0" ]; then
    pkgInstall "go"
    echo -e "$running Installing pup utility.."
    go install github.com/ericchiang/pup@latest &>/dev/null
    sudo cp ~/go/bin/pup /usr/local/bin/pup
  fi
  formulaeInstall "protobuf"  # protoc install/update
  formulaeInstall "android-platform-tools"  # android-platform-tools install/update
  formulaeInstall "openjdk"  # java install/update
  grep -q 'export PATH="/usr/local/opt/openjdk/bin:$PATH"' ~/.zshrc 2>/dev/null || echo 'export PATH="/usr/local/opt/openjdk/bin:$PATH"' >> ~/.zshrc
  # https://github.com/aria2/aria2/issues/1920
  aria2Executing=$(aria2c -q -d "$HOME" -o aria2Executing -U "User-Agent: $USER_AGENT" --header="Referer: https://one.one.one.one/" --ca-certificate="/etc/ssl/cert.pem" --async-dns=true --async-dns-server="$cloudflareIP" "https://one.one.one.one/")
  if echo "$aria2Executing" | grep -q "--async-dns=true" 2>/dev/null; then
    curl -L --progress-bar -C - -o $HOME/Downloads/aria2c-macos-$Arch.tar https://github.com/tofuliang/aria2/releases/download/20240919/aria2c-macos-$Arch.tar
    pv "$HOME/Downloads/aria2c-macos-$Arch.tar" | tar -xf - -C "$HOME/Downloads" && rm -f "$HOME/Downloads/aria2c-macos-$Arch.tar"
    sudo mv $HOME/Downloads/aria2c /usr/local/bin/aria2c
    if aria2c -v &>/dev/null; then
      aria2c -v | head -1 | awk '{print $3}'
    else
      sudo xattr -d com.apple.quarantine /usr/local/bin/aria2c && aria2c -v | head -1 | awk '{print $3}'
    fi
    rm -f ~/aria2Executing
  else
    rm -f ~/aria2Executing
  fi
}
[ "$AutoUpdatesDependencies" == true ] && checkInternet && dependencies

aapt2=("$HOME/Library/Android/sdk/build-tools/"*/aapt2) && aapt2="${aapt2[-1]}"
apksigner=("$HOME/Library/Android/sdk/build-tools/"*/apksigner) && apksigner="${apksigner[-1]}"
keytools=(/usr/local/opt/openjdk*/bin/keytool); keytool="${keytools[0]}"

getSerial() {
  deviceCount=$(adb devices | grep -c "device$")
  if [ $deviceCount -eq 0 ]; then
    serial=
  elif [ $deviceCount -eq 1 ]; then
    serial=$(adb devices | grep "device$" | awk '{print $1}')
  elif [ $deviceCount -gt 1 ]; then
    serials=($(adb devices | grep "device$" | awk '{print $1}'))
    devices=()
    for i in "${!serials[@]}"; do
      serial="${serials[i]}"
      model=$(adb -s $serial shell getprop ro.product.model)
      devices+=("$model ($serial)")
    done
    menu devices bButtons && serial="${serials[$selected]}"
  fi
  [ $deviceCount -gt 0 ] && echo -e "$info serial: $serial"
}; getSerial

adb -s $serial shell 'su -c "id"' &>/dev/null && su=true || su=false

if [ -n "$serial" ]; then
  cpuAbi=$(adb -s $serial shell getprop ro.product.cpu.abi)
  locale=$(adb -s $serial shell getprop persist.sys.locale | cut -d'-' -f1)
  [ -z $locale ] && locale=$(adb -s $serial shell getprop ro.product.locale | cut -d'-' -f1)
  density=$(adb -s $serial shell getprop ro.sf.lcd_density)
  config "ABI" "$cpuAbi"
  config "LOCALE" "$locale"
  config "DENSITY" "$density"
fi