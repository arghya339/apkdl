#!/bin/bash

# Copyright (C) 2025, Arghyadeep Mondal <github.com/arghya339>

curl -sL https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/auth.sh -o $apkdl/auth.sh
source $apkdl/auth.sh

# src: https://gitlab.com/AuroraOSS/gplayapi/-/tree/master/lib/src/main/java/com/aurora/gplayapi/GooglePlayApi.kt  # src: https://github.com/whyorean/GPlayApi/blob/master/src%2Fmain%2Fjava%2Fcom%2Faurora%2Fgplayapi%2FGooglePlayApi.kt
baseUrl="https://android.clients.google.com"
fdfeUrl="$baseUrl/fdfe"
tocUrl="$fdfeUrl/toc"
acceptTosUrl="$fdfeUrl/acceptTos"
searchUrl="$fdfeUrl/search"
searchListUrl="$fdfeUrl/searchList"
detailsUrl="$fdfeUrl/details"
bulkDetailsUrl="$fdfeUrl/bulkDetails"
acquireUrl="$fdfeUrl/acquire"
purchaseUrl="$fdfeUrl/purchase"
purchaseHistoryUrl="$fdfeUrl/purchaseHistory"
deliveryUrl="$fdfeUrl/delivery"

# src: https://gitlab.com/AuroraOSS/gplayapi/-/blob/master/lib/src/main/java/com/aurora/gplayapi/data/providers/HeaderProvider.kt
Headers=(
  -H "Authorization: Bearer $authToken"
  -H "User-Agent: $userAgentString"
  -H "X-DFE-Device-Id: $gsfId"
  -H "Accept-Language: en_US"
  -H "X-DFE-Client-Id: am-android-google"
  -H "X-DFE-Network-Type: 4"
  -H "X-DFE-Content-Filters: "
  -H "X-Limit-Ad-Tracking-Enabled: false"
  -H "X-Ad-Id: "
  -H "X-DFE-UserLanguages: en_US"
  -H "X-DFE-Request-Params: timeoutMs=4000"
  -H "app: com.google.android.gms"
  -H "X-DFE-Locale: $Locales"
)
# -H "app: com.android.vending"
# -H "app: com.google.android.gms"

# Request toc (Table of Contents) to initialize a session and get session cookies
echo -e "$running Initializing fdfe session.."
[ -f cookies.txt ] && rm -f cookies.txt
curl -sL -c "cookies.txt" "$tocUrl" "${Headers[@]}" -H "Accept: application/x-protobuf" -o "toc.protobuf"
protoc --decode_raw < toc.protobuf > toc.txt && rm -f toc.protobuf
tosToken=$(awk -F'"' '/1 \{/{f1=1} f1&&/6 \{/{f6=1} f6&&/7: "/{print $2; exit}' toc.txt)  # tosToken (Terms of Service Token) is usually in field 7 of tocResponse
# Accept Google Play's Terms of Service
if [ -n "$tosToken" ]; then
  echo -e "$notice Terms of Service found! Accepting.."
  curl -sL -X POST "$acceptTosUrl" "${Headers[@]}" -b "cookies.txt" -d "tost=$tosToken" -d "toscme=false" -o /dev/null
  echo -e "$good Terms of Service accepted."
fi
rm -f toc.txt
Headers+=(-b "cookies.txt")

# src: https://gitlab.com/AuroraOSS/AuroraStore/-/blob/master/app/src/main/java/com/aurora/store/util/CommonUtil.kt
humanReadableForm() {
  sizeB=$1
  sizeB=${sizeB#-}
  if [ $sizeB -ge 1073741824 ]; then
    echo "$((sizeB/1073741824)) GB"
  elif [ $sizeB -ge 1048576 ]; then
    echo "$((sizeB/1048576)) MB"
  elif [ $sizeB -ge 1024 ]; then
    echo "$((sizeB/1024)) KB"
  else
    echo "${sizeB} B"
  fi
}

detailsList() {
  local rawProto="${1}"
  declare -g -a pkgs  # declares empty global array
  pkgs=($(grep -o 'doc=[^"&]*' <<< "$rawProto" | cut -d= -f2 | awk '!seen[$0]++'))
  declare -g -a names offeredBys offerTypes appIconUrls versionCodes versionNames downloadSizes downloads lastUpdates targetAPILevels categorys containsAds dlCountsShorts starRatings contentRatings shortDescriptions
  for ((i=0; i<${#pkgs[@]}; i++)); do
    name=$(grep -A 10 "${pkgs[i]}" <<< "$rawProto" | grep -m 1 '5: "' | cut -d'"' -f2)
    [ -n "$name" ] && names+=("$name") || names+=("N/A")
    offeredBy=$(grep -A 10 "${pkgs[i]}" <<< "$rawProto" | grep -m 1 '6: "' | cut -d'"' -f2)
    [ -n "$offeredBy" ] && offeredBys+=("$offeredBy") || offeredBys+=("N/A")
    offerType=$(grep -A 20 "${pkgs[i]}" <<< "$rawProto" | grep -A 5 '8 {' | grep -m 1 '8:' | tr -d ' ' | cut -d':' -f2)
    [ -n "$offerType" ] && offerTypes+=($offerType) || offerTypes+=("N/A")
    appIconUrl=$(awk -v p="${pkgs[i]}" '$0~"1: \""p"\""{f=1} /1: ".*"/&&!($0~p){f=0} f&&/10 \{/{b=1;i=0} f&&b&&/1: 4/{i=1} f&&i&&/5: "/{gsub(/.*5: "|"[[:space:]]*$/,"");print;exit}' <<< "$rawProto")
    [ -n "$appIconUrl" ] && appIconUrls+=("$appIconUrl") || appIconUrls+=("N/A")
    versionCode=$(grep -A 200 "${pkgs[i]}" <<< "$rawProto" | grep -A 5 '13 {' | grep -A 2 '1 {' | grep -m 1 '3:' | tr -d ' ' | cut -d':' -f2)
    [ -n "$versionCode" ] && versionCodes+=("$versionCode") || versionCodes+=("N/A")
    versionName=$(grep -A 300 "${pkgs[i]}" <<< "$rawProto" | grep -A 5 '13 {' | grep -m 1 '4: "' | cut -d'"' -f2)
    [ -n "$versionName" ] && versionNames+=("$versionName") || versionNames+=("N/A")
    downloadSize=$(grep -A 500 "${pkgs[i]}" <<< "$rawProto" | grep -A 20 '13 {' | grep -m 1 '9:' | tr -d ' ' | cut -d':' -f2)
    [ -n "$downloadSize" ] && downloadSizes+=("$downloadSize") || downloadSizes+=("N/A")
    download=$(grep -A 500 "${pkgs[i]}" <<< "$rawProto" | grep -m 1 "downloads" | cut -d'"' -f2)
    [ -n "$download" ] && downloads+=("$download") || downloads+=("N/A")
    lastUpdate=$(grep -A 600 "${pkgs[i]}" <<< "$rawProto" | grep -A 50 '13 {' | grep -m 1 '16: "' | cut -d'"' -f2)
    [ -n "$lastUpdate" ] && lastUpdates+=("$lastUpdate") || lastUpdates+=("N/A")
    targetAPILevel=$(awk -v p="${pkgs[i]}" '$0~"1: \""p"\""{f=1} f&&/13 \{/{b=1} f&&b&&/32:/{print $2;exit}' <<< "$rawProto")
    [ -n "$targetAPILevel" ] && targetAPILevels+=("$targetAPILevel") || targetAPILevels+=("N/A")
    category=$(grep -A 800 "${pkgs[i]}" <<< "$rawProto" | grep -A 100 '13 {' | grep -m 1 '48: "' | cut -d'"' -f2)
    [ -n "$category" ] && categorys+=("$category") || categorys+=("N/A")
    containAds=$(grep -A 800 "${pkgs[i]}" <<< "$rawProto" | sed '/14 {/q' | grep '30: "' | cut -d'"' -f2)
    [ -n "$containAds" ] && containsAds+=("$containAds") || containsAds+=("N/A")
    dlCountShort=$(grep -A 800 "${pkgs[i]}" <<< "$rawProto" | sed '/14 {/q' | grep '61: "' | cut -d'"' -f2)
    [ -n "$dlCountShort" ] && dlCountsShort+=("$dlCountShort") || dlCountsShort+=("N/A")
    starRating=$(grep -A 1000 "${pkgs[i]}" <<< "$rawProto" | grep -A 5 '14 {' | grep -m 1 '17: "' | cut -d'"' -f2)
    [ -n "$starRating" ] && starRatings+=("$starRating") || starRatings+=("N/A")
    contentRating=$(grep -A 1200 "${pkgs[i]}" <<< "$rawProto" | grep -A 20 '15 {' | grep -A 5 '29 {' | grep -m 1 '1: "' | cut -d'"' -f2)
    [ -n "$contentRating" ] && contentRatings+=("$contentRating") || contentRatings+=("N/A")
    shortDescription=$(grep -A 1500 "${pkgs[i]}" <<< "$rawProto" | grep -m 1 '27: "' | cut -d'"' -f2)
    [ -n "$shortDescription" ] && shortDescriptions+=("$shortDescription") || shortDescriptions+=("N/A")
  done
}

# src: https://gitlab.com/AuroraOSS/gplayapi/-/blob/master/lib/src/main/java/com/aurora/gplayapi/helpers/SearchHelper.kt
gPlayApiSearchApps() {
  while true; do read -r -p ">> Enter appName: " inputAppName; [[ "$inputAppName" =~ ^[Qq] ]] && inputAppName=; break; [ -n "$inputAppName" ] && break || echo -e "$notice Please enter a valid appName!"; done
  
  if [ -n "$inputAppName" ]; then
    query=$(echo "$inputAppName" | sed 's/ /+/g')
    page=1
    searchAppsUrl=("$searchUrl?q=${query}&c=3&ksm=1")
    while true; do
      curl -sL "${searchAppsUrl[$((page-1))]}" "${Headers[@]}" -H "Accept: application/x-protobuf" -o "search.protobuf"
      search=$(protoc --decode_raw < search.protobuf) && rm -f search.protobuf
      detailsList "$search"
      declare -a appInfo offerTypesS containsAdsS
      for ((i=0; i<${#pkgs[@]}; i++)); do
        [ ${offerTypes[i]} -eq 1 ] && offerTypesS+=(Free) || offerTypesS+=(Paid)
        [ -n "${containsAds[i]}" ] && containsAdsS+=(containsAds) || containsAdsS+=(containsNoAds)
        appInfo+=("${names[i]} | ${offeredBys[i]} | ${dlCountsShort[i]} | ${starRatings[i]} | ${offerTypesS[i]} | ${containsAdsS[i]} | $(humanReadableForm ${downloadSizes[i]}) | ${categorys[i]}")
      done
      if [ $page -gt 2 ]; then
        appInfo+=(First)
      elif [ $page -ne 1 ]; then
        appInfo+=(Prev)
      fi
      nextPage=$(awk -F'"' '/getCluster\?enpt=/ {print $2}' <<< "$search")  # nextPage start with getCluster?enpt=
      if [ -n "$nextPage" ]; then
        nextPageUrl="$searchUrl/$nextPage"
        curl -sL "$nextPageUrl" "${Headers[@]}" -H "Accept: application/x-protobuf" -o nextPage.protobuf
        protoc --decode_raw < nextPage.protobuf > nextPage.txt && rm -f nextPage.protobuf
        if ! grep -q "Server busy, please try again later." nextPage.txt; then
          appInfo+=(Next)
          searchAppsUrl[page]="$nextPageUrl"
        fi
        rm -f nextPage.txt
      fi
      if [ ${#pkgs[@]} -eq 1 ]; then
        pkg="${pkgs[0]}"
        break
      else
        buttons=("<Select>" "<Back>"); if menu "appInfo" "buttons" "10"; then selected=${selected}; else break; fi
        if [ "${appInfo[selected]}" == "First" ]; then
          page=1
          continue
        elif [ "${appInfo[selected]}" == "Prev" ]; then
          [ $page -gt 1 ] && ((page--))
          continue
        elif [ "${appInfo[selected]}" == "Next" ]; then
          ((page++))
          continue
        else
          pkg="${pkgs[selected]}"
          break
        fi
      fi
    done
    [ -n "$pkg" ] && return 0 || return 1
  else
    return 1
  fi
}

# src: https://gitlab.com/AuroraOSS/gplayapi/-/blob/master/lib/src/main/java/com/aurora/gplayapi/helpers/AppDetailsHelper.kt
gPlayApiAppDetails() {
  curl -sL "$detailsUrl?doc=${pkg}" "${Headers[@]}" -H "Accept: application/x-protobuf" -o "details.protobuf"
  protoc --decode_raw < details.protobuf > details.txt && rm -f details.protobuf && details=$(cat details.txt) && rm -f details.txt
  packageName=$(awk -F'"' '/ *1: "/ {print $2; exit}' <<< "$details")  # packageName
  appName=$(awk -F'"' '/ *5: "/ {print $2; exit}' <<< "$details")  # appName
  offeredBy=$(awk -F'"' '/ *6: "/ {print $2; exit}' <<< "$details")  # offeredBy
  #awk -F'"' '/ *7: "/ {print $2; exit}' <<< "$details"  # Description
  offerType=$(awk '/^      8 {/ {f=1} f && /8: / {print $2; exit}' <<< "$details")  # offerType: 1=free
  appIconUrl=$(awk '/10 \{/{in_block=1; is_icon=0} in_block && /1:[[:space:]]*4/{is_icon=1} in_block && is_icon && /5:[[:space:]]*"/{gsub(/.*5:[[:space:]]*"|"[[:space:]]*$/, ""); print; exit}' <<< "$details")  # appIcon Url
  versionCode=$(awk '/13 {/{found=1} found && /3: [0-9]+/{print $2; exit}' <<< "$details")  # versionCode
  versionName=$(awk -F'"' '/ *4: "/ {print $2; exit}' <<< "$details")  # versionName
  #awk -F'"' '/ *10: "/ {print $2}' <<< "$details"  # permission
  permissions=$(awk -F'"' '/ *10: "/ {print "\"" $2 "\""}' <<< "$details" | tr '\n' ',' | sed 's/,$//')  # "perm1","perm2","perm3"
  developerEmail=$(awk -F'"' '/ *11: "/ {print $2; exit}' <<< "$details")  # developerEmail
  developerWebsite=$(awk -F'"' '/ *12: "/ {print $2; exit}' <<< "$details")  # developerWebsite
  downloadsCount=$(awk -F'"' '/ *13: "/ {print $2; exit}' <<< "$details")  # downloadsCount
  Changelog=$(awk -F'"' '/ *13 {/ {in_details=1} in_details && / *15: "/ {print $2; exit}' <<< "$details")  # Changelog
  #awk -F'"' '/ *16: "/ {print $2; exit}' <<< "$details"  # lastUpdated
  GAME=$(sed -n '/53 {/,/}/p' <<< "$details" | grep '1: "' | cut -d'"' -f2)
  Files=("${packageName}")
  if [ -n "$GAME" ]; then
    Files+=("${packageName}")
    ext="obb"
  else
    Files+=($(awk -F'"' ' / *17 {/ {in_split_block=1} / *}/    {in_split_block=0} in_split_block && / *4: "/ {print $2} ' <<< "$details"))  # Files: ${pkg}.${versionCode}.apk, config.*dpi.$versionCode.apk, config.${abi}.$versionCode.apk
    #Files+=($(awk -F'"' '/34 {/{f=1;c=0} f{t=$0;c+=gsub(/{/,"",t);c-=gsub(/}/,"",t);if($0~/11: "/)print $2;if(c<=0)f=0}' <<< "$details"))
    ext="apk"
  fi
  filesSize=($(awk '/17 \{/ {flag=1} /}/ {flag=0} flag && /3:/ {print $2}' <<< "$details"))  # filesSize
  containsAds=$(awk -F'"' '/30: "/ {print $2}' <<< "$details")
  #awk -F'"' '/ *11: "pub:/ {print $2; exit}' <<< "$details"  # pub
  dlCountShort=$(awk -F'"' '/ *61: "/ {print $2; exit}' <<< "$details")  # dlCountShort
  [ -z "$dlCountShort" ] && dlCountShort=$(awk -F'"' '/ *77: "/ {print $2; exit}' <<< "$details")
  lastUpdates=$(awk -F'"' '/ *64 \{/ { in_block=1 }in_block && / *1: "/ { print $2; exit }' <<< "$details")  # lastUpdates
  targetAPILevel=$(grep -A 100 "13 {" <<< "$details" | grep -m 1 "32:" | awk '{print $2}')  # targetAPILevel
  #awk '/ *9 \{/ { in_cat=1; depth=0; next } in_cat { if ($0 ~ /\{/) depth++; if ($0 ~ /\}/) { if (depth == 0) in_cat=0; else depth-- } if (depth == 1 && $0 ~ / *1: "/) { s=$0; sub(/.*1: "/, "", s); sub(/"$/, "", s); print s } }' <<< "$details"  # catagoryTagName
  InAppPurchases=$(awk '/ *67: "/ { s=$0; sub(/.*: "/, "", s); sub(/"$/, "", s); print s }' <<< "$details")  # In-AppProductPriceRange
  downloadSize=$(awk '/13 \{/{a=1} a && /1 \{/{b=1} a && b && /9:/{print $2; exit}' <<< "$details")  # downloadSize
  minAndroid=$(awk '/ *82 \{/ { in_82=1 } in_82 && / *1 \{/ { in_inner=1 } in_inner && / *1: "/ { s=$0; sub(/.*: "/, "", s); sub(/"$/, "", s); print s; in_inner=0; in_82=0 }' <<< "$details")  # requiredOS
  #awk '/ *86 \{/ { in_dev=1; next } in_dev && / *\}/ { in_dev=0 } in_dev { if ($0 ~ / *: "/) { val=$0; sub(/.*: "/, "", val); sub(/"$/, "", val); if ($1 == "1:") print "Name: " val; if ($1 == "2:") print "Email: " val; if ($1 == "3:") print "Address: " val; if ($1 == "4:") print "Phone: " val } }' <<< "$details"  # aboutDeveloper
  starRating=$(awk '/ *14 \{/ { in_14=1; next } in_14 && / *\}/ { in_14=0 } in_14 && / *17: "/ { val=$0; sub(/.*17: "/, "", val); sub(/"$/, "", val); print val }' <<< "$details")  # starRating
  #[ -z "$starRating" ] && starRating=$(awk -F'"' '/14 {/,/}/ {if ($0 ~ /17:/) print $2}' <<< "$details")
  reviewCountShort=$(sed -n '/14 {/,/}/p' <<< "$details" | grep '18: "' | cut -d'"' -f2)
  contentRating=$(awk '/ *15 \{/ { in_15=1 } in_15 && / *29 \{/ { in_29=1 } in_29 && / *1: "/ { s=$0; sub(/.*: "/, "", s); sub(/"$/, "", s); print s; in_29=0 }' <<< "$details")  # contentRating
  #awk '/ *39 \{/ { in_39=1; depth=0; next } in_39 { if ($0 ~ /\{/) depth++; if ($0 ~ /\}/) { if (depth == 0) in_39=0; else depth-- } if (depth == 0) { if ($0 ~ / *1: "/) { s=$0; sub(/.*: "/, "", s); sub(/"$/, "", s); print "Type: " s } if ($0 ~ / *4: "/) { s=$0; sub(/.*: "/, "", s); sub(/"$/, "", s); print "Note: " s } } }' <<< "$details"  # featureTag & featureDescription
  #awk '/ *65 \{/ { in_65=1; depth=0; next } in_65 { if ($0 ~ /\{/) depth++; if ($0 ~ /\}/) { if (depth == 0) in_65=0; else depth-- } if (depth == 0 && $0 ~ / *1: "/) { s=$0; sub(/.*: "/, "", s); sub(/"$/, "", s); print s } }' <<< "$details"  # trandingTag
  appUrl=$(awk '/ *17: "https/ { s=$0; sub(/.*: "/, "", s); sub(/"$/, "", s); print s }' <<< "$details")  # appUrl
  #awk '/ *25 \{/ { in_25=1 } in_25 && / *2 \{/ { in_2=1 } in_2 && / *1: "/ { s=$0; sub(/.*: "/, "", s); sub(/"$/, "", s); print s } / *\}/ { if (in_2) in_2=0; else if (in_25) in_25=0 }' <<< "$details"  # In-appPurchases
  releasedOn=$(awk '/ *25 \{/ { in_25=1 } in_25 && / *2 \{/ { in_item=1; is_target=0 } in_item && / *1: "Released on"/ { is_target=1 } in_item && is_target && / *3 \{/ { in_val=1 } in_val && / *2: "/ { s=$0; sub(/.*: "/, "", s); sub(/"$/, "", s); print s; exit }' <<< "$details")  # releasedOn
  shortDescription=$(awk '/ *27: "/ { s=$0; sub(/.*: "/, "", s); sub(/"$/, "", s); print s }' <<< "$details")  # shortDescription
  echo -e "$info appName: $appName"
  echo -e "$info offeredBy: $offeredBy"
  echo -e "$info packageName: $packageName"
  echo -e "$info Version: $versionName ($versionCode)"
  [ $offerType -eq 1 ] && echo -e "$info offerType: Free" || echo -e "$info offerType: Paid"

  echo -e "$info starRating: ${starRating}★"
  echo -e "$info reviewCountShort: $reviewCountShort"
  echo -e "$info downloadCount: $dlCountShort ($downloadsCount)"
  echo -e "$info downloadSize: $(humanReadableForm $downloadSize)"
  echo -e "$info lastUpdates: $lastUpdates"
  echo -e "$info Changelog: $Changelog"
  echo -e "$info shortDescription: $shortDescription"
  [ -n "$GAME" ] && echo -e "$info TYPE: $GAME" || echo -e "$info TYPE: APPLICATION"
  filenames=("${Files[0]}.${versionCode}.apk")
  for ((i=1; i<${#Files[@]}; i++)); do
    filenames+=(${Files[i]}.${versionCode}.$ext)
  done
  echo -e "$info FilesInfo:"
  for ((i=0; i<${#Files[@]}; i++)); do
    echo "${filenames[i]} | $(humanReadableForm ${filesSize[i]})"
  done
  [ -n "$containsAds" ] && echo -e "$info containsAds: Yes" || echo -e "$info containsAds: No"
  echo -e "$info contentRating: $contentRating"
  echo -e "$info InAppPurchases: $InAppPurchases"
  echo -e "$info releasedOn: $releasedOn"
  echo -e "$info minAndroid: $minAndroid"

  { [ -n $developerWebsite ] && grep -q "http" <<< "$developerWebsite"; } && echo -e "$info developerWebsite: ${Blue}$developerWebsite${Reset}"
  echo -e "$info developerEmail: $developerEmail"
  echo -e "$info appUrl: ${Blue}$appUrl${Reset}"
}

gPlayApiAppsDetails() {
  pkgnames=("$@")  # collect all arguments as pkgnames array
  echo -e "$running Get Installed packages updates.."
  curl -sL https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/genProtoBin.sh -o "$apkdl/genProtoBin.sh"
  source $apkdl/genProtoBin.sh
  genBulkDetailsProtoBin
  curl -sL -X POST "$bulkDetailsUrl" "${Headers[@]}" -H "Content-Type: application/x-protobuf" --data-binary @bulkDetails.bin -o "bulkDetails.protobuf"  # Send Request
  rm -f bulkDetails.bin
  bulkDetails=$(protoc --decode_raw < bulkDetails.protobuf) && rm -f bulkDetails.protobuf  # Decode Response
  detailsList "$bulkDetails"
  echo -e "$info total-apps: ${#pkgnames[@]}\n$good found: ${#pkgs[@]}\n$notice not-found: $(( ${#pkgnames[@]} - ${#pkgs[@]}))"
}

gPlayApiAppsUpdates() {
  curl -sL https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/installedApps.sh -o "$apkdl/installedApps.sh"
  source $apkdl/installedApps.sh
  packagesInfo
  gPlayApiAppsDetails "${packages[@]}"
  declare -g -a installedVersions installedVersionCodes lastUpdates
  for i in ${!pkgs[@]}; do
    installedVersion=""; versionCode=""; lastUpdateTime=""
    for ((j=0; j<${#pkgnames[@]}; j++)); do
      if [ "${pkgs[i]}" == "${pkgnames[j]}" ]; then
        installedVersion="${iVersionNames[j]}"
        versionCode="${iVersionCodes[j]}"
        lastUpdateTime="${iLastUpdateTimes[j]}"
        break
      fi
    done
    installedVersions+=("$installedVersion")
    installedVersionCodes+=("$versionCode")
    lastUpdateTimes+=("$lastUpdateTime")
  done

  declare -g -a pnames apps
  for ((i=0; i<${#pkgs[@]}; i++)); do
    [ "${installedVersionCodes[i]}" -lt "${versionCodes[i]}" ] && { pnames+=(${pkgs[i]}); apps+=("${names[i]} (${pkgs[i]}) | ${installedVersions[i]} (${lastUpdateTimes[i]}) → ${versionNames[i]} (${lastUpdates[i]})"); }
  done
}

gPlayApiShowUpdates() {
  buttons=("<Select>" "<Back>")
  if [ ${#apps[@]} -ge 1 ]; then
    if menu "apps" "buttons"; then
      pkg="${pnames[selected]}"
      offerType=${offerTypes[selected]}
      appIconUrl="${appIconUrls[selected]}"
      versionCode="${versionCodes[selected]}"
      targetAPILevel=${targetAPILevels[selected]}
      installedVersionCode="${installedVersionCodes[selected]}"
      GAME=$(awk -v p="${pkg}" '$0~"1: \""p"\""{f=1} $0~/1: "com\./&&$0!~p&&$0!~/gms|vending|play\.games/{f=0;i=0} f&&/53 \{/{i=1} i&&/1:/{gsub(/"/,"",$2);print $2;exit}' <<< "$bulkDetails")
      Files=("${pkg}")
      if [ -n "$GAME" ]; then
        Files+=("${pkg}")
        ext="obb"
      else
        Files+=($(awk -v p="${pkg}" -F'"' '$0~"1: \""p"\""{f=1} $0~/1: "com\./&&$0!~p&&$0!~/gms|vending/{f=0} / *17 \{/{b=1} / *}/{b=0} f&&b&&/ *4: "/{print $2}' <<< "$bulkDetails"))
        ext="apk"
      fi
      filesSize=($(awk -v p="${pkg}" '$0~"1: \""p"\""{f=1} $0~/1: "com\./&&$0!~p&&$0!~/gms|vending/{f=0} /17 \{/{b=1} /}/{b=0} f&&b&&/3:/{print $2}' <<< "$bulkDetails"))
      filenames=("${Files[0]}.${versionCode}.apk")
      for ((i=1; i<${#Files[@]}; i++)); do
        filenames+=(${Files[i]}.${versionCode}.$ext)
      done
      return
    else
      return 1
    fi
  else
    return 1
  fi
}

genManifestJson() {
  [ -f $HOME/manifest.json ] && rm -f $HOME/manifest.json
  [ -f $HOME/icon.png ] && rm -f $HOME/icon.png
  locales_name=${Locales//_/-}
<<comment
  targetSDK=35
  case "$minAndroid" in
    "Android 5.0 and up") minSDK=21 ;;
    "Android 6.0 and up") minSDK=23 ;;
    "Android 7.0 and up") minSDK=24 ;;
    "Android 8.0 and up") minSDK=26 ;;
    "Android 9 and up") minSDK=28 ;;
    "Android 10 and up") minSDK=29 ;;
    "Android 11 and up") minSDK=30 ;;
    "Android 12 and up") minSDK=31 ;;
    "Android 12L and up") minSDK=32 ;;
    "Android 13 and up") minSDK=33 ;;
    "Android 14 and up") minSDK=34 ;;
    "Android 15 and up") minSDK=35 ;;
    "Android 16 and up") minSDK=36 ;;
  esac
comment
  curl -sL $appIconUrl -H "User-Agent: $userAgentString" -o $HOME/icon.png  # dlAppIcon
  cat > manifest.json << EOF
{
  "xapk_version":2,
  "package_name":"$packageName",
  "name":"${appName}",
  "locales_name":{"$locales_name":"${appName}"},
  "version_code":"$versionCode",
  "version_name":"$versionName",
  "min_sdk_version":"$minSdkVersion",
  "target_sdk_version":"$targetSdkVersion",
  "permissions":[${permissions}],
  "total_size":$downloadSize,
  "icon":"icon.png",
  "expansions":[{"file":"Android/obb/${packageName}/main.${versionCode}.${packageName}.obb","install_location":"EXTERNAL_STORAGE","install_path":"Android/obb/${packageName}/main.${versionCode}.${packageName}.obb"}],
  "split_apks":[{"file":"${packageName}","id":"base"}]
}
EOF
}

# src: https://gitlab.com/AuroraOSS/gplayapi/-/blob/master/lib/src/main/java/com/aurora/gplayapi/helpers/PurchaseHelper.kt
gPlayApiDownloadApp() {
  reqPatch=${1:-0}
  curl -sL https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/genProtoBin.sh -o "$apkdl/genProtoBin.sh"
  source $apkdl/genProtoBin.sh
  genAcquireProtoBin
  # Acquire request (associate specific app with specific Google account)
  curl -sL -X POST "$acquireUrl" "${Headers[@]}" -H "Content-Type: application/x-protobuf" --data-binary @acquire.bin -o acquire.protobuf
  rm -f acquire.bin
  # Acquire call will fail (return DF-DFERH-01) if already own the app
  protoc --decode_raw < acquire.protobuf > acquire.txt && rm -f acquire.protobuf
  grep -q "DF-DFERH-01" acquire.txt && echo -e "$notice $appName already acquire!" || echo -e "$good $appName acquire successfully."
  rm -f acquire.txt
  
  # Google's servers check their records. "Does this account have an entitlement for this app?" If acquire step was successful (or happened in past), answer is yes, and a delivery token is generated.
  # get Delivery Token using purchase endpoint
  curl -sL -X POST "$purchaseUrl" "${Headers[@]}" -H "Accept: application/x-protobuf" -d "doc=$pkg&ot=$offerType&vc=$versionCode" -o "purchase.protobuf"
  protoc --decode_raw < purchase.protobuf > purchase.txt && rm -f purchase.protobuf && purchase=$(cat purchase.txt) && rm -f purchase.txt
  # download credentials
  cookie=$(awk -F'"' '/^    55: "/ {print $2; exit}' <<< "$purchase")  # ANDROIDSECURE cookie (download cookie)
  token=$(awk '/5 \{/ {f=1} f && /2:/ {print $2; exit}' <<< "$purchase" | tr -d '"')  # Delivery Token
  { [ -n "$cookie" ] && [ -n "$token" ]; } && echo -e "$info cookie: $cookie\n$info token: $token"
  
  #echo -e "$notice purchaseHistory"
  #curl -sL -X GET "$purchaseHistoryUrl?o=0" "${Headers[@]}" -o "purchaseHistory.protobuf"  # offset=0 to start from beginning of purchase history
  #protoc --decode_raw < purchaseHistory.protobuf && rm -f purchaseHistory.protobuf

  # Request Delivery Data (URLs and File names)
  if [ $reqPatch -eq 0 ]; then
    dlUrl="$deliveryUrl?doc=${pkg}&ot=${offerType}&vc=${versionCode}&delivery_token=${token}"
  else
    dlUrl="$deliveryUrl?doc=$pkg&ot=$offerType&vc=$versionCode&bvc=$installedVersionCode&pf=1&delivery_token=$token"  # Receive a smaller patch file instead of full APK for app update. pf=patchFormat (GZIPPED_BSDIFF)
  fi
  curl -sL "$dlUrl" "${Headers[@]}" -H "Accept: application/x-protobuf" -o "delivery.protobuf"
  protoc --decode_raw < delivery.protobuf > delivery.txt && rm -f delivery.protobuf
  
  # Extract File Size, Download Url and File SHA-1 from delivery.txt
  sizes=($(awk '/2 \{/ {in_block=1} in_block && /1: [0-9]+/ {print $2; exit}' delivery.txt | tr -d '"'))  # base.apk fileSize
  urls=($(awk '/2 \{/ {in_block=1} in_block && /3:/ {print $2; exit}' delivery.txt | tr -d '"'))  # base.apk dlUrl
  Base64SHA=("$(awk '/2 \{/ {in_block=1} in_block && /2:/ {print $2; exit}' delivery.txt | tr -d '"')=")  # base.apk base64-encoded shasum1
  for ((c=1; c<${#Files[@]}; c++)); do
    if [ -n "$GAME" ]; then
      sizes+=("${filesSize[c]}")  # apk fileSize
      urls+=($(awk -v s="${filesSize[c]}" '$2==s {k=$1; gsub(/:/,"",k); t=k+1} t && $1==t":" {split($0,p,"\""); print p[2]; exit}' delivery.txt))  # obb dlUrl
      Base64SHA+=("$(grep -A 10 "${filesSize[c]}" delivery.txt | grep -m 1 "8: " | cut -d'"' -f2)=")  # obb base64-encoded shasum1
    else
      sizes+=($(awk -v target="${Files[c]}" '$0 ~ "1: \"" target "\"" {found=1} found && /2:/{print $2; exit}' delivery.txt))  # apk fileSize
      urls+=($(awk -v target="${Files[c]}" '$0 ~ "1: \"" target "\"" {found=1} found && /5: "https/ {split($0, a, "\""); print a[2]; exit}' delivery.txt))  # apk dlUrl
      Base64SHA+=("$(grep -A 5 "1: \"${Files[c]}\"" delivery.txt | grep -m 1 "4: " | cut -d'"' -f2)=")  # apk base64-encoded shasum1
    fi
  done
  rm -f delivery.txt
  
  # DOWNLOADING FILES
  [ -n "$GAME" ] && apk_ext="xapk" || apk_ext="apks"
  fileName="${appName}_v${versionName}-${versionCode}.$apk_ext"
  filePath="$Download/$fileName"
  if [ ! -f "$filePath" ]; then
    for ((i=0; i<${#Files[@]}; i++)); do
      echo -e "$running Downloading ${Red}${filenames[i]}${Reset} from ${Blue}${urls[i]}${Reset} fileSize ${Cyan}$(humanReadableForm ${sizes[i]})${Reset}"
      while true; do
        if [ $(( ${sizes[i]} / 1048576 )) -le 25 ]; then
          curl --progress-bar -L -C -  "${urls[i]}" --doh-url "$cloudflareDOH" -H "User-Agent: $userAgentString" --cookie "ANDROIDSECURE=${cookie}" -o "$HOME/${filenames[i]}"
          [ $? -eq 0 ] && break || sleep 5
        else
          if [ $isAndroid -eq 1 ]; then
            aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$HOME" -o "${filenames[i]}" -U "User-Agent: $userAgentString" --header="Cookie: ANDROIDSECURE=${cookie}" --async-dns=true  --async-dns-server="$cloudflareIP" "${urls[i]}"
            aria2ExitStatus=$?
          elif [ $isMacOS -eq 1 ]; then
            aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$HOME" -o "${filenames[i]}" -U "User-Agent: $userAgentString" --header="Cookie: ANDROIDSECURE=${cookie}" --ca-certificate="/etc/ssl/cert.pem" --async-dns=true  --async-dns-server="$cloudflareIP" "${urls[i]}"
            aria2ExitStatus=$?
          fi
          [ $aria2ExitStatus -eq 0 ] && { echo; break; } || sleep 5
        fi
      done
      remoteFileSHA=$(echo -n "${Base64SHA[i]}" | tr '_-' '/+' | base64 -d | xxd -p)  # convert Base64 SHA-1 to Hex SHA-1
      if [ $isAndroid -eq 1 ]; then
        downloadedFileSHA=$(sha1sum "${filenames[i]}" | cut -d' ' -f1)
      elif [ $isMacOS -eq 1 ]; then
        downloadedFileSHA=$(shasum -a 1 "${filenames[i]}" | cut -d' ' -f1)  # downloaded file hex sha1
      fi
      if [ "$remoteFileSHA" == "$downloadedFileSHA" ]; then
        echo -e "$good Downloaded file appears in the original state."
      else
        echo -e "$notice Look like downloaded file appears corrupted!"
        echo -e "$notice SHA1 SUM Diffs - Expected: ${Cyan}$remoteFileSHA${Reset} ~ Result: ${Cyan}$downloadedFileSHA${Reset}"
      fi
    done
  
    app_info=$($aapt2 dump badging "$HOME/${filenames[0]}" 2>/dev/null)
    minSdkVersion=$(awk -F"'" '/minSdkVersion/ {print $2}' <<< $app_info)
    targetSdkVersion=$(awk -F"'" '/^targetSdkVersion/ {print $2}' <<< $app_info)

    mkdir -p "$HOME/${appName}_v${versionName}-${versionCode}"
    if [ -n "$GAME" ]; then
      # Create XAPK
      genManifestJson
      mkdir -p "$HOME/${appName}_v${versionName}-${versionCode}/Android/obb/${packageName}"
      mv $HOME/${filenames[0]} "$HOME/${appName}_v${versionName}-${versionCode}/${packageName}.apk"
      mv $HOME/${filenames[1]} "$HOME/${appName}_v${versionName}-${versionCode}/Android/obb/${packageName}/main.${versionCode}.${packageName}.obb"
      mv $HOME/manifest.json "$HOME/${appName}_v${versionName}-${versionCode}/manifest.json"
      mv $HOME/icon.png "$HOME/${appName}_v${versionName}-${versionCode}/icon.png"
      echo -e "$running Creating XAPK archive.."
      #bsdtar --format=zip -c -f "$HOME/${appName}_v${versionName}-${versionCode}.xapk" -C "$HOME/${appName}_v${versionName}-${versionCode}" .  # zip compression without progress-bar
      #uncompressedSize=$(find "$HOME/${appName}_v${versionName}-${versionCode}" -type f -exec stat -f%z {} + | awk '{sum+=$1} END {print sum}')
      #bsdtar --format=zip -c -f - -C "$HOME/${appName}_v${versionName}-${versionCode}" . | pv -s "${uncompressedSize}" > "$HOME/${appName}_v${versionName}-${versionCode}.xapk"  # zip compression with progress-bar but wrong percentage (compressesSize < uncompressedSize)
      bsdtar --format=zip -c -f - -C "$HOME/${appName}_v${versionName}-${versionCode}" . | pv -t -b -r > "$HOME/${appName}_v${versionName}-${versionCode}.xapk"  # zip compression with progress-bar but no progress-bar percentage
      mv "$HOME/${appName}_v${versionName}-${versionCode}.xapk" "$Download/${appName}_v${versionName}-${versionCode}.xapk"
    elif [ ${#Files[@]} -ge 2 ]; then
      # Create APKS
      curl -sL https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/genTocPb.sh -o "$apkdl/genTocPb.sh"
      source $apkdl/genTocPb.sh
      mkdir -p "$HOME/${appName}_v${versionName}-${versionCode}/splits"
      mv $HOME/${filenames[0]} "$HOME/${appName}_v${versionName}-${versionCode}/splits/base-master.$ext"
      for ((i=1; i<${#Files[@]}; i++)); do
        mv $HOME/${filenames[i]} "$HOME/${appName}_v${versionName}-${versionCode}/splits/base-$(cut -d'.' -f2 <<< ${Files[i]}).$ext"
      done
      mv $HOME/toc.pb "$HOME/${appName}_v${versionName}-${versionCode}/toc.pb"
      echo -e "$running Creating APKS archive.."
      bsdtar --format=zip -c -f - -C "$HOME/${appName}_v${versionName}-${versionCode}" . | pv -t -b -r > "$HOME/${appName}_v${versionName}-${versionCode}.apks"
      mv "$HOME/${appName}_v${versionName}-${versionCode}.apks" "$Download/${appName}_v${versionName}-${versionCode}.apks"
    else
      mv $HOME/${filenames[0]} "$Download/${appName}_v${versionName}-${versionCode}.$ext"
    fi
    rm -rf "$HOME/${appName}_v${versionName}-${versionCode}"
  else
    echo -e "$notice Download skipped! ${appName}_v${versionName}-${versionCode}.$apk_ext already exists in $Download."
  fi
}

APKS2APK() {
  dlAPKEditor
  if [ $isMacOS -eq 1 ]; then
    java -jar $APKEditorPath m -i "$filePath" -o "${filePath%.*}.apk"
  elif [ $isAndroid -eq 1 ]; then
    $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $APKEditorPath m -i "$filePath" -o "${filePath%.*}.apk"
  fi
  rm -f "$filePath"
}
###############################################################################################################################################################################################################