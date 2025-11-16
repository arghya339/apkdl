#!/bin/bash

searchGLAB() {
  while true; do read -r -p ">> Enter repoName: " repoName; [[ "$repoName" =~ ^[Qq] ]] && repoName=; break; [ -n "$repoName" ] && break || echo -e "$notice Please enter a valid repoName!"; done
  repoName=$(echo $repoName | sed 's/ /+/g')
  repoName=$(echo $repoName | sed 's|/|%2F|g')
  
  if [ -n "$repoName" ]; then
    page=1
    while true; do
      [ $page -eq 1 ] && searchUrl="https://gitlab.com/api/v4/projects?search=${repoName}&order_by=star_count&sort=desc" || searchUrl="https://gitlab.com/api/v4/projects?search=${repoName}&page=$page&order_by=star_count&sort=desc"
      searchJSON=$(curl -sL ${glabAuth} "$searchUrl")
    
      if [ $(jq 'length' <<< "$searchJSON") -eq 0 ]; then
        echo -e "$notice No repositories found!"
        return 1
      fi

      declare -a descriptions paths created_at topics web_urls forks_counts star_counts last_activity_at
      index=0
      while IFS= read -r line; do
        descriptions[index]=$(echo "$line" | jq -r '.description // "No description"')
        paths[index]=$(echo "$line" | jq -r '.path')
        path_with_namespaces[index]=$(echo "$line" | jq -r '.path_with_namespace')
        created_at[index]=$(echo "$line" | jq -r '.created_at')
        topics[index]=$(echo "$line" | jq -r '.topics | join(", ") // "None"')
        web_urls[index]=$(echo "$line" | jq -r '.web_url')
        forks_counts[index]=$(echo "$line" | jq -r '.forks_count')
        star_counts[index]=$(echo "$line" | jq -r '.star_count')
        last_activity_at[index]=$(echo "$line" | jq -r '.last_activity_at')
        namespace_paths[index]=$(echo "$line" | jq -r '.namespace.path')
        ((index++))
      done < <(echo "$searchJSON" | jq -c '.[]')
    
      availableRepo=()
      for ((i=0; i<index; i++)); do
        availableRepo+=("${path_with_namespaces[$i]} - ${descriptions[$i]}")
      done
      [ $page -ne 1 ] && availableRepo+=(Previous)
      availableRepo+=(Next)
      buttons=("<Select>" "<Back>")
      if menu "availableRepo" "buttons" "10"; then
        selected=$selected;
        if [ $page -ne 1 ] && [ $selected -eq $((${#availableRepo[@]}-2)) ]; then
          ((page--))
          continue
        elif [ $selected -eq $((${#availableRepo[@]}-1)) ]; then
          ((page++))
          continue
        else
          owner="${namespace_paths[selected]}"
          repo="${paths[selected]}"
          echo -e "$info Owner: $owner"
          echo -e "$info Repo: $repo"
          echo -e "$info path_with_namespaces: ${path_with_namespaces[selected]}"
          echo -e "$info Description: ${descriptions[selected]}"
          echo -e "$info Created: ${created_at[selected]}"
          echo -e "$info Topics: ${topics[selected]}"
          echo -e "$info Stars: ${star_counts[selected]}"
          echo -e "$info Forks: ${forks_counts[selected]}"
          echo -e "$info Last Activity: ${last_activity_at[selected]}"
          echo -e "$info URL: ${Blue}${web_urls[selected]}${Reset}"
          break
          return 0
        fi
      else
        break
        return 1
      fi
    done
  else
    return 1
  fi
}

glabReleases() {
  page=1
  while true; do
    [ $page -eq 1 ] && releasesUrl="https://gitlab.com/api/v4/projects/${owner}%2F${repo}/releases" || releasesUrl="https://gitlab.com/api/v4/projects/${owner}%2F${repo}/releases?page=$page"
    releasesJSON=$(curl -sL ${glabAuth} "$releasesUrl")
    
    if [ "$releasesJSON" = "[]" ]; then
      echo -e "$notice No releases found!"
      return 1
    fi
    
    release_names=() release_tag_names=() release_created_ats=() release_released_ats=() release_descriptions=() release_author_names=() release_assets_list=()
    releaseCount=$(jq -r 'length' <<< "$releasesJSON")
    
    if [ $releaseCount -eq 0 ]; then
      echo -e "$notice No releases found on page $page!"
      [ $page -eq 1 ] && return 1 || { ((page--)); continue; }
    fi
    
    for ((i=0; i<releaseCount; i++)); do
      release_names[$i]=$(echo "$releasesJSON" | jq -r ".[$i].name")
      release_tag_names[$i]=$(echo "$releasesJSON" | jq -r ".[$i].tag_name")
      release_created_ats[$i]=$(echo "$releasesJSON" | jq -r ".[$i].created_at")
      release_released_ats[$i]=$(echo "$releasesJSON" | jq -r ".[$i].released_at")
      release_descriptions[$i]=$(echo "$releasesJSON" | jq -r ".[$i].description // \"No description\"")
      release_author_names[$i]=$(echo "$releasesJSON" | jq -r ".[$i].author.name // \"Unknown\"")
      release_assets_list[$i]=$(echo "$releasesJSON" | jq -r ".[$i].assets | tostring")
    done
    
    releases=()
    for i in "${!release_names[@]}"; do
      releases+=("${release_names[$i]} - ${release_released_ats[$i]}")
    done
    [ $page -ne 1 ] && releases+=(Previous)
    releases+=(Next)
    
    buttons=("<Select>" "<Back>")
    if menu "releases" "buttons" "10"; then
      if [ $page -ne 1 ] && [ $selected -eq $((${#releases[@]}-2)) ]; then
        ((page--))
        continue
      elif [ $selected -eq $((${#releases[@]}-1)) ]; then
        ((page++))
        continue
      else
        echo -e "\n${good} Selected Release: ${release_names[$selected]}"
        echo -e "${info} Tag Name: ${release_tag_names[$selected]}"
        echo -e "${info} Created: ${release_created_ats[$selected]}"
        echo -e "${info} Released: ${release_released_ats[$selected]}"
        echo -e "${info} Author: ${release_author_names[$selected]}"
        echo -e "${info} Description: ${release_descriptions[$selected]}"
        
        assetsJSON="${release_assets_list[$selected]}"
        assetCount=$(jq -r '.links | length' <<< "$assetsJSON")
        
        asset_names=() asset_urls=() asset_types=() asset_direct_urls=()
        
        if [ $assetCount -gt 0 ]; then
          for ((i=0; i<assetCount; i++)); do
            asset_names[$i]=$(echo "$assetsJSON" | jq -r ".links[$i].name")
            asset_urls[$i]=$(echo "$assetsJSON" | jq -r ".links[$i].url")
            asset_types[$i]=$(echo "$assetsJSON" | jq -r ".links[$i].link_type // \"other\"")
            asset_direct_urls[$i]=$(echo "$assetsJSON" | jq -r ".links[$i].direct_asset_url")
          done
          
          assets=()
          for ((i=0; i<assetCount; i++)); do
            asset=$(basename "${asset_urls[$i]}")
            format="${asset##*.}"
            assets+=("${asset_names[$i]} - $format")
          done
          
          if [ ${#assets[@]} -gt 1 ]; then
            buttons=("<Select>" "<Back>")
            if menu "assets" "buttons" "10"; then
              selected=$selected
            else
              selected=
            fi
          else
            selected=0
          fi
          
          if [[ "$selected" =~ ^[0-9]+$ ]]; then
            asset_name=${asset_names[$selected]}
            dlUrl=${asset_urls[$selected]}
            asset_type=${asset_types[$selected]}
            asset_direct_url=${asset_direct_urls[$selected]}
            echo -e "$info Asset Name: $asset_name"
            echo -e "$info Asset Type: $asset_type"
            echo -e "$info Asset URL: ${Blue}$dlUrl${Reset}"
            echo -e "$info Direct Asset URL: ${Blue}$asset_direct_url${Reset}"
            return 0
          else
            echo -e "$notice No asset selected!"
            return 1
          fi
        else
          echo -e "$notice No assets available for ${release_tag_names[$selected]} release!"
          return 1
        fi
      fi
    else
      return 1
    fi
  done
}

dlGLAB() {
  while true; do
    if [ $isAndroid -eq 1 ]; then
      aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$fileName" -d "$Download" "$dlUrl"
      aria2c_exit_status=$?
    elif [ $isMacOS -eq 1 ]; then
      aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$fileName" -d "$Download" --ca-certificate="/etc/ssl/cert.pem" "$dlUrl"
      aria2c_exit_status=$?
    fi
    [ $aria2c_exit_status -eq 0 ] && { echo; break; } || sleep 5
  done
}
################################################################