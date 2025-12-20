#!/usr/bin/bash

Android=$(getprop ro.build.version.release | cut -d. -f1)

# Install final apk
apkInstall() {
  local outputAPK=${1}
  local activity=$2  # for non-rooted user to launch app after installtion
  iCmd() {
    icmd=${1}
    if [ $su -eq 1 ]; then
      su -c "$icmd"
    elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
      ~/rish -c "$icmd"
    elif "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
      ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "$icmd"
    fi
  }
  local outputFileName=$(basename "$outputAPK")
  output_dir=$(dirname "$outputAPK")
  wo_ext="${outputAPK%.*}"
  apk_ext="${outputFileName##*.}"
  if [ "$apk_ext" == "apk" ]; then
    isAPK=1; isAPKS=0; isXAPK=0
  elif [ "$apk_ext" == "apks" ]; then
    isAPKS=1; isAPK=0; isXAPK=0
  elif [ "$apk_ext" == "xapk" ]; then
    isXAPK=1; isAPK=0; isAPKS=0
  fi
  isGame=0
  if [ $isAPK -eq 0 ]; then
    bsdtar -tf "$outputAPK" --include='*.obb' >/dev/null 2>&1 && isGame=1 || isGame=0  # Check if APK contains OBB files (common in games)
    mkdir -p "$wo_ext"
    pv "$outputAPK" | bsdtar -xf - -C "$wo_ext"
    if [ $isXAPK -eq 1 ]; then
      pkgName=$(cat "$wo_ext/manifest.json" | jq -r '.package_name')
      appName=$(cat "$wo_ext/manifest.json" | jq -r '.name')
      versionCode=$(cat "$wo_ext/manifest.json" | jq -r '.version_code')
      outputAPK="$wo_ext/$pkgName.apk"  # base.apk path
      outputFileName="$pkgName.apk"
    fi
    if [ $isGame -eq 1 ]; then
      obbInstallPath=$(cat "$wo_ext/manifest.json" | jq -r '.expansions.[].install_path')  # Android/obb/com.example.package/main.1234.com.example.obb
      outputOBB="$wo_ext/$obbInstallPath"  # obb file path
    else
      apks=($(bsdtar -tf "$outputAPK" --include='*.apk' | awk -F/ '{print $NF}' | sort -u))
      if [ $isAPKS -eq 1 ]; then
        outputAPK="$wo_ext/splits/base-master.apk"
      fi
    fi
  fi
  app_info=$($HOME/aapt2 dump badging "$outputAPK" 2>/dev/null)
  pkgName=$(awk -F"'" '/package/ {print $2}' <<< "$app_info" | head -1)
  appName=$(awk -F"'" '/application-label:/ {print $2}' <<< "$app_info")
  if [ $su -eq 1 ]; then
    [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=1; } || writeSELinux=0
  fi
  if [ $su -eq 1 ] || "$HOME/rish" -c "id" >/dev/null 2>&1 || "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
    iCmdOut=$(iCmd "pm resolve-activity --brief $pkgName")
    local activityClass=$(tail -n 1 <<< "$iCmdOut") && unset iCmdOut
    [ $DisablePlayProtect -eq 1 ] && iCmd "settings put global package_verifier_user_consent -1"  # Disabled Play Protect
    if [ $DisableVerifyAdbInstalls -eq 1 ]; then
      [ $Android -le 10 ] && iCmd "settings put global package_verifier_enable 0" || iCmd "settings put global verifier_verify_adb_installs 0"  # Disable Verify Adb Installs
    fi
    if [ $isAPKS -eq 1 ] || { [ $isXAPK -eq 1 ] && [ $isGame -eq 0 ]; }; then
      iCmdOut=$(iCmd "pm install-create ${cmd}") && unset iCmdOut
      sessionId=$(grep -oE '[0-9]+' <<< "$iCmdOut")
      [ -z $sessionId ] && { iCmdOut=$(iCmd "dumpsys package installer"); sessionId=$(grep "Active Session" <<< "$iCmdOut" | grep -oE '[0-9]+'); unset iCmdOut; }
      if [ $cpuAbi == "arm64-v8a" ]; then arch="arm64_v8a"; elif [ $cpuAbi == "armeabi-v7a" ]; then arch="armeabi_v7a"; else arch="$cpuAbi"; fi
      for apk in "${apks[@]}"; do
        case "$apk" in
          base-master.apk|"$pkgName".apk|base.apk)
            split_identifier="base.apk"
            ;;
          base-"$arch".apk|config."$arch".apk|split_config."$arch".apk)
            split_identifier="config.arch"
            ;;
          base-*dpi.apk|config.*dpi.apk|split_config.*dpi.apk)
            split_identifier="config.dpi"
            ;;
          *)
            case $apk in
              base-[a-z][a-z].apk) split_identifier="config.$(awk -F'-' '{print $2}' <<< "$apk")" ;;  # apks
              config.[a-z][a-z].apk) split_identifier="config.$(awk -F'.' '{print $2}' <<< "$apk")" ;;  # xapk
              split_config.[a-z][a-z].apk) split_identifier="config.$(awk -F'.' '{print $2}' <<< "$apk")" ;;  # apkm
            esac
            ;;
        esac
        iCmd "cp \"$wo_ext/splits/$apk\" \"/data/local/tmp/\""
        iCmd "pm install-write $sessionId $split_identifier \"/data/local/tmp/$apk\""
        iCmd "rm -f \"/data/local/tmp/$apk\""
      done
      if ! output=$(iCmd "pm install-commit $sessionId" 2>&1); then
        echo "$output"
        iCmd "pm install-abandon $sessionId" >/dev/null 2>&1
      else
        echo "$output"
      fi
      rm -rf "$wo_ext"
      outputAPK="$wo_ext.$apk_ext"
    else
      iCmd "cp '$outputAPK' '/data/local/tmp/$outputFileName'"
      output=$(iCmd "pm install ${cmd} \"/data/local/tmp/${outputFileName}\"" 2>&1); echo "$output"
      if [[ "$output" == *"signatures do not match"* ]]; then
        echo -e "$notice The current app has a different signature than the patched one!"
        buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to uninstall the current app and proceed?" "buttons" "1" && response=Yes || response=No
        if [ "$response" == "Yes" ]; then
          iCmd "pm uninstall $pkgName"
          output=$(iCmd "pm install ${cmd} \"/data/local/tmp/${outputFileName}\"" 2>&1); echo "$output"
        fi
      fi
      iCmd "rm -f '/data/local/tmp/$outputFileName'"
      if [ $isGame -eq 1 ]; then
        iCmd "mkdir -p /sdcard/Android/obb/$pkgName"
        iCmd "cp \"$outputOBB\" /sdcard/$obbInstallPath" && rm -rf "$wo_ext"
        outputAPK="$wo_ext.$apk_ext"
      fi
    fi
    [ $DisablePlayProtect -eq 1 ] && iCmd "settings put global package_verifier_user_consent 1"  # Enabled Play Protect
    if [ $DisableVerifyAdbInstalls -eq 1 ]; then
      [ $Android -le 10 ] && iCmd "settings put global package_verifier_enable 1" || iCmd "settings put global verifier_verify_adb_installs 1"  # Enabled Verify Adb Installs
    fi
    if [[ $output == *"Downgrade detected"* ]] && [ $KeepsData -eq 1 ]; then
      echo -e "${Green}$appName uninstall successfully with keeps app data.${Reset}\n${Yellow}Don't forget to restart apkdl after reboot!${Reset}"
      iCmd "cmd package uninstall -k $pkgName"
      cp "$outputAPK" "$POST_INSTALL"
      echo; read -p "Press Enter to reboot..."
      iCmd "reboot"
    fi
    am start -n "$activityClass" &> /dev/null  # launch app after install
    if [ $? != 0 ]; then
      iCmd "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
    fi
    if [ $EnableRoolback -eq 1 ]; then
      buttons=("<Yes>" "<No>"); confirmPrompt "Is $appName app working correctly?" "buttons" && response=Yes || response=No
      if [[ "$response" == [Nn]* ]]; then
        echo -e "$running Roolback to previous version.."
        iCmd "pm rollback-app $pkgName"
        am start -n "$activityClass"
      fi
    fi
  else
    local activityClass="$activity"
    if [ $Android -le 6 ]; then
      am start -a android.intent.action.VIEW -t application/vnd.android.package-archive -d "file://$outputAPK" > /dev/null 2>&1  # Activity Manager
    else
      termux-open --view "$outputAPK"  # install apk using Session installer
    fi
    sleep 15 && am start -n "$activityClass" &> /dev/null  # launch app after install
  fi
  if [ $su -eq 1 ]; then
    [ $writeSELinux -eq 1 ] && su -c "setenforce 1"
  fi
  [ $RmFileAfterInstallation -eq 1 ] && rm -f "$outputAPK"
}
########################################################################################################################################################
