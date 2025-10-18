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

curl -sL -o "$apkdl/APKMdl.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/APKMdl.sh"
curl -sL -o "$apkdl/dlUptodown.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/dlUptodown.sh"
curl -sL -o "$apkdl/RVdl.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/RVdl.sh"

apkdlJson="$apkdl/apkdl.json"  # Configuration file to store apkdl settings

isRipLocale=1  # Default value (true/on/1) for RipLocale, it's delete locale from apk file except device specific locale by default
isRipDpi=1  # Default value (true/on/1) for RipDpi, it's delete dpi from apk file except device specific dpi by default
isRipLib=1  # Default value (true/on/1) for RipLib, it's delete lib dir from apk file except device specific arch lib by default

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
crVersion="140.0.0.0"
crVersion=$(curl -sL "https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Android&num=1" | jq -r '.[0].version')

if [ $isMacOS -eq 1 ]; then
  Download="$HOME/Downloads"
  [ $(uname -m) == "x86_64" ] && Arch=$Arch || Arch=arm64
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
  printf '\n'
  printf '\n'
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
  # --- Check if brew is installed ---
  if brew --version >/dev/null 2>&1; then
    brew update > /dev/null 2>&1
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null 2>&1
  fi
  formulaeList=$(brew list 2>/dev/null)
  outdatedFormulae=$(brew outdated 2>/dev/null)

  # --- formulae upgrade function ---
  formulaeUpdate() {
    local formulae=$1
    if echo "$outdatedFormulae" | grep -q "^$formulae" 2>/dev/null; then
      echo -e "$running Upgrading $formulae formulae.."
      brew upgrade "$formulae" > /dev/null 2>&1
    fi
  }

  # --- formulae install/update function ---
  formulaeInstall() {
    local formulae=$1
    if echo "$formulaeList" | grep -q "$formulae" 2>/dev/null; then
      formulaeUpdate "$formulae"
    else
      echo -e "$running Installing $formulae formulae.."
      brew install "$formulae" > /dev/null 2>&1
    fi
  }

  formulaeInstall "bash"  # bash update
  formulaeInstall "grep"  # grep update
  formulaeInstall "curl"  # curl update
  formulaeInstall "aria2"  # aria2 install/update
  formulaeInstall "ca-certificate"  # ca-certificate update
  formulaeInstall "jq"  # jq install/update
  formulaeInstall "pv"  # pv install/update
  formulaeInstall "pup"  # pup install/update
  formulaeInstall "openjdk"  # java install/update
  grep -q 'export PATH="/usr/local/opt/openjdk/bin:$PATH"' ~/.zshrc 2>/dev/null || echo 'export PATH="/usr/local/opt/openjdk/bin:$PATH"' >> ~/.zshrc
  # https://github.com/aria2/aria2/issues/1920
  aria2Executing=$(aria2c -q -d "$HOME" -o aria2Executing -U "User-Agent: $USER_AGENT" -U "Referer: https://one.one.one.one/" --ca-certificate="/etc/ssl/cert.pem" --async-dns=true --async-dns-server="$cloudflareIP" "https://one.one.one.one/")
  if echo "$aria2Executing" | grep -q "--async-dns=true" 2>/dev/null; then
    curl -L --progress-bar -C - -o $HOME/Downloads/aria2c-macos-$Arch.tar https://github.com/tofuliang/aria2/releases/download/20240919/aria2c-macos-$Arch.tar
    pv "$HOME/Downloads/aria2c-macos-$Arch.tar" | tar -xf - -C "$HOME/Downloads" && rm -f "$HOME/Downloads/aria2c-macos-$Arch.tar"
    sudo mv $HOME/Downloads/aria2c /usr/local/bin/aria2c
    if aria2c -v &>/dev/null; then
      aria2c -v | head -1 | awk '{print $3}'
    else
      sudo xattr -d com.apple.quarantine /usr/local/bin/aria2c && aria2c -v | head -1 | awk '{print $3}'
    fi
    rm -f ~/aria2Executing
  else
    rm -f ~/aria2Executing
  fi
elif [ $isAndroid -eq 1 ]; then
  pkg update > /dev/null 2>&1 || apt update >/dev/null 2>&1  # It downloads latest package list with versions from Termux remote repository, then compares them to local (installed) pkg versions, and shows a list of what can be upgraded if they are different.
  outdatedPKG=$(apt list --upgradable 2>/dev/null)  # list of outdated pkg
  echo "$outdatedPKG" | grep -q "dpkg was interrupted" 2>/dev/null && { yes "N" | dpkg --configure -a; outdatedPKG=$(apt list --upgradable 2>/dev/null); }
  installedPKG=$(pkg list-installed 2>/dev/null)  # list of installed pkg

  # --- Storage Permission Check Logic ---
  if ! ls /sdcard/ 2>/dev/null | grep -E -q "^(Android|Download)"; then
    echo -e "${notice} ${Yellow}Storage permission not granted!${Reset}\n$running ${Green}termux-setup-storage${Reset}.."
    if [ "$Android" -gt 5 ]; then  # for Android 5 storage permissions grant during app installation time, so Termux API termux-setup-storage command not required
      count=0
      while true; do
        if [ "$count" -ge 2 ]; then
          echo -e "$bad Failed to get storage permissions after $count attempts!"
          echo -e "$notice Please grant permissions manually in Termux App info > Permissions > Files > File permission → Allow."
          am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.termux &> /dev/null
          exit 0
        fi
        termux-setup-storage  # ask Termux Storage permissions
        sleep 3  # wait 3 seconds
        if ls /sdcard/ 2>/dev/null | grep -q "^Android" || ls "$HOME/storage/shared/" 2>/dev/null | grep -q "^Android"; then
          if [ "$Android" -lt 8 ]; then
            exit 0  # Exit the script
          fi
          break
        fi
        ((count++))
      done
    fi
  fi

  # --- enabled allow-external-apps ---
  isOverwriteTermuxProp=0
  if [ $Android -eq 6 ] && [ ! -f "$HOME/.termux/termux.properties" ]; then
    mkdir -p "$HOME/.termux" && echo "allow-external-apps = true" > "$HOME/.termux/termux.properties"
    isOverwriteTermuxProp=1
    echo -e "$notice 'termux.properties' file has been created successfully & 'allow-external-apps = true' line has been add (enabled) in Termux \$HOME/.termux/termux.properties."
    termux-reload-settings
  elif [ $Android -eq 6 ] && [ -f "$HOME/.termux/termux.properties" ]; then
    if grep -q "^# allow-external-apps" "$HOME/.termux/termux.properties"; then
      sed -i '/allow-external-apps/s/# //' "$HOME/.termux/termux.properties"  # uncomment 'allow-external-apps = true' line
      isOverwriteTermuxProp=1
      echo -e "$notice 'allow-external-apps = true' line has been uncommented (enabled) in Termux \$HOME/.termux/termux.properties."
      termux-reload-settings
    fi
  fi
  if [ "$Android" -ge 6 ]; then
    if grep -q "^# allow-external-apps" "$HOME/.termux/termux.properties"; then
      # other Android applications can send commands into Termux.
      # termux-open utility can send an Android Intent from Termux to Android system to open apk package file in pm.
      # other Android applications also can be Access Termux app data (files).
      sed -i '/allow-external-apps/s/# //' "$HOME/.termux/termux.properties"  # uncomment 'allow-external-apps = true' line
      isOverwriteTermuxProp=1
      echo -e "$notice 'allow-external-apps = true' line has been uncommented (enabled) in Termux \$HOME/.termux/termux.properties."
      #if [ "$Android" -eq 7 ] || [ "$Android" -eq 6 ]; then
        termux-reload-settings  # reload (restart) Termux settings required for Android 6 after enabled allow-external-apps, also required for Android 7 due to 'Package installer has stopped' err
      #fi
    fi
  fi

  su -c "id" >/dev/null 2>&1 && su=1 || su=0

  # --- Shizuku Setup first time ---
  if [ $su -eq 0 ] && { [ ! -f "$HOME/rish" ] || [ ! -f "$HOME/rish_shizuku.dex" ]; }; then
    #echo -e "$info Please manually install Shizuku from Google Play Store." && sleep 1
    #termux-open-url "https://play.google.com/store/apps/details?id=moe.shizuku.privileged.api"
    echo -e "$info Please manually install Shizuku from GitHub." && sleep 1
    termux-open-url "https://github.com/RikkaApps/Shizuku/releases/latest"
    am start -n com.android.settings/.Settings\$MyDeviceInfoActivity > /dev/null 2>&1  # Open Device Info

    curl -sL -o "$HOME/rish" "https://raw.githubusercontent.com/arghya339/crdl/refs/heads/main/Termux/Shizuku/rish" && chmod +x "$HOME/rish"
    sleep 0.5 && curl -sL -o "$HOME/rish_shizuku.dex" "https://raw.githubusercontent.com/arghya339/crdl/refs/heads/main/Termux/Shizuku/rish_shizuku.dex"
  
    if [ "$Android" -lt 11 ]; then
      url="https://youtu.be/ZxjelegpTLA"  # YouTube/@MrPalash360: Start Shizuku using Computer
      activityClass="com.android.settings/.Settings\$DevelopmentSettingsDashboardActivity"  # Open Developer options
    else
      activityClass="com.android.settings/.Settings\$WirelessDebuggingActivity"  # Open Wireless Debugging Settings
      url="https://youtu.be/YRd0FBfdntQ"  # YouTube/@MrPalash360: Start Shizuku Android 11+
    fi
    echo -e "$info Please start Shizuku by following guide: $url" && sleep 1
    am start -n "$activityClass" > /dev/null 2>&1
    termux-open-url "$url"
  fi
  if ! "$HOME/rish" -c "id" >/dev/null 2>&1 && [ -f "$HOME/rish_shizuku.dex" ]; then
    if ~/rish -c "id" 2>&1 | grep -q 'java.lang.UnsatisfiedLinkError'; then
      rm -f "$HOME/rish_shizuku.dex" && curl -sL -o "$HOME/rish_shizuku.dex" "https://raw.githubusercontent.com/arghya339/crdl/refs/heads/main/Termux/Shizuku/Play/rish_shizuku.dex"
    fi
  fi

  if [ "$(getprop ro.product.manufacturer)" == "Genymobile" ] && [ ! -f "$HOME/adb" ]; then
    curl -sL -o "$HOME/adb" "https://raw.githubusercontent.com/rendiix/termux-adb-fastboot/refs/heads/master/binary/${cpuAbi}/bin/adb" && chmod +x ~/adb
  fi

  # --- pkg uninstall function ---
  pkgUninstall() {
    local pkg=$1
    if echo "$installedPKG" | grep -q "^$pkg/" 2>/dev/null; then
      echo -e "$running Uninstalling $pkg pkg.."
      pkg uninstall "$pkg" -y > /dev/null 2>&1
    fi
  }

  # --- pkg upgrade function ---
  pkgUpdate() {
  local pkg=$1
    if echo "$outdatedPKG" | grep -q "^$pkg/" 2>/dev/null; then
      echo -e "$running Upgrading $pkg pkg.."
      output=$(pkg install --only-upgrade "$pkg" -y 2>/dev/null)
      echo "$output" | grep -q "dpkg was interrupted" 2>/dev/null && { yes "N" | dpkg --configure -a; yes "N" | pkg install --only-upgrade "$pkg" -y > /dev/null 2>&1; }
    fi
  }

  # --- pkg install/update function ---
  pkgInstall() {
    local pkg=$1
    if echo "$installedPKG" | grep -q "^$pkg/" 2>/dev/null; then
      pkgUpdate "$pkg"
    else
      echo -e "$running Installing $pkg pkg.."
      pkg install "$pkg" -y > /dev/null 2>&1
    fi
  }

  #pkgInstall "apt"  # apt update
  pkgInstall "dpkg"  # dpkg update
  #pkgInstall "bash"  # bash update
  pkgInstall "libgnutls"  # pm apt & dpkg use it to securely download packages from repositories over HTTPS
  #pkgInstall "coreutils"  # It provides basic file, shell, & text manipulation utilities. such as: ls, cp, mv, rm, mkdir, cat, echo, etc.
  pkgInstall "termux-core"  # it's contains basic essential cli utilities, such as: ls, cp, mv, rm, mkdir, cat, echo, etc.
  pkgInstall "termux-tools"  # it's provide essential commands, sush as: termux-change-repo, termux-setup-storage, termux-open, termux-share, etc.
  pkgInstall "termux-keyring"  # it's use during pkg install/update to verify digital signature of the pkg and remote repository
  pkgInstall "termux-am"  # termux am (activity manager) update
  pkgInstall "termux-am-socket"  # termux am socket (when run: am start -n activity ,termux-am take & send to termux-am-stcket and it's send to Termux Core to execute am command) update
  pkgInstall "inetutils"  # ping utils is provided by inetutils
  pkgInstall "util-linux"  # it provides: kill, killall, uptime, uname, chsh, lscpu
  pkgInstall "libsmartcols"  # a library from the util-linux pkg
  pkgInstall "curl"  # curl update
  pkgInstall "libcurl"  # curl lib update
  pkgInstall "aria2"  # aria2 install/update
  #pkgInstall "openssl"  # openssl install/update
  pkgInstall "jq"  # jq install/update
  pkgInstall "pup"  # pup install/update
  pkgInstall "openjdk-21"  # java install/update
  pkgInstall "bsdtar"  # bsdtar install/update
  pkgInstall "pv"  # pv install/update
  pkgInstall "grep"  # grep update
  pkgInstall "gawk"  # gnu awk update
  pkgInstall "sed"  # sed update
  pkgInstall "findutils"  # find utils update
  pkgInstall "glow"  # glow install/update

  # Create apkdl config
  all_key=("RipLocale" "RipDpi" "RipLib")
  all_value=("$isRipLocale" "$isRipDpi" "$isRipLib")
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

  # Build locale
  if [ $RipLocale -eq 1 ]; then
    locale=$(getprop persist.sys.locale | cut -d'-' -f1)  # Get System Languages
    [ -z $locale ] && locale=$(getprop ro.product.locale | cut -d'-' -f1)  # Get Languages
  elif [ $RipLocale -eq 0 ]; then
    locale="[a-z][a-z]"
  fi

  # Build lcd_dpi
  if [ $RipDpi -eq 1 ]; then
    density=$(getprop ro.sf.lcd_density)  # Get the device screen density
    # Check and categorize the density
    if [ "$density" -le 120 ]; then
      lcd_dpi="ldpi"  # Low Density
    elif [ "$density" -le 160 ]; then
      lcd_dpi="mdpi"  # Medium Density
    elif [ "$density" -le 240 ]; then
      lcd_dpi="hdpi"  # High Density
    elif [ "$density" -le 320 ]; then
      lcd_dpi="xhdpi"  # Extra High Density
    elif [ "$density" -le 480 ]; then
      lcd_dpi="xxhdpi"  # Extra Extra High Density
    elif [ "$density" -gt 480 ] || [ "$density" -ge 640 ]; then
      lcd_dpi="xxxhdpi"  # Extra Extra Extra High Density
    else
      lcd_dpi="*dpi"
    fi
  elif [ $RipDpi -eq 0 ]; then
    lcd_dpi="*dpi"
  fi
fi

downloadAPK() {
  while true; do
    if [ $isAndroid -eq 1 ]; then
      aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" -U "User-Agent: $USER_AGENT" -U "Referer: https://www.apkmirror.com/" --async-dns=true --async-dns-server="$cloudflareIP" "$finalDownloadButtonLink"
      exitStatus=$?
    elif [ $isMacOS -eq 1 ]; then
      aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" -U "User-Agent: $USER_AGENT" -U "Referer: $variantLink" --ca-certificate="/etc/ssl/cert.pem" --async-dns=true --async-dns-server=$cloudflareIP "$finalDownloadButtonLink"
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

while true; do
  options=(APKMirror Uptodown ReVanced)
  [ $isAndroid -eq 1 ] && options+=(Configuration)
  buttons=("<Select>" "<Exit>"); if menu "options" "buttons" "10"; then selected=${options[selected]}; fi
  case "$selected" in
    APKMirror)
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
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    Uptodown)
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
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    ReVanced)
      source $apkdl/APKMdl.sh
      
      source $apkdl/RVdl.sh
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
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    Configuration)
      while true; do
        RipLocale="$(jq -r '.RipLocale' "$apkdlJson" 2>/dev/null)"
        RipDpi="$(jq -r '.RipDpi' "$apkdlJson" 2>/dev/null)"
        RipLib="$(jq -r '.RipLib' "$apkdlJson" 2>/dev/null)"
        options=(RipLocale RipDpi RipLib)
        buttons=("<Select>" "<Back>"); if menu "options" "buttons"; then selected="${options[$selected]}"; else break; fi
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
        esac
      done
      ;;
  esac
done
#########################################################################################################################