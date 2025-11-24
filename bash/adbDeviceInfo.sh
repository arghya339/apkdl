#!/bin/bash

# src: https://gitlab.com/AuroraOSS/gplayapi/-/blob/master/lib/src/main/java/com/aurora/gplayapi/data/providers/DeviceInfoProvider.kt
getDeviceInfo() {
  BuildRADIO=$(adb -s $serial shell getprop gsm.version.baseband)
  BuildBOOTLOADER=$(adb -s $serial shell getprop ro.bootloader)
  ScreenDensity=$(adb -s $serial shell getprop ro.sf.lcd_density)  # Equivalent to metrics.densityDpi
  GLExtensions=$(adb -s $serial shell dumpsys SurfaceFlinger | grep -A 30 "GLES:" | grep "GL_" | tr ' ' '\n' | grep "^GL_" | sort -u | tr '\n' ',' | sed 's/,$//')
  BuildBRAND=$(adb -s $serial shell getprop ro.product.brand)
  BuildID=$(adb -s $serial shell getprop ro.build.id)
  Platforms=$(adb -s $serial shell getprop ro.product.cpu.abilist)  # Equivalent to Build.SUPPORTED_ABIS
  BuildFINGERPRINT=$(adb -s $serial shell getprop ro.build.fingerprint)
  Vendingversion=$(adb -s $serial shell dumpsys package com.android.vending | grep "versionCode=" | awk '{print $1}' | cut -d '=' -f 2 | head -1) || Vendingversion="84880700"
  resolution=$(adb -s $serial shell wm size | grep "Physical size" | cut -d' ' -f3) && { ScreenWidth=${resolution%x*}; ScreenHeight=${resolution#*x}; } || { ScreenWidth=1920; ScreenHeight=1200; }
  BuildHARDWARE=$(adb -s $serial shell getprop ro.hardware)
  BuildVERSIONRELEASE=$(adb -s $serial shell getprop ro.build.version.release)
  BuildVERSIONSDK_INT=$(adb -s $serial shell getprop ro.build.version.sdk)
  BuildMODEL=$(adb -s $serial shell getprop ro.product.model)
  locale=$(adb -s $serial shell getprop ro.product.locale) && Locales=${locale//-/_}
  SharedLibraries=$(adb -s $serial shell pm list libraries | cut -d: -f2 | tr -d '\r' | paste -sd "," -)
  # OpenGL ES version
  GLVersion=$(adb -s $serial shell getprop ro.opengles.version)
  # adb -s $serial shell dumpsys SurfaceFlinger 2>/dev/null | grep -o "OpenGL ES [0-9]\.[0-9]" | awk '{print $3}'
  GSFversion=$(adb -s $serial shell dumpsys package com.google.android.gms | grep "versionCode=" | awk '{print $1}' | cut -d '=' -f 2 | head -1) || GSFversion="254534004"
  if adb -s $serial shell dumpsys telephony.registry 2>/dev/null | grep "mServiceState" | head -1 | grep -q "roamingType=NOT_ROAMING"; then
    Roaming="mobile-notroaming"
  else
    Roaming="mobile-roaming"
  fi
  TimeZone=$(adb -s $serial shell getprop persist.sys.timezone)
  VendingversionString=$(adb -s $serial shell dumpsys package com.android.vending | grep "versionName=" | cut -d '=' -f 2 | head -1) || VendingversionString="48.8.07-23 [0] [PR] 829632341"
  if adb -s $serial shell dumpsys input 2>/dev/null | grep -q "AT Translated Set 2 keyboard"; then
    HasHardKeyboard="true"
    Keyboard=2  # keyboardCount=hardKeyboard+softKeyboard=1+1=2
  else
    HasHardKeyboard="false"
    Keyboard=1
  fi
  Features=$(adb -s $serial shell pm list features | grep -v "reqGlEsVersion" | sed 's/^feature://' | cut -d'=' -f1 | paste -sd "," -)
  BuildMANUFACTURER=$(adb -s $serial shell getprop ro.product.manufacturer)
  UserReadableName="$BuildMANUFACTURER $BuildMODEL"
  SimOperator=$(adb -s $serial shell getprop gsm.sim.operator.numeric)
  BuildDEVICE=$(adb -s $serial shell getprop ro.product.device)
  mGlobalConfiguration=$(adb -s $serial shell dumpsys activity | grep "mGlobalConfiguration:" 2>/dev/null)
  # mGlobalConfiguration=$(adb -s $serial shell dumpsys window | grep mGlobalConfiguration)
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
  BuildPRODUCT=$(adb -s $serial shell getprop ro.product.name)
  CellOperator=$(adb -s $serial shell getprop gsm.operator.numeric)
}
###################################################################