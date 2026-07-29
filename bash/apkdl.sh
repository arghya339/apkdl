#!/usr/bin/env bash

# Copyright (C) 2025, Arghyadeep Mondal <github.com/arghya339>

shopt -s extglob

good="\033[92;1m[✔]\033[0m"
bad="\033[91;1m[✘]\033[0m"
info="\033[94;1m[i]\033[0m"
running="\033[37;1m[~]\033[0m"
notice="\033[93;1m[!]\033[0m"
question="\033[93;1m[?]\033[0m"

Green="\033[92m"
Red="\033[91m"
Blue="\033[94m"
skyBlue="\033[38;5;117m"
Cyan="\033[96m"
White="\033[37m"
whiteBG="\e[47m\e[30m"
Yellow="\033[93m"
Orange="\e[38;5;208m"
Reset="\033[0m"

checkInternet() {
  if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    return
  else
    echo -e "$bad ${Red}No Internet Connection available!${Reset}"
    return 1
  fi
}

isMacOS=false; isAndroid=false; isFedora=false
if [[ "$(uname)" == "Darwin" ]]; then
  isMacOS=true; scripts=(macOS adbInstall adbDeviceInfo)
elif [[ -d "/sdcard" ]] && [[ -d "/system" ]]; then
  isAndroid=true; scripts=(apkInstall Termux deviceInfo)
elif [[ -f "/etc/os-release" ]]; then
  if grep -qi "fedora" /etc/os-release 2>/dev/null; then
    isFedora=true; scripts=(Fedora adbInstall adbDeviceInfo)
  fi
fi

apkdl="$HOME/.apkdl"
[ -d "$HOME/apkdl" ] && mv ~/apkdl ~/.apkdl  # Temporary: Hides script folder from $HOME
[ $isAndroid == true ] && Download="/sdcard/Download" || Download="$HOME/Downloads"
mkdir -p $apkdl
apkdlJson="$apkdl/apkdl.json"
read rows cols < <(stty size)
eButtons=("<Select>" "<Exit>")
bButtons=("<Select>" "<Back>")
ynButtons=("<Yes>" "<No>")
tfButtons=("<true>" "<false>")
cloudflareDOH="https://cloudflare-dns.com/dns-query"
cloudflareIP="1.1.1.1,1.0.0.1"
checkInternet && crVersion=$(curl -sL "https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Android&num=1" | jq -r '.[0].version') || crVersion="146.0.0.0"

reloadConfig() {
  printArt=$(jq -r '.printArt' "$apkdlJson" 2>/dev/null)
  AutoUpdatesScript=$(jq -r '.AutoUpdatesScript' "$apkdlJson" 2>/dev/null)
  AutoUpdatesDependencies=$(jq -r '.AutoUpdatesDependencies' "$apkdlJson" 2>/dev/null)
  [ $isAndroid == true ] && CheckTermuxUpdate=$(jq -r '.CheckTermuxUpdate' "$apkdlJson" 2>/dev/null)
  ShowSystemApps=$(jq -r '.ShowSystemApps' "$apkdlJson" 2>/dev/null)
  RipLocale=$(jq -r '.RipLocale' "$apkdlJson" 2>/dev/null)
  RipDpi=$(jq -r '.RipDpi' "$apkdlJson" 2>/dev/null)
  RipLib=$(jq -r '.RipLib' "$apkdlJson" 2>/dev/null)
  RmFileAfterInstallation=$(jq -r '.RmFileAfterInstallation' "$apkdlJson" 2>/dev/null)
  PreReleasePatches=$(jq -r '.PreReleasePatches' "$apkdlJson" 2>/dev/null)
  AppUpdatesSource=$(jq -r '.AppUpdatesSource' "$apkdlJson" 2>/dev/null)
}
[ -f $apkdlJson ] && reloadConfig

config() {
  local key="$1"
  local value="$2"
  local jsonFile="${3:-$apkdlJson}"
  
  [ ! -f "$jsonFile" ] && jq -n "{}" > "$jsonFile"
  jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$jsonFile" > temp.json && mv temp.json "$jsonFile"
}

runCmd() {
  cmd=${1}
  if [ $isAndroid == true ]; then
    if [ $su == true ]; then
      [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=true; } || writeSELinux=false
      su -c "$cmd"
      [ $writeSELinux == true ] && su -c "setenforce 1"
    elif rish -c "id" &>/dev/null; then
      rish -c "$cmd"
    elif adb -s $(adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" &>/dev/null; then
      adb -s $(adb devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) $cmd
    fi
  else
    adb -s $serial $cmd
  fi
}

shellCmd() {
  cmd=${1}
  if [ $isAndroid == true ]; then
    if [ $su == true ] || rish -c "id" &>/dev/null; then
      runCmd "$cmd"
    elif adb -s $(adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" &>/dev/null; then
      runCmd "shell $cmd"
    fi
  else
    runCmd "shell $cmd"
  fi
}

scripts+=(auth genProtoBin genTocPb play dlGitHub dlGitLab dlFDroid APKMdl dlAPKPure dlUptodown RVdl otherSources myApps)

run() { source $apkdl/menu.sh; source $apkdl/confirmPrompt.sh; for ((c=0; c<${#scripts[@]}; c++)); do source $apkdl/${scripts[c]}.sh; done; }

[ -f "$apkdl/.version" ] && localVersion=$(cat "$apkdl/.version") || localVersion=
checkInternet &>/dev/null && remoteVersion=$(curl -sL "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/.version") || remoteVersion="$localVersion"
updates() {
  curl -sL -o "$apkdl/.version" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/.version"
  curl -sL -o "$HOME/.apkdl.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/apkdl.sh"
  curl -sL -o $apkdl/menu.sh https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/bash/menu.sh && source $apkdl/menu.sh
  curl -sL -o $apkdl/confirmPrompt.sh https://raw.githubusercontent.com/arghya339/Simplify/refs/heads/next/bash/confirmPrompt.sh && source $apkdl/confirmPrompt.sh
  if [ $isAndroid == true ]; then
    [ ! -f "$PREFIX/bin/apkdl" ] && ln -s ~/.apkdl.sh $PREFIX/bin/apkdl
  elif [ $isMacOS == true ]; then
    [ ! -f "/usr/local/bin/apkdl" ] && ln -s $HOME/.apkdl.sh /usr/local/bin/apkdl
  else
    [ ! -f "/usr/local/bin/apkdl" ] && sudo ln -s $HOME/.apkdl.sh /usr/local/bin/apkdl
  fi
  [ ! -x $HOME/.apkdl.sh ] && chmod +x $HOME/.apkdl.sh
  for ((c=0; c<${#scripts[@]}; c++)); do
    curl -sL -o "$apkdl/${scripts[c]}.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/${scripts[c]}.sh"
    source $apkdl/${scripts[c]}.sh
  done
}

[ -f "$apkdlJson" ] && AutoUpdatesScript=$(jq -r '.AutoUpdatesScript' "$apkdlJson" 2>/dev/null) || AutoUpdatesScript=true
if [ $AutoUpdatesScript == true ]; then
  [ "$remoteVersion" != "$localVersion" ] && { checkInternet && updates && localVersion="$remoteVersion"; } || run
else
  run
fi

print_apkdl() {
  printf '\033[2J\033[3J\033[H'                                                        
  printf "${Orange}                       _/   ${Reset}    ${White}     _/    ${Reset}${Cyan}         _/  _/${Reset}\n"   
  printf "${Orange}    _/_/_/  _/_/_/    _/  _/${Reset}    ${White}      _/   ${Reset}${Cyan}    _/_/_/  _/ ${Reset}\n"   
  printf "${Orange} _/    _/  _/    _/  _/_/   ${Reset}    ${White}       _/  ${Reset}${Cyan} _/    _/  _/  ${Reset}\n"   
  printf "${Orange}_/    _/  _/    _/  _/  _/  ${Reset}    ${White}    _/     ${Reset}${Cyan}_/    _/  _/   ${Reset}\n"   
  printf "${Orange} _/_/_/  _/_/_/    _/    _/ ${Reset}    ${White} _/        ${Reset}${Cyan} _/_/_/  _/    ${Reset}\n"   
  printf "${Orange}        _/                  ${Reset}    ${White}           ${Reset}${Cyan}               ${Reset}\n"  
  printf "${Orange}       _/                   ${Reset}   ${White}_/_/_/_/_/  ${Reset}${Cyan}               ${Reset}\n"
  echo
}

all_key=(printArt AutoUpdatesScript AutoUpdatesDependencies "RipLocale" "RipDpi" "RipLib" "RmFileAfterInstallation" "PreReleasePatches" "AppUpdatesSource")
all_value=(true true true true true true true false "PlayStore")

if { [ $isAndroid == false ] && [ -n "$serial" ]; } || [ $isAndroid == true ]; then
  all_key+=("ShowSystemApps" "InstallPackageFor" "KeepsData" "GrantAllRuntimePermissions" "InstalledAsTestOnly" "BypassLowTargetSdkBolck" "DisablePlayProtect" "DisableVerifyAdbInstalls" "Installer" "Reinstall" "EnableRoolback")
  all_value+=(false "0" false false false true true false "com.android.vending" true false)
fi

[ $isAndroid == true ] && { all_key+=("CheckTermuxUpdate" "openjdk"); all_value+=(true "21"); }

isConfigured=false
for i in "${!all_key[@]}"; do
  ! jq -e --arg key "${all_key[i]}" 'has($key)' "$apkdlJson" >/dev/null && { config "${all_key[i]}" "${all_value[i]}"; isConfigured=true; }
done
[ $isConfigured == true ] && reloadConfig

if [ $isAndroid == false ]; then
  jq -e '.ABI != null' "$apkdlJson" >/dev/null 2>&1 && cpuAbi="$(jq -r '.ABI' "$apkdlJson" 2>/dev/null)" || cpuAbi=
  jq -e '.LOCALE != null' "$apkdlJson" >/dev/null 2>&1 && locale="$(jq -r '.LOCALE' "$apkdlJson" 2>/dev/null)" || locale=
  jq -e '.DENSITY != null' "$apkdlJson" >/dev/null 2>&1 && density="$(jq -r '.DENSITY' "$apkdlJson" 2>/dev/null)" || density=
fi

ripLocaleGen() {
  if [ $RipLocale == true ] && [ -n "$locale" ]; then
    if [ $isAndroid == true ]; then
      locale=$(getprop persist.sys.locale | cut -d'-' -f1)
      [ -z $locale ] && locale=$(getprop ro.product.locale | cut -d'-' -f1)
    else
      locale="$(jq -r '.LOCALE' "$apkdlJson" 2>/dev/null)"
    fi
  else
    locale="[a-z][a-z]"
  fi
}; ripLocaleGen

ripDpiGen() {
  if [ $RipDpi == true ] && [ -n "$density" ]; then
    if [ "$density" -le "120" ]; then
      lcd_dpi="ldpi"  # Low Density
    elif [ "$density" -le "160" ]; then
      lcd_dpi="mdpi"  # Medium Density
    elif [ "$density" -le "213" ]; then
      lcd_dpi="tvdpi"  # TV Density
    elif [ "$density" -le "240" ]; then
      lcd_dpi="hdpi"  # High Density
    elif [ "$density" -le "320" ]; then
      lcd_dpi="xhdpi"  # Extra High Density
    elif [ "$density" -le "480" ]; then
      lcd_dpi="xxhdpi"  # Extra Extra High Density
    elif [ "$density" -gt "480" ] || [ "$density" -ge "640" ]; then
      lcd_dpi="xxxhdpi"  # Extra Extra Extra High Density
    else
      lcd_dpi="*dpi"
    fi
  else
    lcd_dpi="*dpi"
  fi
}; ripDpiGen

genPMCmd() {
  InstallPackageFor=$(jq -r '.InstallPackageFor' "$apkdlJson" 2>/dev/null)
  KeepsData=$(jq -r '.KeepsData' "$apkdlJson" 2>/dev/null)
  GrantAllRuntimePermissions=$(jq -r '.GrantAllRuntimePermissions' "$apkdlJson" 2>/dev/null)
  InstalledAsTestOnly=$(jq -r '.InstalledAsTestOnly' "$apkdlJson" 2>/dev/null)
  if [ -n "$Android" ]; then
    [ $Android -ge 14 ] && BypassLowTargetSdkBolck=$(jq -r '.BypassLowTargetSdkBolck' "$apkdlJson" 2>/dev/null)
  fi
  DisablePlayProtect=$(jq -r '.DisablePlayProtect' "$apkdlJson" 2>/dev/null)
  DisableVerifyAdbInstalls=$(jq -r '.DisableVerifyAdbInstalls' "$apkdlJson" 2>/dev/null)
  Installer=$(jq -r '.Installer' "$apkdlJson" 2>/dev/null)
  Reinstall=$(jq -r '.Reinstall' "$apkdlJson" 2>/dev/null)
  EnableRoolback=$(jq -r '.EnableRoolback' "$apkdlJson" 2>/dev/null)
  
  if [ $InstallPackageFor -eq 0 ]; then
    if [ $isAndroid == true ]; then
      pmCmd="--user $(am get-current-user)"
    elif [ $isAndroid == false ] && [ -n "$serial" ]; then
      pmCmd="--user $(adb -s $serial shell am get-current-user)"
    fi
  else
    pmCmd="--user all"
  fi
  [ $GrantAllRuntimePermissions == true ] && pmCmd+=" -g"
  [ $InstalledAsTestOnly == true ] && pmCmd+=" -t"
  if [ -n "$Android" ] && [ $Android -ge 14 ]; then
    [ $BypassLowTargetSdkBolck == true ] && pmCmd+=" --bypass-low-target-sdk-block"
  fi
  case "$Installer" in
    "com.android.vending") pmCmd+=" -i com.android.vending" ;;
    "com.android.packageinstaller") pmCmd+=" -i com.android.packageinstaller" ;;
    "com.android.shell") pmCmd+=" -i com.android.shell" ;;
    "adb") pmCmd+=" -i adb" ;;
  esac
  [ $Reinstall == true ] && pmCmd+=" -r"
  [ $EnableRoolback == true ] && pmCmd+=" --enable-rollback"
}
([ $isAndroid == true ] || [ -n "$serial" ]) && genPMCmd

sign() {
  apkPath="${1}"
  fileName=$(basename "$apkPath")
  outApkPath="${apkPath%.*}-signed.apk"
  verify() {
    if [ $isAndroid == true ]; then
      echo -e "$running Checking $fileName Certificate.."
      certs=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar verify --print-certs "${apkPath}" 2>/dev/null)
      apksigner_exit_status=$?
      grep -oP 'Signer #1 certificate DN: \K.*' <<< "$certs"
    else
      echo -e "$running Checking $fileName Certificate.."
      certs=$($apksigner verify --print-certs "${apkPath}" 2>/dev/null)
      apksigner_exit_status=$?
      grep "Signer #1 certificate DN:" <<< "$certs" | cut -d: -f2-
    fi
  }; verify
  if [ $apksigner_exit_status -ne 0 ]; then
    if [ $isAndroid == true ]; then
      [ ! -f $apkdl/ks.keystore ] && { echo -e "$running Create a ${Red}ks.keystore${Reset} for Signing apk.."; $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -genkey -v -storetype pkcs12 -keystore $apkdl/ks.keystore -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=In" -storepass 123456 -keypass 123456; echo -e "$running Checking details about keystore entries.."; $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -list -v -keystore $apkdl/ks.keystore -storepass 123456 | grep -oP '(?<=Owner:).*' | xargs; }
      echo -e "$running Signing apk.."
      $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar sign --ks $apkdl/ks.keystore --ks-pass pass:123456 --ks-key-alias ReVancedKey --key-pass pass:123456 --out "${outApkPath}" "${apkPath}"
      signing_exit_status=$?
    else
      [ ! -f $apkdl/ks.keystore ] && { echo -e "$running Create a ${Red}ks.keystore${Reset} for Signing apk.."; $keytool -genkey -v -storetype pkcs12 -keystore $apkdl/ks.keystore -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=In" -storepass 123456 -keypass 123456; echo -e "$running Checking details about keystore entries.."; $keytool -list -v -keystore $apkdl/ks.keystore -storepass 123456 | grep "Owner:" | cut -d: -f2- | xargs; }
      echo -e "$running Signing apk.."
      $apksigner sign --ks $apkdl/ks.keystore --ks-pass pass:123456 --ks-key-alias ReVancedKey --key-pass pass:123456 --out "${outApkPath}" "${apkPath}"
      signing_exit_status=$?
    fi
    [ $signing_exit_status -eq 0 ] && { rm -f "$outApkPath.idsig"; rm -f "$apkPath"; mv "$outApkPath" "$apkPath"; verify; }
  fi
}

downloadAPK() {
  Referer=${1}
  [ -n "$Referer" ] && aria2Arg=("--header=\"Referer: $Referer\"") || aria2Arg=()
  while true; do
    if [ $isMacOS == true ]; then
      aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" -U "User-Agent: $USER_AGENT" "${aria2Arg[@]}" --ca-certificate="/etc/ssl/cert.pem" --async-dns=true --async-dns-server=$cloudflareIP "$dlLink"
      exitStatus=$?
    else
      aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" -U "User-Agent: $USER_AGENT" "${aria2Arg[@]}" --async-dns=true --async-dns-server="$cloudflareIP" "$dlLink"
      exitStatus=$?
    fi
    echo
    [ $exitStatus -eq 0 ] && break || sleep 5
  done 
  
  if [ $isMacOS == true ]; then
    sha256sum=$(shasum -a 256 "$apkPath" | cut -d' ' -f1)
  else
    sha256sum=$(sha256sum "$apkPath" | cut -d' ' -f1)
  fi
  if [ "$sha256sum" == "$SHA256" ]; then
    echo -e "$good Downloaded file appears in the original state."
  else
    echo -e "$bad Look like downloaded file appears corrupted!"
    echo -e "$notice SHA-256 SUM Diffs - Expected: ${Cyan}$SHA256${Reset} ~ Result: ${Cyan}$sha256sum${Reset}"
  fi
}

dlAPKEditor() {
  owner="ReAndroid"; repo="APKEditor"
  ghApiResponseJson=$(curl -sL ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest")
  tag_name=$(jq -r '.tag_name | sub("^V"; "")' <<< "$ghApiResponseJson")  # 1.4.5
  APKEditor="APKEditor-$tag_name.jar"
  APKEditorPath="$apkdl/$APKEditor"
  findAPKEditorPath=$(find "$apkdl" -maxdepth 1 -type f -name "APKEditor-*.jar" -print -quit)
  findAPKEditor=$(basename "$findAPKEditorPath" 2>/dev/null)
  if [ "$APKEditor" != "$findAPKEditor" ]; then
    [ -f "$findAPKEditorPath" ] && { echo -e "$notice diffs: $APKEditor ~ $findAPKEditor"; rm -f "$findAPKEditorPath"; }
    while true; do
      curl -L --progress-bar -o $APKEditorPath -C - https://github.com/REAndroid/APKEditor/releases/download/V$tag_name/APKEditor-$tag_name.jar
      [ $? -eq 0 ] && break || sleep 5
    done
  fi
}; dlAPKEditor

apks2apk() {
  if [ $isMacOS == true ]; then
    if [ -n "$cpuAbi" ]; then
      mkdir -p "$Download/${appName}_v${version}-${arch}"
      if [ $RipLib == true ]; then
        pv "$apkPath" | tar -xf - -C "$Download/${appName}_v${version}-${arch}/" --include "$pkgName.apk" "config.${cpuAbi//-/_}.apk" "config.${locale}.apk" "config.${lcd_dpi}.apk"
        tar_exit_status=$?
      elif [ $RipLib == false ]; then
        pv "$apkPath" | tar -xf - -C "$Download/${appName}_v${version}-${arch}/" --include "$pkgName.apk" "config.arm64_v8a.apk" "config.armeabi_v7a.apk" "config.x86_64.apk" "config.x86.apk" "config.${locale}.apk" "config.${lcd_dpi}.apk"
        tar_exit_status=$?
      fi
      if [ $tar_exit_status -ne 0 ]; then  # check if tar return exit code 1 (error)
        rm -rf "$Download/${appName}_v${version}-${arch}"
        java -jar $APKEditorPath m -i "$apkPath" -o "$Download/${appName}_v${version}-${arch}.apk" && rm -f "$apkPath"
      else
        rm -f "$apkPath"
        java -jar $APKEditorPath m -i "$Download/${appName}_v${version}-${arch}" -o "$Download/${appName}_v${version}-${arch}.apk" && rm -rf "$Download/${appName}_v${version}-${arch}"
      fi
    else
      java -jar $APKEditorPath m -i "$apkPath" -o "$Download/${appName}_v${version}-${arch}.apk" && rm -f "$apkPath"
    fi
  else
    mkdir -p "$Download/${appName}_v${version}-${arch}"
    termux-wake-lock
    if [ $RipLib == true ]; then
      pv "$apkPath" | bsdtar -xf - -C "$Download/${appName}_v${version}-${arch}/" --include "$pkgName.apk" "config.${cpuAbi//-/_}.apk" "config.${locale}.apk" "config.${lcd_dpi}.apk"
      bsdtar_exit_status=$?
    elif [ $RipLib == false ]; then
      pv "$apkPath" | bsdtar -xf - -C "$Download/${appName}_v${version}-${arch}/" --include "$pkgName.apk" "config.arm64_v8a.apk" "config.armeabi_v7a.apk" "config.x86_64.apk" "config.x86.apk" "config.${locale}.apk" "config.${lcd_dpi}.apk"
      bsdtar_exit_status=$?
    fi
    if [ $bsdtar_exit_status -ne 0 ]; then  # check if bsdtar return exit code 1 (error)
      rm -rf "$Download/${appName}_v${version}-${arch}"
      $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $APKEditorPath m -i "$apkPath" -o "$Download/${appName}_v${version}-${arch}.apk" && rm -f "$apkPath"
    else
      rm -f "$apkPath"
      $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $APKEditorPath m -i "$Download/${appName}_v${version}-${arch}" -o "$Download/${appName}_v${version}-${arch}.apk" && rm -rf "$Download/${appName}_v${version}-${arch}"
    fi
    termux-wake-unlock
  fi
}

pat() {
  echo -e "${running} Creating Personal Access Token.."
  # Create a PAT with scope `public_repo` / `read_repository` | `read_user` scope provides username for token validation
  [ "$userInput" == "GitHub" ] && url="https://github.com/settings/tokens/new?scopes=public_repo&description=apkdl" || url="https://gitlab.com/-/user_settings/personal_access_tokens?name=apkdl&scopes=read_user,read_repository"
  if [ $isAndroid == true ]; then termux-open-url "$url"; elif [ $isMacOS == true ]; then open "$url"; else xdg-open "$url"; fi
  echo -n "PAT: "  # Display prompt
  # Read characters one by one
  while IFS= read -rsn 1 char; do
    # Handle Enter key (newline)
    if [[ "$char" == $'\0' || "$char" == $'\n' || "$char" == $'\r' ]]; then
      # Only break if input is not empty, input not start with space, input doesn't contain space & pat is valid
      if [[ -n "$input" && ! "$input" =~ ^[[:space:]] && ! "$input" =~ [[:space:]] ]]; then
        if [ "$userInput" == "GitHub" ]; then
          curl -sL -f -H "Authorization: Bearer ${input}" "https://api.github.com/repos/cli/cli/releases/latest" | jq -r '.tag_name'
          auth_status=${PIPESTATUS[0]}
        else
          curl -sL -f -H "Authorization: Bearer ${input}" "https://gitlab.com/api/v4/user" | jq '.username'
          auth_status=${PIPESTATUS[0]}
        fi
        if [ $auth_status -eq 0 ]; then
          echo -e "\n$good ${Green}Successfully added your $userInput PAT!${Reset}"
          echo -e "$notice ${Yellow}Your $userInput API rate limit has been increased.${Reset}"
          break
        else
          echo -ne "\r\033[K"  # Clear previous prompt line
          echo -e "$notice ${Yellow}Invalid PAT!${Reset}"  # Display messages if pat is not valid
          input=""  # Clear input variable's value
          echo -n "PAT: "  # Display prompt
        fi
      else
        continue
      fi
    fi
    # Handle backspace ($'\177')
    if [[ "$char" == $'\177' ]]; then
      if [ -n "$input" ]; then
        input="${input%?}"  # Remove last char from input & store in input
        echo -ne "\b \b"  # Move cursor back, print space, move cursor back again
      fi
      continue
    fi
    # Handle delete ($'\E[3~')
    # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
    if [[ "$char" == $'\E' ]]; then
      read -rsn1 -t 0.1 seq1
      if [[ "$seq1" == '[' ]]; then
        read -rsn2 -t 0.1 seq2
        case "$seq2" in
          '3~')  # Delete key
            if [ -n "$input" ]; then
              input="${input%?}"
              echo -ne "\b \b"
            fi
            ;;
        esac
      fi
      continue
    fi
    # Only add printable characters (excluding control characters)
    if [[ "$char" =~ [[:print:]] ]]; then
      input+="$char"  # Add character to input
      echo -n "*"  # Display asterisk
    fi
  done
  [ "$userInput" == "GitHub" ] && config "GH" "$input" || config "GLAB" "$input"
}

auth() {
  while true; do
    if { gh auth status >/dev/null 2>&1 || jq -e '.GH' "$apkdlJson" >/dev/null 2>&1; } || { glab auth status >/dev/null 2>&1 || jq -e '.GLAB' "$apkdlJson" >/dev/null 2>&1; }; then
      web=(); site="GitHub/ GitLab"
      if gh auth status >/dev/null 2>&1 || jq -e '.GH' "$apkdlJson" >/dev/null 2>&1; then
        web+=(GitHub); site="GitHub"
      fi
      if glab auth status >/dev/null 2>&1 || jq -e '.GLAB' "$apkdlJson" >/dev/null 2>&1; then
        web+=(GitLab); site="GitLab"
      fi
      buttons=("<Yes>" "<No>"); confirmPrompt "You already have a $site token! Do you want to delete it?" "buttons" "1" && userInput=Yes || userInput=No
      case "$userInput" in
        Yes)
          if [ ${#web[@]} -eq 2 ]; then
            buttons=("<GitHub>" "<GitLab>"); confirmPrompt "Select WebSite" "buttons" "1" && userInput="GitHub" || userInput="GitLab"
          else
            userInput="${web[0]}"
          fi
          if [ "$userInput" == "GitHub" ]; then
            if gh auth status >/dev/null 2>&1; then
              gh auth logout  # Logout from gh cli
              url="https://github.com/settings/applications"
            elif jq -e '.GH' "$apkdlJson" >/dev/null 2>&1; then
              jq 'del(.GH)' "$apkdlJson" > temp.json && mv temp.json "$apkdlJson"  # Delete GH key from apkdl.json
              url="https://github.com/settings/tokens"
            fi
          elif [ "$userInput" == "GitLab" ]; then
            if glab auth status >/dev/null 2>&1; then
              glab auth logout --hostname gitlab.com  # Logout from glab cli
              url="https://gitlab.com/-/user_settings/applications"
            elif jq -e '.GLAB' "$apkdlJson" >/dev/null 2>&1; then
              jq 'del(.GLAB)' "$apkdlJson" > temp.json && mv temp.json "$apkdlJson"  # Delete GLAB key from apkdl.json
              url="https://gitlab.com/-/user_settings/personal_access_tokens"
            fi
          fi
          if [ $isAndroid == true ]; then termux-open-url "$url"; elif [ $isMacOS == true ]; then open "$url"; else xdg-open "$url"; fi
          echo -e "$good ${Green}Successfully deleted your $userInput token!${Reset}"
          ;;
      esac
    fi
    if { ! gh auth status >/dev/null 2>&1 || ! jq -e '.GH' "$apkdlJson" >/dev/null 2>&1; } || { ! glab auth status >/dev/null 2>&1 || ! jq -e '.GLAB' "$apkdlJson" >/dev/null 2>&1; }; then
      buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to increase the GitHub/ GitLab API rate limit by adding a gh/ glab token?" "buttons" && userInput=Yes || userInput=No
      case "$userInput" in
        Yes)
          buttons=("<GitHub>" "<GitLab>"); confirmPrompt "Select WebSite" "buttons" "1" && userInput="GitHub" || userInput="GitLab"
          case "$userInput" in
            GitHub)
              buttons=("<GH>" "<PAT>"); confirmPrompt "Select a method to create a GitHub access token: (GH) GitHub CLI or (PAT) Personal Access Token?" "buttons" "1" && method=GH || method=PAT
              case "$method" in
                [Gg]*)
                  if [ $isAndroid == true ]; then pkgInstall "gh"; elif [ $isMacOS == true ]; then formulaeInstall "gh"; elif [ $isFedora == true ]; then dnfInstall "gh"; fi # gh install/update
                  echo -e "${running} Creating GitHub access token using GitHub CLI.."
                  gh auth login  # Authenticate gh cli with GitHub account
                  #gh api "repos/desktop/desktop/releases/latest" | cat | jq -r '.tag_name'
                  gh api "repos/cli/cli/releases/latest" | cat | jq -r '.tag_name'
                  if [ ${PIPESTATUS[0]} -eq 0 ]; then
                    echo -e "$good ${Green}Successfully authenticated with GitHub CLI!${Reset}"
                    echo -e "$notice ${Yellow}Your GitHub API rate limit has been increased.${Reset}"
                    break
                  else
                    echo -e "${bad} ${Red}Failed to authenticate with GitHub CLI! Please try again.${Reset}"
                    gh auth logout  # Logout from gh cli
                  fi
                  ;;
                [Pp]*)
                  pat  # Call pat functions to add pat
                  break
                  ;;
              esac
              ;;
            GitLab)
              buttons=("<GLAB>" "<PAT>"); confirmPrompt "Select a method to create a GitLab access token: (GLAB) GitLab CLI or (PAT) Personal Access Token?" "buttons" "1" && method=GLAB || method=PAT
              case "$method" in
                [Gg]*)
                  if [ $isAndroid == true ]; then pkgInstall "glab-cli" ; elif [ $isMacOS == true ]; then formulaeInstall "glab"; elif [ $isFedora == true ]; then dnfInstall "glab"; fi  # glab install/update
                  echo -e "${running} Creating GitLab access token using GitLab CLI.."
                  glab auth login  # Authenticate glab cli with GitLab account
                  glab api "projects/gitlab-org%2Fcli/releases?per_page=1" | cat | jq -r '.[0].tag_name'
                  if [ ${PIPESTATUS[0]} -eq 0 ]; then
                    echo -e "$good ${Green}Successfully authenticated with GitLab CLI!${Reset}"
                    echo -e "$notice ${Yellow}Your GitLab API rate limit has been increased.${Reset}"
                    break
                  else
                    echo -e "${bad} ${Red}Failed to authenticate with GitLab CLI! Please try again.${Reset}"
                    glab auth logout --hostname gitlab.com  # Logout from glab cli
                  fi
                  ;;
                [Pp]*) pat && break ;;
              esac
              ;;
          esac
          ;;
        No) break ;;
      esac
    else
      break
    fi
  done
}

if gh auth status >/dev/null 2>&1; then
  ghToken="$(gh auth token)"
elif jq -e '.GH' "$apdlJson" >/dev/null 2>&1; then
  ghToken="$(jq -r '.GH' "$apkdlJson" 2>/dev/null)"
fi
[ -n "$ghToken" ] && ghAuth="-H \"Authorization: Bearer $ghToken\"" || ghAuth=""
if glab auth status >/dev/null 2>&1; then
  glabToken="$(glab config get token --host gitlab.com)"
elif jq -e '.GLAB' "$apdlJson" >/dev/null 2>&1; then
  glabToken="$(jq -r '.GLAB' "$apkdlJson" 2>/dev/null)"
fi
[ -n "$glabToken" ] && glabAuth="-H \"Authorization: Bearer $glabToken\"" || glabAuth=""

clearAppCaches() {
  humanReadableForm() {
    freeSizeB=${freeSizeB#-}
    if [ $freeSizeB -ge 1073741824 ]; then
      echo -e $good "Free space: $(awk -v freeSizeB=$freeSizeB 'BEGIN {printf "%.1f", freeSizeB/1073741824}')G"
    elif [ $freeSizeB -ge 1048576 ]; then
      echo -e "$good Free space: $(awk -v freeSizeB=$freeSizeB 'BEGIN {printf "%.1f", freeSizeB/1048576}')M"
    elif [ $freeSizeB -ge 1024 ]; then
      echo -e "$good Free space: $(awk -v freeSizeB=$freeSizeB 'BEGIN {printf "%.1f", freeSizeB/1024}')K"
    else
      echo -e "$good Free space: ${freeSizeB}B"
    fi
  }
  if [ $isAndroid == true ]; then
    #size=$(su -c "du -bsh /data/data/com.termux/cache/" | cut -f1) && echo "cache size of com.termux: $size"
    #su -c "echo \"Removing cache of com.termux\"; rm -rf /data/data/com.termux/cache/* 2>/dev/null"
    
    totalSizeB=$(su -c "du -bsc /data/data/*/cache 2>/dev/null | grep total | cut -f1")
    totalSize=$(su -c "du -bsch /data/data/*/cache 2>/dev/null | grep total | cut -f1") && echo -e "$info total cache size: $totalSize"
    echo -e "$running Clear app cache.."
    su -c "for dir in /data/data/*/cache; do pkg=\$(basename \$(dirname \"\$dir\")); echo \"Removing cache of \$pkg\"; rm -rf \"\$dir\"/* 2>/dev/null; done"
    echo -e "$good applications cache has been cleared."
    sleep 0.5
    currentTotalSizeB=$(su -c "du -bsc /data/data/*/cache 2>/dev/null | grep total | cut -f1")
    freeSizeB=$((totalSizeB - currentTotalSizeB))
    humanReadableForm
  else
    #size=$(adb -s $serial shell 'su -c "du -bsh /data/data/com.termux/cache/"' | cut -f1) && echo "cache size of com.termux: $size"
    #adb -s $serial shell 'su -c "
    #  echo \"Removing cache of com.termux\"
    #  rm -rf /data/data/com.termux/cache/* 2>/dev/null"'
    
    totalSizeB=$(adb -s $serial shell 'su -c "du -bsc /data/data/*/cache 2>/dev/null | grep total | cut -f1"')
    totalSize=$(adb -s $serial shell 'su -c "du -bsch /data/data/*/cache 2>/dev/null | grep total | cut -f1"') && echo -e "$info total cache size: $totalSize"
    echo -e "$running Clear app cache.."
    adb -s $serial shell 'su -c "
      for dir in /data/data/*/cache; do
        pkg=\$(basename \$(dirname \"\$dir\"))
        echo \"Removing cache of \$pkg\"
        rm -rf \"\$dir\"/* 2>/dev/null
      done"'
      echo -e "$good applications cache has been cleared."
      sleep 0.5
      currentTotalSizeB=$(adb -s $serial shell 'su -c "du -bsc /data/data/*/cache 2>/dev/null | grep total | cut -f1"')
      freeSizeB=$((totalSizeB - currentTotalSizeB))
      humanReadableForm
  fi
}

[ $printArt == true ] && { printf '\033[?25l' && print_apkdl && sleep 3 && printf '\033[?25h'; }

declare -a apps applications hiddenApps enabledApps disabledApps uninstalledSystemApps
selected_opt=0
while true; do
  options=(PlayStore GitHub GitLab F-Droid APKMirror Uptodown APKPure otherSources ReVanced Morphe RVX)
  if { [ $isAndroid == false ] && [ -n "$serial" ]; } || { [ $isAndroid == true ] && { [ $su == true ] || [ $rish == true ] || [ $adb == true ]; }; }; then
    options+=(manageApps)
  fi
  if { [ $isAndroid == false ] || [ -n "$serial" ]; } || [ $isAndroid == true ]; then
    options+=(Configuration)
  fi
  menu options eButtons "" "" $selected_opt && selected_opt=$selected
  case "${options[selected_option]}" in
    PlayStore)
      source $apkdl/play.sh
      
      gPlayApiSearchApps
      [ $? -eq 0 ] && gPlayApiAppDetails && gPlayApiDownloadApp
      if [ $? -eq 0 ]; then
        buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
        if [ "$opt" == "Yes" ]; then
          [ -n "$serial" ] && adbInstall "$filePath"
          [ $isAndroid == true ] && apkInstall "$filePath"
        else
          [ "$apk_ext" == "apks" ] && APKS2APK && sign "${filePath%.*}.apk"
        fi
      fi
      echo; read -p "Press Enter to continue..."
      ;;
    GitHub)
      searchGH
      [ $? -ne 0 ] && continue

      buttons=("<Releases>" "<Actions>"); confirmPrompt "Browse" "buttons" && opt=Releases || opt=Actions
      if [ "$opt" == "Releases" ]; then
        curl -fsL ${ghAuth} "$releasesUrl/latest" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
          Releases
          [ $? -ne 0 ] && continue
        else
          buttons=("<Latest>" "<Releases>"); confirmPrompt "Please Select release type" "buttons" && opt=Latest || opt=Releases
          if [ "$opt" == "Latest" ]; then
            Latest
            [ $? -ne 0 ] && continue
          else
            Releases
            [ $? -ne 0 ] && continue
          fi
        fi
      else
        ghActions
        [ $? -ne 0 ] && continue
      fi

      fileName=$(basename "$asset_browser_download_url")
      filePath="$Download/$fileName"
      ext="${fileName##*.}"
      [ ! -f "$filePath" ] && dlGH
      if [ -f "$filePath" ]; then
        if { [[ $isMacOS == true && ( ( $ext == "apk" && -n $serial ) || $ext == "dmg" || $ext == "pkg" ) ]]; } || { [ $isFedora == true ] && [ "$ext" == "rpm" ]; } || [[ $isAndroid == true ]]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid == true ]; then
              apkInstall "$filePath"
            elif [ $isMacOS == true ]; then
              ([ "$ext" == "apk" ] && [ -n "$serial" ]) && adbInstall "$filePath"
              ([ "$ext" == "dmg" ] || [ "$ext" == "pkg" ]) && open "$filePath"
            else
              ([ "$ext" == "apk" ] && [ -n "$serial" ]) && adbInstall "$filePath"
              [ "$ext" == "rpm" ] && xdg-open "$filePath"
            fi
          fi
        fi
      fi
      echo; read -p "Press Enter to continue..."
      { [[ $isMacOS == true && ( "$ext" == "dmg" || "$ext" == "pkg" ) && $RmFileAfterInstallation == true ]]; } && rm -f "$filePath"
      ([ $isFedora == true ] && [ "$ext" == "rpm" ] && [ $RmFileAfterInstallation == true ]) && rm -f "$filePath"
      ;;
    GitLab)
      searchGLAB
      [ $? -ne 0 ] && continue

      glabReleases
      [ $? -ne 0 ] && continue

      fileName=$(basename "$dlUrl")
      filePath="$Download/$fileName"
      ext="${fileName##*.}"
      [ ! -f "$filePath" ] && dlGLAB
      if [ -f "$filePath" ]; then
        if { [[ $isMacOS == true && ( ( $ext == "apk" && -n $serial ) || $ext == "dmg" || $ext == "pkg" ) ]]; } || { [ $isFedora == true ] && [ "$ext" == "rpm" ]; } || [[ $isAndroid == true ]]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid == true ]; then
              apkInstall "$filePath"
            elif [ $isMacOS == true ]; then
              ([ "$ext" == "apk" ] && [ -n "$serial" ]) && adbInstall "$filePath"
              ([ "$ext" == "dmg" ] || [ "$ext" == "pkg" ]) && open "$filePath"
            else
              ([ "$ext" == "apk" ] && [ -n "$serial" ]) && adbInstall "$filePath"
              [ "$ext" == "rpm" ] && xdg-open "$filePath"
            fi
          fi
        fi
      fi
      echo; read -p "Press Enter to continue..."
      { [[ $isMacOS == true && ( "$ext" == "dmg" || "$ext" == "pkg" ) && $RmFileAfterInstallation == true ]]; } && rm -f "$filePath"
      ([ $isFedora == true ] && [ "$ext" == "rpm" ] && [ $RmFileAfterInstallation == true ]) && rm -f "$filePath"
      ;;
    F-Droid)
      FDroidSearch
      [ $? -ne 0 ] && continue

      FDroidVersionsList
      if [ $? -eq 0 ]; then
        buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
        if [ "$opt" == "Yes" ]; then
          [ -n "$serial" ] && adbInstall "$filePath"
          [ $isAndroid == true ] && apkInstall "$filePath"
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    APKMirror)
      buttons=("<appName>" "<pkgName>"); confirmPrompt "Please select a method to get appLink" "buttons" && opt=appName || opt=pkgName
     
      if [ "$opt" == "appName" ]; then
        searchApp
        [ $? -ne 0 ] && continue
      elif [ "$opt" == "pkgName" ]; then
        fetchAppsInfo
        [ $? -ne 0 ] && continue
      fi
      
      getLatestUploads
      [ $? -ne 0 ] && continue
      
      getVariant
      [ $? -ne 0 ] && continue
      
      getDownloadLink
      if [ $? -eq 0 ]; then
        getAppDetails
        appName=$(echo "${appName%%[:—(]*}" | xargs)
        fileName="${appName}_v${version}-${arch}${file_ext}"
        apkPath="$Download/$fileName"
        [ ! -f "$Download/${appName}_v${version}-${arch}.apk" ] && downloadAPK "https://www.apkmirror.com/"
        [ -f "$Download/${appName}_v${version}-${arch}.apkm" ] && apkm2apk
        [ -f "$Download/${appName}_v${version}-${arch}.apk" ] && apkPath="$Download/${appName}_v${version}-${arch}.apk"
        if [ -f "$apkPath" ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid == true ]; then
              sign "$apkPath" && apkInstall "$apkPath"
            else
              ext="${fileName##*.}"
              ([[ "$ext" =~ ^apk.*$ ]] && [ -n "$serial" ]) && { sign "$apkPath" && adbInstall "$apkPath"; }
            fi
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    Uptodown)
      UptodownSearch
      [ $? -ne 0 ] && continue

      UptodownVersionLink
      [ $? -ne 0 ] && continue

      UptodownDownloadLink
      if [ $? -eq 0 ]; then
        UptodownAppInfo
        appName=$(echo "${appName%%[:—(]*}" | xargs)
        fileName="${appName}_v${version}-${arch}${file_ext}"
        apkPath="$Download/$fileName"
        [ ! -f "$Download/${appName}_v${version}-${arch}.apk" ] && downloadAPK
        [ -f "$Download/${appName}_v${version}-${arch}.apks" ] && apks2apk
        [ -f "$Download/${appName}_v${version}-${arch}.apk" ] && apkPath="$Download/${appName}_v${version}-${arch}.apk"
        if [ -f "$apkPath" ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid == true ]; then
              sign "$apkPath" && apkInstall "$apkPath"
            else
              ext="${fileName##*.}"
              ([[ "$ext" =~ ^apk.*$ ]] && [ -n "$serial" ]) && { sign "$apkPath" && adbInstall "$apkPath"; }
            fi
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    APKPure)
      APKPureSearch
      [ $? -ne 0 ] && continue

      AllVersions
      [ $? -ne 0 ] && continue

      APKPureVariant
      if [ $? -eq 0 ]; then
        appName=$(echo "${appName%%[/:—(]*}" | xargs)
        fileName="${appName}_v${version}-${arch}${file_ext}"
        apkPath="$Download/$fileName"
        [ ! -f "$Download/${appName}_v${version}-${arch}.apk" ] && dlAPKPure
        [ -f "$Download/${appName}_v${version}-${arch}.apks" ] && apks2apk
        [ -f "$Download/${appName}_v${version}-${arch}.apk" ] && apkPath="$Download/${appName}_v${version}-${arch}.apk"
        if [ -f "$apkPath" ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid == true ]; then
              sign "$apkPath" && apkInstall "$apkPath"
            else
              ext="${fileName##*.}"
              ([[ "$ext" =~ ^apk.*$ ]] && [ -n "$serial" ]) && { sign "$apkPath" && adbInstall "$apkPath"; }
            fi
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    otherSources) oSources ;;
    ReVanced|Morphe|RVX)
      RVdl "${options[selected_option]}"
      [ $? -ne 0 ] && continue
      
      if [ -n "$version" ]; then
        buttons=("<Auto>" "<Manual>"); confirmPrompt "Please select a method to get versionLink" "buttons" && opt=Auto || opt=Manual
        if [ "$opt" == "Auto" ]; then
          getVersionLink
          [ $? -ne 0 ] && continue
        elif [ "$opt" == "Manual" ]; then
          getLatestUploads
          [ $? -ne 0 ] && continue
        fi
      else
        getLatestUploads
        [ $? -ne 0 ] && continue
      fi
      
      getVariant
      [ $? -ne 0 ] && continue
      
      getDownloadLink
      if [ $? -eq 0 ]; then
        getAppDetails
        appName=$(echo "${appName%%[:—(]*}" | xargs)
        fileName="${appName}_v${version}-${arch}${file_ext}"
        apkPath="$Download/$fileName"
        [ ! -f "$Download/${appName}_v${version}-${arch}.apk" ] && downloadAPK "https://www.apkmirror.com/"
        [ -f "$Download/${appName}_v${version}-${arch}.apkm" ] && apkm2apk
        [ -f "$Download/${appName}_v${version}-${arch}.apk" ] && apkPath="$Download/${appName}_v${version}-${arch}.apk"
        if [ -f "$apkPath" ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid == true ]; then
              sign "$apkPath" && apkInstall "$apkPath"
            else
              ext="${fileName##*.}"
              ([[ "$ext" =~ ^apk.*$ ]] && [ -n "$serial" ]) && { sign "$apkPath" && adbInstall "$apkPath"; }
            fi
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    manageApps)
      selected_ma=0
      ma_options=(appUpdates disableApps enableApps uninstallApps recoverSystemApps)
      if { [ $isAndroid == false ] && [ -n "$serial" ] && [ $su == true ]; } || { [ $isAndroid == true ] && [ $su == true ]; }; then
        ma_options+=(clearAppCaches blockInternet unblockInternet hideApps unhideApps)
      fi
      if [ $isAndroid == true ] && [ $su == true ]; then
        [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=1; } || writeSELinux=0
      fi
      while true; do
        menu ma_options bButtons "" "" $selected_ma && selected_ma="$selected" || break
        case "${ma_options[selected_ma]}" in
          appUpdates)      
            if [ "$AppUpdatesSource" == "PlayStore" ]; then
              source $apkdl/play.sh
              [ ${#apps[@]} -eq 0 ] && gPlayApiAppsUpdates
              gPlayApiShowUpdates
              [ $? -ne 0 ] && continue
              gPlayApiDownloadApp "1"
              if [ $? -eq 0 ]; then
                buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
                if [ "$opt" == "Yes" ]; then
                  [ -n "$serial" ] && adbInstall "$filePath"
                  [ $isAndroid == true ] && apkInstall "$filePath"
                else
                  [ "$apk_ext" == "apks" ] && APKS2APK && sign "${filePath%.*}.apk"
                fi
              fi
            elif [ "$AppUpdatesSource" == "APKMirror" ]; then
              [ ${#apps[@]} -eq 0 ] && getUpdates
              showUpdates
              [ $? -ne 0 ] && continue
              getVariant
              [ $? -ne 0 ] && continue
              getDownloadLink
              if [ $? -eq 0 ]; then
                getAppDetails
                appName=$(echo "${appName%%[:—(]*}" | xargs)
                fileName="${appName}_v${version}-${arch}${file_ext}"
                apkPath="$Download/$fileName"
                [ ! -f "$Download/${appName}_v${version}-${arch}.apk" ] && downloadAPK "https://www.apkmirror.com/"
                [ -f "$Download/${appName}_v${version}-${arch}.apkm" ] && apkm2apk
                [ -f "$Download/${appName}_v${version}-${arch}.apk" ] && apkPath="$Download/${appName}_v${version}-${arch}.apk"
                if [ -f "$apkPath" ]; then
                  buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
                  if [ "$opt" == "Yes" ]; then
                    if [ $isAndroid == true ]; then
                      sign "$apkPath" && apkInstall "$apkPath"
                    else
                      ext="${fileName##*.}"
                      ([[ "$ext" =~ ^apk.*$ ]] && [ -n "$serial" ]) && { sign "$apkPath" && adbInstall "$apkPath"; }
                    fi
                  fi
                fi
              fi
            else
              [ ${#apps[@]} -eq 0 ] && aptoideListAppsUpdates
              aptoideShowUpdates
              [ $? -ne 0 ] && continue
            fi
            ;;
          clearAppCaches) clearAppCaches ;;
          blockInternet)
            [ ${#applications[@]} -eq 0 ] && appsList
            blockInternet
            ;;
          unblockInternet)
            showFirewallBlocklist
            [ $? -ne 0 ] && continue
            unblockInternet
            ;;
          hideApps)
            [ ${#applications[@]} -eq 0 ] && appsList
            hideApps
            ;;
          unhideApps)
            [ ${#hiddenApps[@]} -eq 0 ] && showHiddenApps
            unhideApps
            ;;
          disableApps)
            [ ${#enabledApps[@]} -eq 0 ] && showEnabledApps
            disableApps
            ;;
          enableApps)
            [ ${#disabledApps[@]} -eq 0 ] && showDisabledApps
            enableApps
            ;;
          uninstallApps)
            [ ${#applications[@]} -eq 0 ] && appsList
            packagesUninstall
            ;;
          recoverSystemApps)
            [ ${#uninstalledSystemApps[@]} -eq 0 ] && showUninstalledSystemApps
            recoverSystemApps
            ;;
        esac
        echo; read -p "Press Enter to continue..."
      done
      if [ $isAndroid == true ] && [ $su == true ]; then
        [ $writeSELinux -eq 1 ] && su -c "setenforce 1"
      fi
      ;;
    Configuration)
      selected_settings=0
      while true; do
        reloadConfig
        s_options=(printArt AutoUpdatesScript AutoUpdatesDependencies CheckUpdates About RmFileAfterInstallation PreReleasePatches "Add gh/ glab PAT (increases gh/ glab api rate limit)" AppUpdatesSource)
        if [ $isAndroid == true ] || { [ $isAndroid == false ] && [ -n "$cpuAbi" ]; }; then
          s_options+=(RipLocale RipDpi RipLib)
        fi
        if [ $isAndroid == true ]; then
          CheckTermuxUpdate=$(jq -r '.CheckTermuxUpdate' "$apkdlJson" 2>/dev/null)
          jdkVersion="$(jq -r '.openjdk' "$apkdlJson" 2>/dev/null)"
          if [ $su == true ]; then s_options+=("SU Installation Options"); elif [ $rish == true ]; then s_options+=("SUI Installation Options"); elif [ $adb == true ]; then s_options+=("ADB Installation Options"); fi
          ([ "$(getprop ro.product.manufacturer)" == "Genymobile" ] && [ $adb == false ]) && s_options+=(Pair\ ADB)
          s_options+=("Check Termux update on startup" "Change Java version")
        elif [ $isAndroid == false ] && [ -n "$serial" ]; then
          s_options+=("ADB Installation Options")
        fi
        if { [ $isAndroid == false ] && [ -n "$serial" ]; } || { [ $isAndroid == true ] && { [ $su == true ] || [ $rish == true ] || [ $adb == true ]; }; }; then
          s_options+=(ShowSystemApps)
        fi
        menu s_options bButtons "" "" $selected_settings && selected_settings="$selected" || break
        case "${s_options[selected_settings]}" in
          printArt)
            confirmPrompt "Show apkdl branding on launch" tfButtons "$printArt" && printArt=true || printArt=false
            config "printArt" "$printArt"
            ;;
          AutoUpdatesScript)
            confirmPrompt "Auto updates Script on launch" tfButtons "$AutoUpdatesScript" && AutoUpdatesScript=true || AutoUpdatesScript=false
            config "AutoUpdatesScript" "$AutoUpdatesScript"
            ;;
          AutoUpdatesDependencies)
            confirmPrompt "Auto updates dependencies on launch" tfButtons "$AutoUpdatesDependencies" && AutoUpdatesDependencies=true || AutoUpdatesDependencies=false
            config "AutoUpdatesDependencies" "$AutoUpdatesDependencies"
            ;;
          CheckUpdates) checkInternet && { updates; dependencies; } ;;
          About)
            printf '\033[?25l' && print_apkdl
            echo "Script Version: $localVersion"
            echo; read -p "Press Enter to continue..."; printf '\033[?25h'
            ;;
          RipLocale)
            confirmPrompt "RipLocale" tfButtons "$RipLocale" && RipLocale=true || RipLocale=false
            config "RipLocale" "$RipLocale"
            ripLocaleGen
            ;;
          RipDpi)
            confirmPrompt "RipDpi" tfButtons "$RipDpi" && RipDpi=true || RipDpi=false
            config "RipDpi" "$RipDpi"
            ripDpiGen
            ;;
          RipLib)
            confirmPrompt "RipLib" tfButtons "$RipLib" && RipLib=true || RipLib=false
            config "RipLib" "$RipLib"
            ;;
          RmFileAfterInstallation)
            confirmPrompt "RmFileAfterInstallation" tfButtons "$RmFileAfterInstallation" && RmFileAfterInstallation=true || RmFileAfterInstallation=false
            config "RmFileAfterInstallation" "$RmFileAfterInstallation"
            ;;
          PreReleasePatches)
            confirmPrompt "PreReleasePatches" tfButtons "$PreReleasePatches" && PreReleasePatches=true || PreReleasePatches=false
            config "PreReleasePatches" "$PreReleasePatches"
            ;;
          "SU Installation Options"|"SUI Installation Options"|"ADB Installation Options")
            selected_io=0
            while true; do
              genPMCmd
              io_options=("Install Package for *user" "Allow Downgrade with keeps App data (reboot required)" "Grant All Runtime/ Requested Permissions" Installed\ as\ test-only\ app Bypass\ Low\ Target\ SDK\ Bolck Disable\ Play\ Protect\ Package\ Verification Disable\ Verify\ Adb\ Installs Installer "Reinstall (Replace/ Upgrade) Existing Installed Package" Enable\ Version\ Roolback)
              menu io_options bButtons "" "" $selected_io && selected_io="$selected" || break
              case "${io_options[selected_io]}" in
                "Install Package for *user")
                  buttons=("<default-user>" "<all-users>"); confirmPrompt "InstallPackageFor" buttons "$InstallPackageFor" && InstallPackageFor=0 || InstallPackageFor=1
                  config "InstallPackageFor" "$InstallPackageFor"
                  ;;
                "Allow Downgrade with keeps App data (reboot required)")
                  confirmPrompt "KeepsData" tfButtons "$KeepsData" && KeepsData=true || KeepsData=false
                  config "KeepsData" "$KeepsData"
                  ;;
                "Grant All Runtime/ Requested Permissions")
                  confirmPrompt "GrantAllRuntimePermissions" tfButtons "$GrantAllRuntimePermissions" && GrantAllRuntimePermissions=true || GrantAllRuntimePermissions=false
                  config "GrantAllRuntimePermissions" "$GrantAllRuntimePermissions"
                  ;;
                Installed\ as\ test-only\ app)
                  confirmPrompt "InstalledAsTestOnly" tfButtons "$InstalledAsTestOnly" && InstalledAsTestOnly=true || InstalledAsTestOnly=false
                  config "InstalledAsTestOnly" "$InstalledAsTestOnly"
                  ;;
                Bypass\ Low\ Target\ SDK\ Bolck)
                  confirmPrompt "BypassLowTargetSdkBolck" tfButtons "$BypassLowTargetSdkBolck" && BypassLowTargetSdkBolck=true || BypassLowTargetSdkBolck=false
                  config "BypassLowTargetSdkBolck" "$BypassLowTargetSdkBolck"
                  ;;
                Disable\ Play\ Protect\ Package\ Verification)
                  confirmPrompt "DisablePlayProtect" tfButtons "$DisablePlayProtect" && DisablePlayProtect=true || DisablePlayProtect=false
                  config "DisablePlayProtect" "$DisablePlayProtect"
                  ;;
                Disable\ Verify\ Adb\ Installs)
                  confirmPrompt "DisableVerifyAdbInstalls" tfButtons "$DisableVerifyAdbInstalls" && DisableVerifyAdbInstalls=true || DisableVerifyAdbInstalls=false
                  config "DisableVerifyAdbInstalls" "$DisableVerifyAdbInstalls"
                  ;;
                Installer)
                  case "$Installer" in
                    "com.android.vending") selected_option=0 ;;
                    "com.android.packageinstaller") selected_option=1 ;;
                    "com.android.shell") selected_option=2 ;;
                    "adb") selected_option=3 ;;
                  esac
                  installerName=(Play\ Store Package\ Installer Shell ADB)
                  installerPackage=("com.android.vending" "com.android.packageinstaller" "com.android.shell" "adb")
                  menu installerName bButtons installerPackage "" $selected_option && { Installer="${installerPackage[selected]}"; config "Installer" "$Installer"; }
                  ;;
                "Reinstall (Replace/ Upgrade) Existing Installed Package")
                  confirmPrompt "Reinstall" tfButtons "$Reinstall" && Reinstall=true || Reinstall=false
                  config "Reinstall" "$Reinstall"
                  ;;
                Enable\ Version\ Roolback)
                  confirmPrompt "EnableRoolback" tfButtons "$EnableRoolback" && EnableRoolback=true || EnableRoolback=false
                  config "EnableRoolback" "$EnableRoolback"
                  ;;
              esac
            done
            ;;
          Pair\ ADB)
            echo -e "Enable Developer Options:\n  1. Open Settings app on your device\n  2. tap About Phone\n  3. Find & tap 7 times on Build Number\n  4. You may need to enter your lock screen password\n  >>You will see a toast message saying 'You are now a developer!'"
            echo -e "Enable Wireless Debugging:\n  1. Go back to main Settings screen\n  2. Scroll down & tap System\n  3. Tap Developer Options\n  4. Scroll down & find Wireless Debugging\n  5. Toggle it ON\n  6. A new dialog box will appear with a warning. Read it and tap Allow"
            echo -e "Pair Device with Pairing Code:\n  1. In Wireless Debugging menu, tap Pair device with pairing code. It will show you a IP address & port (e.g., 192.168.1.50:40435) and a 6-digit pairing code (e.g., 123456).\n  2. open Termux & enter [IP address:port] [Wi-Fi pairing code] (e.g., 192.168.1.50:40435 123456)\n"
            am start -n "com.android.settings/.Settings\$WirelessDebuggingActivity" >/dev/null 2>&1
            [ $? -ne 0 ] && am start -n "com.android.settings/.Settings\$DevelopmentSettingsDashboardActivity" >/dev/null 2>&1 || am start -n com.android.settings/.Settings\$MyDeviceInfoActivity >/dev/null 2>&1
            read -r -p "HOST[:PORT] [PAIRING CODE] " input
            host_port=$(echo "$input" | awk '{print $1}'); pairing_code=$(echo "$input" | awk '{print $2}')
            adb pair "$host_port" "$pairing_code"
            ;;
          Check\ Termux\ update\ on\ startup)
            confirmPrompt "CheckTermuxUpdate" tfButtons "$CheckTermuxUpdate" && CheckTermuxUpdate=true || CheckTermuxUpdate=false
            config "CheckTermuxUpdate" "$CheckTermuxUpdate"
            ;;
          Change\ Java\ version)
            echo "openjdkVersion == $jdkVersion"
            # Get available JDK versions
            attempt=0
            while true; do
              jdkVersions=($(pkg search openjdk 2>&1 | grep -E "^openjdk-[0-9]+/" | awk -F'[-/ ]' '{print $2}'))
              [ $attempt -eq 7 ] && { echo -e "$notice Not found any java version in search result, after 7 attempts!"; break; }
              [ ${#jdkVersions[@]} -ne 0 ] && break
              ((attempt++))
              sleep 0.5  # wait 500 milliseconds
            done
            for ((i=0; i<${#jdkVersions[@]}; i++)); do [ ${jdkVersions[i]} -eq $jdkVersion ] && selected_jdk=$i; done
            # Select JDK versions
            menu jdkVersions bButtons "" "" $selected_jdk && version="${jdkVersions[selected]}"
            # Set JDK versions
            if [ -n "$version" ]; then
              echo -e "$info Selected: openjdk-$version"
              config "openjdk" "$version"
              pkgInstall "openjdk-$version"  # java install/update
              echo -e "$good ${Green}Java version change successfully!${Reset}"
            fi
            ;;
          "Add gh/ glab PAT (increases gh/ glab api rate limit)")
            if gh auth status >/dev/null 2>&1; then
              echo -e "$info ${Green}gh_oauth_token: gho_************************************${Reset}"
            elif jq -e '.GH' "$apkdlJson" >/dev/null 2>&1; then
              echo -e "$info ${Green}ghPAT: ghp_************************************${Reset}"
            else
              echo -e "$notice ${Yellow}No GitHub token found!${Reset}"
            fi
            if glab auth status >/dev/null 2>&1; then
              echo -e "$info ${Green}glab_oauth_token: **************************${Reset}"
            elif jq -e '.GLAB' "$apkdlJson" >/dev/null 2>&1; then
              echo -e "$info ${Green}glabPAT: **************************${Reset}"
            else
              echo -e "$notice ${Yellow}No GitLab token found!${Reset}"
            fi
            auth  # Call the auth function to create GitHub/ GitLab token
            ;;
          AppUpdatesSource)
            case "$AppUpdatesSource" in
              "PlayStore") selected_up=0 ;;
              "APKMirror") selected_up=1 ;;
              "Aptoide") selected_up=2 ;;
            esac
            Sources=(PlayStore APKMirror Aptoide)
            menu Sources bButtons "" "" $selected_up && { AppUpdatesSource="${Sources[selected]}"; config "AppUpdatesSource" "$AppUpdatesSource"; }
            ;;
          ShowSystemApps)
            confirmPrompt "ShowSystemApps" tfButtons "$ShowSystemApps" && ShowSystemApps=true || ShowSystemApps=false
            config "ShowSystemApps" "$ShowSystemApps"
            ;;
        esac
      done
      ;;
  esac
done
######################################################################################################################