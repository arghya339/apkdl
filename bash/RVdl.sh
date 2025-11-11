#!/bin/bash

organization=${1}

if [ "$organization" == "ReVanced" ]; then
  [ $PreReleasePatches -eq 0 ] && requestUrl="https://api.revanced.app/v4/patches/version" || requestUrl="https://api.revanced.app/v4/patches/version?prerelease=true"
  current_patches_release_version=$(curl -sLX 'GET' "$requestUrl" -H 'accept: application/json' | jq -r '.version')  # Get current patches release version from ReVanced API
elif [ "$organization" == "RVX" ]; then
  # Get current patches release version from GitHub API
  [ $PreReleasePatches -eq 0 ] && current_patches_release_version=$(curl -s ${auth} "https://api.github.com/repos/anddea/revanced-patches/releases/latest" | jq -r '.tag_name') || current_patches_release_version=$(curl -sL ${auth} "https://api.github.com/repos/anddea/revanced-patches/releases" | jq -r '.[0].tag_name')
fi
patches_release_version=$(jq -r --arg org "$organization" '.[$org]' "$apkdlJson" 2>/dev/null)

# Check if revanced.json file exists and patches_release_version match with current_patches_release_version
if [ -f $apkdl/$organization.json ] && jq -e --arg org "$organization" '.[$org] != null' "$apkdlJson" >/dev/null 2>&1 && [ "$patches_release_version" == "$current_patches_release_version" ]; then
  apps_json=$(cat $apkdl/$organization.json)  # Loading data from revanced.json file
else
  config "$organization" "$current_patches_release_version"  # Store current patches release version in apkdlJson file
  echo -e "$running Fetching fresh data from APKMirror API..."
  
  if [ "$organization" == "ReVanced" ]; then
    # Get list of patches from current patches release using ReVanced API
    [ $PreReleasePatches -eq 0 ] && requestUrl="https://api.revanced.app/v4/patches/list" || requestUrl="https://api.revanced.app/v4/patches?prerelease=true"
    patchesJson=$(curl -sL "$requestUrl")
  elif [ "$organization" == "RVX" ]; then
    [ $PreReleasePatches -eq 0 ] && branch="main" || branch="dev"
    patchesJson=$(curl -sL "https://raw.githubusercontent.com/anddea/revanced-patches/refs/heads/${branch}/patches.json")
  fi
  result=$(jq '
  [.[] | select(.compatiblePackages != null) | .compatiblePackages | to_entries[]]
  | group_by(.key)
  | map({
    package: .[0].key,
    version: ([.[].value] | flatten | map(select(. != null)) | unique | if length > 0 then .[-1] else null end)
  })' <<< "$patchesJson")
    
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
  echo "$apps_json" > $apkdl/$organization.json
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