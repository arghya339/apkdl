#!/bin/bash

adbInstall() {
  local outputAPK="${1}"
  local outputFileName="$(basename "$outputAPK")"
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
  if [ $isAPK -eq 0 ]; then
    bsdtar -tf "$outputAPK" --include='*.obb' >/dev/null 2>&1 && isGame=1 || isGame=0  # Check if APK contains OBB files (common in games)
    if [ $isGame -eq 1 ]; then
      mkdir -p "$wo_ext"
      pv "$outputAPK" | bsdtar -xf - -C "$wo_ext"
      pkgName=$(cat "$wo_ext/manifest.json" | jq -r '.package_name')
      appName=$(cat "$wo_ext/manifest.json" | jq -r '.name')
      outputAPK="$wo_ext/$pkgName.apk"  # base.apk path
      outputFileName="$pkgName.apk"
      obbInstallPath=$(cat "$wo_ext/manifest.json" | jq -r '.expansions.[].install_path')  # Android/obb/com.example.package/main.1234.com.example.obb
      outputOBB="$wo_ext/$obbInstallPath"  # obb file path
    else
      apks=($(bsdtar -tf "$outputAPK" --include='*.apk' | awk -F/ '{print $NF}' | sort -u))
      mkdir -p "$wo_ext"
      pv "$outputAPK" | bsdtar -xf - -C "$wo_ext"
      if [ $isXAPK -eq 1 ]; then
        pkgName=$(cat "$wo_ext/manifest.json" | jq -r '.package_name')
        appName=$(cat "$wo_ext/manifest.json" | jq -r '.name')
        versionCode=$(cat "$wo_ext/manifest.json" | jq -r '.version_code')
        outputAPK="$wo_ext/$pkgName.apk"
      else
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
  
  [ $DisablePlayProtect -eq 1 ] && adb -s $serial shell "settings put global package_verifier_user_consent -1"  # Disabled Play Protect
  if [ $DisableVerifyAdbInstalls -eq 1 ]; then
    [ $Android -le 10 ] && adb -s $serial shell "settings put global package_verifier_enable 0" || adb -s $serial shell "settings put global verifier_verify_adb_installs 0"  # Disable Verify Adb Installs
  fi
  if [ $isAPKS -eq 1 ] || { [ $isXAPK -eq 1 ] && [ $isGame -eq 0 ]; }; then
    sessionId=$(adb -s $serial shell pm install-create ${cmd} | grep -oE '[0-9]+')
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
    output=$(adb -s $serial shell pm install ${cmd} "\"/data/local/tmp/${outputFileName}\"" 2>&1); echo "$output"
    adb -s $serial shell rm -f "/data/local/tmp/$outputFileName"
    #adb -s $serial install ${cmd} "/data/local/tmp/$outputFileName" 2>&1
    #adb -s $serial shell cmd package install ${cmd} "/data/local/tmp/$outputFileName" > /dev/null 2>&1
    if [ $isGame -eq 1 ]; then
      adb -s $serial shell mkdir -p /sdcard/Android/obb/$pkgName
      adb -s $serial push "$outputOBB" /sdcard/$obbInstallPath >/dev/null 2>&1
      rm -rf "$wo_ext"
      outputAPK="$wo_ext.$apk_ext"
    fi
  fi
  [ $DisablePlayProtect -eq 1 ] && adb -s $serial shell "settings put global package_verifier_user_consent 1"  # Enabled Play Protect
  if [ $DisableVerifyAdbInstalls -eq 1 ]; then
    [ $Android -le 10 ] && adb -s $serial shell "settings put global package_verifier_enable 1" || adb -s $serial shell "settings put global verifier_verify_adb_installs 1"  # Enabled Verify Adb Installs
  fi
  
  if [[ $output == *"Downgrade detected"* ]] && [ $KeepsData -eq 1 ]; then
    echo -e "${Green}$appName uninstall successfully with keeps app data.${Reset}\n${Yellow}Don't forget to restart Simplify after reboot!${Reset}"
    adb -s $serial shell "cmd package uninstall -k $pkgName"
    cp "$outputAPK" "$POST_INSTALL"
    sleep 12
    adb -s $serial "reboot"
  fi
  am start -n "$activityClass" &> /dev/null  # launch app after update
  [ $? != 0 ] && adb -s $serial shell "monkey -p $pkgName -c android.intent.category.LAUNCHER 1" > /dev/null 2>&1
  if [ $EnableRoolback -eq 1 ]; then
    buttons=("<Yes>" "<No>"); confirmPrompt "Is $appName app working correctly?" "buttons" && response=Yes || response=No
    if [[ "$response" == [Nn]* ]]; then
      echo -e "$running Roolback to previous version.."
      adb -s $serial shell "pm rollback-app $pkgName"
    fi
  fi
  [ $RmFileAfterInstallation -eq 1 ] && rm -f "$outputAPK"
}