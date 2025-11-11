#!/bin/bash

aapt2=("$HOME/Library/Android/sdk/build-tools/"*/aapt2) && aapt2="${aapt2[-1]}"

adbInstall() {
  local outputAPK="${1}"
  local outputFileName="$(basename "$outputAPK")"
  app_info=$($aapt2 dump badging "$outputAPK" 2>/dev/null)
  pkgName=$(awk -F"'" '/package/ {print $2}' <<< "$app_info" | head -1)
  appName=$(awk -F"'" '/application-label:/ {print $2}' <<< "$app_info")
  local activityClass=$(adb -s $serial shell "pm resolve-activity --brief $pkgName" | tail -n 1)
  Android=$(adb -s $serial shell getprop ro.build.version.release | cut -d. -f1)
  adb -s $serial push "$outputAPK" "/data/local/tmp/$outputFileName" 2>/dev/null
  [ $DisablePlayProtect -eq 1 ] && adb -s $serial shell "settings put global package_verifier_user_consent -1"  # Disabled Play Protect
  if [ $DisableVerifyAdbInstalls -eq 1 ]; then
    [ $Android -le 10 ] && adb -s $serial shell "settings put global package_verifier_enable 0" || adb -s $serial shell "settings put global verifier_verify_adb_installs 0"  # Disable Verify Adb Installs
  fi
  output=$(adb -s $serial shell pm install ${cmd} "\"/data/local/tmp/${outputFileName}\"" 2>&1); echo "$output"
  #adb -s $serial install ${cmd} "/data/local/tmp/$outputFileName" 2>&1
  #adb -s $serial shell cmd package install ${cmd} "/data/local/tmp/$outputFileName" > /dev/null 2>&1
  [ $DisablePlayProtect -eq 1 ] && adb -s $serial shell "settings put global package_verifier_user_consent 1"  # Enabled Play Protect
  if [ $DisableVerifyAdbInstalls -eq 1 ]; then
    [ $Android -le 10 ] && adb -s $serial shell "settings put global package_verifier_enable 1" || adb -s $serial shell "settings put global verifier_verify_adb_installs 1"  # Enabled Verify Adb Installs
  fi
  adb -s $serial shell rm -f "/data/local/tmp/$outputFileName"
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
    read -r -p "Is the $appName app working correctly? [Y/n]: " response
    if [[ "$response" == [Nn]* ]]; then
      echo -e "$running Roolback to previous version.."
      adb -s $serial shell "pm rollback-app $pkgName"
    fi
  fi
  [ $RmFileAfterInstallation -eq 1 ] && rm -f "$outputAPK"
}