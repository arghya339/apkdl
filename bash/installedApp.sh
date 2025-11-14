#!/bin/bash

packagesInfo() {
  reqAppName=${1:-0}
  runCmd() {
    command=${1}
    if [ $isAndroid -eq 1 ]; then
      if [ $su -eq 1 ]; then
        su -c "$command"
      elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
        ~/rish -c "$command"
      elif "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
        ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "$command"
      fi
    elif [ $isMacOS -eq 1 ]; then
      adb -s $serial shell "$command"
    fi
  }
  
  if [ $isAndroid -eq 1 ] && [ $su -eq 1 ]; then
    [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=1; } || writeSELinux=0
  fi
  echo -e "$running Get Installed packages list.."
  #packages=($(~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "pm list packages -3" | sed 's/package://'))
  runCmdOut=$(runCmd "pm list packages -3")
  packages=($(sed 's/package://g' <<< "$runCmdOut")) && unset runCmdOut
  
if [ $reqAppName -eq 1 ]; then
  #~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell [ ! -f "/data/local/tmp/aapt2" ] && ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) push ~/aapt2 /data/local/tmp/ >/dev/null 2>&1
  if [ $isAndroid -eq 1 ]; then
    if [ $su -eq 1 ]; then
      su -c "[ ! -f "/data/local/tmp/aapt2" ]" && su -c "cp ~/aapt2 /data/local/tmp/"
    elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
      ~/rish -c "[ ! -f "/data/local/tmp/aapt2" ]" && ~/rish -c "cp ~/aapt2 /data/local/tmp/"
    elif "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
      ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell [ ! -f "/data/local/tmp/aapt2" ] && ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) push ~/aapt2 /data/local/tmp/ >/dev/null 2>&1
    fi
  elif [ $isMacOS -eq 1 ]; then
    adb -s $serial shell [ ! -f "/data/local/tmp/aapt2" ] && adb -s $serial push ~/aapt2 /data/local/tmp/ >/dev/null 2>&1
  fi
  aapt2="/data/local/tmp/aapt2"
fi
  
  echo -e "$running Get Installed packages info.."
  for ((i=0; i<${#packages[@]}; i++)); do
    echo -e "$running Processing $((i+1))/${#packages[@]}: ${packages[$i]}"
    #appInfo=$(~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "pm dump "${packages[i]}" | grep -E 'versionName|versionCode|firstInstallTime|lastUpdateTime|codePath'")
    runCmdOut=$(runCmd "pm dump ${packages[$i]}")
    appInfo=$(grep -E 'versionName|versionCode|firstInstallTime|lastUpdateTime|codePath' <<< "$runCmdOut") && unset runCmdOut
    versionNames[i]=$(echo "$appInfo" | grep "versionName" | awk -F'=' '{print $2}')
    versionCodes[i]=$(echo "$appInfo" | grep "versionCode" | awk -F'=' '{print $2}' | awk '{print $1}')
    firstInstallTimes[i]=$(echo "$appInfo" | grep "firstInstallTime" | awk -F'=' '{print $2}')
    lastUpdateTimes[i]=$(echo "$appInfo" | grep "lastUpdateTime" | awk -F'=' '{print $2}')
    codePaths[i]=$(echo "$appInfo" | grep "codePath" | sed 's/.*codePath=//')
    basePaths[i]="${codePaths[$i]}/base.apk"
    if [ $reqAppName -eq 1 ]; then
      #application_labels[i]=$(~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "$aapt2 dump badging ${basePaths[$i]}" | grep "application-label:" | cut -d"'" -f2)
      runCmdOut=$(runCmd "$aapt2 dump badging ${basePaths[$i]}")
      application_labels[i]=$(grep "application-label:" <<< "$runCmdOut" | cut -d"'" -f2) && unset runCmdOut
    fi
  done
  if [ $isAndroid -eq 1 ] && [ $su -eq 1 ]; then
    [ $writeSELinux -eq 1 ] && su -c "setenforce 1"
  fi
}

getUpdates() {
  packagesInfo
  echo -e "$running Get Installed packages updates.."
  declare -a installVersions lastUpdate pnames appNames releaseLinks developerNames releaseVersions releasePublishDates releaseWhatsNews
  for ((i=0; i<${#packages[@]}; i++)); do
    pkgName="${packages[$i]}"
    versionName="${versionNames[$i]}"
    lastUpdateTime="${lastUpdateTimes[$i]}"
    echo -e "$running Processing $((i+1))/${#packages[@]}: $pkgName"
    RESPONSE_JSON=$(curl -sL --doh-url "$cloudflareDOH" $APKM_REST_API_URL -A "$USER_AGENT" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Basic $AUTH_TOKEN" -d "{\"pnames\":[\"$pkgName\"]}")
    if echo "$RESPONSE_JSON" | jq -e ".data[] | select(.pname == \"$pkgName\") | .exists == true" > /dev/null 2>&1; then
      echo -e "$good Found: $pkgName"
      releaseVersion=$(jq -r ".data[] | select(.pname == \"$pkgName\") | .release.version" <<< "$RESPONSE_JSON")
      if [ "$releaseVersion" != "$versionName" ]; then
        echo -e "$notice $pkgName is currently outdated!"
        installVersions+=("$versionName")
        lastUpdates+=("$lastUpdateTime")
        pnames+=("$(jq -r ".data[] | select(.pname == \"$pkgName\") | .pname" <<< "$RESPONSE_JSON")")
        appNames+=("$(jq -r ".data[] | select(.pname == \"$pkgName\") | .app.name" <<< "$RESPONSE_JSON" | sed 's/&amp;/&/g')")
        releaseLinks+=("https://www.apkmirror.com$(jq -r ".data[] | select(.pname == \"$pkgName\") | .release.link" <<< "$RESPONSE_JSON")")
        developerNames+=("$(jq -r ".data[] | select(.pname == \"$pkgName\") | .developer.name" <<< "$RESPONSE_JSON")")
        releaseVersions+=("$(jq -r ".data[] | select(.pname == \"$pkgName\") | .release.version" <<< "$RESPONSE_JSON")")
        releasePublishDates+=("$(jq -r ".data[] | select(.pname == \"$pkgName\") | .release.publish_date" <<< "$RESPONSE_JSON")")
        releaseWhatsNews+=("$(jq -r ".data[] | select(.pname == \"$pkgName\") | .release.whats_new" <<< "$RESPONSE_JSON")")
      else
        echo -e "$good $pkgName is currently up to date."
      fi
    else
      echo -e "$notice Not Found: $pkgName"
    fi
  done
  
  apps=()
  for ((i=0; i<${#pnames[@]}; i++)); do
    apps+=("${appNames[i]} (${pnames[i]}) | ${installVersions[i]} (${lastUpdates[i]}) → ${releaseVersions[i]} (${releasePublishDates[i]})")
  done
}

showUpdates() {
  buttons=("<Select>" "<Back>")
  if menu "apps" "buttons"; then
    appName="${appNames[selected]}"
    versionLink="${releaseLinks[selected]}"
    echo -e "releaseLink for ${pnames[selected]}: ${Blue}$versionLink${Reset}"
    return
  else
    return 1
  fi
}

packagesList() {
  packagesInfo "1"
  applications=()
  for ((i=0; i<${#packages[@]}; i++)); do
    applications+=("${packages[$i]} (${application_labels[$i]})")
  done
}

packagesUninstall() {
  buttons=("<Select>" "<Back>")
  if menu "applications" "buttons"; then
    package="${packages[selected]}"
    appLabel="${application_labels[selected]}"
    echo -e "$running Uninstalling $package"
    runCmd "pm uninstall $package" && echo -e "$good Successfully uninstalled $appLabel." || echo -e "$notice Failed to uninstall $appLabel!"
    return
  else
    return 1
  fi
}
############################################################################################################################################