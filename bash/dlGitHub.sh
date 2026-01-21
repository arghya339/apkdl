#!/bin/bash

searchGH() {
  while true; do read -r -p ">> Enter repoName: " repoName; [[ "$repoName" =~ ^[Qq] ]] && repoName=; break; [ -n "$repoName" ] && break || echo -e "$notice Please enter a valid repoName!"; done
  repoName=$(echo $repoName  | sed 's/ /%20/g')
  
  if [ -n "$repoName" ]; then
    page=1
    while true; do
      [ $page -eq 1 ] && searchUrl="https://api.github.com/search/repositories?q=$repoName" || searchUrl="https://api.github.com/search/repositories?q=$repoName&page=$page"
      searchJSON=$(curl -sL ${ghAuth} "$searchUrl" | jq -r '.items[] | [.full_name, .description // "No description", .html_url, .downloads_url, (.releases_url | sub("{\\/id}"; "")), .created_at, .updated_at, .homepage // "No homepage", .stargazers_count, .language // "Not specified", .forks_count, .license?.name // "No license", (.topics | join(", ") // "No topics")] | @tsv')
      full_names=() descriptions=() html_urls=() downloads_urls=() releases_urls=() created_ats=() updated_ats=() homepages=() stargazers_indexs=() languages=() forks_indexs=() licenses=() topics_list=()
      index=0
      while IFS=$'\t' read -r full_name description html_url downloads_url releases_url created_at updated_at homepage stargazers_index language forks_index license topics; do
        full_names[$index]="$full_name"
        descriptions[$index]="$description"
        html_urls[$index]="$html_url"
        downloads_urls[$index]="$downloads_url"
        releases_urls[$index]="$releases_url"
        created_ats[$index]="$created_at"
        updated_ats[$index]="$updated_at"
        homepages[$index]="$homepage"
        stargazers_indexs[$index]="$stargazers_index"
        languages[$index]="$language"
        forks_indexs[$index]="$forks_index"
        licenses[$index]="$license"
        topics_list[$index]="$topics"
        ((index++))
      done <<< "$searchJSON"

      echo -e "$info Found $index repositories:"
      availableRepo=()
      for ((i=0; i<index; i++)); do
        availableRepo+=("${full_names[$i]} - ${descriptions[$i]}")
      done
      availableRepo+=("Search by users")
      [ $page -ne 1 ] && availableRepo+=(Previous)
      availableRepo+=(Next)
      buttons=("<Select>" "<Back>")
      if menu availableRepo buttons; then
        selected=$selected;
        if { [ $page -eq 1 ] && [ $selected -eq $((${#availableRepo[@]}-2)) ]; } || { [ $page -ne 1 ] && [ $selected -eq $((${#availableRepo[@]}-3)) ]; }; then
          read -r -p ">> Enter users name: " users
          if [ -n "$users" ]; then
            curl -fsL ${ghAuth} "https://api.github.com/users/${users}" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
              releasesUrl="$(curl -fsL "https://api.github.com/repos/${users}/${repoName}" | jq -r '.releases_url | sub("{\\/id}"; "")')"
              if [ -n "$releasesUrl" ]; then
                echo -e "$info Releases URL: ${Blue}$releasesUrl${Reset}"
                return
                break
              else
                read -r -p ">> Enter repos name: " repos
                if [ -n "$repos" ]; then
                  releasesUrl="$(curl -fsL "https://api.github.com/repos/${users}/${repos}" | jq -r '.releases_url | sub("{\\/id}"; "")')"
                  if [ -n "$releasesUrl" ]; then
                    echo -e "$info Releases URL: ${Blue}$releasesUrl${Reset}"
                    return
                    break
                  else
                    releasesUrl=""
                  fi
                fi
              fi
            fi
          fi
          continue
        elif [ $page -ne 1 ] && [ $selected -eq $((${#availableRepo[@]}-2)) ]; then
          ((page--))
          continue
        elif [ $selected -eq $((${#availableRepo[@]}-1)) ]; then
          ((page++))
          continue
        else
          releasesUrl="${releases_urls[$selected]}"
          echo -e "$info Repository Details for ${full_names[$selected]}:"
          echo -e "$info Description: ${descriptions[$selected]}"
          echo -e "$info URL: ${Blue}${html_urls[$selected]}${Reset}"
          echo -e "$info Releases URL: ${Blue}$releasesUrl${Reset}"
          echo -e "$info Created: ${created_ats[$selected]}"
          echo -e "$info Updated: ${updated_ats[$selected]}"
          echo -e "$info Homepage: ${Blue}${homepages[$selected]}${Reset}"
          echo -e "$info Stars: ${stargazers_indexs[$selected]}"
          echo -e "$info Forks: ${forks_indexs[$selected]}"
          echo -e "$info Language: ${languages[$selected]}"
          echo -e "$info License: ${licenses[$selected]}"
          echo -e "$info Topics: ${topics_list[$selected]}"
          return
          break
        fi
      else
        return 1
        break
      fi
    done
  else
    return 1
  fi
}

Latest() {
  response=$(curl -sL ${ghAuth} $releasesUrl/latest)
  
  html_url=$(echo "$response" | jq -r '.html_url')
  tag_name=$(echo "$response" | jq -r '.tag_name')
  name=$(echo "$response" | jq -r '.name')
  created_at=$(echo "$response" | jq -r '.created_at')
  updated_at=$(echo "$response" | jq -r '.updated_at')
  published_at=$(echo "$response" | jq -r '.published_at')
  release_info=("url: $html_url" "tag: $tag_name" "name: $name" "created: $created_at" "updated: $updated_at" "published: $published_at")  # Create release info array
  echo "release info: "
  for i in "${!release_info[@]}"; do
    echo "${release_info[i]}"
  done
  
  asset_names=($(echo "$response" | jq -r '.assets[] | .name'))
  asset_sizes=($(echo "$response" | jq -r '.assets[] | .size'))
  asset_digests=($(echo "$response" | jq -r '.assets[] | .digest'))
  asset_download_counts=($(echo "$response" | jq -r '.assets[] | .download_count'))
  asset_created_ats=($(echo "$response" | jq -r '.assets[] | .created_at'))
  asset_updated_ats=($(echo "$response" | jq -r '.assets[] | .updated_at'))
  asset_browser_download_urls=($(echo "$response" | jq -r '.assets[] | .browser_download_url'))
  
  for i in "${!asset_names[@]}"; do
    assets+=("name: ${asset_names[$i]} | size: ${asset_sizes[$i]} bytes | download: ${asset_download_counts[$i]} | created: ${asset_created_ats[$i]} | updated: ${asset_updated_ats[$i]}")
  done
  buttons=("<Select>" "<Back>")
    if menu assets buttons; then
      asset_name=${asset_names[$selected]}
      asset_size=${asset_sizes[$selected]}
      asset_digest=${asset_digests[$selected]}
      asset_download_count=${asset_download_counts[$selected]}
      asset_created_at=${asset_created_ats[$selected]}
      asset_updated_at=${asset_updated_ats[$selected]}
      asset_browser_download_url=${asset_browser_download_urls[$selected]}
      echo -e "$info asset_name: $asset_name"
      echo -e "$info asset_browser_download_url: ${Blue}$asset_browser_download_url${Reset}"
      return
    else
      return 1
    fi
}

Releases() {
  page=1
  while true; do
    [ $page -eq 1 ] && response=$(curl -sL ${ghAuth} $releasesUrl) || response=$(curl -sL ${ghAuth} $releasesUrl?page=$page)

    release_names=() release_html_urls=() release_tag_names=() release_created_ats=() release_updated_ats=() release_published_ats=() release_assets_list=()

    releaseCount=$(echo "$response" | jq -r 'length')
  
    for ((i=0; i<releaseCount; i++)); do
      release_names[$i]=$(echo "$response" | jq -r ".[$i].name")
      release_html_urls[$i]=$(echo "$response" | jq -r ".[$i].html_url")
      release_tag_names[$i]=$(echo "$response" | jq -r ".[$i].tag_name")
      release_created_ats[$i]=$(echo "$response" | jq -r ".[$i].created_at")
      release_updated_ats[$i]=$(echo "$response" | jq -r ".[$i].updated_at")
      release_published_ats[$i]=$(echo "$response" | jq -r ".[$i].published_at")
      release_assets_list[$i]=$(echo "$response" | jq -r ".[$i].assets")
    done
  
    releases=()
    for i in "${!release_names[@]}"; do
      releases+=("name: ${release_names[$i]} | published: ${release_published_ats[$i]} | updated: ${release_updated_ats[$i]}")
    done
    [ $page -ne 1 ] && releases+=(Previous)
    releases+=(Next)

    buttons=("<Select>" "<Back>")
    if menu releases buttons; then
      if [ $page -ne 1 ] && [ $selected -eq $((${#releases[@]}-2)) ]; then
        ((page--))
        continue
      elif [ $selected -eq $((${#releases[@]}-1)) ]; then
        ((page++))
        continue
      else
        echo -e "\n${info} Selected Release: ${release_names[$selected]}"
        echo -e "${info} HTML URL: ${Blue}${release_html_urls[$selected]}${Reset}"
        echo -e "${info} Tag Name: ${release_tag_names[$selected]}"
        echo -e "${info} Created: ${release_created_ats[$selected]}"
        echo -e "${info} Updated: ${release_updated_ats[$selected]}"
        echo -e "${info} Published: ${release_published_ats[$selected]}"
    
        assetsJSON="${release_assets_list[$selected]}"
        assetCount=$(echo "$assetsJSON" | jq -r 'length')
    
        asset_names=() asset_sizes=() asset_digests=() asset_download_counts=() asset_created_ats=() asset_updated_ats=() asset_browser_download_urls=()

        for ((i=0; i<assetCount; i++)); do
          asset_names[$i]=$(echo "$assetsJSON" | jq -r ".[$i].name")
          asset_sizes[$i]=$(echo "$assetsJSON" | jq -r ".[$i].size")
          asset_digests[$i]=$(echo "$assetsJSON" | jq -r ".[$i].digest")
          asset_download_counts[$i]=$(echo "$assetsJSON" | jq -r ".[$i].download_count")
          asset_created_ats[$i]=$(echo "$assetsJSON" | jq -r ".[$i].created_at")
          asset_updated_ats[$i]=$(echo "$assetsJSON" | jq -r ".[$i].updated_at")
          asset_browser_download_urls[$i]=$(echo "$assetsJSON" | jq -r ".[$i].browser_download_url")
        done

        assets=()
        for ((i=0; i<assetCount; i++)); do
          assets+=("name: ${asset_names[$i]} | size: ${asset_sizes[$i]} bytes | download: ${asset_download_counts[$i]} | created: ${asset_created_ats[$i]} | updated: ${asset_updated_ats[$i]}")
        done

        if [ ${#assets[@]} -gt 1 ]; then
          buttons=("<Select>" "<Back>")
          if menu assets buttons; then
            selected=$selected
          else
            selected=
          fi
        else
          selected=0
        fi
        if [[ "$selected" =~ ^[0-9]+$ ]]; then
          asset_name=${asset_names[$selected]}
          asset_size=${asset_sizes[$selected]}
          asset_digest=${asset_digests[$selected]}
          asset_download_count=${asset_download_counts[$selected]}
          asset_created_at=${asset_created_ats[$selected]}
          asset_updated_at=${asset_updated_ats[$selected]}
          asset_browser_download_url=${asset_browser_download_urls[$selected]}
          echo -e "$info asset_name: $asset_name"
          echo -e "$info asset_browser_download_url: ${Blue}$asset_browser_download_url${Reset}"
          return
        else
          return 1
        fi
      fi
    else
      return 1
    fi
  done
}

ghActions() {
  workflowsJson=$(curl -sL $(dirname "$releasesUrl")/actions/workflows)
  workflowsCount=$(jq -r '.total_count' <<< "$workflowsJson")
  mapfile -t workflowsNames < <(jq -r '.workflows.[].name' <<< "$workflowsJson")
  workflowsStates=($(jq -r '.workflows.[].state' <<< "$workflowsJson"))
  updated_ats=($(jq -r '.workflows.[].updated_at' <<< "$workflowsJson"))
  workflows_urls=($(jq -r '.workflows.[].url' <<< "$workflowsJson"))
  declare -a workflowsList
  for ((i=0; i<${workflowsCount}; i++)); do
    workflowsList+=("${workflowsNames[i]} | ${workflowsStates[i]} | ${updated_ats[i]}")
  done
  buttons=("<Select>" "<Back>")
  if menu workflowsList buttons; then
    workflowsName=${workflowsNames[selected]}
    workflows_url=${workflows_urls[selected]}
    echo -e "$info selected: $workflowsName"
    
    runsJson=$(curl -sL "$workflows_url/runs?page=1")
    runsCount=$(jq -r '.total_count' <<< "$runsJson")
    runs_ids=($(jq -r '.workflow_runs.[].id' <<< "$runsJson"))
    head_branchs=($(jq -r '.workflow_runs.[].head_branch' <<< "$runsJson"))
    mapfile -t display_titles < <(jq -r '.workflow_runs.[].display_title' <<< "$runsJson")
    run_numbers=($(jq -r '.workflow_runs.[].run_number' <<< "$runsJson"))
    status=($(jq -r '.workflow_runs.[].status' <<< "$runsJson"))
    conclusions=($(jq -r '.workflow_runs.[].conclusion' <<< "$runsJson"))
    runs_urls=($(jq -r '.workflow_runs.[].url' <<< "$runsJson"))
    mapfile -t actors < <(jq -r '.workflow_runs.[].actor.login' <<< "$runsJson")
    run_started_ats=($(jq -r '.workflow_runs.[].run_started_at' <<< "$runsJson"))
    runsList=()
    for ((i=0; i<${#runs_urls[@]}; i++)); do
      runsList+=("${display_titles[i]} | ${status[i]} | ${head_branchs[i]} | ${run_started_ats[i]} | ${conclusions[i]} | #${run_numbers[i]} | ${actors[i]}")
    done
    if menu runsList buttons; then
      runs_id=${runs_ids[selected]}
      display_title=${display_titles[selected]}
      runs_url=${runs_urls[selected]}
      echo -e "$info selected: $display_title"

      artifactsJson=$(curl -sL "$runs_url/artifacts")
      artifactsCount=$(jq -r '.total_count' <<< "$artifactsJson")
      artifacts_ids=($(jq -r '.artifacts.[].id' <<< "$artifactsJson"))
      names=($(jq -r '.artifacts.[].name' <<< "$artifactsJson"))
      sizes=($(jq -r '.artifacts.[].size_in_bytes' <<< "$artifactsJson"))
      archive_download_urls=($(jq -r '.artifacts.[].archive_download_url' <<< "$artifactsJson"))
      expired=($(jq -r '.artifacts.[].expired' <<< "$artifactsJson"))
      digests=($(jq -r '.artifacts.[].digest' <<< "$artifactsJson"))
      created_ats=($(jq -r '.artifacts.[].created_at' <<< "$artifactsJson"))
      expires_ats=($(jq -r '.artifacts.[].expires_at' <<< "$artifactsJson"))
      artifactsList=()
      for ((i=0; i<$artifactsCount; i++)); do
        artifactsList+=("${names[i]} | ${sizes[i]} | ${created_ats[i]} | expired: ${expired[i]} (${expires_ats[i]})")
      done
      if menu artifactsList buttons; then
        artifacts_id=${artifacts_ids[selected]}
        name=${names[selected]}
        size=${names[selected]}
        archive_download_url=${archive_download_urls[selected]}
        digest=${digests[selected]}
        echo -e "$info dlUrl: ${Blue}$archive_download_url${Reset}"
        browser_download_url="https://github.com/$owner/$repo/actions/runs/$runs_id/artifacts/$artifacts_ids"
        echo -e "$info browser_download_url: ${Blue}$browser_download_url${Reset}"
        fileName="$name.zip"
        if jq -e '.GH' "$apkdlJson" >/dev/null 2>&1; then
          asset_browser_download_url=$(curl -sL -I -H "Authorization: Bearer ${ghToken}" "$archive_download_url" | grep -i "location:" | head -1 | sed 's/location: //i' | tr -d '\r')
          return 0
        else
          [ $isAndroid -eq 1 ] && termux-open-url "$browser_download_url"
          [ $isMacOS -eq 1 ] && open "$browser_download_url"
          return 1
        fi
      else
        return 1
      fi
    else
      return 1
    fi
  else
    return 1
  fi
}

dlGH() {
  while true; do
    if [ $isAndroid -eq 1 ]; then
      aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$fileName" -d "$Download" "$asset_browser_download_url"
      aria2c_exit_status=$?
    elif [ $isMacOS -eq 1 ]; then
      aria2c -x 16 -s 16 --console-log-level=error --summary-interval=0 --download-result=hide -c -o "$fileName" -d "$Download" --ca-certificate="/etc/ssl/cert.pem" "$asset_browser_download_url"
      aria2c_exit_status=$?
    fi
    [ $aria2c_exit_status -eq 0 ] && { echo; break; } || sleep 5
  done
}
###########################################################################################################################################################