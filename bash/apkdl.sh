#!/usr/bin/env bash

shopt -s extglob

# --- Colored log indicators ---
good="\033[92;1m[✔]\033[0m"
bad="\033[91;1m[✘]\033[0m"
info="\033[94;1m[i]\033[0m"
running="\033[37;1m[~]\033[0m"
notice="\033[93;1m[!]\033[0m"
question="\033[93;1m[?]\033[0m"

# ANSI Color Code
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

# --- Checking Internet Connection ---
if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 ; then
  echo -e "${bad} ${Red}Oops! No Internet Connection available.\nConnect to the Internet and try again later."
  exit 1
fi

curl -sL -o "$HOME/.apkdl.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/apkdl.sh"

apkdl="$HOME/apkdl"
mkdir -p $apkdl

apkdlJson="$apkdl/apkdl.json"  # Configuration file to store apkdl settings

isRipLocale=1  # Default value (true/on/1) for RipLocale, it's delete locale from apk file except device specific locale by default
isRipDpi=1  # Default value (true/on/1) for RipDpi, it's delete dpi from apk file except device specific dpi by default
isRipLib=1  # Default value (true/on/1) for RipLib, it's delete lib dir from apk file except device specific arch lib by default
isRmFile=1  # Remove downloaded file after installation 1 (true)
isPreRelease=0  # Default value (false/off/0) for isPreRelease, it's enabled latest release for Patches source
isU=0  # Install Package for 0 (default-user), possible 1 (all-users)
isK=0  # Allow Downgrade with keeps App data 0 (false) because it's required reboot after pkg install, possible 1 (true)
isG=0  # Grant All Runtime Permissions 0 (false) due to Security Risk, possible 1
isT=0  # Installed as test-only app 0, possible 1
isL=1  # Bypass Low Target SDK Bolck 1 (true) it's allow Android 14+ to install apps that target below API level 23 (Android 6 and below), possible value 0
isV=1  # Disable Play Protect Package Verification 1 (true), possible 0
isA=0  # 'Disable Play Protect' is Enabled; this makes Enabling 'Disable Verify ADB installs' unnecessary
isI="com.android.vending"  # default: PlayStore | possible Installer: com.android.packageinstaller (PackageInstaller), com.android.shell (Shell), adb
isR=1  # Reinstall Existing Installed Package 1 (true) because without this app can't be installed if installed and to-be-installed version are same, possible 0
isB=0  # Enable Version Roolback 0, possible 1

# Config creation function
config() {
  local key="$1"
  local value="$2"
  
  [ ! -f "$apkdlJson" ] && jq -n "{}" > "$apkdlJson"
  jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$apkdlJson" > temp.json && mv temp.json "$apkdlJson"
}

# Detect platform and set defaults
if [ "$(uname)" == "Darwin" ]; then
  isMacOS=1
  isAndroid=0
elif [ -d "/sdcard" ] && [ -d "/system" ]; then
  isMacOS=0
  isAndroid=1
fi

if [ $isMacOS -eq 1 ]; then
  [ ! -f "/usr/local/bin/apkdl" ] && ln -s $HOME/.apkdl.sh /usr/local/bin/apkdl  # symlink (shortcut of apkdl.sh)
elif [ $isAndroid -eq 1 ]; then
  [ ! -f "$PREFIX/bin/apkdl" ] && ln -s ~/.apkdl.sh $PREFIX/bin/apkdl
fi

[ ! -x $HOME/.apkdl.sh ] && chmod +x $HOME/.apkdl.sh  # give execute permission to apkdl

cloudflareDOH="https://cloudflare-dns.com/dns-query"
cloudflareIP="1.1.1.1,1.0.0.1"
crVersion=$(curl -sL "https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Android&num=1" | jq -r '.[0].version')

if [ $isMacOS -eq 1 ]; then
  Download="$HOME/Downloads"
  [ $(uname -m) == "x86_64" ] && Arch=amd64 || Arch=arm64
  USER_AGENT="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$crVersion Mobile Safari/537.36"
elif [ $isAndroid -eq 1 ]; then
  Download="/sdcard/Download"
  cpuAbi=$(getprop ro.product.cpu.abi)
  Android=$(getprop ro.build.version.release)
  Model=$(getprop ro.product.model)
  Build=$(getprop ro.build.id)
  K="$Model Build/$Build"
  USER_AGENT="Mozilla/5.0 (Linux; Android $Android; $K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${crVersion} Mobile Safari/537.36"
fi

# --- Construct apkdl shape using string concatenation (ANSI Lean Font) ---
print_apkdl() {
  printf "${Blue}            https://github.com/arghya339/apkdl${Reset}\n"                                                           
  printf "${Orange}                       _/   ${Reset}    ${White}     _/    ${Reset}${Cyan}         _/  _/${Reset}\n"   
  printf "${Orange}    _/_/_/  _/_/_/    _/  _/${Reset}    ${White}      _/   ${Reset}${Cyan}    _/_/_/  _/ ${Reset}\n"   
  printf "${Orange} _/    _/  _/    _/  _/_/   ${Reset}    ${White}       _/  ${Reset}${Cyan} _/    _/  _/  ${Reset}\n"   
  printf "${Orange}_/    _/  _/    _/  _/  _/  ${Reset}    ${White}    _/     ${Reset}${Cyan}_/    _/  _/   ${Reset}\n"   
  printf "${Orange} _/_/_/  _/_/_/    _/    _/ ${Reset}    ${White} _/        ${Reset}${Cyan} _/_/_/  _/    ${Reset}\n"   
  printf "${Orange}        _/                  ${Reset}    ${White}           ${Reset}${Cyan}               ${Reset}\n"  
  printf "${Orange}       _/ ${Reset}${skyBlue}𝒟𝑒𝓋𝑒𝓁𝑜𝓅𝑒𝓇: @𝒶𝓇𝑔𝒽𝓎𝒶𝟥𝟥9${Reset} ${White}_/_/_/_/_/${Reset}${Cyan}               ${Reset}\n"
  #printf '\n'
  echo
}

menu() {
  local -n menu_options=$1
  local -n menu_buttons=$2
  items_per_page=${3:-12}  # Default to 12 if items/page not provided
  
  selected_option=0
  selected_button=0
  
  current_page=0
  total_pages=$(( (${#menu_options[@]} + items_per_page - 1) / items_per_page ))  # Convert to integer from floating point page number

  show_menu() {
    printf '\033[2J\033[3J\033[H'
    print_apkdl  # call print_apkdl function
    # Display guide
    echo -n "Navigate with [↑] [↓] [←] [→]"
    [ $total_pages -gt 1 ] && echo -n " [PGUP] [PGDN]"
    echo -e "\nSelect with [↵]\n"
    
    # Calculate start and end indices for current page
    start_index=$(( current_page * items_per_page ))
    end_index=$(( start_index + (items_per_page - 1) ))
    [ $end_index -ge ${#menu_options[@]} ] && end_index=$((${#menu_options[@]} - 1))
    
    # Display menu options for current page
    for ((i=start_index; i<=end_index; i++)); do
      if [ $i -eq $selected_option ]; then
        echo -e "${whiteBG}➤ ${menu_options[$i]} $Reset"
      else
        [ $(($i + 1)) -le 9 ] && echo " $(($i + 1)). ${menu_options[$i]}" || echo "$(($i + 1)). ${menu_options[$i]}"
      fi
    done
    
    for ((i=end_index+1; i < start_index + items_per_page; i++)); do echo; done  # Fill remaining lines if current page has fewer than items/page options
    
    [ $total_pages -gt 1 ] && echo -e "\nPage: $((current_page + 1))/$total_pages\n" || echo  # Display page info if multiple pages exist
    
    # Display buttons
    for ((i=0; i<=$((${#menu_buttons[@]} - 1)); i++)); do
      if [ $i -eq $selected_button ]; then
        [ $i -eq 0 ] && echo -ne "${whiteBG}➤ ${menu_buttons[$i]} $Reset" || echo -ne "  ${whiteBG}➤ ${menu_buttons[$i]} $Reset"
      else
        [ $i -eq 0 ] && echo -n "  ${menu_buttons[$i]}" || echo -n "   ${menu_buttons[$i]}"
      fi
    done
  }

  printf '\033[?25l'
  while true; do
    show_menu
    read -rsn1 key
    case $key in
      $'\E')  # ESC
        # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
        read -rsn2 -t 0.1 key2
        case "$key2" in
          '[A')  # Up arrow
            selected_option=$((selected_option - 1))
            [ $selected_option -lt 0 ] && selected_option=$((${#menu_options[@]} - 1))
            current_page=$((selected_option / items_per_page))  # Auto switch page
            ;;
          '[B')  # Down arrow
            selected_option=$((selected_option + 1))
            [ $selected_option -ge ${#menu_options[@]} ] && selected_option=0
            current_page=$((selected_option / items_per_page))  # Auto switch page
            ;;
          '[C')  # Right arrow
            [ $selected_button -lt $((${#menu_buttons[@]} - 1)) ] && selected_button=$((selected_button + 1))
            ;;
          '[D')  # Left arrow
            [ $selected_button -gt 0 ] && selected_button=$((selected_button - 1))
            ;;
          '[5') # Page Up
            read -rsn1 -t 0.1 key3
            if [ "$key3" == "~" ]; then
              current_page=$((current_page - 1))
              [ $current_page -lt 0 ] && current_page=$((total_pages - 1))
              selected_option=$((current_page * items_per_page))  # Update selected option to start indices on new page
            fi
            ;;
          '[6') # Page Down
            read -rsn1 -t 0.1 key3
            if [ "$key3" == "~" ]; then
              current_page=$((current_page + 1))
              [ $current_page -ge $total_pages ] && current_page=0
              selected_option=$((current_page * items_per_page))  # Update selected option to start indices on new page
            fi
            ;;
        esac
        ;;
      '')  # Enter key
        break
        ;;
      [0-9])
        read -rsn2 -t0.5 key2
        [[ "$key2" == [0-9] ]] && { key="${key}${key2}"; key=$((10#$key)); }  # Convert to integer (decimal) from strings
        if [ $key -eq 0 ]; then
          selected_option=$((${#menu_options[@]} - 1))
        elif [ $key -gt ${#menu_options[@]} ]; then
          selected_option=0
        else
          selected_option=$(($key - 1))
        fi
        current_page=$((selected_option / items_per_page))  # Auto switch page
        show_menu; sleep 0.5; break
       ;;
    esac
  done
  printf '\033[?25h'

  [ $selected_button -eq 0 ] && { printf '\033[2J\033[3J\033[H'; selected=$selected_option; }
  if [ $selected_button -eq $((${#menu_buttons[@]} - 1)) ]; then
    [ "${menu_buttons[$((${#menu_buttons[@]} - 1))]}" == "<Back>" ] && { printf '\033[2J\033[3J\033[H'; return 1; } || { [ $isOverwriteTermuxProp -eq 1 ] && sed -i '/allow-external-apps/s/^/# /' "$HOME/.termux/termux.properties"; printf '\033[2J\033[3J\033[H'; echo "Script exited !!"; exit 0; }
  fi
}

# Y/n prompt function
confirmPrompt() {
  Prompt=${1}
  local -n prompt_buttons=$2
  Selected=${3:-0}  # :- set value as 0 if unset
  maxLen=50
  
  # breaks long prompts into multiple lines (50 characters per line)
  lines=()  # empty array
  while [ -n "$Prompt" ]; do
    lines+=("${Prompt:0:$maxLen}")  # take first 50 characters from $Prompt starting at index 0
    Prompt="${Prompt:$maxLen}"  # removes first 50 characters from $Prompt by starting at 50 to 0
  done
  
  # print all-lines except last-line
  last_line_index=$(( ${#lines[@]} - 1 ))  # ${#lines[@]} = number of elements in lines array
  for (( i=0; i<last_line_index; i++ )); do
    echo -e "${lines[i]}"
  done
  last_line="${lines[$last_line_index]}"
  
  echo -ne '\033[?25l'  # Hide cursor
  while true; do
    show_prompt() {
      echo -ne "\r\033[K"  # n=noNewLine r=returnCursorToStartOfLine \033[K=clearLine
      echo -ne "$last_line "
      [ $Selected -eq 0 ] && echo -ne "${whiteBG}➤ ${prompt_buttons[0]} $Reset   ${prompt_buttons[1]}" || echo -ne "  ${prompt_buttons[0]}  ${whiteBG}➤ ${prompt_buttons[1]} $Reset"  # highlight selected bt with white bg
    }; show_prompt

    read -rsn1 key
    case $key in
      $'\E')
      # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
        read -rsn2 -t 0.1 key2  # -r=readRawInput -s=silent(noOutput) -t=timeout -n2=readTwoChar | waits upto 0.1s=100ms to read key 
        case $key2 in 
          '[C') Selected=1 ;;  # right arrow key
          '[D') Selected=0 ;;  # left arrow key
        esac
        ;;
      [Yy]*) Selected=0; show_prompt; break ;;
      [Nn]*) Selected=1; show_prompt; break ;;
      "") break ;;  # Enter key
    esac
  done
  echo -e '\033[?25h' # Show cursor
  return $Selected  # return Selected int index from this fun
}

tfConfig() {
  local tfKey=${1}
  local defaultValue=$2
  local m1=${3}
  local m2=${4}
  [ $defaultValue -eq 0 ] && defaultValue=1 || defaultValue=0  # if defaultValue=0 then Select button1 (False) else Select button0 (True) 

    buttons=("<True>" "<False>"); confirmPrompt "$tfKey" "buttons" "$defaultValue" && opt=True || opt=False
    case "$opt" in
      True)
        config "$tfKey" "1"
        echo -e "$good ${Green}$tfKey is True! $m1.${Reset}"
        ;;
      False)
        config "$tfKey" "0"
        echo -e "$good ${Green}$tfKey is False! $m2.${Reset}"
        ;;
    esac
    sleep 2
}

printf '\033[2J\033[3J\033[H' && echo -e "🚀 ${Yellow}Please wait! starting apkdl...${Reset}"

if [ $isMacOS -eq 1 ]; then
  curl -sL -o "$apkdl/macOS.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/macOS.sh"
  source $apkdl/macOS.sh
elif [ $isAndroid -eq 1 ]; then
  curl -sL -o "$apkdl/Termux.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/Termux.sh"
  source $apkdl/Termux.sh
fi

if ([ $isMacOS -eq 1 ] && [ -n "$serial" ]) || [ $isAndroid -eq 1 ]; then
  # Create apkdl config
  all_key=("RipLocale" "RipDpi" "RipLib")
  all_key+=("InstallPackageFor" "KeepsData" "GrantAllRuntimePermissions" "InstalledAsTestOnly" "BypassLowTargetSdkBolck" "DisablePlayProtect" "DisableVerifyAdbInstalls" "Installer" "Reinstall" "EnableRoolback")
  all_value=("$isRipLocale" "$isRipDpi" "$isRipLib")
  all_value+=("$isU" "$isK" "$isG" "$isT" "$isL" "$isV" "$isA" "$isI" "$isR" "$isB")
  # Loop through all keys and set values if they don't exist
  for i in "${!all_key[@]}"; do
    ! jq -e --arg key "${all_key[i]}" 'has($key)' "$apkdlJson" >/dev/null && config "${all_key[i]}" "${all_value[i]}"
  done

  # Get RipLocale value from json
  jq -e '.RipLocale != null' "$apkdlJson" >/dev/null 2>&1 && RipLocale="$(jq -r '.RipLocale' "$apkdlJson" 2>/dev/null)" || RipLocale=1
  # Get RipDpi value from json
  jq -e '.RipDpi != null' "$apkdlJson" >/dev/null 2>&1 && RipDpi="$(jq -r '.RipDpi' "$apkdlJson" 2>/dev/null)" || RipDpi=1
  # Get RipLib value from json
  jq -e '.RipLib != null' "$apkdlJson" >/dev/null 2>&1 && RipLib="$(jq -r '.RipLib' "$apkdlJson" 2>/dev/null)" || RipLib=1

  # Build locale & lcd_dpi
  if [ $isAndroid -eq 1 ]; then
    locale=$(getprop persist.sys.locale | cut -d'-' -f1)  # Get System Languages
    [ -z $locale ] && locale=$(getprop ro.product.locale | cut -d'-' -f1)  # Get Languages
    density=$(getprop ro.sf.lcd_density)  # Get the device screen density
  elif [ $isMacOS -eq 1 ]; then
    locale=$(adb -s $serial shell getprop persist.sys.locale | cut -d'-' -f1)  # Get System Languages
    [ -z $locale ] && locale=$(adb -s $serial shell getprop ro.product.locale | cut -d'-' -f1)  # Get Languages
    density=$(adb -s $serial shell getprop ro.sf.lcd_density)  # Get the device screen density
  fi
  if [ $RipLocale -eq 0 ]; then
    locale="[a-z][a-z]"
  fi
  if [ $RipDpi -eq 1 ]; then
    # Check and categorize the density
    if [ "$density" -le "120" ]; then
      lcd_dpi="ldpi"  # Low Density
    elif [ "$density" -le "160" ]; then
      lcd_dpi="mdpi"  # Medium Density
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
  elif [ $RipDpi -eq 0 ]; then
    lcd_dpi="*dpi"
  fi

  POST_INSTALL="$apkdl/POST_INSTALL"; mkdir -p "$POST_INSTALL"
  InstallPackageFor=$(jq -r '.InstallPackageFor' "$apkdlJson" 2>/dev/null)
  KeepsData=$(jq -r '.KeepsData' "$apkdlJson" 2>/dev/null)
  GrantAllRuntimePermissions=$(jq -r '.GrantAllRuntimePermissions' "$apkdlJson" 2>/dev/null)
  InstalledAsTestOnly=$(jq -r '.InstalledAsTestOnly' "$apkdlJson" 2>/dev/null)
  BypassLowTargetSdkBolck=$(jq -r '.BypassLowTargetSdkBolck' "$apkdlJson" 2>/dev/null)
  DisablePlayProtect=$(jq -r '.DisablePlayProtect' "$apkdlJson" 2>/dev/null)
  DisableVerifyAdbInstalls=$(jq -r '.DisableVerifyAdbInstalls' "$apkdlJson" 2>/dev/null)
  Installer=$(jq -r '.Installer' "$apkdlJson" 2>/dev/null)
  Reinstall=$(jq -r '.Reinstall' "$apkdlJson" 2>/dev/null)
  EnableRoolback=$(jq -r '.EnableRoolback' "$apkdlJson" 2>/dev/null)

  if [ $InstallPackageFor -eq 0 ]; then
    [ $isAndroid -eq 1 ] && cmd="--user $(am get-current-user)"
    [ $isMacOS -eq 1 ] && cmd="--user $(adb -s $serial shell "pm list users | grep running | grep -o 'UserInfo{[0-9]*' | grep -o '[0-9]'")"
  else
    cmd="--user all"
  fi
  [ $GrantAllRuntimePermissions -eq 1 ] && cmd+=" -g"
  [ $InstalledAsTestOnly -eq 1 ] && cmd+=" -t"
  [ $BypassLowTargetSdkBolck -eq 1 ] && cmd+=" --bypass-low-target-sdk-block"
  case "$Installer" in
    "com.android.vending") cmd+=" -i com.android.vending" ;;
    "com.android.packageinstaller") cmd+=" -i com.android.packageinstaller" ;;
    "com.android.shell") cmd+=" -i com.android.shell" ;;
    "adb") cmd+=" -i adb" ;;
  esac
  [ $Reinstall -eq 1 ] && cmd+=" -r"
  [ $EnableRoolback -eq 1 ] && cmd+=" --enable-rollback"
fi

all_key=("RmFileAfterInstallation" "PreReleasePatches")
all_value=("$isRmFile" "$isPreRelease")
for i in "${!all_key[@]}"; do
  ! jq -e --arg key "${all_key[i]}" 'has($key)' "$apkdlJson" >/dev/null && config "${all_key[i]}" "${all_value[i]}"
done
# Get RmFileAfterInstallation value from json
jq -e '.RmFileAfterInstallation != null' "$apkdlJson" >/dev/null 2>&1 && RmFileAfterInstallation="$(jq -r '.RmFileAfterInstallation' "$apkdlJson" 2>/dev/null)" || RmFileAfterInstallation=1
# Get PreReleasePatches value from json
jq -e '.PreReleasePatches != null' "$apkdlJson" >/dev/null 2>&1 && PreReleasePatches="$(jq -r '.PreReleasePatches' "$apkdlJson" 2>/dev/null)" || PreReleasePatches=0

sign() {
  apkPath="${1}"
  fileName=$(basename "$apkPath")
  wo_ext="${apkPath%.*}"
  outApkPath="$wo_ext-signed.apk"
  verify() {
    if [ $isAndroid -eq 1 ]; then
      echo -e "$running Checking $fileName Certificate.."
      certs=$($PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar verify --print-certs "${apkPath}" 2>/dev/null)
      apksigner_exit_status=$?
      grep -oP 'Signer #1 certificate DN: \K.*' <<< "$certs"
    elif [ $isMacOS -eq 1 ]; then
      apksigner=("$HOME/Library/Android/sdk/build-tools/"*/apksigner) && apksigner="${apksigner[-1]}"
      echo -e "$running Checking $fileName Certificate.."
      certs=$($apksigner verify --print-certs "${apkPath}" 2>/dev/null)
      apksigner_exit_status=$?
      grep "Signer #1 certificate DN:" <<< "$certs" | cut -d: -f2-
    fi
  }; verify
  if [ $apksigner_exit_status -ne 0 ]; then
    if [ $isAndroid -eq 1 ]; then
      [ ! -f $apkdl/ks.keystore ] && { echo -e "$running Create a ${Red}ks.keystore${Reset} for Signing apk.."; $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -genkey -v -storetype pkcs12 -keystore $apkdl/ks.keystore -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=In" -storepass 123456 -keypass 123456; echo -e "$running Checking details about keystore entries.."; $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/keytool -list -v -keystore $apkdl/ks.keystore -storepass 123456 | grep -oP '(?<=Owner:).*' | xargs; }
      echo -e "$running Signing apk.."
      $PREFIX/lib/jvm/java-$jdkVersion-openjdk/bin/java -jar $PREFIX/share/java/apksigner.jar sign --ks $apkdl/ks.keystore --ks-pass pass:123456 --ks-key-alias ReVancedKey --key-pass pass:123456 --out "${outApkPath}" "${apkPath}"
      signing_exit_status=$?
    elif [ $isMacOS -eq 1 ]; then
      [ ! -f $apkdl/ks.keystore ] && { keytool="/usr/local/opt/openjdk/bin/keytool"; echo -e "$running Create a ${Red}ks.keystore${Reset} for Signing apk.."; $keytool -genkey -v -storetype pkcs12 -keystore $apkdl/ks.keystore -alias ReVancedKey -keyalg RSA -keysize 2048 -validity 36050 -dname "CN=arghya339, OU=Android Development Team, O=ReVanced, L=Kolkata, S=West Bengal, C=In" -storepass 123456 -keypass 123456; echo -e "$running Checking details about keystore entries.."; $keytool -list -v -keystore $apkdl/ks.keystore -storepass 123456 | grep "Owner:" | cut -d: -f2- | xargs; }
      echo -e "$running Signing apk.."
      $apksigner sign --ks $apkdl/ks.keystore --ks-pass pass:123456 --ks-key-alias ReVancedKey --key-pass pass:123456 --out "${outApkPath}" "${apkPath}"
      signing_exit_status=$?
    fi
    [ $signing_exit_status -eq 0 ] && { rm -f "$outApkPath.idsig"; rm -f "$apkPath"; mv "$outApkPath" "$apkPath"; verify; }
  fi
}

downloadAPK() {
  while true; do
    if [ $isAndroid -eq 1 ]; then
      aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" -U "User-Agent: $USER_AGENT" -U "Referer: https://www.apkmirror.com/" --async-dns=true --async-dns-server="$cloudflareIP" "$dlLink"
      exitStatus=$?
    elif [ $isMacOS -eq 1 ]; then
      aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" -U "User-Agent: $USER_AGENT" -U "Referer: $variantLink" --ca-certificate="/etc/ssl/cert.pem" --async-dns=true --async-dns-server=$cloudflareIP "$dlLink"
      exitStatus=$?
    fi
    echo
    [ $exitStatus -eq 0 ] && break || sleep 5
  done 
  
  if [ $isAndroid -eq 1 ]; then
    sha256sum=$(sha256sum "$apkPath" | cut -d' ' -f1)
  elif [ $isMacOS -eq 1 ]; then
    sha256sum=$(shasum -a 256 "$apkPath" | cut -d' ' -f1)
  fi
  if [ "$sha256sum" == "$SHA256" ]; then
    echo -e "$good Downloaded file appears in the original state."
  else
    echo -e "$bad Look like downloaded file appears corrupted!"
    echo -e "$notice SHA-256 SUM Diffs - Expected: ${Cyan}$SHA256${Reset} ~ Result: ${Cyan}$sha256sum${Reset}"
  fi
}

apks2apk() {
  owner="ReAndroid"; repo="APKEditor"
  ghApiResponseJson=$(curl -sL ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest")
  tag_name=$(jq -r '.tag_name | sub("^V"; "")' <<< "$ghApiResponseJson")  # 1.4.5
  APKEditor="APKEditor-$tag_name.jar"
  APKEditorPath="$apkdl/$APKEditor"
  findAPKEditorPath=$(find "$apkdl" -maxdepth 1 -type f -name "APKEditor-*.jar" -print -quit)
  if [ -f "$findAPKEditorPath" ]; then
    findAPKEditor=$(basename "$findAPKEditorPath" 2>/dev/null)
    if [ "$APKEditor" != "$findAPKEditor" ]; then
      echo -e "$notice diffs: $APKEditor ~ $findAPKEditor"
      rm -f "$findAPKEditorPath"
      while true; do
        curl -L --progress-bar -o $APKEditorPath -C - https://github.com/REAndroid/APKEditor/releases/download/V$tag_name/APKEditor-$tag_name.jar
        [ $? -eq 0 ] && break || sleep 5
      done
    fi
  else
    while true; do
      curl -L --progress-bar -o $APKEditorPath -C - https://github.com/REAndroid/APKEditor/releases/download/V$tag_name/APKEditor-$tag_name.jar
      [ $? -eq 0 ] && break || sleep 5
    done
  fi
  
  if [ $isMacOS -eq 1 ]; then
    java -jar $APKEditorPath m -i "$apkPath" -o "$Download/${appName}_v${version}-${arch}.apk" && rm -f "$apkPath"
  elif [ $isAndroid -eq 1 ]; then
    mkdir -p "$Download/${appName}_v${version}-${arch}"
    termux-wake-lock
    if [ $RipLib -eq 1 ]; then
      pv "$apkPath" | bsdtar -xf - -C "$Download/${appName}_v${version}-${arch}/" --include "$pkgName.apk" "config.${cpuAbi//-/_}.apk" "config.${locale}.apk" "config.${lcd_dpi}.apk"
      bsdtar_exit_status=$?
    elif [ $RipLib -eq 1 ]; then
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
  [ $isAndroid -eq 1 ] && termux-open-url "$url"
  [ $isMacOS -eq 1 ] && open "$url"
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
            userInput="$(echo "${web[@]}")"
          fi
          if [ "$userInput" == "GitHub" ]; then
            if gh auth status >/dev/null 2>&1; then
              gh auth logout  # Logout from gh cli
            elif jq -e '.GH' "$apkdlJson" >/dev/null 2>&1; then
              jq 'del(.GH)' "$apkdlJson" > temp.json && mv temp.json "$apkdlJson"  # Delete GH key from apkdl.json
              url="https://github.com/settings/tokens"
              [ $isAndroid -eq 1 ] && termux-open-url "$url"
              [ $isMacOS -eq 1 ] && open "$url"
            fi
          elif [ "$userInput" == "GitLab" ]; then
            if glab auth status >/dev/null 2>&1; then
              glab auth logout --hostname gitlab.com  # Logout from glab cli
            elif jq -e '.GLAB' "$apkdlJson" >/dev/null 2>&1; then
              jq 'del(.GLAB)' "$apkdlJson" > temp.json && mv temp.json "$apkdlJson"  # Delete GLAB key from apkdl.json
              url="https://gitlab.com/-/user_settings/personal_access_tokens"
              [ $isAndroid -eq 1 ] && termux-open-url "$url"
              [ $isMacOS -eq 1 ] && open "$url"
            fi
          fi
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
                  [ $isAndroid -eq 1 ] && pkgInstall "gh"  # gh install/update
                  [ $isMacOS -eq 1 ] && formulaeInstall "gh"  # gh install/update
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
                  [ $isAndroid -eq 1 ] && pkgInstall "glab-cli"  # glab-cli install/update
                  [ $isMacOS -eq 1 ] && formulaeInstall "glab"  # glab install/update
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

declare -a apps applications
while true; do
  options=(GitHub GitLab APKMirror Uptodown APKPure ReVanced RVX)
  if { [ $isMacOS -eq 1 ] && [ -n "$serial" ]; } || { [ $isAndroid -eq 1 ] && { [ $su -eq 1 ] || "$HOME/rish" -c "id" >/dev/null 2>&1 || "$HOME/adb" -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; }; }; then
    options+=(appUpdates uninstallApps)
  fi
  if { [ "$isMacOS" -eq 1 ] || [ -n "$serial" ]; } || [ "$isAndroid" -eq 1 ]; then
    options+=(Configuration)
  fi
  buttons=("<Select>" "<Exit>"); if menu "options" "buttons" "${#options[@]}"; then selected=${options[selected]}; fi
  case "$selected" in
    GitHub)
      curl -sL -o "$apkdl/dlGitHub.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/dlGitHub.sh"
      source $apkdl/dlGitHub.sh

      searchGH
      [ $? -ne 0 ] && continue

      latestReleasesStatus=$(curl -sL "$releasesUrl/latest" | jq -r '.status')
      if [ "$latestReleasesStatus" -eq "404" ]; then
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

      fileName=$(basename "$asset_browser_download_url")
      filePath="$Download/$fileName"
      ext="${fileName##*.}"
      [ ! -f "$filePath" ] && dlGH
      if [ -f "$filePath" ]; then
        if { [[ $isMacOS -eq 1 && ( ( $ext == "apk" && -n $serial ) || $ext == "dmg" || $ext == "pkg" ) ]]; } || [[ $isAndroid -eq 1 ]]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid -eq 1 ]; then
              apkInstall "$filePath"
            elif [ $isMacOS -eq 1 ]; then
              ([ "$ext" == "apk" ] && [ -n "$serial" ]) && adbInstall "$filePath"
              ([ "$ext" == "dmg" ] || [ "$ext" == "pkg" ]) && open "$filePath"
            fi
          fi
        fi
      fi
      echo; read -p "Press Enter to continue..."
      { [[ $isMacOS -eq 1 && ( "$ext" == "dmg" || "$ext" == "pkg" ) && $RmFileAfterInstallation -eq 1 ]]; } && rm -f "$filePath"
      ;;
    GitLab)
      curl -sL -o "$apkdl/dlGitLab.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/dlGitLab.sh"
      source $apkdl/dlGitLab.sh

      searchGLAB
      [ $? -ne 0 ] && continue

      glabReleases
      [ $? -ne 0 ] && continue

      fileName=$(basename "$dlUrl")
      filePath="$Download/$fileName"
      ext="${fileName##*.}"
      [ ! -f "$filePath" ] && dlGLAB
      if [ -f "$filePath" ]; then
        if { [[ $isMacOS -eq 1 && ( ( $ext == "apk" && -n $serial ) || $ext == "dmg" || $ext == "pkg" ) ]]; } || [[ $isAndroid -eq 1 ]]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid -eq 1 ]; then
              apkInstall "$filePath"
            elif [ $isMacOS -eq 1 ]; then
              ([ "$ext" == "apk" ] && [ -n "$serial" ]) && adbInstall "$filePath"
              ([ "$ext" == "dmg" ] || [ "$ext" == "pkg" ]) && open "$filePath"
            fi
          fi
        fi
      fi
      echo; read -p "Press Enter to continue..."
      { [[ $isMacOS -eq 1 && ( "$ext" == "dmg" || "$ext" == "pkg" ) && $RmFileAfterInstallation -eq 1 ]]; } && rm -f "$filePath"
      ;;
    APKMirror)
      curl -sL -o "$apkdl/APKMdl.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/APKMdl.sh"
      
      source $apkdl/APKMdl.sh
      
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
        [ ! -f "$Download/${appName}_v${version}-${arch}.apk" ] && downloadAPK
        [ -f "$Download/${appName}_v${version}-${arch}.apkm" ] && apkm2apk
        [ -f "$Download/${appName}_v${version}-${arch}.apk" ] && apkPath="$Download/${appName}_v${version}-${arch}.apk"
        if [ -f "$apkPath" ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid -eq 1 ]; then
              sign "$apkPath" && apkInstall "$apkPath"
            elif [ $isMacOS -eq 1 ]; then
              ext="${fileName##*.}"
              ([[ "$ext" =~ ^apk.*$ ]] && [ -n "$serial" ]) && { sign "$apkPath" && adbInstall "$apkPath"; }
            fi
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    Uptodown)
      curl -sL -o "$apkdl/dlUptodown.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/dlUptodown.sh"
      
      source $apkdl/dlUptodown.sh
      
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
            if [ $isAndroid -eq 1 ]; then
              sign "$apkPath" && apkInstall "$apkPath"
            elif [ $isMacOS -eq 1 ]; then
              ext="${fileName##*.}"
              ([[ "$ext" =~ ^apk.*$ ]] && [ -n "$serial" ]) && { sign "$apkPath" && adbInstall "$apkPath"; }
            fi
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    APKPure)
      curl -sL -o "$apkdl/dlAPKPure.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/dlAPKPure.sh"
      source $apkdl/dlAPKPure.sh

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
            if [ $isAndroid -eq 1 ]; then
              sign "$apkPath" && apkInstall "$apkPath"
            elif [ $isMacOS -eq 1 ]; then
              ext="${fileName##*.}"
              ([[ "$ext" =~ ^apk.*$ ]] && [ -n "$serial" ]) && { sign "$apkPath" && adbInstall "$apkPath"; }
            fi
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    ReVanced)
      curl -sL -o "$apkdl/APKMdl.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/APKMdl.sh"
      source $apkdl/APKMdl.sh
      
      curl -sL -o "$apkdl/RVdl.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/RVdl.sh"
      source $apkdl/RVdl.sh "ReVanced"
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
        [ ! -f "$Download/${appName}_v${version}-${arch}.apk" ] && downloadAPK
        [ -f "$Download/${appName}_v${version}-${arch}.apkm" ] && apkm2apk
        [ -f "$Download/${appName}_v${version}-${arch}.apk" ] && apkPath="$Download/${appName}_v${version}-${arch}.apk"
        if [ -f "$apkPath" ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid -eq 1 ]; then
              sign "$apkPath" && apkInstall "$apkPath"
            elif [ $isMacOS -eq 1 ]; then
              ext="${fileName##*.}"
              ([[ "$ext" =~ ^apk.*$ ]] && [ -n "$serial" ]) && { sign "$apkPath" && adbInstall "$apkPath"; }
            fi
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    RVX)
      curl -sL -o "$apkdl/APKMdl.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/APKMdl.sh"
      source $apkdl/APKMdl.sh
      
      curl -sL -o "$apkdl/RVdl.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/RVdl.sh"
      source $apkdl/RVdl.sh "RVX"
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
        [ ! -f "$Download/${appName}_v${version}-${arch}.apk" ] && downloadAPK
        [ -f "$Download/${appName}_v${version}-${arch}.apkm" ] && apkm2apk
        [ -f "$Download/${appName}_v${version}-${arch}.apk" ] && apkPath="$Download/${appName}_v${version}-${arch}.apk"
        if [ -f "$apkPath" ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid -eq 1 ]; then
              sign "$apkPath" && apkInstall "$apkPath"
            elif [ $isMacOS -eq 1 ]; then
              ext="${fileName##*.}"
              ([[ "$ext" =~ ^apk.*$ ]] && [ -n "$serial" ]) && { sign "$apkPath" && adbInstall "$apkPath"; }
            fi
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    appUpdates)
      curl -sL -o "$apkdl/APKMdl.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/APKMdl.sh"
      source $apkdl/APKMdl.sh
      
      curl -sL -o "$apkdl/installedApps.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/installedApps.sh"
      source $apkdl/installedApps.sh
      
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
        [ ! -f "$Download/${appName}_v${version}-${arch}.apk" ] && downloadAPK
        [ -f "$Download/${appName}_v${version}-${arch}.apkm" ] && apkm2apk
        [ -f "$Download/${appName}_v${version}-${arch}.apk" ] && apkPath="$Download/${appName}_v${version}-${arch}.apk"
        if [ -f "$apkPath" ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt=Yes || opt=No
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid -eq 1 ]; then
              sign "$apkPath" && apkInstall "$apkPath"
            elif [ $isMacOS -eq 1 ]; then
              ext="${fileName##*.}"
              ([[ "$ext" =~ ^apk.*$ ]] && [ -n "$serial" ]) && { sign "$apkPath" && adbInstall "$apkPath"; }
            fi
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    uninstallApps)
      curl -sL -o "$apkdl/installedApps.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/installedApps.sh"
      source $apkdl/installedApps.sh
      
      [ ${#applications[@]} -eq 0 ] && packagesList
      
      packagesUninstall
      [ $? -ne 0 ] && continue || { echo; read -p "Press Enter to continue..."; }
      ;;
    Configuration)
      while true; do
        RipLocale="$(jq -r '.RipLocale' "$apkdlJson" 2>/dev/null)"
        RipDpi="$(jq -r '.RipDpi' "$apkdlJson" 2>/dev/null)"
        RipLib="$(jq -r '.RipLib' "$apkdlJson" 2>/dev/null)"
        RmFileAfterInstallation="$(jq -r '.RmFileAfterInstallation' "$apkdlJson" 2>/dev/null)"
        PreReleasePatches=$(jq -r '.PreReleasePatches' "$apkdlJson" 2>/dev/null)
        options=(RipLocale RipDpi RipLib RmFileAfterInstallation PreReleasePatches "Add gh/ glab PAT (increases gh/ glab api rate limit)")
        if [ $isAndroid -eq 1 ]; then
          CheckTermuxUpdate=$(jq -r '.CheckTermuxUpdate' "$apkdlJson" 2>/dev/null)
          jdkVersion="$(jq -r '.openjdk' "$apkdlJson" 2>/dev/null)"
          if [ $su -eq 1 ]; then
            options+=("SU Installation Options")
          elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
            options+=("SUI Installation Options")
          elif "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
            options+=("ADB Installation Options")
          fi
          if [ "$(getprop ro.product.manufacturer)" == "Genymobile" ] && ! "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
            options+=(Pair\ ADB)
          fi
          options+=("Check Termux update on startup" "Change Java version")
        elif [ $isMacOS -eq 1 ] && [ -n "$serial" ]; then
          options+=("ADB Installation Options")
        fi
        buttons=("<Select>" "<Back>"); if menu "options" "buttons" "${#options[@]}"; then selected="${options[$selected]}"; else break; fi
        case "$selected" in
          RipLocale) if [ $RipLocale -eq 1 ]; then echo "RipLocale == true"; else echo "RipLocale == false"; fi
            m1="Device specific locale will be kept in apk file"
            m2="All locale will be kept in apk file"
            tfConfig "RipLocale" "$isRipLocale" "$m1" "$m2"
            ;;
          RipDpi) if [ $RipDpi -eq 1 ]; then echo "RipDpi == true"; else echo "RipDpi == false"; fi
            m1="Device specific dpi will be kept in apk file"
            m2="All dpi will be kept in apk file"
            tfConfig "RipDpi" "$isRipDpi" "$m1" "$m2"
            ;;
          RipLib) if [ $RipLib -eq 1 ]; then echo "RipLib == true"; else echo "RipLib == false"; fi
            m1="Device specific arch lib will be kept in apk file"
            m2="All lib dir will be kept in apk file"
            tfConfig "RipLib" "$isRipLib" "$m1" "$m2"
            ;;
          RmFileAfterInstallation) [ $RmFileAfterInstallation -eq 1 ] && echo "RmFileAfterInstallation == true" || echo "RmFileAfterInstallation == false"
            m1="Remove downloaded file after installation"
            m2="Keep downloaded file after installation"
            tfConfig "RmFileAfterInstallation" "$isRmFile" "$m1" "$m2"
            ;;
          PreReleasePatches)
            [ $PreReleasePatches -eq 0 ] && echo "PreReleasePatches == false" || echo "PreReleasePatches == true"
            m1="Fetch Pre-Release Patches"
            m2="Fetch Latest Release Patches"
            tfConfig "PreReleasePatches" "$isPreRelease" "$m1" "$m2"
            ;;
          "SU Installation Options"|"SUI Installation Options"|"ADB Installation Options")
            while true; do
              InstallPackageFor=$(jq -r '.InstallPackageFor' "$apkdlJson" 2>/dev/null)
              KeepsData=$(jq -r '.KeepsData' "$apkdlJson" 2>/dev/null)
              GrantAllRuntimePermissions=$(jq -r '.GrantAllRuntimePermissions' "$apkdlJson" 2>/dev/null)
              InstalledAsTestOnly=$(jq -r '.InstalledAsTestOnly' "$apkdlJson" 2>/dev/null)
              BypassLowTargetSdkBolck=$(jq -r '.BypassLowTargetSdkBolck' "$apkdlJson" 2>/dev/null)
              DisablePlayProtect=$(jq -r '.DisablePlayProtect' "$apkdlJson" 2>/dev/null)
              DisableVerifyAdbInstalls=$(jq -r '.DisableVerifyAdbInstalls' "$apkdlJson" 2>/dev/null)
              Installer=$(jq -r '.Installer' "$apkdlJson" 2>/dev/null)
              Reinstall=$(jq -r '.Reinstall' "$apkdlJson" 2>/dev/null)
              EnableRoolback=$(jq -r '.EnableRoolback' "$apkdlJson" 2>/dev/null)
              options=("Install Package for *user" "Allow Downgrade with keeps App data (reboot required)" "Grant All Runtime/ Requested Permissions" Installed\ as\ test-only\ app Bypass\ Low\ Target\ SDK\ Bolck Disable\ Play\ Protect\ Package\ Verification Disable\ Verify\ Adb\ Installs Installer "Reinstall (Replace/ Upgrade) Existing Installed Package" Enable\ Version\ Roolback)
              buttons=("<Select>" "<Back>"); if menu "options" "buttons" "10"; then selected="${options[$selected]}"; else break; fi
              case "$selected" in
                "Install Package for *user")
                  if [ "$InstallPackageFor" -eq 0 ]; then echo "InstallPackageFor == 0 (default-user)"; else echo "InstallPackageFor == 1 (all-users)"; fi
                  buttons=("<default-user>" "<all-users>"); confirmPrompt "InstallPackageFor" "buttons" "$isU" && u=default-user || u=all-users
                  if [ -n "$u" ]; then
                    case "$u" in
                      [Dd]*) config "InstallPackageFor" "0" && echo -e "$good ${Green}Install Package for default-user set successfully!${Reset}" ;;
                      [Aa]*) config "InstallPackageFor" "1" && echo -e "$good ${Green}Install Package for all-user set successfully!${Reset}" ;;
                    esac
                    sleep 2
                  fi
                  ;;
                "Allow Downgrade with keeps App data (reboot required)")
                  if [ "$KeepsData" -eq 0 ]; then echo "KeepsData == false"; else echo "KeepsData == true"; fi
                  m1="Allow Downgrade with keeps App data Enabled"
                  m2="Allow Downgrade with keeps App data Disabled"
                  tfConfig "KeepsData" "$isK" "$m1" "$m2"
                  ;;
                "Grant All Runtime/ Requested Permissions")
                  if [ "$GrantAllRuntimePermissions" -eq 0 ]; then echo "GrantAllRuntimePermissions == false"; else echo "GrantAllRuntimePermissions == true"; fi
                  m1="Grant All Runtime Permissions Enabled"
                  m2="Grant All Runtime Permissions Disabled"
                  tfConfig "GrantAllRuntimePermissions" "$isG" "$m1" "$m2"
                  ;;
                Installed\ as\ test-only\ app)
                  if [ "$InstalledAsTestOnly" -eq 0 ]; then echo "InstalledAsTestOnly == false"; else echo "InstalledAsTestOnly == true"; fi
                  m1="Installed as test-only Enabled"
                  m2="Installed as test-only Disabled"
                  tfConfig "InstalledAsTestOnly" "$isT" "$m1" "$m2"
                  ;;
                Bypass\ Low\ Target\ SDK\ Bolck)
                  if [ "$BypassLowTargetSdkBolck" -eq 1 ]; then echo "BypassLowTargetSdkBolck == true"; else echo "BypassLowTargetSdkBolck == false"; fi
                  m1="Bypass Low Target SDK Bolck Enabled"
                  m2="Bypass Low Target SDK Bolck Disabled"
                  tfConfig "BypassLowTargetSdkBolck" "$isL" "$m1" "$m2"
                  ;;
                Disable\ Play\ Protect\ Package\ Verification)
                  if [ "$DisablePlayProtect" -eq 1 ]; then echo "DisablePlayProtect == true"; else echo "DisablePlayProtect == false"; fi
                  m1="Play Protect Package Verification Disabled"
                  m2="Play Protect Package Verification Enabled"
                  tfConfig "DisablePlayProtect" "$isV" "$m1" "$m2"
                  ;;
                Disable\ Verify\ Adb\ Installs)
                  [ $DisableVerifyAdbInstalls -eq 1 ] && echo "DisableVerifyAdbInstalls == true" || echo "DisableVerifyAdbInstalls == false"
                  m1="Verify Adb Installs Disabled"; m2="Verify Adb Installs Enabled"; tfConfig "DisableVerifyAdbInstalls" "$isA" "$m1" "$m2"
                  ;;
                Installer)
                  case "$Installer" in
                    "com.android.vending") echo "Installer == com.android.vending (PlayStore)" ;;
                    "com.android.packageinstaller") echo "Installer == com.android.packageinstaller (PackageInstaller)" ;;
                    "com.android.shell") echo "Installer == com.android.shell (Shell)" ;;
                    "adb") echo "Installer == adb" ;;
                  esac
                  options=(Play\ Store Package\ Installer Shell ADB)
                  buttons=("<Select>" "<Back>"); if menu "options" "buttons" "4"; then selected="${options[$selected]}"; fi
                  if [ -n "$selected" ]; then
                    case "$selected" in
                      Play\ Store) config "Installer" "com.android.vending" && echo -e "$good ${Green}Successfully set Installer as 'com.android.vending' (PlayStore)${Reset}" ;;
                      Package\ Installer) config "Installer" "com.android.packageinstaller" && echo -e "$good ${Green}Successfully set Installer as 'com.android.packageinstaller' (PackageInstaller)${Reset}" ;;
                      Shell) config "Installer" "com.android.shell" && echo -e "$good ${Green}Successfully set Installer as 'com.android.shell' (Shell)${Reset}" ;;
                      ADB) config "Installer" "adb" && echo -e "$good ${Green}Successfully set Installer as 'adb'${Reset}" ;;
                    esac
                    sleep 2
                  fi
                  ;;
                "Reinstall (Replace/ Upgrade) Existing Installed Package")
                  if [ "$Reinstall" -eq 1 ]; then echo "Reinstall == true"; else echo "Reinstall == false"; fi
                  m1="Reinstall Existing Installed Package Enabled"
                  m2="Reinstall Existing Installed Package Disabled"
                  tfConfig "Reinstall" "$isR" "$m1" "$m2"
                  ;;
                Enable\ Version\ Roolback)
                  if [ "$EnableRoolback" -eq 0 ]; then echo "EnableRoolback == false"; else echo "EnableRoolback == true"; fi
                  m1="Version Roolback Enabled"
                  m2="Version Roolback Disabled"
                  tfConfig "EnableRoolback" "$isB" "$m1" "$m2"
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
            ~/adb pair "$host_port" "$pairing_code"
            ;;
          Check\ Termux\ update\ on\ startup) [ $CheckTermuxUpdate -eq 1 ] && echo "CheckTermuxUpdate == true" || echo "CheckTermuxUpdate == false"
            m1="Check for Termux app updates on startup"
            m2="Never check for Termux app updates on startup"
            tfConfig "CheckTermuxUpdate" "$isCheckTermuxUpdate" "$m1" "$m2"
            ;;
          Change\ Java\ version)
            echo "openjdkVersion == $jdkVersion"
            # Get available JDK versions
            attempt=0
            while true; do
              jdkVersion=($(pkg search openjdk 2>&1 | grep -E "^openjdk-[0-9]+/" | awk -F'[-/ ]' '{print $2}'))
              [ $attempt -eq 7 ] && { echo -e "$notice Not found any java version in search result, after 7 attempts!"; break; }
              [ ${#jdkVersion[@]} -ne 0 ] && break
              ((attempt++))
              sleep 0.5  # wait 500 milliseconds
            done
            # Select JDK versions
            buttons=("<Select>" "<Back>"); if menu "jdkVersion" "buttons"; then version="${jdkVersion[$selected]}"; fi
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
        esac
      done
      ;;
  esac
done
#########################################################################################################################
