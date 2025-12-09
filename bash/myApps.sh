#!/bin/bash

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

packagesList() {
  echo -e "$running Get Installed packages list.."
  [ $ShowSystemApps -eq 0 ] && runCmdOut=$(runCmd "pm list packages -3") || runCmdOut=$(runCmd "pm list packages")
  packages=($(sed 's/package://g' <<< "$runCmdOut")) && unset runCmdOut
}

packagesInfo() {
  local -n packages_name=$1
  reqAppName=${2:-0}
  
if [ $reqAppName -eq 1 ]; then
  if [ $isAndroid -eq 1 ]; then
    if [ $su -eq 1 ]; then
      su -c "[ ! -f /data/local/tmp/aapt2 ] && { cp $HOME/aapt2 /data/local/tmp/ && chmod +x /data/local/tmp/aapt2; }"
    elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
      ~/rish -c "[ ! -f /data/local/tmp/aapt2 ] && { cp $HOME/aapt2 /data/local/tmp/ && chmod +x /data/local/tmp/aapt2; }"
    elif "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
      ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell [ ! -f "/data/local/tmp/aapt2" ] && { ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) push ~/aapt2 /data/local/tmp/ >/dev/null 2>&1 && ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell chmod +x /data/local/tmp/aapt2; }
    fi
  elif [ $isMacOS -eq 1 ]; then
    [ ! -f "$apkdl/aapt2" ] && curl -sL --progress-bar -o "$apkdl/aapt2_$cpuAbi" "https://github.com/arghya339/aapt2/releases/download/all/aapt2_$cpuAbi"
    adb -s "$serial" shell "[ ! -f '/data/local/tmp/aapt2' ]" && { adb -s "$serial" push "$apkdl/aapt2_$cpuAbi" /data/local/tmp/aapt2 >/dev/null 2>&1 && adb -s "$serial" shell "chmod +x /data/local/tmp/aapt2"; }
  fi
  aapt2="/data/local/tmp/aapt2"
fi
  
  echo -e "$running Get Installed packages info.."
  for ((i=0; i<${#packages_name[@]}; i++)); do
    echo -e "$running Processing $((i+1))/${#packages_name[@]}: ${packages_name[$i]}"
    runCmdOut=$(runCmd "pm dump ${packages_name[$i]}")
    appInfo=$(grep -E 'versionName|versionCode|firstInstallTime|lastUpdateTime|codePath|installerPackageName' <<< "$runCmdOut") && unset runCmdOut
    iVersionNames[i]=$(echo "$appInfo" | grep "versionName" | awk -F'=' '{print $2}')
    iVersionCodes[i]=$(echo "$appInfo" | grep "versionCode" | awk -F'=' '{print $2}' | awk '{print $1}')
    firstInstallTimes[i]=$(echo "$appInfo" | grep "firstInstallTime" | awk -F'=' '{print $2}')
    iLastUpdateTimes[i]=$(echo "$appInfo" | grep "lastUpdateTime" | awk -F'=' '{print $2}')
    installerPackageNames[i]=$(grep "installerPackageName" <<< "$appInfo" | awk -F'=' '{print $2}')
    codePaths[i]=$(echo "$appInfo" | grep "codePath" | sed 's/.*codePath=//')
    basePaths[i]="${codePaths[$i]}/base.apk"
    if [ $reqAppName -eq 1 ]; then
      runCmdOut=$(runCmd "$aapt2 dump badging ${basePaths[$i]}")
      application_labels[i]=$(grep "application-label:" <<< "$runCmdOut" | cut -d"'" -f2) && unset runCmdOut
    fi
  done
}

getUpdates() {
  packagesList
  packagesInfo "packages"
  echo -e "$running Get Installed packages updates.."
  
  pkgs=$(sed 's/ /", "/g; s/^/"/; s/$/"/' <<< "${packages[@]}")
  RESPONSE_JSON=$(curl -sL --doh-url "$cloudflareDOH" $APKM_REST_API_URL -A "$USER_AGENT" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Basic $AUTH_TOKEN" -d "{\"pnames\":[$pkgs]}")
  
  exists_pnames=($(jq -r '.data[] | select(.exists == true) | .pname' <<< "$RESPONSE_JSON"))
  not_exists_pnames=($(jq -r '.data[] | select(.exists == false) | .pname' <<< "$RESPONSE_JSON"))
  echo -e "$info total-apps: ${#packages[@]}\n$good found: ${#exists_pnames[@]}\n$notice not-found: ${#not_exists_pnames[@]}"
  
  declare -a pnames installedVersions lastUpdates appNames releaseLinks developerNames releaseVersions releasePublishDates releaseWhatsNews
  for i in ${!exists_pnames[@]}; do
    echo -e "$running Processing $((i+1))/${#exists_pnames[@]}: ${exists_pnames[i]}"
    for ((j=0; j<${#packages[@]}; j++)); do
      if [ "${exists_pnames[i]}" == "${packages[j]}" ]; then
        installedVersion="${iVersionNames[j]}"
        lastUpdate="${iLastUpdateTimes[j]}"
        break
      fi
    done
    releaseVersion=$(jq -r ".data[] | select(.pname == \"${exists_pnames[i]}\") | .release.version" <<< "$RESPONSE_JSON")
    if [ "$releaseVersion" != "$installedVersion" ]; then
      pnames+=("${exists_pnames[i]}")
      installedVersions+=("$installedVersion")
      lastUpdates+=("$lastUpdate")
      appNames+=("$(jq -r ".data[] | select(.pname == \"${exists_pnames[i]}\") | .app.name" <<< "$RESPONSE_JSON")")
      releaseLinks+=("https://apkmirror.com$(jq -r ".data[] | select(.pname == \"${exists_pnames[i]}\") | .release.link" <<< "$RESPONSE_JSON")")
      developerNames+=("$(jq -r ".data[] | select(.pname == \"${exists_pnames[i]}\") | .developer.name" <<< "$RESPONSE_JSON")")
      releaseVersions+=("$releaseVersion")
      releasePublishDates+=("$(jq -r ".data[] | select(.pname == \"${exists_pnames[i]}\") | .release.publish_date" <<< "$RESPONSE_JSON")")
      releaseWhatsNews+=("$(jq -r ".data[] | select(.pname == \"${exists_pnames[i]}\") | .release.whats_new" <<< "$RESPONSE_JSON")")
      echo -e "$notice ${appNames[i]} is currently outdated!"
    else
      echo -e "$good ${exists_pnames[i]} is up to date."
    fi
  done
  
  apps=()
  for ((i=0; i<${#pnames[@]}; i++)); do
    apps+=("${appNames[i]} (${pnames[i]}) | ${installedVersions[i]} (${lastUpdates[i]}) → ${releaseVersions[i]} (${releasePublishDates[i]})")
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

aptoideListAppsUpdates() {
  # src: https://github.com/Aptoide/aptoide-client-v8/blob/master/dataprovider/src/main/java/cm/aptoide/pt/dataprovider/ws/v7/listapps/ListAppsUpdatesRequest.java
  aptoideListAppsUpdatesAPI="https://ws75.aptoide.com/api/7/listAppsUpdates"
  packagesList
  packagesInfo "packages"
  echo -e "$running Get Installed packages updates.."
  apks_data="apks_data=["
  for ((i=0; i<${#packages[@]}; i++)); do
    [ $i -eq 0 ] && apks_data+="{\"package\":\"${packages[i]}\",\"vercode\":${iVersionCodes[i]},\"signature\":null}" || apks_data+=",{\"package\":\"${packages[i]}\",\"vercode\":${iVersionCodes[i]},\"signature\":null}"
  done
  apks_data+="]"
  listAppsUpdatesJson=$(curl -sL -d ${apks_data} "$aptoideListAppsUpdatesAPI" | jq -r '.list.[]') #> listAppsUpdates.json
  appsId=($(jq -r '.id' <<< "$listAppsUpdatesJson"))
  mapfile -t names < <(jq -r '.name' <<< "$listAppsUpdatesJson")
  pkgs=($(jq -r '.package' <<< "$listAppsUpdatesJson"))
  icons=($(jq -r '.icon' <<< "$listAppsUpdatesJson"))
  mapfile -t modifieds < <(jq -r '.modified' <<< "$listAppsUpdatesJson")
  developerIds=($(jq -r '.developer.id' <<< "$listAppsUpdatesJson"))
  mapfile -t developerNames < <(jq -r '.developer.name' <<< "$listAppsUpdatesJson")
  mapfile -t vernames < <(jq -r '.file.vername' <<< "$listAppsUpdatesJson")
  vercodes=($(jq -r '.file.vercode' <<< "$listAppsUpdatesJson"))
  md5sums=($(jq -r '.file.md5sum' <<< "$listAppsUpdatesJson"))
  filesizes=($(jq -r '.file.filesize' <<< "$listAppsUpdatesJson"))
  sha1s=($(jq -r '.file.signatures.sha1' <<< "$listAppsUpdatesJson"))
  mapfile -t owners < <(jq -r '.file.signatures.owner' <<< "$listAppsUpdatesJson")
  paths=($(jq -r '.file.path' <<< "$listAppsUpdatesJson"))
  malwareRanks=($(jq -r '.malware.rank' <<< "$listAppsUpdatesJson"))
  downloads=($(jq -r '.stats.downloads' <<< "$listAppsUpdatesJson"))
  avgs=($(jq -r '.stats.prating.avg' <<< "$listAppsUpdatesJson"))
  totals=($(jq -r '.stats.prating.total' <<< "$listAppsUpdatesJson"))
  mapfile -t obbs < <(jq -r '.obb' <<< "$listAppsUpdatesJson")
  advertisings=($(jq -r '.appcoins.advertising' <<< "$listAppsUpdatesJson"))
  mapfile -t billings < <(jq -r '.appcoins.billing' <<< "$listAppsUpdatesJson")
  declare -g -a apps
  for i in ${!pkgs[@]}; do
    installedVersion=; versionCode=; lastUpdateTime=
    for ((j=0; j<${#packages[@]}; j++)); do
      if [ "${pkgs[i]}" == "${packages[j]}" ]; then
        installedVersionName="${iVersionNames[j]}"
        installedVersionCode="${iVersionCodes[j]}"
        lastUpdateTime="${iLastUpdateTimes[j]}"
        break
      fi
    done
    installedVersionNames+=("$installedVersionName")
    installedVersionCodes+=("$installedVersionCode")
    lastUpdateTimes+=("$lastUpdateTime")
    apps+=("${names[i]} (${pkgs[i]}) | ${installedVersionNames[i]} (${lastUpdateTimes[i]}) → ${vernames[i]} (${modifieds[i]})")
  done
}

aptoideShowUpdates() {
  buttons=("<Select>" "<Back>")
  if [ ${#apps[@]} -ge 1 ]; then
    if menu "apps" "buttons"; then
      appName="${names[selected]}"
      versionName="${vernames[selected]}"
      versionCode="${vercodes[selected]}"
      md5sum="${md5sums[selected]}"
      filesize="${filesizes[selected]}"
      dlUrl="${paths[selected]}"
      echo -e "dlUrl: ${Blue}$dlUrl${Reset}"
      fileName="${appName}_v$versionName-$versionCode.apk"
      filePath="$Download/$fileName"
      return
    else
      return 1
    fi
  else
    return 1
  fi
}

appsList() {
  packagesList
  packagesInfo "packages" "1"
  applications=()
  for ((i=0; i<${#packages[@]}; i++)); do
    applications+=("${application_labels[$i]} (${packages[$i]})")
  done
}

firewallService() {
  if [ ! -f $apkdl/firewallBlocklist.json ]; then
    jq -n '[]' > $apkdl/firewallBlocklist.json
  fi
  if ! jq -e --arg package "$package" 'any(.[]; .package == $package)' $apkdl/firewallBlocklist.json >/dev/null 2>&1; then
    jq --arg package "$package" --arg uid "$uid" --arg label "$appLabel" '. += [{"package": $package,"uid": $uid,"label": $label}]' $apkdl/firewallBlocklist.json > tmp.json && mv tmp.json $apkdl/firewallBlocklist.json
  fi
  cat > $apkdl/script.apkdl.firewall.sh << 'EOF'
#!/system/bin/sh

script="/data/adb/script.apkdl.firewall"
jq="$script/utils/bin/jq"
lib="$script/utils/lib"
firewallBlocklistJson="$script/firewallBlocklist.json"

export LD_LIBRARY_PATH="$lib:$LD_LIBRARY_PATH"

until [ "$(getprop sys.boot_completed)" == "1" ]; do
  sleep 1
done

if [ "$(getenforce 2>/dev/null)" == "Enforcing" ]; then
  setenforce 0
  writeSELinux=1
else
  writeSELinux=0
fi

"$jq" -r '.[] | "\(.package) \(.uid)"' "$firewallBlocklistJson" | while read -r package uid; do
  ip6tables -I OUTPUT 1 -m owner --uid-owner ${uid} -j DROP
  iptables -I OUTPUT 1 -m owner --uid-owner ${uid} -j DROP
  am force-stop ${package}
done

[ $writeSELinux -eq 1 ] && setenforce 1
EOF
  if [ $su -eq 1 ]; then
    su -c "mkdir -p /data/adb/script.apkdl.firewall/utils/bin /data/adb/script.apkdl.firewall/utils/lib"
    su -c "[ ! -f /data/adb/script.apkdl.firewall/utils/bin/jq ] && { cp $PREFIX/bin/jq /data/adb/script.apkdl.firewall/utils/bin/jq; chmod +x /data/adb/script.apkdl.firewall/utils/bin/jq; cp $PREFIX/lib/libjq.so /data/adb/script.apkdl.firewall/utils/lib/libjq.so; cp $PREFIX/lib/libonig.so /data/adb/script.apkdl.firewall/utils/lib/libonig.so; }"
    su -c "cp $apkdl/firewallBlocklist.json /data/adb/script.apkdl.firewall/firewallBlocklist.json"
    su -c "mv $apkdl/script.apkdl.firewall.sh /data/adb/service.d/script.apkdl.firewall.sh && chmod 0755 /data/adb/service.d/script.apkdl.firewall.sh"
  elif [ $shellSU -eq 1 ]; then
    adb -s $serial shell su -c "mkdir -p /data/adb/script.apkdl.firewall/utils/bin /data/adb/script.apkdl.firewall/utils/lib"
    if [ "$cpuAbi" == "arm64-v8a" ]; then arch="aarch64"; elif [ "$cpuAbi" == "armeabi-v7a" ]; then arch="arm"; elif [ "$cpuAbi" == "x86" ]; then arch="i686"; else arch="$cpuAbi"; fi
    urls=("https://packages.termux.dev/apt/termux-main/pool/main/j/jq" "https://packages.termux.dev/apt/termux-main/pool/main/o/oniguruma")
    declare -a files filesPath
    for ((i=0; i<${#urls[@]}; i++)); do
      files+=($(curl -sL "${urls[i]}" | pup 'a json{}' | jq -r --arg arch "$arch" '.[] | select(.href | contains($arch)) | .href'))
      path="$apkdl/${files[i]}"
      dlUrl="${urls[i]}/${files[i]}"
      while true; do
        curl -sL -C - -o $path ${urls[i]}
        [ $? -eq 0 ] && break || sleep 5
      done
      bsdtar -xOf $path data.tar.xz | bsdtar -C ~/apkdl -xf -
      [ $i -eq 0 ] && filesPath+=("$apkdl/data/data/com.termux/files/usr/bin/jq" "$apkdl/data/data/com.termux/files/usr/lib/libjq.so") || filesPath+=("$apkdl/data/data/com.termux/files/usr/lib/libonig.so")
    done
    adb -s $serial shell su -c "[ ! -f /data/adb/script.apkdl.firewall/utils/bin/jq ] && { cp ${filesPath[0]} /data/adb/script.apkdl.firewall/utils/bin/jq; chmod +x /data/adb/script.apkdl.firewall/utils/bin/jq; cp ${filesPath[1]} /data/adb/script.apkdl.firewall/utils/lib/libjq.so; cp ${filesPath[2]} /data/adb/script.apkdl.firewall/utils/lib/libonig.so; }"
    [ -d $apkdl/data ] && rm -rf $apkdl/data
    adb -s $serial shell su -c "cp $apkdl/firewallBlocklist.json /data/adb/script.apkdl.firewall/firewallBlocklist.json"
    adb -s $serial shell su -c "mv $apkdl/script.apkdl.firewall.sh /data/adb/service.d/script.apkdl.firewall.sh && chmod 0755 /data/adb/service.d/script.apkdl.firewall.sh"
  fi
}

blockInternet() {
  buttons=("<Select>" "<Back>")
  if menu "applications" "buttons"; then
    package="${packages[selected]}"
    appLabel="${application_labels[selected]}"
    echo -e "$running Blocking internet access for $package"
    runCmdOut=$(runCmd "pm list packages -U")
    uid=$(grep $package <<< "$runCmdOut" | awk -F'uid:' '{print $2}') && unset runCmdOut
    firewallService
    if [ $su -eq 1 ]; then
      runCmd "ip6tables -I OUTPUT 1 -m owner --uid-owner $uid -j DROP"
      runCmd "iptables -I OUTPUT 1 -m owner --uid-owner $uid -j DROP"
      runCmdOut=$(runCmd "ip6tables -L OUTPUT -n -v")
      sleep 0.5
      status=$(grep -i $uid <<< "$runCmdOut") && unset runCmdOut
    elif [ $shellSU -eq 1 ]; then
      adb -s $serial shell su -c "ip6tables -I OUTPUT 1 -m owner --uid-owner $uid -j DROP"
      adb -s $serial shell su -c "iptables -I OUTPUT 1 -m owner --uid-owner $uid -j DROP"
      sleep 0.5
      status=$(adb -s $serial shell su -c "ip6tables -L OUTPUT -n -v | grep -i $uid")
    fi
    [ -n "$status" ] && { echo -e "$good Successfully blocked internet access for $appLabel."; runCmd "am force-stop $package"; } || echo -e "$notice Failed to blocking internet access for $appLabel!"
  fi
}

showFirewallBlocklist() {
  if [ -f $apkdl/firewallBlocklist.json ]; then
    blocked_pkgs=($(jq -r '.[].package' $apkdl/firewallBlocklist.json))
    uids=($(jq -r '.[].uid' $apkdl/firewallBlocklist.json))
    mapfile -t labels < <(jq -r '.[].label' $apkdl/firewallBlocklist.json)
    firewallBlocklist=()
    for ((i=0; i<${#blocked_pkgs[@]}; i++)); do
      firewallBlocklist+=("${labels[i]} (${blocked_pkgs[i]})")
    done
    return
  else
    return 1
  fi
}

unblockInternet() {
  buttons=("<Select>" "<Back>")
  if menu "firewallBlocklist" "buttons"; then
    package="${blocked_pkgs[selected]}"
    uid="${uids[selected]}"
    appLabel="${labels[selected]}"
    echo -e "$running Unblocking internet access for $package"
    jq --arg package "$package" 'map(select(.package != $package))' $apkdl/firewallBlocklist.json > tmp.json && mv tmp.json $apkdl/firewallBlocklist.json
    if [ $(jq 'length' $apkdl/firewallBlocklist.json) -ge 1 ]; then
      if [ $su -eq 1 ]; then
        su -c "cp $apkdl/firewallBlocklist.json /data/adb/script.apkdl.firewall/firewallBlocklist.json"
      elif [ $shellSU -eq 1 ]; then
        adb -s $serial push $apkdl/firewallBlocklist.json /data/local/tmp/firewallBlocklist.json >/dev/null 2>&1
        adb -s $serial shell su -c "mv /data/local/tmp/firewallBlocklist.json /data/adb/script.apkdl.firewall/firewallBlocklist.json"
      fi
    else
      rm -f $apkdl/firewallBlocklist.json
      if [ $su -eq 1 ]; then
        su -c "rm -rf /data/adb/script.apkdl.firewall /data/adb/service.d/script.apkdl.firewall.sh"
      elif [ $shellSU -eq 1 ]; then
        adb -s $serial shell su -c "rm -rf /data/adb/script.apkdl.firewall /data/adb/service.d/script.apkdl.firewall.sh"
      fi
    fi
    if [ $su -eq 1 ]; then
      runCmd "ip6tables -D OUTPUT -m owner --uid-owner $uid -j DROP"
      runCmd "iptables -D OUTPUT -m owner --uid-owner $uid -j DROP"
      runCmdOut=$(runCmd "ip6tables -L OUTPUT -n -v")
      sleep 0.5
      status=$(grep -i $uid <<< "$runCmdOut") && unset runCmdOut
    elif [ $shellSU -eq 1 ]; then
      adb -s $serial shell su -c "ip6tables -D OUTPUT -m owner --uid-owner $uid -j DROP"
      adb -s $serial shell su -c "iptables -D OUTPUT -m owner --uid-owner $uid -j DROP"
      sleep 0.5
      status=$(adb -s $serial shell su -c "ip6tables -L OUTPUT -n -v | grep -i $uid")
    fi
    [ -z "$status" ] && { echo -e "$good Successfully unblocked internet access for $appLabel."; runCmd "am force-stop $package"; } || echo -e "$notice Failed to unblocking internet access for $appLabel!"
  fi
}

hideApps() {
  buttons=("<Select>" "<Back>")
  if menu "applications" "buttons"; then
    package="${packages[selected]}"
    appLabel="${application_labels[selected]}"
    runCmd "pm hide $package" && echo -e "$good Successfully hidden $appLabel." || echo -e "$notice Failed to hidden $appLabel!"
  fi
}

showHiddenApps() {
  all_pkgs=$(runCmd "pm list packages -u")
  installed_pkgs=$(runCmd "pm list packages")
  hidden_pkgs=($(grep -vF -f <(echo "$installed_pkgs") <<< "$all_pkgs" | sed 's/package://'))
  packagesInfo "hidden_pkgs" "1"
  hiddenApps=()
  for ((i=0; i<${#hidden_pkgs[@]}; i++)); do
    hiddenApps+=("${application_labels[i]} (${hidden_pkgs[i]})")
  done
}

unhideApps() {
  buttons=("<Select>" "<Back>")
  if menu "hiddenApps" "buttons"; then
    package="${hidden_pkgs[selected]}"
    echo -e "$running Unhidden $package"
    runCmd "pm unhide $package"
  fi
}

showEnabledApps() {
  #runCmdOut=$(runCmd "pm list packages -e")
  #enabled_pkgs=($(sed 's/package://' <<< "$runCmdOut")) && unset runCmdOut
  runCmdOut=$(runCmd "cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.LAUNCHER")  # filter out non-launchable apps (apps without a launcher activity)
  launchable_pkgs=($(grep 'packageName=' <<< "$runCmdOut" | sed 's/.*packageName=//' | sort -u)) && unset runCmdOut
  packagesInfo "enabled_pkgs" "1"
  enabledApps=()
  for ((i=0; i<${#launchable_pkgs[@]}; i++)); do
    enabledApps+=("${application_labels[i]} (${launchable_pkgs[i]})")
  done
}

disableApps() {
  buttons=("<Select>" "<Back>")
  if menu "enabledApps" "buttons"; then
    package="${launchable_pkgs[selected]}"
    echo -e "$running Disabling $package"
    runCmd "pm disable-user --user 0 $package" && echo -e "$good Successfully disabled $package." || echo -e "$notice Failed to disabled $package!"
  fi
}

showDisabledApps() {
  runCmdOut=$(runCmd "pm list packages -d")
  disabled_pkgs=($(sed 's/package://' <<< "$runCmdOut")) && unset runCmdOut
  packagesInfo "disabled_pkgs" "1"
  disabledApps=()
  for ((i=0; i<${#disabled_pkgs[@]}; i++)); do
    disabledApps+=("${application_labels[i]} (${disabled_pkgs[i]})")
  done
}

enableApps() {
  buttons=("<Select>" "<Back>")
  if menu "disabledApps" "buttons"; then
    package="${disabled_pkgs[selected]}"
    runCmd "pm enable $package"
  fi
}

packagesUninstall() {
  buttons=("<Select>" "<Back>")
  if menu "applications" "buttons"; then
    package="${packages[selected]}"
    appLabel="${application_labels[selected]}"
    echo -e "$running Uninstalling $package"
    runCmdOut=$(runCmd "pm uninstall --user 0 $package")
    if echo "$runCmdOut" | grep -q 'Success' >/dev/null 2>&1; then
      unset runCmdOut; echo -e "$good Successfully uninstalled $appLabel."
    else
      unset runCmdOut
      runCmdOut=$(runCmd "cmd package uninstall -k --user 0 $package")
      echo "$runCmdOut" | grep -q 'Failure' >/dev/null 2>&1 && echo -e "$notice Failed to uninstall $appLabel!" || echo -e "$good Successfully uninstalled $appLabel."
      unset runCmdOut
    fi
  fi
}

showUninstalledSystemApps() {
  all_pkgs=$(runCmd "pm list packages -s -u")
  installed_pkgs=$(runCmd "pm list packages -s")
  uninstalled_pkgs=($(grep -vF -f <(echo "$installed_pkgs") <<< "$all_pkgs" | sed 's/package://'))
  packagesInfo "uninstalled_pkgs" "1"
  uninstalledSystemApps=()
  for ((i=0; i<${#uninstalled_pkgs[@]}; i++)); do
    uninstalledSystemApps+=("${application_labels[i]} (${uninstalled_pkgs[i]})")
  done
}

recoverSystemApps() {
  buttons=("<Select>" "<Back>")
  if menu "uninstalledSystemApps" "buttons"; then
    package="${uninstalled_pkgs[selected]}"
    runCmd "cmd package install-existing $package"
  fi
}
############################################################################################################################################