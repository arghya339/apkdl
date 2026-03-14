#!/bin/bash

# Copyright (C) 2025, Arghyadeep Mondal <github.com/arghya339>

CreateBinaryLauncherShortcuts() {
  shortcutLabel=${1}
  iconPath=${2}
  binaryPath=${3}
  Interactive=${4:-true}
  PolicyKit=${5:-false}
  Categories=${6:-Utility}
  [ $PolicyKit == true ] && polkit="pkexec " || polkit=""
  cat > "$HOME/.local/share/applications/${shortcutLabel}.desktop" <<EOL
[Desktop Entry]
Name=${shortcutLabel}
Icon=${iconPath}
Exec=${polkit}${binaryPath}
Terminal=${Interactive}
Type=Application
Categories=${Categories};
EOL
}
[ ! -f "$apkdl/apkdl.png" ] && curl -L --progress-bar -C - -o "$apkdl/apkdl.png" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/.Icon/apkdl.png"
[ ! -f "$HOME/.local/share/applications/apkdl.desktop" ] && CreateBinaryLauncherShortcuts "apkdl" "$apkdl/apkdl.png" "$HOME/.apkdl.sh"

[ -f "$apkdlJson" ] && AutoUpdatesDependencies=$(jq -r '.AutoUpdatesDependencies' "$apkdlJson" 2>/dev/null) || AutoUpdatesDependencies=true
USER_AGENT="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$crVersion Mobile Safari/537.36"

dnfUpdate() {
  dnf=${1}
  if grep -q "^$dnf" <<< "$dnfUpgradesList" 2>/dev/null; then
    echo -e "$running Upgrading $dnf package.."
    sudo dnf update "$dnf" -y >/dev/null 2>&1
  fi
}

dnfInstall() {
  dnf=${1}
  if grep -q "^$dnf" <<< "$dnfList" 2>/dev/null; then
    dnfUpdate "$dnf"
  else
    echo -e "$running Installing $dnf package.."
    sudo dnf install "$dnf" -y >/dev/null 2>&1
  fi
}

dnfRemove() {
  dnf=${1}
  dnfList=$(dnf list --installed 2>/dev/null)
  if grep -q "^$dnf" <<< "$dnfList" 2>/dev/null; then
    echo -e "$running Uninstalling $dnf package.."
    sudo dnf remove "$dnf" -y >/dev/null 2>&1
  fi
}

dependencies() {
  dnfList=$(dnf list --installed 2>/dev/null)
  dnfUpgradesList=$(dnf --refresh list --upgrades 2>/dev/null)
  dnfInstall "bash"
  dnfInstall "grep"
  dnfInstall "gawk"
  dnfInstall "sed"
  dnfInstall "curl"
  dnfInstall "aria2"
  dnfInstall "jq"
  dnfInstall "bsdtar"
  dnfInstall "pv"
  dnfInstall "protobuf-compiler"
  dnfInstall "android-tools"  # (adb, fastboot)
  dnfInstall "java-21-openjdk"
  sudo alternatives --set java /usr/lib/jvm/java-21-openjdk/bin/java
  if [ ! -f "$HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager" ]; then
    cmdlinetoolslatest=$(curl -sL https://developer.android.com/studio | grep -o "https://dl.google.com/android/repository/commandlinetools-linux-[0-9]*_latest.zip" | head -1 | awk -F'[-_]' '{print $3}')
    curl -L --progress-bar -C - -o "$HOME/Downloads/commandlinetools-linux-${cmdlinetoolslatest}_latest.zip" "https://dl.google.com/android/repository/commandlinetools-linux-${cmdlinetoolslatest}_latest.zip"
    mkdir -p ~/Android/Sdk/cmdline-tools/latest
    pv "$HOME/Downloads/commandlinetools-linux-${cmdlinetoolslatest}_latest.zip" | bsdtar -xf - -C "$HOME/Android/Sdk/cmdline-tools/latest" --strip-components 1
    rm -f "$HOME/Downloads/commandlinetools-linux-${cmdlinetoolslatest}_latest.zip"
    chmod +x ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager
    ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --version
    yes | ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --licenses
    ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager $($HOME/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --list | grep "^  build-tools;" | awk '{print $1}' | tail -1)
    grep -qxF 'export PATH="$HOME/Android/Sdk/build-tools/$(ls $HOME/Android/Sdk/build-tools | sort -V | tail -1):$PATH"' ~/.android-env || echo 'export PATH="$HOME/Android/Sdk/build-tools/$(ls $HOME/Android/Sdk/build-tools | sort -V | tail -1):$PATH"' >> ~/.android-env && source ~/.android-env
  fi
  if ! pup --version &>/dev/null; then
    if [ $(uname -m) == "x86_64" ]; then
      arch="amd64"
    elif [ $(uname -m) == "aarch64" ] || [ $(uname -m) == "arm64" ]; then
      arch="arm64"
    elif [[ $(uname -m) == i*86 ]]; then
      arch="386"
    fi
    curl -L --progress-bar -C - -o "$Download/pup_v0.4.0_linux_${arch}.zip" "https://github.com/ericchiang/pup/releases/download/v0.4.0/pup_v0.4.0_linux_${arch}.zip"
    pv "$Download/pup_v0.4.0_linux_${arch}.zip" | sudo bsdtar -xf - -C "/usr/local/bin"
    [ -x "/usr/local/bin/pup" ] || sudo chmod +x /usr/local/bin/pup
    rm -f "$Download/pup_v0.4.0_linux_${arch}.zip"
  fi
}
[ "$AutoUpdatesDependencies" == true ] && checkInternet && dependencies

aapt2=("$HOME/Android/Sdk/build-tools/"*/aapt2) && aapt2="${aapt2[-1]}"
apksigner=(~/Android/Sdk/build-tools/*/apksigner) && apksigner="${apksigner[-1]}"
keytool="/usr/bin/keytool"

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
