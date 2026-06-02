#!/usr/bin/bash

# Copyright (C) 2025, Arghyadeep Mondal <github.com/arghya339>

runJqCmd() { curl -sL https://raw.githubusercontent.com/arghya339/apkdl/refs/heads/main/deviceInfo.json | jq -r ".${1}"; }

# src: https://gitlab.com/AuroraOSS/gplayapi/-/blob/master/lib/src/main/java/com/aurora/gplayapi/data/providers/DeviceInfoProvider.kt
getDeviceInfo() {
  if [ $su == true ] || [ $rish == true ] || [ $adb == true ]; then
    cmdOut=$(shellCmd "dumpsys SurfaceFlinger")
    GLExtensions=$(grep -A 30 "GLES:" <<< "$cmdOut" | grep "GL_" | tr ' ' '\n' | grep "^GL_" | sort -u | tr '\n' ',' | sed 's/,$//') && unset cmdOut
    
    cmdOut=$(shellCmd "dumpsys package com.android.vending")
    VendingversionString=$(grep "versionName=" <<< "$cmdOut" | cut -d '=' -f 2 | head -1)
    Vendingversion=$(grep "versionCode=" <<< "$cmdOut" | awk '{print $1}' | cut -d '=' -f 2 | head -1); unset cmdOut
    
    cmdOut=$(shellCmd "wm size")
    resolution=$(grep "Physical size" <<< "$cmdOut" | cut -d' ' -f3) && { ScreenWidth=${resolution%x*}; ScreenHeight=${resolution#*x}; unset cmdOut; } || { ScreenWidth=1920; ScreenHeight=1200; }
    
    cmdOut=$(shellCmd "pm list libraries")
    SharedLibraries=$(cut -d: -f2 <<< "$cmdOut" | tr -d '\r' | paste -sd "," -) && unset cmdOut
    
    cmdOut=$(shellCmd "dumpsys package com.google.android.gms")
    GSFversion=$(grep "versionCode=" <<< "$cmdOut" | awk '{print $1}' | cut -d '=' -f 2 | head -1) && unset cmdOut
    
    cmdOut=$(shellCmd "pm list features")
    Features=$(grep -v "reqGlEsVersion" <<< "$cmdOut" | sed 's/^feature://' | cut -d'=' -f1 | paste -sd "," -) && unset cmdOut
    
    cmdOut=$(shellCmd "dumpsys activity")
    # cmdOut=$(shellCmd "dumpsys window")
    mGlobalConfiguration=$(grep "mGlobalConfiguration" <<< "$cmdOut") && unset cmdOut
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
  [ -z "$VendingversionString" ] && VendingversionString="48.8.07-23 [0] [PR] 829632341"
  [ -z "$Vendingversion" ] && Vendingversion="84880700"
  [ -z "$GSFversion" ] && GSFversion="254534004"
  BuildRADIO=$(getprop gsm.version.baseband)
  BuildBOOTLOADER=$(getprop ro.bootloader)
  ScreenDensity=$(getprop ro.sf.lcd_density)  # Equivalent to metrics.densityDpi
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
  
  if grep "mServiceState" <<< $(shellCmd "dumpsys telephony.registry") | head -1 | grep -q "roamingType=ROAMING"; then
    Roaming="mobile-roaming"
  else
    Roaming="mobile-notroaming"
  fi
  TimeZone=$(getprop persist.sys.timezone)
  if grep -q "AT Translated Set 2 keyboard" <<< $(shellCmd "dumpsys input"); then
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