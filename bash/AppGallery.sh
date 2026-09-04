#!/bin/bash

# Copyright (C) 2025, Arghyadeep Mondal <github.com/arghya339>

# --- sources: com/huawei/appgallery/serverreqkit/api/bean/BaseRequestBean.java/getContextMap() ---
deviceId="a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90"
appGalleryVersionName="16.6.1.300"  # https://appgallery.huawei.com/app/C27162
appGalleryVersionCode="100400301"
if [ $isAndroid == true ]; then
  manufacturer=$(getprop ro.product.manufacturer)
  model=$(getprop ro.product.model)
  majorAndroidVersion=$(getprop ro.build.version.release | cut -d. -f1)
  locale=$(getprop persist.sys.locale | awk -F'-' '{print $1"_"$2}')
  cpuAbi=$(getprop ro.product.cpu.abi)
elif [ -n "$serial" ]; then
  manufacturer=$(adb -s $serial shell getprop ro.product.manufacturer)
  model=$(adb -s $serial shell getprop ro.product.model)
  majorAndroidVersion=$(adb -s $serial shell getprop ro.build.version.release | cut -d. -f1)
  locale=$(adb -s $serial shell getprop persist.sys.locale | awk -F'-' '{print $1"_"$2}')
  cpuAbi=$(adb -s $serial shell getprop ro.product.cpu.abi)
else
  deviceInfoJson=$(curl -sL "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/deviceInfo.json")
  manufacturer=$(jq -r '.Build.MANUFACTURER' <<< "$deviceInfoJson")
  model=$(jq -r '.Build.MODEL' <<< "$deviceInfoJson")
  majorAndroidVersion=$(jq -r '.Build.VERSION.RELEASE' <<< "$deviceInfoJson" | cut -d. -f1)
  locale=$(jq -r '.Locales' <<< "$deviceInfoJson")
  cpuAbi="arm64-v8a"
fi
appGalleryUserAgent="HiSpace##${appGalleryVersionName}##${manufacturer}##${model}"
countryIsoCode=$(cut -d'_' -f2 <<< "$locale")
case "$countryIsoCode" in
  "CN") host="store-drcn.hispace.dbankcloud.com" ;;  # China
  "RU") host="store-drru.hispace.dbankcloud.ru" ;;  # Russia
  "AF"|"AM"|"AZ"|"BH"|"BD"|"BT"|"BN"|"KH"|"CY"|"GE"|"IN"|"ID"|"IR"|"IQ"|"IL"|"JP"|"JO"|"KZ"|"KW"|"KG"|"LA"|"LB"|"MY"|"MV"|"MN"|"MM"|"NP"|"KP"|"OM"|"PK"|"PS"|"PH"|"QA"|"SA"|"SG"|"KR"|"LK"|"SY"|"TJ"|"TH"|"TL"|"TR"|"TM"|"AE"|"UZ"|"VN"|"YE") host="store-dra.hispace.dbankcloud.com" ;;  # Asia (excluding CN)
  "AL"|"AD"|"AT"|"BY"|"BE"|"BA"|"BG"|"HR"|"CZ"|"DK"|"EE"|"FI"|"FR"|"DE"|"GR"|"HU"|"IS"|"IE"|"IT"|"LV"|"LI"|"LT"|"LU"|"MT"|"MD"|"MC"|"ME"|"NL"|"MK"|"NO"|"PL"|"PT"|"RO"|"SM"|"RS"|"SK"|"SI"|"ES"|"SE"|"CH"|"UA"|"GB"|"VA") host="store-dre.hispace.dbankcloud.com" ;;  # Europe (excluding RU)
  *) host="store-dre.hispace.dbankcloud.com" ;;  # Fallback to Global (EU) host
esac
if [ "$cpuAbi" == "arm64-v8a" ]; then
  appBits=2
elif [ "$cpuAbi" == "armeabi-v7a" ] || [[ "$cpuAbi" == x86* ]]; then
  appBits=1
else  # mipmap
  appBits=3
fi
clientCmd=(
  curl -sLX POST "https://${host}/hwmarket/api/clientApi"
  -H "User-Agent: $appGalleryUserAgent"
  -H "Accept: application/json"
  -H "Content-Type: application/x-www-form-urlencoded"
  --data-urlencode "brand=$manufacturer"
  --data-urlencode "deviceId=$deviceId"
  --data-urlencode "deviceIdType=9"
  --data-urlencode "firmwareVersion=$majorAndroidVersion"
  --data-urlencode "isFirstLaunch=1"
  --data-urlencode "locale=$locale"
  --data-urlencode "manufacturer=$manufacturer"
  --data-urlencode "needServiceZone=1"
  --data-urlencode "net=1"
  --data-urlencode "oobe=0"
  --data-urlencode "packageName=com.huawei.appmarket"
  --data-urlencode "phoneType=$model"                  
  --data-urlencode "serviceType=0"
  --data-urlencode "subBrand=0"
  --data-urlencode "ts=$(date +%s000)"
  --data-urlencode "version=$appGalleryVersionName"
  --data-urlencode "versionCode=$appGalleryVersionCode"
  --data-urlencode "zone=1"
)

# --- sources: com/huawei/appgallery/serverreqkit/api/bean/startup/StartupRequest.java ---
clientStartup() {
  clientJson=$("${clientCmd[@]}" --data-urlencode "method=client.front2" --data-urlencode "ver=1.1")
  rtnCode=$(jq -r '.rtnCode' <<< "$clientJson")
  if [ $rtnCode -eq 0 ]; then
    sign=$(jq -r '.sign' <<< "$clientJson")
    serviceZone=$(jq -r '.serviceZone' <<< "$clientJson")
  fi
}

# --- sources: com/huawei/appgallery/microsearch/bean/MicroSearchInfoReqBean.java ---
clientSearch() {
  unset keyword
  while true; do read -r -p ">> Enter appName: " keyword; [[ "$keyword" =~ ^[Qq] ]] && keyword=; break; [ -n "$keyword" ] && break || echo -e "$notice Please enter a valid appName!"; done
  [ -z "$sign" ] && clientStartup
  ([ -z "$keyword" ] || [ -z "$sign" ]) && return 1
  clientJson=$("${clientCmd[@]}" --data-urlencode "method=client.newSearchApp2" --data-urlencode "ver=1.1" --data-urlencode "name=$keyword" --data-urlencode "reqPageNum=1" --data-urlencode "maxResults=10" --data-urlencode "sign=$sign")
  cleanResultsJson=$(jq '.results[] | {id: .id, name: .name, downCountDesc: .downCountDesc, releaseDate: .releaseDate, versionCode: .versionCode, packageName: .packageName, downurl: (.downurl | split("?")[0]), memo: .memo, sizeDesc: .sizeDesc, sha256: .sha256}' <<< "$clientJson")
  unset clientJson
  #ids=($(jq -r '.id' <<< "$cleanResultsJson"))
  mapfile -t names < <(jq -r '.name' <<< "$cleanResultsJson")
  mapfile -t downCountDescs < <(jq -r '.downCountDesc' <<< "$cleanResultsJson")
  downurls=($(jq -r '.downurl' <<< "$cleanResultsJson"))
  mapfile -t memos < <(jq -r '.memo' <<< "$cleanResultsJson")
  mapfile -t sizeDescs < <(jq -r '.sizeDesc' <<< "$cleanResultsJson")
  #sha256s=($(jq -r '.sha256' <<< "$cleanResultsJson"))
  titles=()
  for ((i=0; i<${#names[@]}; i++)); do titles+=("${names[i]} | ${downCountDescs[i]} | ${sizeDescs[i]}"); done
  menu titles bButtons memos || return 1
  dlUrl="${downurls[selected]}"
  fileName=$(basename "$dlUrl" 2>/dev/null)
  filePath="$Download/$fileName"
  #sha256="${sha256s[selected]}"
  unset cleanResultsJson names downCountDescs downurls memos sizeDescs
  return 0
}

# --- sources: com/huawei/appgallery/appdownloadinfo/api/GetDetailByIdReqBean.java ---
getDetailResp() {
  detailInfoJson=$(jq -r '.detailInfo[]' <<< "$clientJson")
  appName=$(jq -r '.name' <<< "$detailInfoJson")
  developerName=$(jq -r '.developer' <<< "$detailInfoJson")
  releaseDate=$(jq -r '.releaseDate' <<< "$detailInfoJson")
  fileSizeInt=$(jq -r '.size' <<< "$detailInfoJson")
  fileSizeStr=$(jq -r '.sizeDesc' <<< "$detailInfoJson")
  url=$(jq -r '.url' <<< "$detailInfoJson"); dlUrl="${url%%\?*}"; fileName=$(basename "$dlUrl" 2>/dev/null); filePath="$Download/$fileName"
  downloadCountInt=$(jq -r '.download' <<< "$detailInfoJson")
  appCategory=$(jq -r '.kindName' <<< "$detailInfoJson")
  app3rdCategory=$(jq -r '.thirdKindName' <<< "$detailInfoJson")
  shortDescription=$(jq -r '.comment' <<< "$detailInfoJson")
  downloadCountStr=$(jq -r '.downCountDesc' <<< "$detailInfoJson")
  isGame=$(jq -r '.isGame' <<< "$detailInfoJson")
  offerTypeStr=$(jq -r '.tariffDesc' <<< "$detailInfoJson")
  sha256=$(jq -r '.sha256' <<< "$detailInfoJson")
  minAge=$(jq -r '.minAge' <<< "$detailInfoJson")
  versionCode=$(jq -r '.versionCode' <<< "$detailInfoJson")
  versionName=$(jq -r '.versionName' <<< "$detailInfoJson")
  packageName=$(jq -r '.package' <<< "$detailInfoJson")
}

clientAppDetailById() {
  unset appId
  while true; do read -r -p ">> Enter appId: " appId; [[ "$appId" =~ ^[Qq] ]] && appId=; break; [ -n "$appId" ] && break || echo -e "$notice Please enter a valid appId!"; done
  [ -z "$sign" ] && clientStartup
  ([ -z "$appId" ] || [ -z "$sign" ]) && return 1
  clientJson=$("${clientCmd[@]}" --data-urlencode "sign=$sign" --data-urlencode "method=client.appDetailById" --data-urlencode "id=$appId")
  getDetailResp
  return 0
}

clientAppDetailByPackage() {
  unset packageName
  while true; do read -r -p ">> Enter packageName: " packageName; [[ "$packageName" =~ ^[Qq] ]] && packageName=; break; [ -n "$packageName" ] && break || echo -e "$notice Please enter a valid packageName!"; done
  [ -z "$sign" ] && clientStartup
  ([ -z "$packageName" ] || [ -z "$sign" ]) && return 1
  clientJson=$("${clientCmd[@]}" --data-urlencode "method=client.appDetailById" --data-urlencode "ver=1.1" --data-urlencode "package=$packageName" --data-urlencode "sign=$sign")
  getDetailResp
  return 0
}

<<comment
# --- sources: com/huawei/appmarket/service/batchappdetail/BatchAppDetailRequest.java ---
getBatchAppDetailResp() {
  appListJson=$(jq -r '.appList[]' <<< "$clientJson")
  mapfile -t appNames < <(jq -r '.name' <<< "$appListJson")
  mapfile -t briefDescriptions < <(jq -r '.briefDescription' <<< "$appListJson")
  mapfile -t developers < <(jq -r '.developer' <<< "$appListJson")
  releaseDates=($(jq -r '.releaseDate' <<< "$appListJson"))
  appIds=($(jq -r '.id' <<< "$appListJson"))
  mapfile -t sizeDescs < <(jq -r '.sizeDesc' <<< "$appListJson")
  urls=($(jq -r '.url' <<< "$appListJson"))
  kindTypeNames=($(jq -r '.kindTypeName' <<< "$appListJson"))
  mapfile -t kindNames < <(jq -r '.kindName' <<< "$appListJson")
  mapfile -t thirdKindNames < <(jq -r '.thirdKindName' <<< "$appListJson")
  mapfile -t downCountDescs < <(jq -r '.downCountDesc' <<< "$appListJson")
  tariffDescs=($(jq -r '.tariffDesc' <<< "$appListJson"))
  sha2s=($(jq -r '.sha256' <<< "$appListJson"))
  minAges=($(jq -r '.minAge' <<< "$appListJson"))
  versionCodes=($(jq -r '.versionCode' <<< "$appListJson"))
  mapfile -t versionNames < <(jq -r '.versionName' <<< "$appListJson")
  packages=($(jq -r '.package' <<< "$appListJson"))
}

clientBatchAppDetail() {
  [ -z "$sign" ] && clientStartup
  ([ -z "$1" ] || [ -z "$sign" ]) && return 1
  local -n packageList=$1
  elements="${packageList[*]}"; idList="${elements// /,}"
  clientJson=$("${clientCmd[@]}" --data-urlencode "method=client.batchAppDetail" --data-urlencode "ver=1.1" --data-urlencode "idList=$idList" --data-urlencode "idType=2" --data-urlencode "sign=$sign")
  getBatchAppDetailResp
  return 0
} #; pkgs=(com.huawei.appmarket com.zhiliaoapp.musically org.telegram.messenger); clientBatchAppDetail pkgs
comment

# --- sources: com/huawei/appgallery/updatemanager/api/UpgradeRequest.java ---
getNotRcmListResp() {
  notRcmListJson=$(jq -r '.notRcmList[]' <<< "$clientJson")
  mapfile -t appNames < <(jq -r '.name' <<< "$notRcmListJson")
  appIds=($(jq -r '.id' <<< "$notRcmListJson"))
  releaseDates=($(jq -r '.releaseDate' <<< "$notRcmListJson"))
  versionCodes=($(jq -r '.versionCode' <<< "$notRcmListJson"))
  sizes=($(jq -r '.size' <<< "$notRcmListJson"))
  mapfile -t versions < <(jq -r '.version' <<< "$notRcmListJson")
  mapfile -t newFeatures < <(jq -r '.newFeatures' <<< "$notRcmListJson")
  mapfile -t oldVersionNames < <(jq -r '.oldVersionName' <<< "$notRcmListJson")
  oldVersionCodes=($(jq -r '.oldVersionCode' <<< "$notRcmListJson"))
  isGames=($(jq -r '.isGame' <<< "$notRcmListJson"))
  sha2s=($(jq -r '.sha256' <<< "$notRcmListJson"))
  packages=($(jq -r '.package' <<< "$notRcmListJson"))
  downurls=($(jq -r '(.downurl | split("?")[0])' <<< "$notRcmListJson"))
}

clientUpgrade() {
  [ -z "$sign" ] && clientStartup
  ([ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ] || [ -z "$sign" ]) && return 1
  local -n packageName=$1
  local -n vCode=$2
  local -n vName=$3
  local -n signatureSha256=$4
  updateJson="{\"params\": ["
  for ((i=0; i<${#packageName[@]}; i++)); do
    updateJson+="{\"package\": \"${packageName[i]}\", \"versionCode\": ${vCode[i]}, \"oldVersion\": \"${vName[i]}\", \"sSha2\": \"${signatureSha256[i]}\", \"pkgMode\": 0, \"installationFree\": 0, \"appBits\": $appBits}"
  done
  updateJson+="]}"
  [ "$serviceZone" == "CN" ] && isFetchAllGxxApps=0 || isFetchAllGxxApps=1
  clientJson=$("${clientCmd[@]}" --data-urlencode "method=client.diffUpgrade2" --data-urlencode "ver=1.2" --data-urlencode "json=$updateJson" --data-urlencode "supportDiffTypes=[0]" --data-urlencode "isFetchAllGxxApps=$isFetchAllGxxApps" \
    --data-urlencode "isFullUpgrade=0" --data-urlencode "installCheck=0" --data-urlencode "isWlanIdle=0" --data-urlencode "sign=$sign")
  getNotRcmListResp
  return 0
}

clientCheckUpdates() {
  if [ ${#apps[@]} -eq 0 ]; then
    packagesList
    packagesInfo "packages"
    echo -e "$running Checking for updates..."
    ssha2s=()
    for ((i=0; i<${#packages[@]}; i++)); do ssha2s+=(a9436644e0bd71ff512c63839f8ac27114399f36956958688555dfcc63257ede); done
    clientUpgrade packages iVersionCodes iVersionNames ssha2s
    apps=()
    for ((i=0; i<${#packages[@]}; i++)); do
      apps+=("${appNames[i]} (${packages[i]}) | ${oldVersionNames[i]} (${oldVersionCodes[i]}) → ${versions[i]} (${versionCodes[i]})")
    done
  fi
  [ ${#apps[@]} -eq 0 ] && return
  selected_app=0
  while true; do
    menu apps bButtons "" "" $selected_app && selected_app=$selected || break
    dlUrl="${downurls[selected_app]}"; fileName=$(basename "$dlUrl" 2>/dev/null); filePath="$Download/$fileName"
    dlOther
    if { [ $isAndroid == false ] && [ -n "$serial" ]; } || [ $isAndroid == true ]; then
      confirmPrompt "Do you want to install $fileName" "ynButtons" && opt="Yes" || opt="No"
      if [ "$opt" == "Yes" ]; then
        [ $isAndroid == false ] && adbInstall "$filePath"
        [ $isAndroid == true ] && apkInstall "$filePath"
      fi
    fi
    echo; read -p "Press Enter to continue..."
  done
}
##############################################