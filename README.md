<h1 align="center">apkdl</h1>
<p align="center">
apk downloader
<br>
<br>
<img src="docs/images/Main.png">
<br>

## Purpose
- This script automates process of downloading apk file using shell script.

## Supported sources
- [PlayStore](https://play.google.com/store/apps/)
- [GitHub](https://github.com/)
- [GitLab](https://gitlab.com/)
- [F-Droid](https://f-droid.org/)
- [APKMirror](https://apkmirror.com/)
- [Uptodown](https://en.uptodown.com/)
- [APKPure](https://apkpure.com/)
- otherSources
  - [Codeberg](https://codeberg.org/)
  - [IzzyOnDroid](https://apt.izzysoft.de/fdroid/)
  - [AppGallery](https://appgallery.huawei.com/)
  - [SourceForge](https://sourceforge.net/)
  - [APKCombo](https://apkcombo.com/)
  - [Aptoide](https://en.aptoide.com/group/applications/)
  - [LITEAPKS](https://liteapks.com/)
- [ReVanced](https://revanced.app/)
- [RVX](https://github.com/inotia00/revanced-patches/)

## Prerequisites
- macOS/ Android device with working internet connection.

## Usage
### ![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)/ ![macOS](https://img.shields.io/badge/mac%20os-000000?style=for-the-badge&logo=macos&logoColor=F0F0F0)
  - Open [Termux](https://github.com/termux/termux-app/releases/) and type following command and press `Enter` key twice:
```sh
  pkg update && pkg install --only-upgrade apt bash coreutils openssl -y
  ```
  - Open macOS Terminal/ Android [Termux](https://github.com/termux/termux-app/releases/) & run script with following command:
  ```sh
  curl -L --progress-bar -o "$HOME/.apkdl.sh" https://raw.githubusercontent.com/arghya339/apkdl/main/bash/apkdl.sh && bash "$HOME/.apkdl.sh"
  ```
  Run apkdl with these commands in Terminal/ Termux:
  ```
  apkdl
  ```
> [!NOTE]
> This script was tested on an arm64-v8a device running Android 14 with Termux v0.118.3 with bash v5.2.37(1).

> [!NOTE]
> This script was tested on an Intel Mac running macOS Sonoma (14) with Terminal v2.14(453) with bash v5.3.3(1).

## How it works (_[Demo on YouTube](https://youtube.com/)_)

## Developer: [@arghya339](https://github.com/arghya339)