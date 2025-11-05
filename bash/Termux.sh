#!/usr/bin/bash

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
    echo -e "$info Please start Shizuku by following guide: ${Blue}$url${Reset}" && sleep 1
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
  
  curl -sL -o "$apkdl/apkInstall.sh" "https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/bash/apkInstall.sh"
  source $apkdl/apkInstall.sh
  
  # --- Create apkdl shortcut on Laucher Home ---
  if [ ! -f "$HOME/.shortcuts/apkdl" ] || [ ! -f "$HOME/.termux/widget/dynamic_shortcuts/apkdl" ]; then
    # Download & Install Termux:Widget app from GitHub
    if ! am start -n com.termux.widget/com.termux.widget.TermuxLaunchShortcutActivity > /dev/null 2>&1; then
      tag_name=$(curl -s ${auth} "https://api.github.com/repos/termux/termux-widget/releases/latest" | jq -r '.tag_name')
      while true; do
        curl -L -C - --progress-bar -o "$Download/termux-widget-app_${tag_name}+github.debug.apk" "https://github.com/termux/termux-widget/releases/download/$tag_name/termux-widget-app_$tag_name+github.debug.apk"
        [ $? -eq 0 ] && break || sleep 5
      done
      apkPath=$(find "$Download" -type f -name "termux-widget-app_v*+github.debug.apk" -print -quit)  # find downloaded Termux:Widget app package
      [ -f "$apkPath" ] && apkInstall.sh "$apkPath" ""  # Install Termux:Widget app using apkInstall.sh
    fi
    # Create apkdl shortcut
    if am start -n com.termux.widget/com.termux.widget.TermuxLaunchShortcutActivity > /dev/null 2>&1; then
      [ -f "$apkPath" ] && rm -f "$apkPath"  # if Termux:Widget app package exist then remove it 
      echo -e "$notice Please wait few seconds! Creating apkdl shortcut to access apkdl from Launcher Widget."
      mkdir -p ~/.shortcuts  # create $HOME/.shortcuts dir if it not exist
      echo -e "#!/usr/bin/bash\nbash \$PREFIX/bin/apkdl" > ~/.shortcuts/apkdl  # create apkdl shortcut script
      mkdir -p ~/.termux/widget/dynamic_shortcuts
      echo -e "#!/usr/bin/bash\nbash \$PREFIX/bin/apkdl" > ~/.termux/widget/dynamic_shortcuts/apkdl  # create apkdl dynamic shortcut script
      chmod +x ~/.termux/widget/dynamic_shortcuts/apkdl  # give execute (--x) permissions to apkdl script
      echo -e "$info From Termux:Widget app tap on ${Green}apkdl → Add to home screen${Reset}. Opening Termux:Widget app in 6 seconds.." && sleep 6
      am start -n com.termux.widget/com.termux.widget.TermuxCreateShortcutActivity > /dev/null 2>&1  # open Termux:Widget app shortcut create activity (screen/view) to add shortcut on Launcher Home
    fi
    # Enabled Display over other apps
    if [ $su -eq 1 ]; then
      if [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ]; then
        su -c "setenforce 0"  # set SELinux to Permissive mode to unblock unauthorized operations
        su -c "cmd appops set com.termux SYSTEM_ALERT_WINDOW allow"
        su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
      else
        su -c "cmd appops set com.termux SYSTEM_ALERT_WINDOW allow"
      fi
    elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
      $HOME/rish -c "cmd appops set com.termux SYSTEM_ALERT_WINDOW allow"
    else
      echo -e "$info Please manually turn on: ${Green}Display over other apps → Termux → Allow display over other apps${Reset}" && sleep 6
      am start -a android.settings.action.MANAGE_OVERLAY_PERMISSION &> /dev/null  # open manage overlay permission settings
    fi
  fi