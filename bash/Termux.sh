#!/usr/bin/bash

# Copyright (C) 2025, Arghyadeep Mondal <github.com/arghya339>
if [ -f "$apkdlJson" ]; then
  jdkVersion=$(jq -r '.openjdk' "$apkdlJson" 2>/dev/null)
  AutoUpdatesDependencies=$(jq -r '.AutoUpdatesDependencies' "$apkdlJson" 2>/dev/null)
  CheckTermuxUpdate=$(jq -r '.CheckTermuxUpdate' "$apkdlJson" 2>/dev/null)
else
  jdkVersion="21"
  AutoUpdatesDependencies=true
  CheckTermuxUpdate=true
fi
cpuAbi=$(getprop ro.product.cpu.abi)
Android=$(getprop ro.build.version.release)
Model=$(getprop ro.product.model)
Build=$(getprop ro.build.id)
K="$Model Build/$Build"
USER_AGENT="Mozilla/5.0 (Linux; Android $Android; $K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${crVersion} Mobile Safari/537.36"
Android=$(getprop ro.build.version.release | cut -d. -f1)
locale=$(getprop persist.sys.locale | cut -d'-' -f1)
[ -z $locale ] && locale=$(getprop ro.product.locale | cut -d'-' -f1)
density=$(getprop ro.sf.lcd_density)
POST_INSTALL="$apkdl/POST_INSTALL"; mkdir -p "$POST_INSTALL"

# --- Storage Permission Check Logic ---
if ! ls /sdcard/ 2>/dev/null | grep -qE "^(Android|Download)"; then
  echo -e "${notice} ${Yellow}Storage permission not granted!${Reset}\n$running ${Green}termux-setup-storage${Reset}.."
  if [ $Android -gt 5 ]; then  # for Android 5 storage permissions grant during app installation time, so Termux API termux-setup-storage command not required
    count=0
    while true; do
      if [ $count -ge 2 ]; then
        echo -e "$bad Failed to get storage permissions after $count attempts!"
        echo -e "$notice Please grant permissions manually in Termux App info > Permissions > Files > File permission → Allow."
        am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.termux &> /dev/null
        exit 0
      fi
      termux-setup-storage  # ask Termux Storage permissions
      sleep 3  # wait 3 seconds
      if ls /sdcard/ 2>/dev/null | grep -q "^Android" || ls "$HOME/storage/shared/" 2>/dev/null | grep -q "^Android"; then
        [ $Android -lt 8 ] && exit 0  # Exit the script
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

su=false; rish=false; adb=false
adb version &>/dev/null && adb start-server 2>/dev/null
if su -c "id" &>/dev/null; then su=true; elif rish -c "id" &>/dev/null; then rish=true; elif adb -s $(adb devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "id" &>/dev/null; then adb=true; fi

# --- Shizuku Setup first time ---
if [ $su == false ] && { [ ! -f "$PREFIX/bin/rish" ] || [ ! -f "$PREFIX/bin/rish_shizuku.dex" ]; }; then
  curl -sL -o "$PREFIX/bin/rish" "https://raw.githubusercontent.com/arghya339/crdl/refs/heads/main/Shizuku/rish" && chmod +x "$PREFIX/bin/rish"
  sleep 0.5 && curl -sL -o "$PREFIX/bin/rish_shizuku.dex" "https://raw.githubusercontent.com/arghya339/crdl/refs/heads/main/Shizuku/rish_shizuku.dex"
  if ! am start -n "moe.shizuku.privileged.api/moe.shizuku.manager.legacy.ShellRequestHandlerActivity" &>/dev/null; then
    #echo -e "$info Please manually install Shizuku from Google Play Store." && sleep 1
    #termux-open-url "https://play.google.com/store/apps/details?id=moe.shizuku.privileged.api"
    echo -e "$info Please manually install Shizuku from GitHub." && sleep 1
    termux-open-url "https://github.com/RikkaApps/Shizuku/releases/latest"
  fi
  if [ $rish == true ]; then
    am start -n com.android.settings/.Settings\$MyDeviceInfoActivity &>/dev/null  # Open Device Info
    if [ $Android -lt 11 ]; then
      url="https://youtu.be/ZxjelegpTLA"  # YouTube/@MrPalash360: Start Shizuku using Computer
      activityClass="com.android.settings/.Settings\$DevelopmentSettingsDashboardActivity"  # Open Developer options
    else
      activityClass="com.android.settings/.Settings\$WirelessDebuggingActivity"  # Open Wireless Debugging Settings
      url="https://youtu.be/YRd0FBfdntQ"  # YouTube/@MrPalash360: Start Shizuku Android 11+
    fi
    echo -e "$info Please start Shizuku by following guide: ${Blue}$url${Reset}" && sleep 1
    am start -n "$activityClass" &>/dev/null
    termux-open-url "$url"
  fi
fi
if [ $rish == false ] && [ -f "$PREFIX/bin/rish_shizuku.dex" ]; then
  if rish -c "id" 2>&1 | grep -q 'java.lang.UnsatisfiedLinkError'; then
    rm -f "$PREFIX/bin/rish_shizuku.dex" && curl -sL -o "$PREFIX/bin/rish_shizuku.dex" "https://raw.githubusercontent.com/arghya339/crdl/refs/heads/main/Shizuku/Play/rish_shizuku.dex"
  fi
fi

if [ "$(getprop ro.product.manufacturer)" == "Genymobile" ] && [ ! -f "$PREFIX/bin/adb" ]; then
  curl -sL -o "$PREFIX/bin/adb" "https://raw.githubusercontent.com/rendiix/termux-adb-fastboot/refs/heads/master/binary/${cpuAbi}/bin/adb" && chmod +x $PREFIX/bin/adb
fi

pkgUpdate() {
  pkg=$1
  if echo "$outdatedPkg" | grep -q "^$pkg/" 2>/dev/null; then
    echo -e "$running Upgrading $pkg pkg.."
    output=$(yes "N" | apt install --only-upgrade "$pkg" -y 2>/dev/null)
    echo "$output" | grep -q "dpkg was interrupted" 2>/dev/null && { yes "N" | dpkg --configure -a; yes "N" | apt install --only-upgrade "$pkg" -y > /dev/null 2>&1; }
  fi
}

pkgInstall() {
  pkg=$1
  if echo "$installedPkg" | grep -q "^$pkg/" 2>/dev/null; then
    pkgUpdate "$pkg"
  else
    echo -e "$running Installing $pkg pkg.."
    pkg install "$pkg" -y > /dev/null 2>&1
  fi
}

pkgUninstall() {
  installedPkg=$(pkg list-installed 2>/dev/null)
  pkg=$1
  if echo "$installedPkg" | grep -q "^$pkg/" 2>/dev/null; then
    echo -e "$running Uninstalling $pkg pkg.."
    pkg uninstall "$pkg" -y > /dev/null 2>&1
  fi
}

dependencies() {
  installedPkg=$(pkg list-installed 2>/dev/null)  # list of installed pkg
  pkg update > /dev/null 2>&1 || apt update >/dev/null 2>&1  # It downloads latest package list with versions from Termux remote repository, then compares them to local (installed) pkg versions, and shows a list of what can be upgraded if they are different.
  outdatedPkg=$(apt list --upgradable 2>/dev/null)  # list of outdated pkg
  echo "$outdatedPkg" | grep -q "dpkg was interrupted" 2>/dev/null && { yes "N" | dpkg --configure -a; outdatedPkg=$(apt list --upgradable 2>/dev/null); }

  pkgInstall "apt"  # apt update
  pkgInstall "dpkg"  # dpkg update
  pkgInstall "bash"  # bash update
  pkgInstall "libgnutls"  # pm apt & dpkg use it to securely download packages from repositories over HTTPS
  pkgInstall "coreutils"  # It provides basic file, shell, & text manipulation utilities. such as: ls, cp, mv, rm, mkdir, cat, echo, etc.
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
  pkgInstall "openssl"  # openssl install/update
  pkgInstall "aria2"  # aria2 install/update
  pkgInstall "jq"  # jq install/update
  pkgInstall "pup"  # pup install/update
  pkgInstall "openjdk-$jdkVersion" # java install/update
  pkgInstall "bsdtar"  # bsdtar install/update
  pkgInstall "pv"  # pv install/update
  pkgInstall "grep"  # grep update
  pkgInstall "gawk"  # gnu awk update
  pkgInstall "sed"  # sed update
  pkgInstall "findutils"  # find utils update
  pkgInstall "glow"  # glow install/update
  pkgInstall "protobuf"  # protoc install/update
  pkgInstall "xxd"  # xxd install/update
}
[ "$AutoUpdatesDependencies" == true ] && checkInternet && dependencies
  
aapt2="$PREFIX/bin/aapt2"
[[ $($PREFIX/bin/aapt2 version 2>&1 | awk '{print $NF}') =~ ^(2.19-V14.0.6.0.TKSMIXM|2.19-3401)$ ]] || { rm -f $PREFIX/bin/aapt2 && curl -L --progress-bar -C - -o $PREFIX/bin/aapt2 $(curl -sL https://api.github.com/repos/ReVanced/aapt2/releases/latest | jq -r --arg arch "$cpuAbi" '.assets[] | select(.name == "aapt2-" + $arch) | .browser_download_url') && chmod +x $PREFIX/bin/aapt2 && $PREFIX/bin/aapt2 version 2>&1; }
  
# --- Create apkdl shortcut on Laucher Home ---
if [ ! -f "$HOME/.shortcuts/apkdl" ] || [ ! -f "$HOME/.termux/widget/dynamic_shortcuts/apkdl" ]; then
  # Download & Install Termux:Widget app from GitHub
  if ! am start -n com.termux.widget/com.termux.widget.TermuxLaunchShortcutActivity > /dev/null 2>&1; then
    tag_name=$(curl -s ${auth} "https://api.github.com/repos/termux/termux-widget/releases/latest" | jq -r '.tag_name')
    while true; do
      curl -L -C - --progress-bar -o "$Download/termux-widget-app_${tag_name}+github.debug.apk" "https://github.com/termux/termux-widget/releases/download/$tag_name/termux-widget-app_$tag_name+github.debug.apk"
      [ $? -eq 0 ] && break || sleep 5
    done
    [ -f "$Download/termux-widget-app_${tag_name}+github.debug.apk" ] && apkInstall "$Download/termux-widget-app_${tag_name}+github.debug.apk" ""  # Install Termux:Widget app using apkInstall.sh
  fi
  # Create apkdl shortcut
  if am start -n com.termux.widget/com.termux.widget.TermuxLaunchShortcutActivity > /dev/null 2>&1; then
    [ -f "$Download/termux-widget-app_${tag_name}+github.debug.apk" ] && rm -f "$Download/termux-widget-app_${tag_name}+github.debug.apk"  # if Termux:Widget app package exist then remove it 
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
  if [ $su == true ]; then
    [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; writeSELinux=true; } || writeSELinux=false
    su -c "cmd appops set com.termux SYSTEM_ALERT_WINDOW allow"
    [ $writeSELinux == true ] && su -c "setenforce 1"
  elif [ $rish == true ] || [ $adb == true ]; then
    shellCmd "cmd appops set com.termux SYSTEM_ALERT_WINDOW allow"
  else
    echo -e "$info Please manually turn on: ${Green}Display over other apps → Termux → Allow display over other apps${Reset}" && sleep 6
    am start -a android.settings.action.MANAGE_OVERLAY_PERMISSION &> /dev/null  # open manage overlay permission settings
  fi
fi

if [ $CheckTermuxUpdate == true ]; then
  if [ $Android -ge 8 ]; then
    latestReleases=$(curl -s https://api.github.com/repos/termux/termux-app/releases/latest | jq -r '.tag_name')  # v0.118.3
    fileName="termux-app_${latestReleases}+github-debug_$cpuAbi.apk"
  else
    latestReleases=$(curl -s https://api.github.com/repos/termux/termux-app/tags | jq -r '.[0].name')  # v0.119.0-beta.3
    [ $Android -eq 7 ] && variant=7 || variant=5
    fileName="termux-app_${latestReleases}+apt-android-$variant-github-debug_$cpuAbi.apk"
  fi
  dlUrl="https://github.com/termux/termux-app/releases/download/$latestReleases/$fileName"
  filePath="$Download/$fileName"
  if [ "$TERMUX_VERSION" != "$(echo "$latestReleases" | sed 's/^v//')" ]; then
    echo -e "$notice Termux app is outdated!"
    echo -e "$running Downloading Termux app update.."
    while true; do
      curl -L --progress-bar -C - -o "$filePath" "$dlUrl"
      [ $? -eq 0 ] && break || { echo -e "$notice Retrying in 5 seconds.."; sleep 5; }
    done
    echo -e "$notice Please rerun this script again after updating the Termux app!"
    echo -e "$running Installing app update and restarting Termux app.." && sleep 3
    if [ $su == true ]; then
      su -c "cp '$filePath' '/data/local/tmp/$fileName'"
      [ "$(su -c 'getenforce 2>/dev/null')" = "Enforcing" ] && { su -c "setenforce 0"; touch "$apkdl/writeSELinux"; }
      su -c 'pm grant com.termux android.permission.POST_NOTIFICATIONS'
      su -c "cmd deviceidle whitelist +com.termux" &>/dev/null
      su -c "pm install -i com.android.vending '/data/local/tmp/$fileName'"
    else
      if [ $rish == true ] || [ $adb == true ]; then
        shellCmd 'pm grant com.termux android.permission.POST_NOTIFICATIONS'
        shellCmd "cmd deviceidle whitelist +com.termux" &>/dev/null
        shellCmd "cmd appops set com.termux REQUEST_INSTALL_PACKAGES allow"
      else
        echo -e "$info Please Disabled: ${Green}Battery optimization → Not optimized → All apps → Termux → Don't optiomize → DONE${Reset}" && sleep 6
        am start -n com.android.settings/.Settings\$HighPowerApplicationsActivity &> /dev/null
        echo -e "$info Please Allow: ${Green}Install unknown apps → Termux → Allow from this source${Reset}" && sleep 6
        am start -n com.android.settings/.Settings\$ManageExternalSourcesActivity &> /dev/null
      fi
      apkInstall "$filePath" "com.termux/.app.TermuxActivity"
    fi
  else
    if [ -f "$filePath" ]; then
      if [ $su == true ]; then
        if [ "$(su -c 'getenforce 2>/dev/null')" = "Permissive" ] && [ -f "$apkdl/writeSELinux" ]; then
          su -c "setenforce 1"  # set SELinux to Enforcing mode to block unauthorized operations
          rm -f "$apkdl/writeSELinux"
        fi
        su -c "rm -f '/data/local/tmp/$fileName'"
      elif [ $rish == true ] || [ $adb == true ]; then
        shellCmd "rm -f '/data/local/tmp/$fileName'"
      fi
      rm -f "$filePath"
    fi
  fi
fi