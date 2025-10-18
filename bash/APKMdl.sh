#!/bin/bash

APKM_REST_API_URL="https://www.apkmirror.com/wp-json/apkm/v1/app_exists/"
AUTH_TOKEN="YXBpLXRvb2xib3gtZm9yLWdvb2dsZS1wbGF5OkNiVVcgQVVMZyBNRVJXIHU4M3IgS0s0SCBEbmJL"

cf_chl_error() {
  echo -e "$bad ${Red}Cloudflare security challenge detected!${Reset}\n$notice ${Yellow}This webpage is protected by Cloudflare's anti-bot system.${Reset}\n ${Blue}Solutions${Reset}:\n   1. ${Yellow}Please try again after some time.${Reset}\n   2. ${Yellow}Disable your VPN if you are connected to one.${Reset}\n   3. ${Yellow}Connect to a Cloudflare WARP proxy and try again.${Reset}"
  sleep 12
  if [ $isAndroid -eq 1 ]; then
    am start -n com.cloudflare.onedotonedotonedotone/com.cloudflare.app.presentation.main.SplashActivity &> /dev/null || termux-open-url "https://play.google.com/store/apps/details?id=com.cloudflare.onedotonedotonedotone"
  elif [ $isMacOS -eq 1 ]; then
    [ -d "/Applications/Cloudflare WARP.app" ] && open -a "Cloudflare WARP" || { formulaeInstall "cloudflare-warp"; open -a "Cloudflare WARP"; }
  fi
  exit 1
}

fetchAppsInfo() {
  while true; do read -r -p ">> Enter pkgName: " pkgName; [[ "$pkgName" =~ ^[Qq] ]] && pkgName=; break; [ -n "$pkgName" ] && break || echo -e "$notice Please enter a valid pkgName!"; done
  
  if [ -n "$pkgName" ]; then
    RESPONSE_JSON=$(curl -sS --doh-url "$cloudflareDOH" $APKM_REST_API_URL -A "$USER_AGENT" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Basic $AUTH_TOKEN" -d "{\"pnames\":[\"$pkgName\"]}")
    if echo "$RESPONSE_JSON" | jq -e ".data[] | select(.pname == \"$pkgName\") | .exists == true" > /dev/null 2>&1; then
      appName=$(jq -r ".data[] | select(.pname == \"$pkgName\") | .app.name" <<< "$RESPONSE_JSON")
      appName="${appName//amp;/}"
      appLink="https://www.apkmirror.com$(jq -r ".data[] | select(.pname == \"$pkgName\") | .app.link" <<< "$RESPONSE_JSON")"
      echo -e "$info Url for ${Green}$appName${Reset}: ${Blue}$appLink${Reset}"
      return
    else
      echo -e "$bad pkgName: ${Blue}$pkgName${Reset} not found on APKMirror!" >&2
      return 1
    fi
  else
    return 1
  fi
}

searchApp() {
  while true; do read -r -p ">> Enter appName: " inputAppName; [[ "$inputAppName" =~ ^[Qq] ]] && inputAppName=; break; [ -n "$inputAppName" ] && break || echo -e "$notice Please enter a valid appName!"; done
  
  if [ -n "$inputAppName" ]; then
    echo -e "$running Searching $inputAppName on APKMirror.."
    
    input_app_name=$(echo "$inputAppName" | sed 's/ /+/g')
    [[ "$inputAppName" =~ [:space:] ]] && searchTerm="$input_app_name" || searchTerm="$inputAppName"
    
    page=1
    searchUrl="https://www.apkmirror.com/?post_type=app_release&searchtype=apk&bundles%5B%5D=apkm_bundles&bundles%5B%5D=apk_files&s=$searchTerm"
    searchResultHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$searchUrl")
    echo "$searchResultHTML" | grep -q "_cf_chl_" 2>/dev/null && cf_chl_error
    lastPageLink=$(pup 'a.last attr{href}' <<< "$searchResultHTML")
    ! echo "$lastPageLink" | grep -q "https://www.apkmirror.com" 2>/dev/null && lastPageLink="https://www.apkmirror.com$lastPageLink"
    lastPageLink="${lastPageLink//amp;/}"
    lastPage=$(echo "$lastPageLink" | grep -o 'page=[0-9]*' | cut -d= -f2)
    while true; do
      if [ $page -eq 1 ]; then
        echo -e "$info Results for “${inputAppName}”"
        #local searchUrl="https://www.apkmirror.com/?post_type=app_release&searchtype=apk&bundles%5B%5D=apkm_bundles&bundles%5B%5D=apk_files&s=$searchTerm"
      elif [ $page -gt 1 ]; then
        echo -e "$info Results for “${inputAppName}” (Page $page)"
        local searchUrl="https://www.apkmirror.com/?post_type=app_release&searchtype=apk&page=$page&s=$searchTerm&bundles%5B%5D=apkm_bundles&bundles%5B%5D=apk_files"
      fi

      searchResultHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$searchUrl")
      echo "$searchResultHTML" | grep -q "_cf_chl_" 2>/dev/null && cf_chl_error
      searchResultJSON=$(pup 'div.appRow json{}' <<< "$searchResultHTML" | jq -r '[.[] | .. | objects | select(.tag == "a" and .class == "fontBlack") | {title: .text, href: ("https://www.apkmirror.com" + .href)} ] | .[0:10]')
    
      mapfile -t availableApps < <(echo "$searchResultJSON" | jq -r '[.[] | .title | sub(" [0-9]+(\\.[0-9]+)*.*$"; "")] | unique[]')
      [ $page -ge 3 ] && availableApps+=(First)
      [ $page -ge 2 ] && availableApps+=(Prev)
      [ $page -ne $lastPage ] && { availableApps+=(Next); availableApps+=(Last); }
      buttons=("<Select>" "<Back>"); if menu "availableApps" "buttons" "10"; then selected=${availableApps[$selected]}; else break; fi
      
      if [ "${selected}" == "First" ]; then
        echo
        page=1
        searchUrl="https://www.apkmirror.com/?post_type=app_release&searchtype=apk&bundles%5B%5D=apkm_bundles&bundles%5B%5D=apk_files&s=$searchTerm"
        continue
      elif [ "${selected}" == "Prev" ]; then
        echo
        ((page--))
        continue
      elif [ "${selected}" == "Next" ]; then
        echo
        ((page++))
        continue
      elif [ "${selected}" == "Last" ]; then
        echo
        page=$lastPage
        continue
      else
        appName="$selected"
        searchTerm=$(echo "$appName" | sed 's/ /+/g')
        selectedUrl=$(echo "$searchResultJSON" | jq -r --arg app "$appName" '.[] | select(.title | startswith($app)) | .href' | head -1)
        appPageHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$selectedUrl")
        echo "$appPageHTML" | grep -q "_cf_chl_" 2>/dev/null && cf_chl_error
        appLink="https://www.apkmirror.com$(echo "$appPageHTML" | pup '#breadcrumbs a attr{href}' | sed -n '2p')"
        echo -e "$notice Selected: ${Green}$appName${Reset}"
        echo -e "$info Url for ${Green}$appName${Reset}: ${Blue}$appLink${Reset}"
        break
      fi
    done
  fi
  [ -z "$appLink" ] && return 1 || return 0
}

getLatestUploads() {
    echo -e "$running Get latest $appName uploads list from APKMirror.."
    page=1
    appPageHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$appLink")
    echo "$appPageHTML" | grep -q "_cf_chl_" 2>/dev/null && cf_chl_error
    latestUploadsUrl="https://www.apkmirror.com$(pup '#primary a:contains("See more uploads...") attr{href}' <<< "$appPageHTML")"
    baseUploadsUrl=$(basename "$latestUploadsUrl")
    latestUploadsHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$latestUploadsUrl")
    echo "$latestUploadsHTML" | grep -q "_cf_chl_" 2>/dev/null && cf_chl_error
    lastPageLink=$(pup 'a.last[aria-label="Last Page"] attr{href}' <<< "$latestUploadsHTML"); lastPage=$(echo "$lastPageLink" | grep -oE '[0-9]+')
    while true; do
      if [ $page -eq 1 ]; then
        echo -e "$info Latest $appName Uploads"
      else
        echo -e "$info Latest $appName Uploads - Page $page"
        latestUploadsUrl="https://www.apkmirror.com/uploads/page/$page/$baseUploadsUrl"
      fi
      latestUploadsHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$latestUploadsUrl")
      echo "$latestUploadsHTML" | grep -q "_cf_chl_" 2>/dev/null && cf_chl_error
      latestUploadsJSON=$(echo "$latestUploadsHTML" | grep -Eo '<a class="fontBlack"[^>]*href="[^"]+"[^>]*>[^<]+</a>' | head -n 30 | jq -R -s 'split("\n") | map(select(length > 0)) | map(capture("<a [^>]*href=\"(?<href_val>[^\"]+)\"[^>]*>(?<title_text>[^<]+)</a>") | {title: .title_text, link: ("https://www.apkmirror.com" + .href_val)})')
      
      mapfile -t availableVersions < <(echo "$latestUploadsJSON" | jq -r '.[] | .title')
      if [ -n "$version" ]; then
        for i in "${!availableVersions[@]}"; do
          if [ "${availableVersions[$i]}" == "${appName} $version" ]; then
            availableVersions[$i]="${appName} $version (Recommended)"
          fi
        done
      fi
      [ $page -ge 3 ] && availableVersions+=(First)
      [ $page -ge 2 ] && availableVersions+=(Prev)
      [ $page -ne $lastPage ] && { availableVersions+=(Next); availableVersions+=(Last); }
      mapfile -t versionUrls < <(echo "$latestUploadsJSON" | jq -r '.[] | .link')
      
      buttons=("<Select>" "<Back>"); if menu "availableVersions" "buttons" "10"; then selected="$selected"; else break; fi
      
      if [ "${availableVersions[$selected]}" == "First" ]; then
        echo
        page=1
        latestUploadsUrl="https://www.apkmirror.com/uploads/?appcategory=$searchTerm"
        continue
      elif [ "${availableVersions[$selected]}" == "Prev" ]; then
        echo
        ((page--))
        continue
      elif [ "${availableVersions[$selected]}" == "Next" ]; then
        echo
        ((page++))
        continue
      elif [ "${availableVersions[$selected]}" == "Last" ]; then
        echo
        page=$lastPage
        continue
      else
        selectedVersion="${availableVersions[$selected]}"
        versionLink="${versionUrls[$selected]}"
        echo -e "$good Selected Version: ${Green}$selectedVersion${Reset}"
        echo -e "$info versionLink: ${Blue}$versionLink${Reset}"
        break
      fi
    done
  [ -z "$versionLink" ] && return 1 || return 0
}

getVersionLink() {
  echo -e "$running Searching for target app version in APKMirror's Latest Uploads page.."
  appPageHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$appLink")
  echo "$appPageHTML" | grep -q "_cf_chl_" 2>/dev/null && cf_chl_error
  latestUploadsUrl="https://www.apkmirror.com$(pup '#primary a:contains("See more uploads...") attr{href}' <<< "$appPageHTML")"
  baseUploadsUrl=$(basename "$latestUploadsUrl")
  page=1  # start searching target app vresion from first page (latest uploads)
  while true; do
    if [ $page -eq 1 ]; then
      echo -e "$info Latest $appName Uploads"
    else
      echo -e "$info Latest $appName Uploads - Page $page"
      latestUploadsUrl="https://www.apkmirror.com/uploads/page/$page/$baseUploadsUrl"
    fi
    latestUploadsHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$latestUploadsUrl")
    echo "$latestUploadsHTML" | grep -q "_cf_chl_" 2>/dev/null && cf_chl_error
    pup 'span.infoSlide-name:contains("Version:") + span.infoSlide-value text{}' <<< $latestUploadsHTML  # print Version list (30items/page) from latest uploads page html
    # extract both title (appName version) & link (versionLink)
    latestUploadsJSON=$(pup 'a.fontBlack json{}' <<< "$latestUploadsHTML" | jq -c '[.[] | select(.text != null) | {title: .text, link: ("https://www.apkmirror.com" + .href)}]')
    # try to match target version with a title in json_output and extract its link if found
    versionLink=$(jq -r --arg version "$version" '.[] | select(.title | test($version)) | .link' <<< "$latestUploadsJSON" | head -n1)
    if [ -n "$versionLink" ]; then
      # if versionLink populate (not empty) then print successfull messages
      echo -e "$good Found version $version"
      echo -e "$info versionLink: ${Blue}$versionLink${Reset}"
      return
      break  # break while loop
    else
      echo -e "$notice Version $version not found on page $page, moving to next page.."
      ((page++))  # increase +1 page number
      continue  # skip next iteration (remaining commands) of loop then continue to next iteration
    fi
  done  # end of while loop
  [ -z "$versionLink" ] && return 1
}

getVariant() {
  echo -e "$running Get Variant list from APKMirror.."
  variantHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$versionLink")
  echo "$variantHTML" | grep -q "_cf_chl_" 2>/dev/null && cf_chl_error
  variantJSON=$(echo "$variantHTML" | pup 'div.table-row json{}')
  
  mapfile -t variants_table_row < <(echo "$variantJSON" | jq -r '.[] | select((.children | type) == "array" and (.children | length) == 5)
    | select(
      (.children[0].children[0].text | type) == "string" and # Version text
      (.children[0].children[1].text | type) == "string" and # Type text (BUNDLE/APK)
      (.children[1].text | type) == "string" and # Arch text
      (.children[2].text | type) == "string" and # OS text
      (.children[3].text | type) == "string" and # DPI text
      (.children[4].children[0].href | type) == "string" # Link href
    )
    | [
        (.children[0].text // .children[0].children[0].text), # Version (fallback)
        (try (.children[0].children | map(select(.class? == "colorLightBlack")) | .[0].text // "") catch ""), # Version code from colorLightBlack class
        .children[0].children[1].text, # Type (BUNDLE/APK)
        .children[1].text, # Arch
        .children[2].text, # OS
        .children[3].text, # DPI
        ("https://www.apkmirror.com" + .children[4].children[0].href) # Link
      ] | join("\t")
  ')
  
  for i in "${!variants_table_row[@]}"; do
    IFS=$'\t' read -r version version_code type arch os dpi link <<< "${variants_table_row[$i]}"
    
    if [ $i -eq 0 ]; then
      options=("Version: $version ($version_code) | Type: $type | Arch: $arch | OS: $os | DPI: $dpi")
    else
      options+=("Version: $version ($version_code) | Type: $type | Arch: $arch | OS: $os | DPI: $dpi")
    fi
  done
  
  buttons=("<Select>" "<Back>")
  if menu "options" "buttons" "10"; then
    selectedVariantIndex=$selected
    IFS=$'\t' read -r version version_code type arch os dpi link <<< "${variants_table_row[$selectedVariantIndex]}"
      
      echo -e "$notice Selected Variant: "
      echo -e "$info versionCode: $version_code | Type: $type | Arch: $arch | OS: $os | DPI: $dpi"
      variantLink="$link"
      echo -e "$info variantLink: ${Blue}$variantLink${Reset}"
      return 0
  else
    return 1
  fi
}

getDownloadLink() {
  echo -e "$running Get download button link from: ${Blue}$variantLink${Reset}"
  
  downloadButtonHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: https://www.apkmirror.com/" "$variantLink")
  echo "$downloadButtonHTML" | grep -q "_cf_chl_" 2>/dev/null && cf_chl_error
  or=$(echo "$downloadButtonHTML" | pup -p --charset utf-8 'a.downloadButton text{}, p:contains("- or -") text{}' 2>/dev/null)
  downloadButtonJOSN=$(pup 'a.downloadButton json{}' <<< "$downloadButtonHTML" | jq '
    [.[] | {
      type: (if (.children[2].text | test("splits")) then "Download APK Bundle" else "Download APK" end),
      size: (.children[2].text | split(", ")[-1]),
      url: .href
    }]
  ')

  if [ -n "$or" ]; then
    jsonLength=$(echo "$downloadButtonJOSN" | jq '. | length')
    for ((i=0; i<jsonLength; i++)); do
      types[i]=$(echo "$downloadButtonJOSN" | jq -r ".[$i].type")
      sizes[i]=$(echo "$downloadButtonJOSN" | jq -r ".[$i].size")
      urls[i]=$(echo "$downloadButtonJOSN" | jq -r ".[$i].url")
      [ $i -eq 0 ] && downloadButtonTypes=("${types[i]} | ${sizes[i]}") || downloadButtonTypes+=("${types[i]} | ${sizes[i]}")
    done
    buttons=("<Select>" "<Back>")
    if menu "downloadButtonTypes" "buttons" "10"; then
      selectedTypeIndex=$selected
      fileType="${types[selectedTypeIndex]}"
      fileSize="${sizes[selectedTypeIndex]}"
      downloadButtonLink="${urls[selectedTypeIndex]}"
      ! echo "$downloadButtonLink" | grep -q "https://www.apkmirror.com" 2>/dev/null && downloadButtonLink="https://www.apkmirror.com$downloadButtonLink"
      downloadButtonLink="${downloadButtonLink//amp;/}"
      echo "Selected download type:"
      echo -e "$info fileType: $fileType"
      echo -e "$info fileSize: $fileSize"
      echo -e "$info downloadButtonLink: ${Blue}$downloadButtonLink${Reset}"
    fi
  else
    fileType=$(echo "$downloadButtonJOSN" | jq -r '.[0].type')
    fileSize=$(echo "$downloadButtonJOSN" | jq -r '.[0].size')
    downloadButtonLink=$(echo "$downloadButtonJOSN" | jq -r '.[0].url')
    ! echo "$downloadButtonLink" | grep -q "https://www.apkmirror.com" 2>/dev/null && downloadButtonLink="https://www.apkmirror.com$downloadButtonLink"
    downloadButtonLink="${downloadButtonLink//amp;/}"
    echo -e "$info fileSize: $fileSize"
    echo -e "$info downloadButtonLink: ${Blue}$downloadButtonLink${Reset}"
  fi
  
  if [ "$fileType" == "Download APK" ]; then
    file_ext=".apk"
    SHA256=$(<<<"$downloadButtonHTML" awk '/<h4>APK file hashes<\/h4>/,/<h5>Verify the file you downloaded/' | sed -n 's/.*SHA-256: *<span[^>]*>\([0-9a-fA-F]\{64\}\)<\/span.*/\1/p' | head -n1)
  else
    file_ext=".apkm"
    SHA256=$(<<<"$downloadButtonHTML" awk '/<h4>APK bundle file hashes<\/h4>/,/<h5>Verify the APK bundle file you downloaded/' | sed -n 's/.*SHA-256: *<span[^>]*>\([0-9a-fA-F]\{64\}\)<\/span.*/\1/p' | head -n1)
  fi

  if [ -n "$downloadButtonLink" ]; then
  echo -e "$running Get final download link from: ${Blue}$downloadButtonLink${Reset}"
  finalDownloadButtonHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: $variantLink" "$downloadButtonLink")  # Referer must required here
  echo "$finalDownloadButtonHTML" | grep -q "_cf_chl_" 2>/dev/null && cf_chl_error
  finalDownloadButtonLink=$(pup -p --charset UTF-8 'a:contains("here") attr{href}' <<< "$finalDownloadButtonHTML" | head -1 2>/dev/null)
    # https://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=XXXXXXX&key=XxX 
    # https://www.androidpolice.com/2020/07/04/how-to-download-apps-without-the-play-store-and-why-apkmirror-is-the-best-place-to-get-them/
    # https://github.com/illogical-robot/apkmirror-public/issues
  [ -n "$finalDownloadButtonLink" ] && { finalDownloadButtonLink="https://www.apkmirror.com$finalDownloadButtonLink"; echo -e "$good Found final download Link: ${Blue}$finalDownloadButtonLink${Reset}"; }
  fi
  [ -z "$finalDownloadButtonLink" ] && return 1 || return 0
}

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

apkm2apk() {
  owner="ReAndroid"; repo="APKEditor"
  ghApiResponseJson=$(curl -sL ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest")
  tag_name=$(jq -r '.tag_name | sub("^V"; "")' <<< "$ghApiResponseJson")  # 1.4.5
  APKEditor="APKEditor-$tag_name.jar"
  APKEditorPath="$HOME/$APKEditor"
  findAPKEditorPath=$(find "$HOME" -maxdepth 1 -type f -name "APKEditor-*.jar" -print -quit)
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
      curl -L --progress-bar -o $APKEditor -C - https://github.com/REAndroid/APKEditor/releases/download/V$tag_name/APKEditor-$tag_name.jar
      [ $? -eq 0 ] && break || sleep 5
    done
  fi
  if [ $isMacOS -eq 1 ]; then
    java -jar $APKEditorPath m -i "$apkPath" -o "$Download/${appName}_v${version}-${arch}.apk" && rm -f "$apkPath"
  elif [ $isAndroid -eq 1 ]; then
    mkdir -p "$Download/${appName}_v${version}-${arch}"
    termux-wake-lock
    if [ $RipLib -eq 1 ]; then
      pv "$apkPath" | bsdtar -xf - -C "$Download/${appName}_v${version}-${arch}/" --include "base.apk" "split_config.${cpuAbi//-/_}.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk"
      bsdtar_exit_status=$?
    elif [ $RipLib -eq 0 ]; then
      pv "$apkPath" | bsdtar -xf - -C "$Download/${appName}_v${version}-${arch}/" --include "base.apk" "split_config.arm64_v8a.apk" "split_config.armeabi_v7a.apk" "split_config.x86_64.apk" "split_config.x86.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk"
      bsdtar_exit_status=$?
    fi
    if [ $bsdtar_exit_code -ne 0 ]; then  # check if bsdtar return exit code 1 (error)
      rm -rf "$Download/${appName}_v${version}-${arch}"
      java -jar $APKEditorPath m -i "$apkPath" -o "$Download/${appName}_v${version}-${arch}.apk" && rm -f "$apkPath"
    else
      rm -f "$apkPath"
      java -jar $APKEditorPath m -i "$Download/${appName}_v${version}-${arch}" -o "$Download/${appName}_v${version}-${arch}.apk" && rm -rf "$Download/${appName}_v${version}-${arch}"
    fi
    termux-wake-unlock
  fi
}
################################################################################################################