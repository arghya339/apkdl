#!/bin/bash

oidPackagesIndex() {
  #$baseUrl/fdroid/index/apk/$pkg
  packagesJson=$(curl -sL "$baseUrl/fdroid/api/v1/packages/$pkg")
  mapfile -t versionNames < <(jq -r '.packages[].versionName' <<< "$packagesJson")
  mapfile -t versionCodes < <(jq -r '.packages[].versionCode' <<< "$packagesJson")
  declare -a versionsList
  for ((i=0; i<${#versionNames[@]}; i++)); do
    versionsList+=("${versionNames[i]} (${versionCodes[i]})")
  done
  buttons=("<Select>" "<Back>")
  if menu versionsList buttons; then
    versionName="${versionNames[selected]}"
    versionCode="${versionCodes[selected]}"
    dlUrl="$baseUrl/fdroid/repo/${pkg}_$versionCode.apk"
    fileName="${appName}_v$versionName-$versionCode.apk"
    filePath="$Download/$fileName"
    echo -e "dlUrl: ${Blue}$dlUrl${Reset}\nfileName: $fileName"
    return
  else
    return 1
  fi
}

IzzyOnDroidSearch() {
  baseUrl="https://apt.izzysoft.de"
  buttons=("<IzzyOnDroid>" "<F-Droid Archive>"); confirmPrompt "Select repo:" "buttons" && repo=iod || repo=archive
  while true; do read -r -p ">> Enter appName: " appName; [[ "$appName" =~ ^[Qq] ]] && appName=; break; [ -n "$appName" ] && break || echo -e "$notice Please enter a valid appName!"; done
  if [ -n "$appName" ]; then
    app_name=$(echo "$appName" | sed 's/ /+/g')
    page=1
    appsPerPage=10  # possible value: 10 / 25 / 50 / 100
    while true; do
      searchUrl="$baseUrl/fdroid/index.php/list/page/$page?repo=$repo;searchterm=$app_name;doFilter=1;limit=$appsPerPage"
      izzysoftHTML=$(curl -sL "$searchUrl")
      approwJson=$(pup 'div.approw json{}' <<< "$izzysoftHTML") && echo $approwJson > approw.json
      mapfile -t appNames < <(jq -r '.. | select(.class? == "boldname") | .text' <<< "$approwJson")  # appName
      mapfile -t versionAddeds < <(jq -r '.. | select(.class? == "minor-details") | .text | select(test(" / [0-9]{4}-[0-9]{2}-[0-9]{2}"))' <<< "$approwJson")  # versionName / addedOn
      mapfile -t versionNames < <(jq -r '.. | select(.class? == "minor-details") | .text | select(test(" / [0-9]{4}")) | split(" / ")[0]' <<< "$approwJson")  # versionName
      mapfile -t addedOns < <(jq -r '.. | select(.class? == "minor-details") | .text | select(test(" / [0-9]{4}")) | split(" / ")[1]' <<< "$approwJson")  # addedOn
      mapfile -t Licenses < <(jq -r '.. | select(.class? == "minor-details") | .text | select(test(" / [0-9]{4}") | not)' <<< "$approwJson")  # License
      mapfile -t Descriptions < <(jq -r '.. | select(.class? == "appdetailcell" and .text?) | .text' <<< "$approwJson")  # appDescription
      mapfile -t detailsUrls < <(jq -r '.. | select(.text? == "Details") | .href' <<< "$approwJson")  # Details Url
      mapfile -t downloadUrls < <(jq -r '.. | select(.text? == "Download") | .href' <<< "$approwJson")  # Download Url
      mapfile -t webUrls < <(jq -r '.. | select(.text? == "Web") | .href' <<< "$approwJson")  # Web Url
      mapfile -t sourceUrls < <(jq -r '.. | select(.text? == "Source") | .href' <<< "$approwJson")  # SourceCode Url
      mapfile -t trackerUrls < <(jq -r '.. | select(.text? == "Tracker") | .href' <<< "$approwJson")  # issueTracker Url
      mapfile -t changelogUrls < <(jq -r '.. | select(.text? == "Changelog") | .href' <<< "$approwJson")  # Changelog Url
      appsList=()
      for ((i=0; i<${#appNames[@]}; i++)); do
        appsList+=("${appNames[i]} | ${Descriptions[i]} | ${versionAddeds[i]}")
      done
      pagerrowJson=$(pup 'div.pagerrow json{}' <<< "$izzysoftHTML" | jq -r '.[].children.[].children.[]')
      firstUrl=$(jq 'select(.children?[0].alt? == "|«") | .href' <<< "$pagerrowJson")  # firstPageUrl
      leftUrl=$(jq 'select(.children?[0].alt? == "«") | .href' <<< "$pagerrowJson")  # prevPageUrl
      rightUrl=$(jq 'select(.children?[0].alt? == "»") | .href' <<< "$pagerrowJson")  # nextPageUrl
      lastUrl=$(jq 'select(.children?[0].alt? == "»|") | .href' <<< "$pagerrowJson")  # lastPageUrl
      [ -n "$firstUrl" ] && appsList+=(First)
      [ -n "$leftUrl" ] && appsList+=(Prev)
      [ -n "$rightUrl" ] && appsList+=(Next)
      [ -n "$lastUrl" ] && appsList+=(Last)
      buttons=("<Select>" "<Back>")
      if menu appsList buttons; then
        if [ "${appsList[selected]}" == "First" ]; then
          page=1
        elif [ "${appsList[selected]}" == "Prev" ]; then
          ((page--))
        elif [ "${appsList[selected]}" == "Next" ]; then
          ((page++))
        elif [ "${appsList[selected]}" == "Last" ]; then
          page=$(awk -F'/page/|\\?' '{print $2}' <<< "$lastUrl")
        else
          downloadUrl="${downloadUrls[selected]}"
          [ "$repo" == "iod" ] && dlUrl="$baseUrl/fdroid/$downloadUrl" || dlUrl="$downloadUrl"
          pkg=$(basename "$dlUrl" | cut -d'_' -f1)
          appName="${appNames[selected]}"
          versionName="${versionNames[selected]}"
          versionCode="${versionCodes[selected]}"
          [ -z "$versionCode" ] && { versionCode="${downloadUrl##*_}"; versionCode="${versionCode%.apk}"; } 
          sourceUrl=${sourceUrls[selected]}
          if [ "$repo" == "iod" ]; then
            echo -e "sourceUrl: $sourceUrl\npkgName: $pkg"
            oidPackagesIndex
          else
            echo -e "dlUrl: ${Blue}$dlUrl${Reset}\nsourceUrl: $sourceUrl\npkgName: $pkg"
            fileName="${appName}_v$versionName-$versionCode.apk"
            filePath="$Download/$fileName"
            echo "fileName: $fileName"
          fi
          return
          break
        fi
      else
        return 1
      fi
    done
  else
    return 1
  fi
}; IzzyOnDroidSearch

dlAppGallery() {
  [ $isAndroid -eq 1 ] && termux-open-url "https://appgallery.huawei.com"
  [ $isMacOS -eq 1 ] && open "https://appgallery.huawei.com"
  while true; do read -r -p ">> Enter appId: " appId; [[ "$appId" =~ ^[Qq] ]] && appId=; break; [ -n "$appId" ] && break || echo -e "$notice Please enter a valid appId!"; done
  if [ -n "$appId" ]; then
    dlUrl=$(curl -s -D - -o /dev/null "https://appgallery.cloud.huawei.com/appdl/$appId" | grep -i "location:" | head -1 | sed 's/location: //i' | tr -d '\r')  # make GET request but only show response headers
    fileName=$(echo "$dlUrl" | sed 's/.*\///; s/\?.*//')  # extract everything between last / and ?
    filePath="$Download/$fileName"
    return
  else
    return 1
  fi
}; dlAppGallery #C101184875
###############################################################################################################################################################################################################