#!/bin/bash

deviceInfoJson="$apkdl/deviceInfo.json"
if [ ! -f $deviceInfoJson ]; then
  if [ $isAndroid -eq 1 ]; then
    curl -sL https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/deviceInfo.sh -o $apkdl/deviceInfo.sh
    source $apkdl/deviceInfo.sh
  elif [ $isMacOS -eq 1 ]; then
    curl -sL https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/adbDeviceInfo.sh -o $apkdl/adbDeviceInfo.sh
    source $apkdl/adbDeviceInfo.sh
  fi
  if [ $isAndroid -eq 1 ] && [ $su -eq 1 ]; then
    [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=1; } || writeSELinux=0
  fi
  { [ $isAndroid -eq 1 ] || [[ $isMacOS -eq 1 && -n "$serial" ]]; } && getDeviceInfo
  if [ $isAndroid -eq 1 ] && [ $su -eq 1 ]; then
    [ $writeSELinux -eq 1 ] && su -c "setenforce 1"
  fi
  all_key=("Build.RADIO" "Build.BOOTLOADER" "Screen.Density" "GL.Extensions" "HasFiveWayNavigation" "Build.BRAND" "Build.ID" "Client" "Platforms" "TouchScreen" "Build.FINGERPRINT" "Vending.version" "Screen.Width" "Build.HARDWARE")
  all_value=("$BuildRADIO" "$BuildBOOTLOADER" "$ScreenDensity" "$GLExtensions" "false" "$BuildBRAND" "$BuildID" "android-google" "$Platforms" "$TouchScreen" "$BuildFINGERPRINT" "$Vendingversion" "$ScreenWidth" "$BuildHARDWARE")
  all_key+=("Build.VERSION.RELEASE" "Build.VERSION.SDK_INT" "Build.MODEL" "Locales" "SharedLibraries" "GL.Version" "GSF.version" "Roaming" "Screen.Height" "TimeZone" "Vending.versionString" "HasHardKeyboard" "Features" "Navigation")
  all_value+=("$BuildVERSIONRELEASE" "$BuildVERSIONSDK_INT" "$BuildMODEL" "$Locales" "$SharedLibraries" "$GLVersion" "$GSFversion" "$Roaming" "$ScreenHeight" "$TimeZone" "$VendingversionString" "$HasHardKeyboard" "$Features" "$Navigation")
  all_key+=("UserReadableName" "Build.MANUFACTURER" "SimOperator" "Keyboard" "Build.DEVICE" "ScreenLayout" "Build.PRODUCT" "CellOperator")
  all_value+=("$UserReadableName" "$BuildMANUFACTURER" "$SimOperator" "$Keyboard" "$BuildDEVICE" "$ScreenLayout" "$BuildPRODUCT" "$CellOperator")
  if [ $isAndroid -eq 1 ] || [[ $isMacOS -eq 1 && -n "$serial" ]]; then
    for i in "${!all_key[@]}"; do
      config "${all_key[i]}" "${all_value[i]}" "$deviceInfoJson" 
    done
  fi
fi
[ -f $deviceInfoJson ] && deviceInfoProviderJson=$(cat "$deviceInfoJson") || deviceInfoProviderJson=$(curl -sL https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/deviceInfo.json)

glabApiResponseJson=$(curl -sL ${glabAuth} "https://gitlab.com/api/v4/projects/AuroraOSS%2FAuroraStore/releases")
AuroraStoreVersionName=$(jq -r '.[0].tag_name' <<< "$glabApiResponseJson") || AuroraStoreVersionName="4.7.5"
AuroraStoreVersionCode=$(jq -r '.[0].description' <<< "$glabApiResponseJson" | awk -F'[()]' 'NR==1{print $2}') || AuroraStoreVersionCode="71"
AuroraStoreVersion="$AuroraStoreVersionName-$AuroraStoreVersionCode"

# src: https://gitlab.com/AuroraOSS/AuroraStore/-/blob/master/app/src/main/java/com/aurora/Constants.kt
# src: https://gitlab.com/AuroraOSS/AuroraStore/-/blob/master/app/src/main/java/com/aurora/store/data/providers/AuthProvider.kt
authJson="$apkdl/auth.json"
oauth() {
  echo -e "$running Requesting new session.."
  auth=$(curl -sL -X POST "https://auroraoss.com/api/auth" -H "User-Agent: com.aurora.store-$AuroraStoreVersion" -H "Content-Type: application/json" -d "$deviceInfoProviderJson")
  if echo "$auth" | grep -q "error code: 500"; then
    echo -e "$notice Failed to generate session, $auth"
    echo -e "$bad Internal server error, Error code 500"
    if [ $isAndroid -eq 1 ]; then
      termux-open-url "https://www.cloudflare.com/5xx-error-landing/"
      termux-open "https://auroraoss.com/"
    elif [ $isMacOS -eq 1 ]; then
      open "https://www.cloudflare.com/5xx-error-landing/"
      open "https://auroraoss.com/"
    fi
    exit 1
  elif [ -n "$(jq -r '.authtoken' <<< "$auth")" ]; then
    # echo "$auth" | jq .  # keep for debugging
    authToken=$(jq -r '.authToken' <<< "$auth")
    
    gsfId=$(printf "%016x\n" $(adb shell 'su -c "/data/local/tmp/sqlite-arm64-v8a /data/data/com.google.android.gsf/databases/gservices.db \"select * from main where name = '\''android_id'\'';\""' | awk -F'|' '{print $2}'))
    [ "$gsfId" == "0000000000000000" ] && gsfId=$(jq -r '.gsfId' <<< "$auth")
    email=$(jq -r '.email' <<< "$auth")
    userAgentString=$(jq -r '.deviceInfoProvider.userAgentString' <<< "$auth")
    config "time" "$(date +%s)" "$authJson"
    config "authToken" "$authToken" "$authJson"
    config "gsfId" "$gsfId" "$authJson"
    config "email" "$email" "$authJson"
    config "userAgentString" "$userAgentString" "$authJson"
    echo -e "$notice Log in using $email"
    return
  else
    echo -e "$notice You are rate limit! try after some time."
    return 1
  fi
}

if [ ! -f "$authJson" ]; then
  oauth
else
  echo -e "$running Verifying session.."
  time="$(jq -r '.time' "$authJson" 2>/dev/null)"
  tokenAge=$(($(date +%s) - time))
  tokenAgeM=$((tokenAge / 60))
  # Google tokens typically expire in 1 hour (60 minutes)
  if [ $tokenAgeM -gt 60 ]; then
    curl -fsL "$searchUrl?q=google&c=3&ksm=1" "${Headers[@]}" -H "Accept: application/x-protobuf" -o "search.protobuf"
    [ $? -ne 0 ] && oauth
    rm -f search.protobuf
  else
    authToken="$(jq -r '.authToken' "$authJson" 2>/dev/null)"
    gsfId="$(jq -r '.gsfId' "$authJson" 2>/dev/null)"
    email="$(jq -r '.email' "$authJson" 2>/dev/null)"
    userAgentString="$(jq -r '.userAgentString' "$authJson" 2>/dev/null)"
  fi
  Locales="$(jq -r '.Locales' "$deviceInfoJson" 2>/dev/null)"
fi
echo -e "$info authToken: ${Cyan}$authToken${Reset}\n$info gsfId: $gsfId\n$info email: $email\n$info userAgentString: $userAgentString"
#######################################################################################################################################