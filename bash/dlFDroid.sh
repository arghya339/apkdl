#!/bin/bash

# Copyright (C) 2025, Arghyadeep Mondal <github.com/arghya339>

FDroidSearch() {
  while true; do read -r -p ">> Enter appName: " appName; [[ "$appName" =~ ^[Qq] ]] && appName=; break; [ -n "$appName" ] && break || echo -e "$notice Please enter a valid appName!"; done
  if [ -n "$appName" ]; then
    app_name=$(echo "$appName" | sed 's/ /+/g')
    searchUrl="https://search.f-droid.org/api/search_apps?q=${app_name}"
    responseJson=$(curl -sL "$searchUrl")
    appsCount=$(jq '.apps | length' <<< "$responseJson")
    
    mapfile -t names < <(jq -r '.apps[].name' <<< "$responseJson")
    mapfile -t summarys < <(jq -r '.apps[].summary' <<< "$responseJson")
    mapfile -t urls < <(jq -r '.apps[].url' <<< "$responseJson")

    appsList=()
    for ((i=0; i<${#names[@]}; i++)); do
      appsList+=("${names[i]} | ${summarys[i]}")
    done

    if [ ${#names[@]} -ge 1 ]; then
      buttons=("<Select>" "<Back>")
      if menu appsList buttons; then
        appName="${names[selected]}"
        appUrl="${urls[selected]}"
        pkg=$(basename "$appUrl" 2>/dev/null)
        echo -e "url: ${Blue}$appUrl${Reset}\npkg: $pkg"
        return
      else
        return 1
      fi
    else
      return 1
    fi
  else
    return 1
  fi
}

dlFDroid() {
  while true; do
    dlUtility=${1:-curl}
    if [ "$dlUtility" == "curl" ]; then
      curl -L -C - --progress-bar -o "$filePath" "$dlUrl"
      [ $? -eq 0 ] && break || sleep 5
    else
      if [ $isMacOS == true ]; then
        aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$fileName" -d "$Download" --ca-certificate="/etc/ssl/cert.pem" "$dlUrl"
        aria2c_exit_status=$?
      else
        aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$fileName" -d "$Download" "$dlUrl"
        aria2c_exit_status=$?
      fi
      [ $aria2c_exit_status -eq 0 ] && { echo; break; } || sleep 5
    fi
  done
}

FDroidVersionsList() {
  #responseJson=$(curl -sL https://f-droid.org/api/v1/packages/$pkg)
  responseJson=$(curl -sL "https://f-droid.org/en/packages/$pkg/" | pup 'ul.package-versions-list li.package-version json{}')  # | jq . > response.json
  #responseYml=$(curl -sL "https://gitlab.com/fdroid/fdroiddata/-/raw/master/metadata/$pkg.yml")  # pkg install yq | brew install yq
  versionsCount=$(jq 'length' <<< "$responseJson")
  if [ $versionsCount -ge 1 ]; then
    mapfile -t versionNames < <(jq -r '.[] | if .id == "latest" then .children[1].children[0].name else .children[0].children[0].name end' <<< "$responseJson")
    #mapfile -t versionNames < <(yq eval '.Builds[].versionName' - <<< "$responseYml" | tail -r)
    mapfile -t versionCodes < <(jq -r '.[] | if .id == "latest" then .children[1].children[1].name else .children[0].children[1].name end' <<< "$responseJson")
    #mapfile -t versionCodes < <(yq eval '.Builds[].versionCode' - <<< "$responseYml" | tail -r)
    suggestedVersionCode=$(jq -r '.[] | select(.id == "latest") | .children[1].children[1].name' <<< "$responseJson")
    mapfile -t addedDates < <(jq -r '.[] | .children[]? | select(.class? == "package-version-header") | .text' <<< "$responseJson" | grep -o 'Added on [A-Za-z 0-9,]*')
    mapfile -t pkgNativeCodes < <(jq -r '.[] | .children[]? | select(.class? == "package-version-nativecode") | .children[]?.text?' <<< "$responseJson")
    #mapfile -t pkgNativeCodes < <(yq eval '.Builds[] | .gradleprops[] | select(contains("ABI_FILTERS")) | sub("ABI_FILTERS=", "")' - <<< "$responseYml" | tail -r)
    mapfile -t pkgVersionRequirement < <(jq -r '.[] | .children[]? | select(.class? == "package-version-requirement") | .text?' <<< "$responseJson" | sed 's/This version requires //' | sed 's/\.$//')
    permissionLabel=$(jq -r --arg vCode "$suggestedVersionCode" '.[] | select((.children[]? | select(.class? == "package-version-header") | .children[]?.name? // empty) == $vCode) | .. | objects | select(.class? == "permission-label") | .text' <<< "$responseJson")
    permissionLabelWithDescription=$(jq -r --arg vCode "$suggestedVersionCode" '.[] | select((.children[]? | select(.class? == "package-version-header") | .children[]?.name? // empty) == $vCode) | .children[]?.children[]?.children[]? | select(.class? == "package-version-permissions-list") | .children[] | {label: (.children[]? | select(.class? == "permission-label") | .text), desc: (.children[]? | select(.class? == "permission-description") | .text)} | "\(.label): \(.desc)"' <<< "$responseJson")
    mapfile -t APKdlUrls < <(jq -r '.[] | .children[]? | select(.class? == "package-version-download") | .children[]?.children[]?.href?' <<< "$responseJson" | grep "\.apk$")
    mapfile -t APKdlSizes < <(jq -r '.[] | .children[]? | select(.class? == "package-version-download") | .text' <<< "$responseJson" | grep -o '[0-9.]\+ MiB')
    declare -a versionsList
    isSuggested=0
    for ((i=0; i<$versionsCount; i++)); do
      if [ "${pkgNativeCodes[i]}" == "$cpuAbi" ] && [ $isSuggested -eq 0 ]; then
        versionsList+=("${versionNames[i]} (${versionCodes[i]}) suggested | ${pkgNativeCodes[i]} | ${pkgVersionRequirement[i]} | ${APKdlSizes[i]} | ${addedDates[i]}")
        isSuggested=1
      else
        versionsList+=("${versionNames[i]} (${versionCodes[i]}) | ${pkgNativeCodes[i]} | ${pkgVersionRequirement[i]} | ${APKdlSizes[i]} | ${addedDates[i]}")
      fi
    done
    buttons=("<Select>" "<Back>")
      if menu versionsList buttons; then
        versionName="${versionNames[selected]}"
        versionCode="${versionCodes[selected]}"
        pkgNativeCode="${pkgNativeCodes[selected]}"
        APKdlSize="${APKdlSizes[selected]}"
        APKdlSizeN=$(awk '{print $1}' <<< "$APKdlSize")
        #dlUrl="https://f-droid.org/repo/${pkg}_${versionCode}.apk"
        dlUrl="${APKdlUrls[selected]}"
        fileName="${appName}_v$versionName-$versionCode.apk"
        filePath="$Download/$fileName"
        echo -e "dlUrl: ${Blue}$dlUrl${Reset}"
        [ $APKdlSizeN -le 25 ] && dlFDroid || dlFDroid "aria2c"
        return
      else
        return 1
      fi
  else
    return 1
  fi
}
###############################################################################################################################################################################################################