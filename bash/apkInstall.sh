#!/usr/bin/bash

# Copyright (C) 2025, Arghyadeep Mondal <github.com/arghya339>

apkInstall() {
  local outputAPK=${1}
  local activity=$2  # for non-rooted user to launch app after installtion
  local outputFileName=$(basename "$outputAPK")
  output_dir=$(dirname "$outputAPK")
  wo_ext="${outputAPK%.*}"
  apk_ext="${outputFileName##*.}"
  case "$apk_ext" in
    "apk") isAPK=true; isAPKS=false; isXAPK=false ;;
    "apks") isAPKS=true; isAPK=false; isXAPK=false ;;
    "xapk") isXAPK=true; isAPK=false; isAPKS=false ;;
  esac
  isGame=false
  if [ $isAPK == false ]; then
    bsdtar -tf "$outputAPK" --include='*.obb' >/dev/null 2>&1 && isGame=true || isGame=false  # Check if APK contains OBB files (common in games)
    mkdir -p "$wo_ext"
    pv "$outputAPK" | bsdtar -xf - -C "$wo_ext"
    if [ $isXAPK == true ]; then
      pkgName=$(cat "$wo_ext/manifest.json" | jq -r '.package_name')
      appName=$(cat "$wo_ext/manifest.json" | jq -r '.name')
      versionCode=$(cat "$wo_ext/manifest.json" | jq -r '.version_code')
      outputAPK="$wo_ext/$pkgName.apk"  # base.apk path
      outputFileName="$pkgName.apk"
    fi
    if [ $isGame == true ]; then
      obbInstallPath=$(cat "$wo_ext/manifest.json" | jq -r '.expansions.[].install_path')  # Android/obb/com.example.package/main.1234.com.example.obb
      outputOBB="$wo_ext/$obbInstallPath"  # obb file path
    else
      apks=($(bsdtar -tf "$outputAPK" --include='*.apk' | awk -F/ '{print $NF}' | sort -u))
      if [ $isAPKS == true ]; then
        outputAPK="$wo_ext/splits/base-master.apk"
      fi
    fi
  fi
  app_info=$($aapt2 dump badging "$outputAPK" 2>/dev/null)
  pkgName=$(awk -F"'" '/package/ {print $2}' <<< "$app_info" | head -1)
  appName=$(awk -F"'" '/application-label:/ {print $2}' <<< "$app_info")
  if [ $su == true ]; then
    [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=true; } || writeSELinux=false
  fi
  if [ $su == true ] || [ $rish == true ] || [ $adb == true ]; then
    cmdOut=$(shellCmd "pm resolve-activity --brief $pkgName")
    local activityClass=$(tail -n 1 <<< "$cmdOut") && unset cmdOut
    [ $DisablePlayProtect == true ] && shellCmd "settings put global package_verifier_user_consent -1"  # Disabled Play Protect
    if [ $DisableVerifyAdbInstalls == true ]; then
      [ $Android -le 10 ] && shellCmd "settings put global package_verifier_enable 0" || shellCmd "settings put global verifier_verify_adb_installs 0"  # Disable Verify Adb Installs
    fi
    if [ $isAPKS == true ] || { [ $isXAPK == true ] && [ $isGame == false ]; }; then
      cmdOut=$(shellCmd "pm install-create ${pmCmd}") && unset cmdOut
      sessionId=$(grep -oE '[0-9]+' <<< "$cmdOut")
      [ -z $sessionId ] && { cmdOut=$(shellCmd "dumpsys package installer"); sessionId=$(grep "Active Session" <<< "$cmdOut" | grep -oE '[0-9]+'); unset cmdOut; }
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
        shellCmd "cp \"$wo_ext/splits/$apk\" \"/data/local/tmp/\""
        shellCmd "pm install-write $sessionId $split_identifier \"/data/local/tmp/$apk\""
        shellCmd "rm -f \"/data/local/tmp/$apk\""
      done
      if ! output=$(shellCmd "pm install-commit $sessionId" 2>&1); then
        echo "$output"
        shellCmd "pm install-abandon $sessionId" >/dev/null 2>&1
      else
        echo "$output"
      fi
      rm -rf "$wo_ext"
      outputAPK="$wo_ext.$apk_ext"
    else
      shellCmd "cp '$outputAPK' '/data/local/tmp/$outputFileName'"
      output=$(shellCmd "pm install ${pmCmd} \"/data/local/tmp/${outputFileName}\"" 2>&1); echo "$output"
      if [[ "$output" == *"signatures do not match"* ]]; then
        echo -e "$notice The current app has a different signature than the patched one!"
        confirmPrompt "Do you want to uninstall the current app and proceed?" "ynButtons" "1" && response=Yes || response=No
        if [ "$response" == "Yes" ]; then
          shellCmd "pm uninstall $pkgName"
          output=$(shellCmd "pm install ${pmCmd} \"/data/local/tmp/${outputFileName}\"" 2>&1); echo "$output"
        fi
      fi
      shellCmd "rm -f '/data/local/tmp/$outputFileName'"
      if [ $isGame == true ]; then
        shellCmd "mkdir -p /sdcard/Android/obb/$pkgName"
        shellCmd "cp \"$outputOBB\" /sdcard/$obbInstallPath" && rm -rf "$wo_ext"
        outputAPK="$wo_ext.$apk_ext"
      fi
    fi
    [ $DisablePlayProtect == true ] && shellCmd "settings put global package_verifier_user_consent 1"  # Enabled Play Protect
    if [ $DisableVerifyAdbInstalls == true ]; then
      [ $Android -le 10 ] && shellCmd "settings put global package_verifier_enable 1" || shellCmd "settings put global verifier_verify_adb_installs 1"  # Enabled Verify Adb Installs
    fi
    if [[ $output == *"Downgrade detected"* ]] && [ $KeepsData == true ]; then
      echo -e "${Green}$appName uninstall successfully with keeps app data.${Reset}\n${Yellow}Don't forget to restart apkdl after reboot!${Reset}"
      shellCmd "cmd package uninstall -k $pkgName"
      cp "$outputAPK" "$POST_INSTALL"
      echo; read -p "Press Enter to reboot..."
      shellCmd "reboot"
    fi
    am start -n "$activityClass" &> /dev/null  # launch app after install
    if [ $? != 0 ]; then
      shellCmd "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
    fi
    if [ $EnableRoolback == true ]; then
      buttons=("<Yes>" "<No>"); confirmPrompt "Is $appName app working correctly?" "buttons" && response=Yes || response=No
      if [[ "$response" == [Nn]* ]]; then
        echo -e "$running Roolback to previous version.."
        shellCmd "pm rollback-app $pkgName"
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
  ([ $su == true ] && [ $writeSELinux == true ]) && su -c "setenforce 1"
  [ $RmFileAfterInstallation == true ] && rm -f "$outputAPK"
}
###############################################################################################################################
