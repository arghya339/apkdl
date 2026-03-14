#!/bin/bash

# Copyright (C) 2025, Arghyadeep Mondal <github.com/arghya339>

adbInstall() {
  local outputAPK="${1}"
  local outputFileName="$(basename "$outputAPK")"
  output_dir=$(dirname "$outputAPK")
  wo_ext="${outputAPK%.*}"
  apk_ext="${outputFileName##*.}"
  if [ "$apk_ext" == "apk" ]; then
    isAPK=true; isAPKS=false; isXAPK=false
  elif [ "$apk_ext" == "apks" ]; then
    isAPKS=true; isAPK=false; isXAPK=false
  elif [ "$apk_ext" == "xapk" ]; then
    isXAPK=true; isAPK=false; isAPKS=false
  fi
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
  versionCode=$(awk -F"versionCode='" '{print $2}' <<< "$app_info" | awk -F"'" '{print $1}')
  appName=$(awk -F"'" '/application-label:/ {print $2}' <<< "$app_info")
  local activityClass=$(adb -s $serial shell "pm resolve-activity --brief $pkgName" | tail -n 1)
  Android=$(adb -s $serial shell getprop ro.build.version.release | cut -d. -f1)
  
  [ $DisablePlayProtect == true ] && adb -s $serial shell "settings put global package_verifier_user_consent -1"  # Disabled Play Protect
  if [ $DisableVerifyAdbInstalls == true ]; then
    [ $Android -le 10 ] && adb -s $serial shell "settings put global package_verifier_enable 0" || adb -s $serial shell "settings put global verifier_verify_adb_installs 0"  # Disable Verify Adb Installs
  fi
  if [ $isAPKS == true ] || { [ $isXAPK == true ] && [ $isGame == false ]; }; then
    sessionId=$(adb -s $serial shell pm install-create ${pmCmd} | grep -oE '[0-9]+')
    [ -z $sessionId ] && sessionId=$(adb -s $serial shell dumpsys package installer | grep "Active Session" | grep -oE '[0-9]+')
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
      adb -s $serial push "$wo_ext/splits/$apk" "/data/local/tmp/"
      adb -s "$serial" shell pm install-write "$sessionId" "$split_identifier" "/data/local/tmp/$apk"
      adb -s "$serial" shell rm -f "/data/local/tmp/$apk"
    done
    if ! output=$(adb -s $serial shell pm install-commit $sessionId 2>&1); then
      echo "$output"
      adb -s $serial shell pm install-abandon $sessionId >/dev/null 2>&1
    else
      echo "$output"
    fi
    rm -rf "$wo_ext"
    outputAPK="$wo_ext.$apk_ext"
  else
    adb -s $serial push "$outputAPK" "/data/local/tmp/$outputFileName" 2>/dev/null
    output=$(adb -s $serial shell pm install ${pmCmd} "\"/data/local/tmp/${outputFileName}\"" 2>&1); echo "$output"
    if [[ "$output" == *"signatures do not match"* ]]; then
      echo -e "$notice The current app has a different signature than the patched one!"
      buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to uninstall the current app and proceed?" "buttons" "1" && response=Yes || response=No
      if [ "$response" == "Yes" ]; then
        adb -s $serial uninstall $pkgName
        output=$(adb -s $serial shell pm install ${pmCmd} "\"/data/local/tmp/${outputFileName}\"" 2>&1); echo "$output"
      fi
    fi
    adb -s $serial shell rm -f "/data/local/tmp/$outputFileName"
    #adb -s $serial install ${pmCmd} "/data/local/tmp/$outputFileName" 2>&1
    #adb -s $serial shell cmd package install ${pmCmd} "/data/local/tmp/$outputFileName" > /dev/null 2>&1
    if [ $isGame == true ]; then
      adb -s $serial shell mkdir -p /sdcard/Android/obb/$pkgName
      adb -s $serial push "$outputOBB" /sdcard/$obbInstallPath >/dev/null 2>&1
      rm -rf "$wo_ext"
      outputAPK="$wo_ext.$apk_ext"
    fi
  fi
  [ $DisablePlayProtect == true ] && adb -s $serial shell "settings put global package_verifier_user_consent 1"  # Enabled Play Protect
  if [ $DisableVerifyAdbInstalls == true ]; then
    [ $Android -le 10 ] && adb -s $serial shell "settings put global package_verifier_enable 1" || adb -s $serial shell "settings put global verifier_verify_adb_installs 1"  # Enabled Verify Adb Installs
  fi
  
  if [[ $output == *"Downgrade detected"* ]] && [ $KeepsData == true ]; then
    echo -e "${Green}$appName uninstall successfully with keeps app data.${Reset}\n${Yellow}Don't forget to restart apkdl after reboot!${Reset}"
    adb -s $serial shell "cmd package uninstall -k $pkgName"
    cp "$outputAPK" "$POST_INSTALL"
    echo; read -p "Press Enter to reboot..."
    adb -s $serial "reboot"
  fi
  am start -n "$activityClass" &> /dev/null  # launch app after install
  [ $? != 0 ] && adb -s $serial shell "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
  if [ $EnableRoolback == true ]; then
    confirmPrompt "Is $appName app working correctly?" "ynButtons" && response=Yes || response=No
    if [[ "$response" == [Nn]* ]]; then
      echo -e "$running Roolback to previous version.."
      adb -s $serial shell "pm rollback-app $pkgName"
      am start -n "$activityClass" &> /dev/null
    fi
  fi
  [ $RmFileAfterInstallation == true ] && rm -f "$outputAPK"
}