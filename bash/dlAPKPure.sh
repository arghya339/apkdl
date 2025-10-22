#!/bin/bash

CONTENT_TYPE="application/octet-stream"  # octet-stream = binary data being sent
ACCEPT_LANGUAGE="en-US,en;q=0.9"  # client language prefers US-English with 90% quality rating
CONNECTION="keep-alive"  # requests to keep TCP connection open for multiple requests
UPGRADE_INSECURE_REQUESTS="1"  # client prefers HTTPS connections over HTTP
CACHE_CONTROL="max-age=0"  # tells intermediaries not to use cached versions, forces fresh request
ACCEPT="text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"  # Accept header: Specifies what content types the client can handle, with quality preferences
ALL_HEADER=(
  --header="User-Agent: $USER_AGENT"
  --header="Content-Type: $CONTENT_TYPE"
  --header="Accept-Language: $ACCEPT_LANGUAGE"
  --header="Connection: $CONNECTION"
  --header="Upgrade-Insecure-Requests: $UPGRADE_INSECURE_REQUESTS"
  --header="Cache-Control: $CACHE_CONTROL"
  --header="Accept: $ACCEPT"
)

APKPureSearch() {
  while true; do read -r -p ">> Enter appName: " appName; [[ "$appName" =~ ^[Qq] ]] && appName=; break; [ -n "$appName" ] && break || echo -e "$notice Please enter a valid appName!"; done
  app_name=$(echo "$appName" | tr '[:upper:]' '[:lower:]' | sed 's/ /+/g')

  if [ -n "$app_name" ]; then
    apiUrl="https://apkpure.com/api/v1/search_suggestion_new?key=${app_name}&limit=20"
    aria2c -q -o response.json "${ALL_HEADER[@]}" --connect-timeout=30 --save-cookies=cookies.txt --check-certificate=false --referer="https://apkpure.com" --async-dns=true --async-dns-server="$cloudflareIP" "$apiUrl"
    responseJSON=$(cat response.json) && rm -f response.json

    index=0
    while IFS= read -r line; do
      if [ -n "$line" ]; then
        decoded=$(echo "$line" | base64 --decode)
        title=$(echo "$decoded" | jq -r '.title')
        package=$(echo "$decoded" | jq -r '.packageName')
        url=$(echo "$decoded" | jq -r '.fullUrl')
        
        titles[$index]="$title"
        packages[$index]="$package"
        urls[$index]="$url"
        ((index++))
      fi
    done < <(jq -r '.[] | select(.packageName != null) | @base64' <<< "$responseJSON")
   
    if [ ${#titles[@]} -gt 0 ]; then
      buttons=("<Select>" "<Back>")
      if menu "titles" "buttons" "10"; then
        appName=${titles[$selected]}
        pkgName=${packages[$selected]}
        appLink=${urls[$selected]}
        echo -e "$info appName: $appName"
        echo -e "$info pkgName: $pkgName"
        echo -e "$info appLink: ${Blue}$appLink${Reset}"
        return
      else
        return 1
      fi
    else
      searchUrl="https://apkpure.com/search?q=$app_name"
      aria2c -q -o apkpure_page.html -d "$HOME" "${ALL_HEADER[@]}" --connect-timeout=30 --load-cookies=cookies.txt --save-cookies=cookies.txt --check-certificate=false --referer="https://apkpure.com/" --async-dns=true --async-dns-server="$cloudflareIP" "$searchUrl" && searchHTML=$(cat "$HOME/apkpure_page.html") && rm -f ~/apkpure_page.html
      while IFS=, read -r appLink appName by; do
        appLinks+=("$appLink")
        appNames+=("$appName")
        bys+=("$by")
      done < <(pup 'ul.search-res li a.dd json{}' <<< "$searchHTML" | jq -r '.[] | "\(.href),\(.children[1].children[0].text),\(.children[1].children[1].text)"')
      for i in "${!appNames[@]}"; do
        results+=("${appNames[i]} by ${bys[i]}")
      done
      buttons=("<Select>" "<Back>")
      if menu "results" "buttons" "10"; then
        appName="${appNames[$selected]}"
        by="${bys[$selected]}"
        appLink="${appLinks[$selected]}"
        echo -e "$info Selected App: $appName by $by"
        echo -e "$info appLink: ${Blue}$appLink${Reset}"
        return
      else
        return 1
      fi
    fi
  else
    return 1
  fi
}

AllVersions() {
  AllVersions="$appLink/versions"
  aria2c -q -o apkpure_page.html -d "$HOME" "${ALL_HEADER[@]}" --connect-timeout=30 --save-cookies=cookies.txt --load-cookies=cookies.txt --check-certificate=false --referer="$appLink" --async-dns=true --async-dns-server="$cloudflareIP" "$AllVersions" && allVersionsHTML=$(cat "$HOME/apkpure_page.html") && rm -f ~/apkpure_page.html
  allVersionsJSON=$(pup 'ul.ver-wrap li json{}' <<< "$allVersionsHTML")

  json_data=$(jq -r '
  [
    .[]
    | .children[]
    | select(.class == "ver_download_link")
    | {
        versionName: (
          [.children[]?.children[]? | select(.class=="ver-item-n")?.text][0]
          | split("\n")
          | map(gsub("\\s+"; ""))
          | join(" ")
        ),
        fileSize: (
          [.children[]?.children[]?.children[]? | select(.class=="ver-item-s")?.text][0]
        ),
        updateOn: (
          [.children[]?.children[]?.children[]? | select(.class=="update-on")?.text][0]
        ),
        variant: (
          .["data-dt-variant"] // ""
        ),
        versionLink: .href
      }
  ]' <<< "$allVersionsJSON")
  
  readarray -t versionNames < <(echo "$json_data" | jq -r '.[].versionName')
  readarray -t fileSizes < <(echo "$json_data" | jq -r '.[].fileSize')
  readarray -t updateOns < <(echo "$json_data" | jq -r '.[].updateOn')
  readarray -t variants < <(echo "$json_data" | jq -r '.[].variant')
  readarray -t versionLinks < <(echo "$json_data" | jq -r '.[].versionLink')
  
  versions=()
  for i in "${!versionNames[@]}"; do
    versions+=("${versionNames[$i]} | ${fileSizes[$i]} | ${updateOns[$i]}")
  done
  
  buttons=("<Select>" "<Back>")
  if menu "versions" "buttons" "10"; then
    versionName="${versionNames[$selected]}"
    fileSize="${fileSizes[$selected]}"
    updateOn="${updateOns[$selected]}"
    variant="${variants[$selected]}"
    versionLink="${versionLinks[$selected]}"
    echo -e "$info versionName: $versionName"
    echo -e "$info fileSize: $fileSize"
    echo -e "$info updateOn: $updateOn"
    echo -e "$info variant: $variant"
    echo -e "$info versionLink: ${Blue}$versionLink${Reset}"
    return
  else
    return 1
  fi
}

decodeHTML() {
  echo "$1" | sed -e 's/&amp;/\&/g' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e "s/&#39;/'/g" -e 's/&quot;/"/g' -e 's/&nbsp;/ /g' -e 's/&#[0-9]*;/ /g'
}

APKPureVariant() {
  aria2c -q -o apkpure_page.html -d "$HOME" "${ALL_HEADER[@]}" --connect-timeout=30 --save-cookies=cookies.txt --load-cookies=cookies.txt --check-certificate=false --referer="$AllVersions" --async-dns=true --async-dns-server="$cloudflareIP" "$versionLink" && versionHTML=$(cat "$HOME/apkpure_page.html") && rm -f ~/apkpure_page.html
  downloads=$(pup 'ul.dev-partnership-head-info li div.head text{}' <<< "$versionHTML" | sed -n '2p')
  languages=$(pup 'div.fancybox-custom-dialog-2#language-dialog ul li text{}' <<< "$versionHTML")
  permissions=$(pup 'div.fancybox-custom-dialog-2#permission-dialog ul li text{}' <<< "$versionHTML")
  
  variantsJSON=$(pup 'div.apk json{}' <<< "$versionHTML")
  index=0
  while IFS= read -r line; do
    version[$index]=$(echo "$line" | jq -r '.children[1].children[0].children[0].text')
    versionCode[$index]=$(echo "$line" | jq -r '.children[1].children[0].children[1].text' | tr -d '()')
    TYPE[$index]=$(echo "$line" | jq -r '.children[1].children[0].children[2].text')
    updateOn[$index]=$(echo "$line" | jq -r '.children[1].children[1].children[0].text')
    fileSize[$index]=$(echo "$line" | jq -r '.children[1].children[1].children[1].text')
    minAndroid[$index]=$(echo "$line" | jq -r '.children[1].children[1].children[2].text')
    dlLink[$index]=$(echo "$line" | jq -r '.children[2].href')
    versionTitle[$index]=$(echo "$line" | jq -r '.children[3].children[0].children[0].text')
    architecture[$index]=$(echo "$line" | jq -r '.children[3].children[1].children[0].children[0].children[1].text')
    requiresAndroid[$index]=$(echo "$line" | jq -r '.children[3].children[1].children[0].children[1].children[1].text')
    signatures[$index]=$(echo "$line" | jq -r '.children[3].children[1].children[0].children[2].children[1].text')
    screenDPI[$index]=$(echo "$line" | jq -r '.children[3].children[1].children[0].children[3].children[1].text')
    fileSHA1[$index]=$(echo "$line" | jq -r '.children[3].children[1].children[0].children[4].children[1].text')
    xFileSHA1[$index]=$(echo "$line" | jq -r '.children[3].children[1].children[0].children[6].children[1].text')
    uploadedBy[$index]=$(echo "$line" | jq -r '.children[3].children[1].children[0].children[5].children[1].text')
    xUploadedBy[$index]=$(echo "$line" | jq -r '.children[3].children[1].children[0].children[7].children[1].text')
    #type[$index]=$(echo "$line" | jq -r '.class')
    pkgName[$index]=$(echo "$line" | jq -r '.["data-dt-app"]')
    ((index++))
  done < <(jq -c '.[]' <<< "$variantsJSON")
  
  variants=()
  for ((i=0; i<index; i++)); do
    variants+=("${versionCode[$i]} | ${architecture[$i]} | ${minAndroid[$i]} | ${TYPE[$i]} | ${screenDPI[$i]}") # ${fileSize[$i]} | ${updateDate[$i]}")
  done
  
  if [ "$variant" == "true" ]; then
    buttons=("<Select>" "<Back>")
    menu "variants" "buttons" "10" || return 1
  elif [ "$variant" == "false" ]; then
    selected=0
  fi
  if [[ "$selected" =~ ^[0-9]+$ ]]; then
    version="${version[$selected]}"
    versionCode="${versionCode[$selected]}"
    TYPE="${TYPE[$selected]}"
    updateOn="${updateOn[$selected]}"
    fileSize="${fileSize[$selected]}"
    dlLink=$(decodeHTML "${dlLink[$selected]}")
    arch="${architecture[$selected]}"
    requiresAndroid="${requiresAndroid[$selected]}"
    signatures="${signatures[$selected]}"
    screenDPI="${screenDPI[$selected]}"
    [ "${TYPE}" == "APK" ] && fileSHA1="${fileSHA1[$selected]}" || baseAPK="${fileSHA1[$selected]}"
    [ "${TYPE}" == "APK" ] && uploadedBy="${uploadedBy[$selected]}" || splitAPK="${uploadedBy[$selected]}"
    pkgName="${pkgName[$selected]}"
    baseAPK="${baseAPK[$selected]}"
    [ "$TYPE" == "APK" ] && file_ext=".apk" || file_ext=".apks"

    echo -e "$info version               : $version"
    echo -e "$info versionCode           : $versionCode"
    echo -e "$info TYPE                  : $TYPE"
    echo -e "$info updateON              : $updateOn"
    echo -e "$info fileSize              : $fileSize"
    echo -e "$info dlLink                : ${Blue}$dlLink${Reset}"
    echo -e "$info supportedarchitecture : $arch"
    echo -e "$info requiresAndroid       : $requiresAndroid"
    echo -e "$info signatures            : $signatures"
    echo -e "$info screenDPI             : $screenDPI"
    [ "${TYPE}" == "XAPK" ] && fileSHA1="$xFileSHA1"
    echo -e "$info fileSHA1              : $fileSHA1"
    [ "$baseAPK" != "" ] && echo -e "$info baseAPK               : $baseAPK"
    [ "$splitAPK" != "" ] && echo -e "$info splitAPK              : $splitAPK"
    [ "${TYPE}" == "APK" ] && echo -e "$info uploadedBy            : $uploadedBy"
    [ "${TYPE}" == "XAPK" ] && echo -e "$info uploadedBy            : $xUploadedBy"
    echo -e "$info pkgName               : $pkgName"
    echo -e "$info Downloads             : $downloads"
    #echo -e "$info Languages             : $languages"
    #echo -e "$info Permissions           : $permissions"
    return
  else
    return 1
  fi
}

dlAPKPure() {
  while true; do
    if [ $isAndroid -eq 1 ]; then
      aria2c  -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" "${ALL_HEADER[@]}" --connect-timeout=30 --save-cookies=cookies.txt --load-cookies=cookies.txt --check-certificate=false --referer="$versionLink" --async-dns=true  --async-dns-server="$cloudflareIP" "$dlLink"
      exitStatus=$?
    elif [ $isMacOS -eq 1 ]; then
      aria2c  -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" "${ALL_HEADER[@]}" --connect-timeout=30 --save-cookies=cookies.txt --load-cookies=cookies.txt --check-certificate=false --referer="$versionLink" --ca-certificate="/etc/ssl/cert.pem" --async-dns=true  --async-dns-server="$cloudflareIP" "$dlLink"
      exitStatus=$?
    fi
    echo
    [ $exitStatus -eq 0 ] && { rm -f cookies.txt; break; } || sleep 5
  done 
  
  if [ $isAndroid -eq 1 ]; then
    sha1sum=$(sha1sum "$apkPath" | cut -d' ' -f1)
  elif [ $isMacOS -eq 1 ]; then
    sha1sum=$(shasum -a 1 "$apkPath" | cut -d' ' -f1)
  fi
  if [ "$fileSHA1" == "$sha1sum" ]; then
    echo -e "$good Downloaded file appears in the original state.\n"
  else
    echo -e "$notice Look like downloaded file appears corrupted!"
    echo -e "$notice SHA1 SUM Diffs - Expected: ${Cyan}$fileSHA1${Reset} ~ Result: ${Cyan}$sha1sum${Reset}"
  fi
}
#######################################################################################################