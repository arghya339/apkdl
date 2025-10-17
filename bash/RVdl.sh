#!/bin/bash

current_patches_release_version=$(curl -sLX 'GET' 'https://api.revanced.app/v4/patches/version' -H 'accept: application/json' | jq -r '.version')  # Get current patches release version from ReVanced API

# Check if revanced.json file exists and patches_release_version match with current_patches_release_version
if [ -f $apkdl/revanced.json ] && [ -f $apkdl/patches_release_version ] && [ "$(cat $apkdl/patches_release_version)" == "$current_patches_release_version" ]; then
  apps_json=$(cat $apkdl/revanced.json)  # Loading data from revanced.json file
else
  echo "$current_patches_release_version" > $apkdl/patches_release_version  # Store current patches release version in patches_release_version file
  echo -e "$running Fetching fresh data from APKMirror API..."
    
  # Get list of patches from current patches release using ReVanced API
  result=$(curl -sL 'https://api.revanced.app/v4/patches/list' | jq '
  [.[] | select(.compatiblePackages != null) | .compatiblePackages | to_entries[]]
  | group_by(.key)
  | map({
    package: .[0].key,
    version: ([.[].value] | flatten | map(select(. != null)) | unique | if length > 0 then .[-1] else null end)
  })')
    
  # Start with empty apps_json array
  apps_json="[]"
  total_apps=$(echo "$result" | jq length)
    
  # Process each package to get APKMirror apps data
  for ((i=0; i<total_apps; i++)); do
    pkgName=$(echo "$result" | jq -r ".[$i].package")
    version=$(echo "$result" | jq -r ".[$i].version")
        
    echo -e "$running Processing $((i+1))/$total_apps: $pkgName"
        
    RESPONSE_JSON=$(curl -sL --doh-url "$cloudflareDOH" $APKM_REST_API_URL -A "$USER_AGENT" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Basic $AUTH_TOKEN" -d "{\"pnames\":[\"$pkgName\"]}")
        
    if echo "$RESPONSE_JSON" | jq -e ".data[] | select(.pname == \"$pkgName\") | .exists == true" > /dev/null 2>&1; then
      appName=$(jq -r ".data[] | select(.pname == \"$pkgName\") | .app.name" <<< "$RESPONSE_JSON")
      appName="${appName//amp;/}"
      #appName=$(echo "${appName%%[:—(]*}" | xargs)
      appLink="https://www.apkmirror.com$(jq -r ".data[] | select(.pname == \"$pkgName\") | .app.link" <<< "$RESPONSE_JSON")"
            
      # Add valid app to apps_json
      new_app=$(jq -n --arg pkg "$pkgName" --arg ver "$version" --arg name "$appName" --arg link "$appLink" '{package: $pkg, version: $ver, name: $name, link: $link}')
            
      apps_json=$(echo "$apps_json" | jq ". += [$new_app]")
      echo -e "$good Found: $appName"
    else
      echo -e "$notice Not Found: $pkgName"
      continue
    fi
  done
    
  # Save apps data to $apkdl/revanced.json file
  echo "$apps_json" > $apkdl/revanced.json
  unset pkgName version appName appLink
fi

# Convert JSON to arrays
mapfile -t names < <(echo "$apps_json" | jq -r '.[].name')
mapfile -t packages < <(echo "$apps_json" | jq -r '.[].package')
mapfile -t versions < <(echo "$apps_json" | jq -r '.[].version | if . == null then "null" else . end')
mapfile -t links < <(echo "$apps_json" | jq -r '.[].link')

buttons=("<Select>" "<Back>")
if menu "names" "buttons" "10"; then
  selected=$selected
else
  selected=
fi

if [ -n "$selected" ]; then
  # Get selected item details from arrays
  appName="${names[$selected]}"
  searchTerm=$(echo "$appName" | sed 's/ /+/g')
  pkgName="${packages[$selected]}"
  version="${versions[$selected]}"
  appLink="${links[$selected]}"

  # Print results
  echo "Selected App:"
  echo -e "$info Name: $appName"
  echo -e "$info Package: $pkgName"
   echo -e "$info Version: $version"
  echo -e "$info Link: ${Blue}$appLink${Reset}"

  # Access full selected item as JSON
  echo -e "\nFull JSON data for selected item:"
  echo "$apps_json" | jq ".[$selected]"
  [ "$version" == "null" ] && version=
  return 0
else
  return 1
fi
######################################################################################################