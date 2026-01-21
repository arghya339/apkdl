#!/bin/bash

decodeHTML() {
  echo "$1" | sed -e 's/&amp;/\&/g' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e "s/&#39;/'/g" -e 's/&quot;/"/g' -e 's/&nbsp;/ /g'
}

UptodownSearch() {
  while true; do read -r -p ">> Enter appName: " appName; [[ "$appName" =~ ^[Qq] ]] && appName=; break; [ -n "$appName" ] && break || echo -e "$notice Please enter a valid appName!"; done
  if [ -n "$appName" ]; then
    app_name=$(echo "$appName" | tr '[:upper:]' '[:lower:]')
    
    page=1
    index=0
    
    while IFS= read -r line; do
      name=$(echo "$line" | jq -r '.name')
      url=$(echo "$line" | jq -r '.url')
      description=$(echo "$line" | jq -r '.description')
    
      name=$(decodeHTML "$name")
      description=$(decodeHTML "$description")
    
      if [[ -n "$name" && "$name" != "null" ]]; then
        names[$index]="$name"
        urls[$index]="$url"
        descriptions[$index]="$description"
        ((index++))
      fi
    done < <(curl -sL -A "$USER_AGENT" -X POST "https://en.uptodown.com/android/search" -d "q=${app_name}" -d "page=$page" | pup '.item json{}' | jq -c '.[] | {name: .children[1].children[0].text, description: .children[2].text, url: .children[1].children[0].href}')
  
    for i in "${!names[@]}"; do
      [ $i -eq 0 ] && availableApps=("${names[$i]} - ${descriptions[$i]}") || availableApps+=("${names[$i]} - ${descriptions[$i]}")
    done
  
    buttons=("<Select>" "<Back>"); if menu availableApps buttons; then selected=$selected; else selected=""; fi
  
    if [[ "$selected" =~ ^[0-9]+$ ]]; then
      appName="${names[$selected]}"
      appLink="${urls[$selected]}"
      echo -e "$info Selected app: $appName"
      echo -e "$info Description: ${descriptions[$selected]}"
      echo -e "$info appLink: ${Blue}$appLink${Reset}"
      return
    else
      return 1
    fi
  else
    return 1
  fi
}

UptodownVersionLink() {
  dataCode=$(curl -sL -A "$USER_AGENT" "$appLink" | grep -i "data-code" | sed -n 's/.*data-code="\([0-9]*\)".*/\1/p')  # Get app ID on Uptodown
  if [[ "$dataCode" =~ ^[0-9]+$ ]]; then
    page=1
    while true; do
      versionsJSON=$(curl -sL -A "$USER_AGENT" "$appLink/apps/$dataCode/versions/$page")  # Uptodown’s OLDER VERSIONS Page Url
      jsonLength=$(jq '.data | length' <<< "$versionsJSON")
      if [ $jsonLength -gt 0 ]; then
        index=0
        while IFS=$'\t' read -r fileID version sdkVersion kindFile baseUrl extraUrl versionID lastUpdate; do
          if [[ -n "$fileID" && "$fileID" != "null" ]]; then
            fileIDs[$index]="$fileID"
            versions[$index]="$version"
            sdkVersions[$index]="$sdkVersion"
            kindFiles[$index]="$kindFile"
            lastUpdates[$index]="$lastUpdate"
            versionURLs[$index]="$baseUrl/$extraUrl/$versionID"
            ((index++))
          fi
        done < <(jq -r '.data[] | [.fileID, .version, .sdkVersion, .kindFile, .versionURL.url, .versionURL.extraURL, .versionURL.versionID, .lastUpdate] | @tsv' <<< "$versionsJSON")
        availableVersions=()
        for ((i=0; i<${#fileIDs[@]}; i++)); do
          availableVersions+=("v${versions[$i]} | min ${sdkVersions[$i]} | fileType ${kindFiles[$i]} | lastUpdate ${lastUpdates[$i]}")
        done
        [ $page -ne 1 ] && availableVersions+=("SEE LESS")
        availableVersions+=("SEE MORE")
        if menu availableVersions buttons; then
          selected=$selected
          if [ $page -ne 1 ] && [ $selected -eq $((${#availableVersions[@]}-2)) ]; then
            ((page--))
            continue
          elif [ $selected -eq $((${#availableVersions[@]}-1)) ]; then
            ((page++))
            continue
          else
            versionLink="${versionURLs[$selected]}"
            echo -e "\n$info Selected version details:"
            echo -e "$info fileID (versionID)         : ${fileIDs[$selected]}"
            echo -e "$info version                    : ${versions[$selected]}"
            echo -e "$info sdkVersion (minAndroid)    : ${sdkVersions[$selected]}"
            echo -e "$info kindFile (fileType)        : ${kindFiles[$selected]}"
            echo -e "$info lastUpdate                 : ${lastUpdates[$selected]}"
            echo -e "$info versionURL                 : ${Blue}$versionLink${Reset}"
            return
            break
          fi
        else
          return 1
        fi
      else
        return 1
      fi
    done
  else
    return 1
  fi
}

UptodownDownloadLink() {
  versionHTML=$(curl -sL -A "$USER_AGENT" "$versionLink")
  dataVersion=$(sed -n 's/.*<button class="button variants" data-version="\([^"]*\)".*/\1/p' <<< "$versionHTML")  # 'ALL VARIANTS' BUTTON ID
  if [ -z "$dataVersion" ]; then
    variantHTML="$versionHTML"
    dataUrl=$(pup '#detail-download-button attr{data-url}' <<< "$variantHTML")
    dlLink="https://dw.uptodown.com/dwn/${dataUrl}"
    echo -e "$info dlUrl: ${Blue}$dlLink${Reset}"
  else
    baseAppLink=$(dirname $appLink)  # https://app.en.uptodown.com/~~android~~
    filesJSON=$(curl -sL -A "$USER_AGENT" "$baseAppLink/app/${dataCode}/version/${dataVersion}/files" | jq -r '.content')  # 'ALL VARIANTS' NETWORK RESPONSE HEADERS
    baseVersionLink=$(dirname $versionLink)  # https://app.en.uptodown.com/android/download/~~fileID~~
    variantCount=$(echo "$filesJSON" | pup 'div.variant' | grep -c 'class="variant"')  # Count variants from 'ALL VARIANTS' Response
    # Loops through variant for print all list of variant info
    [ $variantCount -gt 1 ] && variants=()
    for ((i = 1; i <=variantCount; i++)); do
      if [ $variantCount -eq 1 ]; then
        arch=$(pup "div.content > p:nth-of-type($i) text{}" <<< "$filesJSON" | xargs)  # Get variant arch(arm64-v8a) form 'ALL VARIANTS' Response
        type=$(pup "div.variant:nth-of-type($i) div.v-file span text{}" <<< "$filesJSON" | xargs)  # Get variant type(xapk/apk) form 'ALL VARIANTS' Response
        data_file_id=$(pup "div.variant:nth-of-type($i) > .v-report attr{data-file-id}" <<< "$filesJSON")  # Get variant ID form 'ALL VARIANTS' Response
        location_url="$baseVersionLink/${data_file_id}-x"
      else
        arch=$(pup "div.content > p:nth-of-type($i) text{}" <<< "$filesJSON" | xargs)  # Get variant arch(arm64-v8a) form 'ALL VARIANTS' Response
        type=$(pup "div.variant:nth-of-type($i) div.v-file span text{}" <<< "$filesJSON" | xargs)  # Get variant type(xapk/apk) form 'ALL VARIANTS' Response
        data_file_id=$(pup "div.variant:nth-of-type($i) > .v-report attr{data-file-id}" <<< "$filesJSON")  # Get variant ID form 'ALL VARIANTS' Response
        location_url="$baseVersionLink/${data_file_id}-x"
        archs[$(($i-1))]+="$arch"; types[$(($i-1))]+="$type"; data_file_ids[$(($i-1))]="$data_file_id"; location_urls[$(($i-1))]="$location_url"
        variants+=("arch: $arch | type: $type | file_id: $data_file_id")
      fi
    done
    if [ $variantCount -eq 1 ]; then
      data_url=$(curl -sL -A "$USER_AGENT" "$location_url" | pup '#detail-download-button attr{data-url}')
      dlLink="https://dw.uptodown.com/dwn/${data_url}"
      echo -e "$info dlUrl: ${Blue}$dlLink${Reset}"
      return
    else
      if menu variants buttons; then
        selected=$selected
        location_url="${location_urls[$selected]}"
        data_url=$(curl -sL -A "$USER_AGENT" "$location_url" | pup '#detail-download-button attr{data-url}')
        dlLink="https://dw.uptodown.com/dwn/${data_url}"
        echo -e "$info dlUrl: ${Blue}$dlLink${Reset}"
        return
      else
        return 1
      fi
    fi
  fi
}

UptodownAppInfo() {
  [ -n "$dataVersion" ] && variantHTML=$(curl -sL -A "$USER_AGENT" "$location_url")
  
  version=$(pup 'div.version json{}' <<< "$variantHTML" | jq -r '.[0].text')
  pkgName=$(grep -A1 "Package Name" <<< "$variantHTML" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  size=$(grep -A1 "Size" <<< "$variantHTML" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  downloads=$(grep -A1 "Downloads" <<< "$variantHTML" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  Type=$(grep -A1 "File type" <<< "$variantHTML" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  arch=$(grep -A1 "Architecture" <<< "$variantHTML" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  SHA256=$(grep -A1 "SHA256" <<< "$variantHTML" | tail -1 | sed -e 's/<[^>]*>//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  requirements=$(awk '/<th[^>]*>Requirements<\/th>/{flag=1;next} flag && /<li>/{gsub(/.*<li>|<\/li>.*/,"");print;exit}' <<< "$variantHTML" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ "$Type" == "XAPK" ] && file_ext=".apks" || file_ext=".apk"

  echo -e "Information about $appName $version"
  echo -e "${info} pkgName       : ${Reset}${pkgName}"
  echo -e "${info} fileSize      : ${Reset}${size}"
  echo -e "${info} Downloads     : ${Reset}${downloads}"
  echo -e "${info} fileType      : ${Reset}${Type}"
  echo -e "${info} supportedArch : ${Reset}${arch}"
  echo -e "${info} fileSHA256    : ${Reset}${SHA256}"
  echo -e "${info} reqOS         : ${Reset}${requirements}\n"
}
#####################################################################################################################################################################################