#!/bin/bash

APKM_REST_API_URL="https://www.apkmirror.com/wp-json/apkm/v1/app_exists/"
AUTH_TOKEN="YXBpLXRvb2xib3gtZm9yLWdvb2dsZS1wbGF5OkNiVVcgQVVMZyBNRVJXIHU4M3IgS0s0SCBEbmJL"

cf_chl_error() {
  echo -e "$bad ${Red}Cloudflare security challenge detected!${Reset}\n$notice ${Yellow}This webpage is protected by Cloudflare's anti-bot system.${Reset}\n ${Blue}Solutions${Reset}:\n   ${Blue}1${Reset}. ${Yellow}Please try again after some time.${Reset}\n   ${Blue}2${Reset}. ${Yellow}Disable your VPN if you are connected to one.${Reset}\n   ${Blue}3${Reset}. ${Yellow}Connect to a Cloudflare WARP proxy and try again.${Reset}"
  if [ $isAndroid -eq 1 ]; then
    am start -n com.cloudflare.onedotonedotonedotone/com.cloudflare.app.presentation.main.SplashActivity &> /dev/null || termux-open-url "https://play.google.com/store/apps/details?id=com.cloudflare.onedotonedotonedotone"
  elif [ $isMacOS -eq 1 ]; then
    [ -d "/Applications/Cloudflare WARP.app" ] && open -a "Cloudflare WARP" || { formulaeInstall "cloudflare-warp"; open -a "Cloudflare WARP"; }
  fi
  echo; read -p "Press Enter to continue..."
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
  unset appLink
  while true; do read -r -p ">> Enter appName: " inputAppName; [[ "$inputAppName" =~ ^[Qq] ]] && inputAppName=; break; [ -n "$inputAppName" ] && break || echo -e "$notice Please enter a valid appName!"; done
  
  if [ -n "$inputAppName" ]; then
    echo -e "$running Searching $inputAppName on APKMirror.."
    
    input_app_name=$(echo "$inputAppName" | sed 's/ /+/g')
    [[ "$inputAppName" =~ [:space:] ]] && searchTerm="$input_app_name" || searchTerm="$inputAppName"
    
    page=1
    searchUrl="https://www.apkmirror.com/?post_type=app_release&searchtype=apk&bundles%5B%5D=apkm_bundles&bundles%5B%5D=apk_files&s=$searchTerm"
    searchResultHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$searchUrl")
    if ! grep -q "_cf_chl_" <<< "$searchResultHTML"; then
      lastPageLink=$(pup 'a.last attr{href}' <<< "$searchResultHTML")
      ! grep -q "https://www.apkmirror.com" <<< "$lastPageLink" && lastPageLink="https://www.apkmirror.com$lastPageLink"
      lastPageLink="${lastPageLink//amp;/}"
      lastPage=$(grep -o 'page=[0-9]*' <<< "$lastPageLink" | cut -d= -f2)
      while true; do
        if [ $page -eq 1 ]; then
          echo -e "$info Results for “${inputAppName}”"
          #local searchUrl="https://www.apkmirror.com/?post_type=app_release&searchtype=apk&bundles%5B%5D=apkm_bundles&bundles%5B%5D=apk_files&s=$searchTerm"
        elif [ $page -gt 1 ]; then
          echo -e "$info Results for “${inputAppName}” (Page $page)"
          local searchUrl="https://www.apkmirror.com/?post_type=app_release&searchtype=apk&page=$page&s=$searchTerm&bundles%5B%5D=apkm_bundles&bundles%5B%5D=apk_files"
        fi
        
        searchResultHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$searchUrl")
        grep -q "_cf_chl_" <<< "$searchResultHTML" && cf_chl_error && break
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
          if ! grep -q "_cf_chl_" <<< "$appPageHTML"; then
            appLink="https://www.apkmirror.com$(echo "$appPageHTML" | pup '#breadcrumbs a attr{href}' | sed -n '2p')"
            echo -e "$notice Selected: ${Green}$appName${Reset}"
            echo -e "$info Url for ${Green}$appName${Reset}: ${Blue}$appLink${Reset}"
          else
            cf_chl_error
          fi
          break
        fi
      done
    else
      cf_chl_error
    fi
  fi
  [ -z "$appLink" ] && return 1 || return 0
}

getLatestUploads() {
  unset versionLink
  echo -e "$running Get latest $appName uploads list from APKMirror.."
  page=1
  appPageHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$appLink")
  if ! grep -q "_cf_chl_" <<< "$appPageHTML"; then
    latestUploadsUrl="https://www.apkmirror.com$(pup '#primary a:contains("See more uploads...") attr{href}' <<< "$appPageHTML")"
    baseUploadsUrl=$(basename "$latestUploadsUrl")
    latestUploadsHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$latestUploadsUrl")
    if ! grep -q "_cf_chl_" <<< "$latestUploadsHTML"; then
      lastPageLink=$(pup 'a.last[aria-label="Last Page"] attr{href}' <<< "$latestUploadsHTML"); lastPage=$(echo "$lastPageLink" | grep -oE '[0-9]+')
      while true; do
        [ $page -eq 1 ] && echo -e "$info Latest $appName Uploads" || echo -e "$info Latest $appName Uploads - Page $page"
        latestUploadsUrl="https://www.apkmirror.com/uploads/page/$page/$baseUploadsUrl"
        latestUploadsHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$latestUploadsUrl")
        grep -q "_cf_chl_" <<< "$latestUploadsHTML" && cf_chl_error && break
        latestUploadsJSON=$(pup 'a.fontBlack json{}' <<< "$latestUploadsHTML" | jq '.[0:30] | map({title: .text, link: ("https://www.apkmirror.com" + .href)})')
        
        mapfile -t availableVersions < <(jq -r '.[] | .title' <<< "$latestUploadsJson" | grep -o '[0-9].*')
        if [ -n "$version" ]; then
          for i in "${!availableVersions[@]}"; do
            if [ "${availableVersions[$i]}" == "${appName} $version" ]; then
              versionName=$(grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' <<< "${availableVersions[$i]}")
            [ "$versionName" == "$version" ] && availableVersions[$i]="${availableVersions[$i]} (Recommended)"
            fi
          done
        fi
        [ $page -ge 3 ] && availableVersions+=(First)
        [ $page -ge 2 ] && availableVersions+=(Prev)
        [ $page -ne $lastPage ] && { availableVersions+=(Next); availableVersions+=(Last); }
        mapfile -t versionUrls < <(echo "$latestUploadsJSON" | jq -r '.[] | .link')
        
        buttons=("<Select>" "<Back>"); menu "availableVersions" "buttons" "10" || break
        
        if [ "${availableVersions[$selected]}" == "First" ]; then
          echo
          page=1
          #latestUploadsUrl="https://www.apkmirror.com/uploads/$baseUploadsUrl"
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
          selectedVersion="${selectedVersion%% (Recommended)}"
          versionLink="${versionUrls[$selected]}"
          echo -e "$good Selected Version: ${Green}$selectedVersion${Reset}"
          echo -e "$info versionLink: ${Blue}$versionLink${Reset}"
          break
        fi
      done
    else
      cf_chl_error
    fi
  else
    cf_chl_error
  fi
  [ -z "$versionLink" ] && return 1 || return 0
}

getVersionLink() {
  unset versionLink
  echo -e "$running Searching for target app version in APKMirror's Latest Uploads page.."
  appPageHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$appLink")
  if ! grep -q "_cf_chl_" <<< "$appPageHTML"; then
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
      grep -q "_cf_chl_" <<< "$latestUploadsHTML" && cf_chl_error && break
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
  else
    cf_chl_error
  fi
  [ -z "$versionLink" ] && return 1 || return 0
}

getVariant() {
  unset variantLink
  echo -e "$running Get Variant list from APKMirror.."
  variantHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" "$versionLink")
  if ! grep -q "_cf_chl_" <<< "$variantHTML"; then
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
        if [ $isAndroid -eq 1 ]; then
          if [ "$arch" == "$cpuAbi" ]; then
            options=("Version: $version ($version_code) | Type: $type | Arch: $arch | OS: $os | DPI: $dpi (Recommended)")
          else
            options=("Version: $version ($version_code) | Type: $type | Arch: $arch | OS: $os | DPI: $dpi")
          fi
        else
          options=("Version: $version ($version_code) | Type: $type | Arch: $arch | OS: $os | DPI: $dpi")
        fi
      else
        if [ $isAndroid -eq 1 ]; then
          if [ "$arch" == "$cpuAbi" ]; then
            options+=("Version: $version ($version_code) | Type: $type | Arch: $arch | OS: $os | DPI: $dpi (Recommended)")
          else
            options+=("Version: $version ($version_code) | Type: $type | Arch: $arch | OS: $os | DPI: $dpi")
          fi
        else
          options+=("Version: $version ($version_code) | Type: $type | Arch: $arch | OS: $os | DPI: $dpi")
        fi
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
  else
    cf_chl_error
    return 1
  fi
}

getDownloadLink() {
  unset downloadButtonLink
  echo -e "$running Get download button link from: ${Blue}$variantLink${Reset}"
  
  downloadButtonHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: https://www.apkmirror.com/" "$variantLink")
  if ! grep -q "_cf_chl_" <<< "$downloadButtonHTML"; then
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
        ! grep -q "https://www.apkmirror.com" <<< "$downloadButtonLink" && downloadButtonLink="https://www.apkmirror.com$downloadButtonLink"
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
      ! grep -q "https://www.apkmirror.com" <<< "$downloadButtonLink" && downloadButtonLink="https://www.apkmirror.com$downloadButtonLink"
      downloadButtonLink="${downloadButtonLink//amp;/}"
      echo -e "$info fileSize: $fileSize"
      echo -e "$info downloadButtonLink: ${Blue}$downloadButtonLink${Reset}"
    fi
  
    if [ "$fileType" == "Download APK" ]; then
      file_ext=".apk"
      CERTIFICATE=$(<<< "$downloadButtonHTML" awk '/<h4>APK certificate fingerprints<\/h4>/,/<h5>The cryptographic signature guarantees/' | sed -n 's/.*Certificate: *<span[^>]*>\([^<]*\)<\/span.*/\1/p' | head -n1)
      SHA256=$(<<<"$downloadButtonHTML" awk '/<h4>APK file hashes<\/h4>/,/<h5>Verify the file you downloaded/' | sed -n 's/.*SHA-256: *<span[^>]*>\([0-9a-fA-F]\{64\}\)<\/span.*/\1/p' | head -n1)
    else
      file_ext=".apkm"
      CERTIFICATE=$(<<< "$downloadButtonHTML" awk '/<h4>APK certificate fingerprints<\/h4>/,/<h5>The cryptographic signature of each APK/' | sed -n 's/.*Certificate: *<span[^>]*>\([^<]*\)<\/span.*/\1/p' | head -n1)
      SHA256=$(<<<"$downloadButtonHTML" awk '/<h4>APK bundle file hashes<\/h4>/,/<h5>Verify the APK bundle file you downloaded/' | sed -n 's/.*SHA-256: *<span[^>]*>\([0-9a-fA-F]\{64\}\)<\/span.*/\1/p' | head -n1)
    fi

    if [ -n "$downloadButtonLink" ]; then
      echo -e "$running Get final download link from: ${Blue}$downloadButtonLink${Reset}"
      finalDownloadButtonHTML=$(curl -sL --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: $variantLink" "$downloadButtonLink")  # Referer must required here
      if ! grep -q "_cf_chl_" <<< "$finalDownloadButtonHTML"; then
        finalDownloadButtonLink=$(pup -p --charset UTF-8 'a:contains("here") attr{href}' <<< "$finalDownloadButtonHTML" | head -1 2>/dev/null)
          # https://www.apkmirror.com/wp-content/themes/APKMirror/download.php?id=XXXXXXX&key=XxX 
          # https://www.androidpolice.com/2020/07/04/how-to-download-apps-without-the-play-store-and-why-apkmirror-is-the-best-place-to-get-them/
          # https://github.com/illogical-robot/apkmirror-public/issues
        [ -n "$finalDownloadButtonLink" ] && { dlLink="$(curl -sL -I --doh-url "$cloudflareDOH" -A "$USER_AGENT" -H "Referer: $variantLink" "https://www.apkmirror.com$finalDownloadButtonLink" | grep -i "location:" | head -1 | sed 's/location: //i' | tr -d '\r')"; echo -e "$good Found final download Link: ${Blue}$dlLink${Reset}"; return; } || return 1
      else
        cf_chl_error
      fi
    fi
  else
    cf_chl_error
  fi
  [ -n "$downloadButtonLink" ] && return 0 || return 1
}

getAppDetails() {
  echo -e "$running Scraping app details from: ${Blue}$variantLink${Reset}"
  downloadButtonJSON=$(pup 'div.apk-detail-table json{}' --plain <<< "$downloadButtonHTML")
  
  VERSION=$(jq -r '.. | objects | select(.text? and (.text | test("^Version:"))) | .text | sub("^Version: *"; "")' <<< "$downloadButtonJSON" | sed -E 's/ *Downloads:.*//;s/ +\(/ \(/' | head -n1)
  LANGUAGES=$(jq -r '.. | objects | select(.class == "accent_color" and .href == "#languages" and .text) | .text' <<< "$downloadButtonJSON" | head -n1)
  PACKAGE=$(jq -r '.. | objects | select(.text? and (.text | test("^Package:"))) | .text | sub("^Package: *"; "")' <<< "$downloadButtonJSON" | head -n1)
  DOWNLOADS=$(jq -r '.. | objects | select(.text? and (.text | test("Downloads: [0-9,]+"))) | .text | capture("Downloads: (?<d>[0-9,]+)") | .d' <<< "$downloadButtonJSON" | head -n1)
  FILESIZE=$(jq -r '.. | .text? | select(type == "string" and test("^[0-9]+\\.[0-9]+ MB \\("))' <<< "$downloadButtonJSON" | head -n1)
  MIN_VERSION=$(jq -r '.. | objects | select(.text? and (.text | test("Min: Android"))) | .text | sub("Min: *"; "") | sub("Target:.*"; "") | gsub(" +$"; "")' <<< "$downloadButtonJSON" | head -n1)
  TARGET_VERSION=$(jq -r '.. | objects | select(.text? and (.text | test("Min: Android"))) | .text' <<< "$downloadButtonJSON" | head -n1 | sed -nE 's/.*Target: (Android [0-9]+ \(API [0-9]+\)).*/\1/p')
  ARCHITECTURES=$(jq -r '.. | objects | select(.text? and (.text | test("arm64-v8a|armeabi-v7a|x86|x86_64"))) | .text' <<< "$downloadButtonJSON" | head -n1)
  EXTRA_FEATURES=$(jq -r '.. | objects | select(.text? and (.text | test("^Supports Android Auto$"))) | .text' <<< "$downloadButtonJSON" | head -n1)
  UPLOAD_TIME=$(jq -r '.. | objects | select(.class? == "datetime_utc" and .text?) | .text' <<< "$downloadButtonJSON" | head -n1)
  [ -z "$UPLOAD_TIME" ] && UPLOAD_TIME=$(jq -r '.. | objects | select(.text? and (.text | test("^Uploaded"))) | .text | sub("^Uploaded by .+[A-Z][a-z]{3} [0-9]{1,2}, [0-9]{4} at [0-9]{1,2}:[0-9]{2}[AP]M UTC"; "")' <<< "$downloadButtonJSON" | head -1)
  UPLOADED_BY=$(jq -r '.. | objects | select(.text? and (.text | test("^Uploaded by "))) | .text | sub("^Uploaded by *"; "")' <<< "$downloadButtonJSON" | head -n1)
  
  echo "🏷️ Version: $VERSION"
  echo "🌐 Languages: $LANGUAGES"
  echo "📦 Package: $PACKAGE"
  echo "📥 Downloads: $DOWNLOADS"
  echo "💿 File size: $FILESIZE"
  echo "📱 Min: $MIN_VERSION"
  echo "🎯 Target: $TARGET_VERSION"
  echo "🛠 Supported arch: $ARCHITECTURES"
  echo "🔑 Certificate: $CERTIFICATE"
  echo "# SHA-256 SUM: $SHA256"
  [ -n "$EXTRA_FEATURES" ] && echo "✨ Extra Features: $EXTRA_FEATURES"
  echo "📅 Upload time: $UPLOAD_TIME"
  echo "👤 Uploaded by: $UPLOADED_BY"
}

apkm2apk() {
  dlAPKEditor
  if [ $isMacOS -eq 1 ]; then
    if [ -n "$cpuAbi" ]; then
      mkdir -p "$Download/${appName}_v${version}-${arch}"
      if [ $RipLib -eq 1 ]; then
        pv "$apkPath" | tar -xf - -C "$Download/${appName}_v${version}-${arch}/" --include "base.apk" "split_config.${cpuAbi//-/_}.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk"
        tar_exit_status=$?
      elif [ $RipLib -eq 0 ]; then
        pv "$apkPath" | tar -xf - -C "$Download/${appName}_v${version}-${arch}/" --include "base.apk" "split_config.arm64_v8a.apk" "split_config.armeabi_v7a.apk" "split_config.x86_64.apk" "split_config.x86.apk" "split_config.${locale}.apk" "split_config.${lcd_dpi}.apk"
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
################################################################################################################
