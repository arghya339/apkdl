#!/bin/bash

  # --- Check if brew is installed ---
  if brew --version >/dev/null 2>&1; then
    brew update > /dev/null 2>&1
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null 2>&1
  fi
  formulaeList=$(brew list 2>/dev/null)
  outdatedFormulae=$(brew outdated 2>/dev/null)

  # --- formulae upgrade function ---
  formulaeUpdate() {
    local formulae=$1
    if echo "$outdatedFormulae" | grep -q "^$formulae" 2>/dev/null; then
      echo -e "$running Upgrading $formulae formulae.."
      brew upgrade "$formulae" > /dev/null 2>&1
    fi
  }

  # --- formulae install/update function ---
  formulaeInstall() {
    local formulae=$1
    if echo "$formulaeList" | grep -q "$formulae" 2>/dev/null; then
      formulaeUpdate "$formulae"
    else
      echo -e "$running Installing $formulae formulae.."
      brew install "$formulae" > /dev/null 2>&1
    fi
  }

  formulaeInstall "bash"  # bash update
  formulaeInstall "grep"  # grep update
  formulaeInstall "curl"  # curl update
  formulaeInstall "aria2"  # aria2 install/update
  formulaeInstall "ca-certificate"  # ca-certificate update
  formulaeInstall "jq"  # jq install/update
  formulaeInstall "pv"  # pv install/update
  formulaeInstall "pup"  # pup install/update
  formulaeInstall "protobuf"  # protoc install/update
  formulaeInstall "android-platform-tools"  # android-platform-tools install/update
  formulaeInstall "openjdk"  # java install/update
  grep -q 'export PATH="/usr/local/opt/openjdk/bin:$PATH"' ~/.zshrc 2>/dev/null || echo 'export PATH="/usr/local/opt/openjdk/bin:$PATH"' >> ~/.zshrc
  # https://github.com/aria2/aria2/issues/1920
  aria2Executing=$(aria2c -q -d "$HOME" -o aria2Executing -U "User-Agent: $USER_AGENT" -U "Referer: https://one.one.one.one/" --ca-certificate="/etc/ssl/cert.pem" --async-dns=true --async-dns-server="$cloudflareIP" "https://one.one.one.one/")
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
      buttons=("<Select>" "<Back>")
      if menu "devices" "buttons"; then
        serial="${serials[$selected]}"
      fi
    fi
    [ $deviceCount -gt 0 ] && echo -e "$info serial: $serial"
  }; getSerial

  adb -s $serial shell 'su -c "id"' &>/dev/null && shellSU=1 || shellSU=0

  aapt2=("$HOME/Library/Android/sdk/build-tools/"*/aapt2) && aapt2="${aapt2[-1]}"

  curl -sL -o "$apkdl/adbInstall.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/adbInstall.sh"
  source $apkdl/adbInstall.sh