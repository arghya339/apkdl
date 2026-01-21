#!/bin/bash

organization=${1}

if [ "$organization" == "ReVanced" ]; then
  [ $PreReleasePatches -eq 0 ] && requestUrl="https://api.revanced.app/v4/patches/version" || requestUrl="https://api.revanced.app/v4/patches/version?prerelease=true"
  current_patches_release_version=$(curl -sLX 'GET' "$requestUrl" -H 'accept: application/json' | jq -r '.version')  # Get current patches release version from ReVanced API
elif [ "$organization" == "Morphe" ] || [ "$organization" == "RVX" ]; then
  # Get current patches release version from GitHub API
  [ "$organization" == "Morphe" ] && { owner="MorpheApp"; repo="morphe-patches"; } || { owner="anddea"; repo="revanced-patches"; }
  if [ $PreReleasePatches -eq 0 ]; then
  current_patches_release_version=$(curl -s ${auth} "https://api.github.com/repos/$owner/$repo/releases/latest" | jq -r '.tag_name')
  else
    current_patches_release_version=$(curl -sL ${auth} "https://api.github.com/repos/$owner/$repo/releases" | jq -r '.[0].tag_name')
  fi
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
  elif [ "$organization" == "Morphe" ] || [ "$organization" == "RVX" ]; then
    [ $PreReleasePatches -eq 0 ] && branch="main" || branch="dev"
    [ "$organization" == "Morphe" ] && patchesJson=$(curl -sL "https://github.com/MorpheApp/morphe-patches/blob/${branch}/patches-list.json") || patchesJson=$(curl -sL "https://raw.githubusercontent.com/anddea/revanced-patches/refs/heads/${branch}/patches.json")
  fi
  result=$(jq '
  [.[] | select(.compatiblePackages != null) | .compatiblePackages | to_entries[]]
  | group_by(.key)
  | map({
    package: .[0].key,
    version: ([.[].value] | flatten | map(select(. != null)) | unique | if length > 0 then .[-1] else null end)
  })' <<< "$patchesJson")
  total_apps=$(echo "$result" | jq length)
  pkgName=($(echo "$result" | jq -r ".[].package"))
  
  pkgNames=$(sed 's/ /", "/g; s/^/"/; s/$/"/' <<< "${pkgName[@]}")
  RESPONSE_JSON=$(curl -sL --doh-url "$cloudflareDOH" $APKM_REST_API_URL -A "$USER_AGENT" -H 'Accept: application/json' -H 'Content-Type: application/json' -H "Authorization: Basic $AUTH_TOKEN" -d "{\"pnames\":[$pkgNames]}")
  
  exists_pname=($(jq -r '.data[] | select(.exists == true) | .pname' <<< "$RESPONSE_JSON"))
  not_exists_pname=($(jq -r '.data[] | select(.exists == false) | .pname' <<< "$RESPONSE_JSON"))
  echo -e "$info total_apps: $total_apps\n$good found: ${#exists_pname[@]}\n$notice not-found: ${#not_exists_pname[@]}"
  
  declare -a appName appLink version
  for i in ${!exists_pname[@]}; do
    appName[i]="$(jq -r ".data[] | select(.pname == \"${exists_pname[i]}\") | .app.name" <<< "$RESPONSE_JSON")"
    version[i]="$(echo "$result" | jq -r ".[] | select(.package == \"${exists_pname[i]}\") | .version")"
    appLink[i]="https://apkmirror.com$(jq -r ".data[] | select(.pname == \"${exists_pname[i]}\") | .app.link" <<< "$RESPONSE_JSON")"
  done
  
  # Initialize empty JSON array
  apps_json="[]"
  for i in ${!exists_pname[@]}; do
    # Process each existing package
    pkgName="${exists_pname[i]}"
    appName="${appName[i]}"
    version="${version[i]}"
    appLink="${appLink[i]}"
    # Create new app object
    new_app=$(jq -n --arg pkg "$pkgName" --arg ver "$version" --arg name "$appName" --arg link "$appLink" '{package: $pkg, version: $ver, name: $name, link: $link}')
    # Add to main array
    apps_json=$(echo "$apps_json" | jq ". += [$new_app]")
  done
  # Save apps data to $apkdl/$org.json file
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