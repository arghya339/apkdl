#!/usr/bin/bash

runDroidCmd() {
  cmd=${1}
  if [ $su -eq 1 ]; then
    su -c "$command"
  elif "$HOME/rish" -c "id" >/dev/null 2>&1; then
    ~/rish -c "$command"
  elif "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
    ~/adb -s $("$HOME/adb" devices 2>/dev/null | grep "device$" | awk '{print $1}' | tail -1) shell "$command"
  fi
}

runJqCmd() {
  key=$1
  curl -sL https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/deviceInfo.json | jq -r ".$key"
}

# src: https://gitlab.com/AuroraOSS/gplayapi/-/blob/master/lib/src/main/java/com/aurora/gplayapi/data/providers/DeviceInfoProvider.kt
getDeviceInfo() {
  if [ $su -eq 1 ] || "$HOME/rish" -c "id" >/dev/null 2>&1 || "$HOME/adb" -s $(~/adb devices | grep "device$" | awk '{print $1}' | tail -1) shell "id" >/dev/null 2>&1; then
    runDroidCmdOut=$(runDroidCmd "dumpsys SurfaceFlinger")
    GLExtensions=$(grep -A 30 "GLES:" <<< "$runDroidCmdOut" | grep "GL_" | tr ' ' '\n' | grep "^GL_" | sort -u | tr '\n' ',' | sed 's/,$//') && unset runDroidCmdOut
    
    runDroidCmdOut=$(runDroidCmd "dumpsys package com.android.vending")
    VendingversionString=$(grep "versionName=" <<< "$runDroidCmdOut" | cut -d '=' -f 2 | head -1) || VendingversionString="48.8.07-23 [0] [PR] 829632341"
    Vendingversion=$(grep "versionCode=" <<< "$runDroidCmdOut" | awk '{print $1}' | cut -d '=' -f 2 | head -1) && unset runDroidCmdOut || Vendingversion="84880700"
    
    runDroidCmdOut=$(runDroidCmd "wm size")
    resolution=$(grep "Physical size" <<< "$runDroidCmdOut" | cut -d' ' -f3) && { ScreenWidth=${resolution%x*}; ScreenHeight=${resolution#*x}; unset runDroidCmdOut; } || { ScreenWidth=1920; ScreenHeight=1200; }
    
    runDroidCmdOut=$(runDroidCmd "pm list libraries")
    SharedLibraries=$(cut -d: -f2 <<< "$runDroidCmdOut" | tr -d '\r' | paste -sd "," -) && unset runDroidCmdOut
    
    runDroidCmdOut=$(runDroidCmd "dumpsys package com.google.android.gms")
    GSFversion=$(grep "versionCode=" <<< "$runDroidCmdOut" | awk '{print $1}' | cut -d '=' -f 2 | head -1) && unset runDroidCmdOut || GSFversion="254534004"
    
    runDroidCmdOut=$(runDroidCmd "pm list features")
    Features=$(grep -v "reqGlEsVersion" <<< "$runDroidCmdOut" | sed 's/^feature://' | cut -d'=' -f1 | paste -sd "," -) && unset runDroidCmdOut
    
    runDroidCmdOut=$(runDroidCmd "dumpsys activity")
    # runDroidCmdOut=$(runDroidCmd "dumpsys window")
    mGlobalConfiguration=$(grep "mGlobalConfiguration" <<< "$runDroidCmdOut") && unset runDroidCmdOut
  else
    GLExtensions=$(runJqCmd "GL.Extensions")
    VendingversionString=$(runJqCmd "Vending.versionString")
    Vendingversion=$(runJqCmd "Vending.version")
    ScreenWidth=$(runJqCmd "Screen.Width"); ScreenHeight=$(runJqCmd "Screen.Height")
    SharedLibraries=$(runJqCmd "SharedLibraries")
    GSFversion=$(runJqCmd "GSF.version")
    Features=$(runJqCmd "Features")
    mGlobalConfiguration="nrml"
  fi
  BuildRADIO=$(getprop gsm.version.baseband)
  BuildBOOTLOADER=$(getprop ro.bootloader)
  ScreenDensity=$(getprop ro.sf.lcd_density)  # Equivalent to metrics.densityDpi
  runCmdOut=$(runCmd "pm list packages -3")
  BuildBRAND=$(getprop ro.product.brand)
  BuildID=$(getprop ro.build.id)
  Platforms=$(getprop ro.product.cpu.abilist)  # Equivalent to Build.SUPPORTED_ABIS
  BuildFINGERPRINT=$(getprop ro.build.fingerprint)
  BuildHARDWARE=$(getprop ro.hardware)
  BuildVERSIONRELEASE=$(getprop ro.build.version.release)
  BuildVERSIONSDK_INT=$(getprop ro.build.version.sdk)
  BuildMODEL=$(getprop ro.product.model)
  locale=$(getprop ro.product.locale) && Locales=${locale//-/_}
  
  # OpenGL ES version
  GLVersion=$(getprop ro.opengles.version)
  # adb shell dumpsys SurfaceFlinger 2>/dev/null | grep -o "OpenGL ES [0-9]\.[0-9]" | awk '{print $3}'
  
  if grep "mServiceState" <<< $(runDroidCmd "dumpsys telephony.registry") | head -1 | grep -q "roamingType=ROAMING"; then
    Roaming="mobile-roaming"
  else
    Roaming="mobile-notroaming"
  fi
  TimeZone=$(getprop persist.sys.timezone)
  if grep -q "AT Translated Set 2 keyboard" <<< $(runDroidCmd "dumpsys input"); then
    HasHardKeyboard="true"
    Keyboard=2  # keyboardCount=hardKeyboard+softKeyboard=1+1=2
  else
    HasHardKeyboard="false"
    Keyboard=1
  fi
  BuildMANUFACTURER=$(getprop ro.product.manufacturer)
  UserReadableName="$BuildMANUFACTURER $BuildMODEL"
  SimOperator=$(getprop gsm.sim.operator.numeric)
  BuildDEVICE=$(getprop ro.product.device)
  if echo "$mGlobalConfiguration" 2>/dev/null | grep -q "xlrg"; then
    ScreenLayout=4
  elif echo "$mGlobalConfiguration" 2>/dev/null | grep -q "lrg"; then
    ScreenLayout=3
  elif echo "$mGlobalConfiguration" 2>/dev/null | grep -q "nrml"; then
    ScreenLayout=2
  elif echo "$mGlobalConfiguration" 2>/dev/null | grep -q "sm"; then
    ScreenLayout=1
  else
    ScreenLayout="Unknown"
  fi
  if echo "$mGlobalConfiguration" | grep -q -- "-nav"; then
    Navigation=1
  elif echo "$mGlobalConfiguration" | grep -q "dpad"; then
    Navigation=2
  elif echo "$mGlobalConfiguration" | grep -q "trackball"; then
    Navigation=3
  elif echo "$mGlobalConfiguration" | grep -q "wheel"; then
    Navigation=4
  else
    Navigation=0
  fi
  if echo "$mGlobalConfiguration" | grep -q "finger"; then
    TouchScreen=3
  elif echo "$mGlobalConfiguration" | grep -q "stylus"; then
    TouchScreen=2
  elif echo "$mGlobalConfiguration" | grep -q "notouch"; then
    TouchScreen=1
  else
    TouchScreen=0
  fi
  BuildPRODUCT=$(getprop ro.product.name)
  CellOperator=$(getprop gsm.operator.numeric)
}
##############################################