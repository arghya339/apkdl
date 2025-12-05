#!/bin/bash

codebergSearch() {
  codebergReposUrl="https://codeberg.org/api/v1/repos"
  while true; do read -r -p ">> Enter repoName: " repoName; [[ "$repoName" =~ ^[Qq] ]] && repoName=; break; [ -n "$repoName" ] && break || echo -e "$notice Please enter a valid repoName!"; done
  if [ -n "$repoName" ]; then
    repo_name=$(echo $repoName  | sed 's/ /%20/g')
    page=1
    items_per_page=30
    sort=stars  # sort search results by most stars
    order=desc  # order search results "descending" (highest to lowest)
    curl -fsL "https://codeberg.org/" >/dev/null 2>&1
    [ ${PIPESTATUS[0]} -ne 0 ] && { open "https://status.codeberg.org/status/codeberg"; return 1; break; }
    while true; do
      searchUrl="$codebergReposUrl/search?q=${repo_name}&page=${page}&limit=${items_per_page}&sort=${sort}&order=${order}"
      searchDataJson=$(curl -sL "$searchUrl" | jq -r '.data.[]')
      full_names=($(jq -r '.full_name' <<< "$searchDataJson"))
      mapfile -t descriptions < <(jq -r '.description' <<< "$searchDataJson")
      mapfile -t languages < <(jq -r '.language' <<< "$searchDataJson")
      websites=($(jq -r '.website' <<< "$searchDataJson"))
      stars_counts=($(jq -r '.stars_count' <<< "$searchDataJson"))
      forks_counts=($(jq -r '.forks_count' <<< "$searchDataJson"))
      created_ats=($(jq -r '.created_at' <<< "$searchDataJson"))
      updated_ats=($(jq -r '.updated_at' <<< "$searchDataJson"))
      has_releasess=($(jq -r '.has_releases' <<< "$searchDataJson"))
      mapfile -t topicss < <(jq -r '.topics.[]' <<< "$searchDataJson")
      availableRepo=()
      for ((i=0; i<${#full_names[@]}; i++)); do
        availableRepo+=("${full_names[i]} - ${descriptions[i]}")
      done
      [ $page -ne 1 ] && availableRepo+=(Previous)
      availableRepo+=(Next)
      buttons=("<Select>" "<Back>")
      if menu "availableRepo" "buttons" "10"; then
        if [ "${availableRepo[selected]}" == "Previous" ]; then
          ((page--))
        elif [ "${availableRepo[selected]}" == "Next" ]; then
          ((page++))
        else
          full_name="${full_names[selected]}"
          echo "selected: $full_name"
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

codebergLatestReleases() {
  codebergLatestReleasesUrl="$codebergReposUrl/${full_name}/releases/latest"
  latestReleasesJson=$(curl -sL "$codebergLatestReleasesUrl")
  assets_names=($(jq -r '.assets.[].name' <<< "$latestReleasesJson"))
  assets_sizes=($(jq -r '.assets.[].size' <<< "$latestReleasesJson"))
  download_counts=($(jq -r '.assets.[].download_count' <<< "$latestReleasesJson"))
  created_ats=($(jq -r '.assets.[].created_at' <<< "$latestReleasesJson"))
  browser_download_urls=($(jq -r '.assets.[].browser_download_url' <<< "$latestReleasesJson"))
  declare -a assets
  for ((i=0; i<${#assets_names[@]}; i++)); do
    assets+=("📦 ${assets_names[i]} | 💾 ${assets_sizes[i]} B | ${download_counts[i]}↓ | 📅 ${created_ats[i]}")
  done
  buttons=("<Select>" "<Back>")
  if menu assets buttons; then
    assets_name="${assets_names[selected]}"
    dlUrl="${browser_download_urls[selected]}"
    echo -e "dlUrl: ${Blue}$dlUrl${Reset}"
    fileName="$assets_name"
    filePath="$Download/$fileName"
    return
  else
    return 1
  fi
}

#full_name="forgejo/forgejo"
#full_name="Freeyourgadget/Gadgetbridge"
codebergReleases() {
  codebergReleasesUrl="$codebergReposUrl/${full_name}/releases"
  page=1
  while true; do
    releasesJson=$(curl -sL "$codebergReleasesUrl?page=$page")
    releasesCount=$(jq -r 'length' <<< "$releasesJson")
    releases_names=(); changelogs=(); html_urls=(); created_ats=(); author_usernames=(); releases_assets=(); releases=()
    for ((i=0; i<releasesCount; i++)); do
      releases_names[i]="$(jq -r ".[$i].name" <<< "$releasesJson")"
      changelogs[i]="$(jq -r ".[$i].body" <<< "$releasesJson")"
      html_urls+=($(jq -r ".[$i].html_url" <<< "$releasesJson"))
      created_ats+=($(jq -r ".[$i].created_at" <<< "$releasesJson"))
      author_usernames+=($(jq -r ".[$i].author.username" <<< "$releasesJson"))
      releases_assets[i]="$(jq -r ".[$i].assets" <<< "$releasesJson")"
      releases+=("${releases_names[i]} | ${created_ats[i]} | ${author_usernames[i]}")
    done
    [ $page -ne 1 ] && releases+=(Previous)
    releases+=(Next)
    buttons=("<Select>" "<Back>")
    if menu releases buttons; then
      if [ "${releases[selected]}" == "Previous" ]; then
        ((page--))
      elif [ "${releases[selected]}" == "Next" ]; then
        ((page++))
      else
        selected_assets="${releases_assets[selected]}"
        assetsCount=$(jq -r 'length' <<< "$selected_assets")
        declare -a assets_names assets_sizes download_counts created_ats browser_download_urls
        for ((i=0; i<${assetsCount}; i++)); do
          assets_names+=($(jq -r ".[$i].name" <<< "$selected_assets"))
          assets_sizes+=($(jq -r ".[$i].size" <<< "$selected_assets"))
          download_counts+=($(jq -r ".[$i].download_count" <<< "$selected_assets"))
          created_ats+=($(jq -r ".[$i].created_at" <<< "$selected_assets"))
          browser_download_urls+=($(jq -r ".[$i].browser_download_url" <<< "$selected_assets"))
        done
        declare -a assets
        for ((i=0; i<${#assets_names[@]}; i++)); do
          assets+=("📦 ${assets_names[i]} | 💾 ${assets_sizes[i]} B | ${download_counts[i]}↓ | 📅 ${created_ats[i]}")
        done
        buttons=("<Select>" "<Back>")
        if menu assets buttons; then
          assets_name="${assets_names[selected]}"
          dlUrl="${browser_download_urls[selected]}"
          echo -e "dlUrl: ${Blue}$dlUrl${Reset}"
          fileName="$assets_name"
          filePath="$Download/$fileName"
          return
          break
        else
          return 1
          break
        fi
      fi
    else
      return 1
      break
    fi
  done
}

iodPackagesIndex() {
  #$baseUrl/fdroid/index/apk/$pkg
  packagesJson=$(curl -sL "$baseUrl/fdroid/api/v1/packages/$pkg")
  mapfile -t versionNames < <(jq -r '.packages[].versionName' <<< "$packagesJson")
  mapfile -t versionCodes < <(jq -r '.packages[].versionCode' <<< "$packagesJson")
  declare -a versionsList
  for ((i=0; i<${#versionNames[@]}; i++)); do
    versionsList+=("${versionNames[i]} (${versionCodes[i]})")
  done
  buttons=("<Select>" "<Back>")
  if menu versionsList buttons; then
    versionName="${versionNames[selected]}"
    versionCode="${versionCodes[selected]}"
    dlUrl="$baseUrl/fdroid/repo/${pkg}_$versionCode.apk"
    fileName="${appName}_v$versionName-$versionCode.apk"
    filePath="$Download/$fileName"
    echo -e "dlUrl: ${Blue}$dlUrl${Reset}\nfileName: $fileName"
    return
  else
    return 1
  fi
}

IzzyOnDroidSearch() {
  baseUrl="https://apt.izzysoft.de"
  buttons=("<IzzyOnDroid>" "<F-Droid Archive>"); confirmPrompt "Select repo:" "buttons" && repo=iod || repo=archive
  while true; do read -r -p ">> Enter appName: " appName; [[ "$appName" =~ ^[Qq] ]] && appName=; break; [ -n "$appName" ] && break || echo -e "$notice Please enter a valid appName!"; done
  if [ -n "$appName" ]; then
    app_name=$(echo "$appName" | sed 's/ /+/g')
    page=1
    appsPerPage=10  # possible value: 10 / 25 / 50 / 100
    while true; do
      searchUrl="$baseUrl/fdroid/index.php/list/page/$page?repo=$repo;searchterm=$app_name;doFilter=1;limit=$appsPerPage"
      izzysoftHTML=$(curl -sL "$searchUrl")
      approwJson=$(pup 'div.approw json{}' <<< "$izzysoftHTML")
      mapfile -t appNames < <(jq -r '.. | select(.class? == "boldname") | .text' <<< "$approwJson")  # appName
      mapfile -t versionAddeds < <(jq -r '.. | select(.class? == "minor-details") | .text | select(test(" / [0-9]{4}-[0-9]{2}-[0-9]{2}"))' <<< "$approwJson")  # versionName / addedOn
      mapfile -t versionNames < <(jq -r '.. | select(.class? == "minor-details") | .text | select(test(" / [0-9]{4}")) | split(" / ")[0]' <<< "$approwJson")  # versionName
      mapfile -t addedOns < <(jq -r '.. | select(.class? == "minor-details") | .text | select(test(" / [0-9]{4}")) | split(" / ")[1]' <<< "$approwJson")  # addedOn
      mapfile -t Licenses < <(jq -r '.. | select(.class? == "minor-details") | .text | select(test(" / [0-9]{4}") | not)' <<< "$approwJson")  # License
      mapfile -t Descriptions < <(jq -r '.. | select(.class? == "appdetailcell" and .text?) | .text' <<< "$approwJson")  # appDescription
      mapfile -t detailsUrls < <(jq -r '.. | select(.text? == "Details") | .href' <<< "$approwJson")  # Details Url
      mapfile -t downloadUrls < <(jq -r '.. | select(.text? == "Download") | .href' <<< "$approwJson")  # Download Url
      mapfile -t webUrls < <(jq -r '.. | select(.text? == "Web") | .href' <<< "$approwJson")  # Web Url
      mapfile -t sourceUrls < <(jq -r '.. | select(.text? == "Source") | .href' <<< "$approwJson")  # SourceCode Url
      mapfile -t trackerUrls < <(jq -r '.. | select(.text? == "Tracker") | .href' <<< "$approwJson")  # issueTracker Url
      mapfile -t changelogUrls < <(jq -r '.. | select(.text? == "Changelog") | .href' <<< "$approwJson")  # Changelog Url
      appsList=()
      for ((i=0; i<${#appNames[@]}; i++)); do
        appsList+=("${appNames[i]} | ${Descriptions[i]} | ${versionAddeds[i]}")
      done
      pagerrowJson=$(pup 'div.pagerrow json{}' <<< "$izzysoftHTML" | jq -r '.[].children.[].children.[]')
      firstUrl=$(jq 'select(.children?[0].alt? == "|«") | .href' <<< "$pagerrowJson")  # firstPageUrl
      leftUrl=$(jq 'select(.children?[0].alt? == "«") | .href' <<< "$pagerrowJson")  # prevPageUrl
      rightUrl=$(jq 'select(.children?[0].alt? == "»") | .href' <<< "$pagerrowJson")  # nextPageUrl
      lastUrl=$(jq 'select(.children?[0].alt? == "»|") | .href' <<< "$pagerrowJson")  # lastPageUrl
      [ -n "$firstUrl" ] && appsList+=(First)
      [ -n "$leftUrl" ] && appsList+=(Prev)
      [ -n "$rightUrl" ] && appsList+=(Next)
      [ -n "$lastUrl" ] && appsList+=(Last)
      buttons=("<Select>" "<Back>")
      if menu appsList buttons; then
        if [ "${appsList[selected]}" == "First" ]; then
          page=1
        elif [ "${appsList[selected]}" == "Prev" ]; then
          ((page--))
        elif [ "${appsList[selected]}" == "Next" ]; then
          ((page++))
        elif [ "${appsList[selected]}" == "Last" ]; then
          page=$(awk -F'/page/|\\?' '{print $2}' <<< "$lastUrl")
        else
          downloadUrl="${downloadUrls[selected]}"
          [ "$repo" == "iod" ] && dlUrl="$baseUrl/fdroid/$downloadUrl" || dlUrl="$downloadUrl"
          pkg=$(basename "$dlUrl" | cut -d'_' -f1)
          appName="${appNames[selected]}"
          versionName="${versionNames[selected]}"
          versionCode="${versionCodes[selected]}"
          [ -z "$versionCode" ] && { versionCode="${downloadUrl##*_}"; versionCode="${versionCode%.apk}"; } 
          sourceUrl=${sourceUrls[selected]}
          if [ "$repo" == "iod" ]; then
            echo -e "sourceUrl: $sourceUrl\npkgName: $pkg"
            iodPackagesIndex
          else
            echo -e "dlUrl: ${Blue}$dlUrl${Reset}\nsourceUrl: $sourceUrl\npkgName: $pkg"
            fileName="${appName}_v$versionName-$versionCode.apk"
            filePath="$Download/$fileName"
            echo "fileName: $fileName"
          fi
          return
          break
        fi
      else
        return 1
      fi
    done
  else
    return 1
  fi
}

dlAppGallery() {
  [ $isAndroid -eq 1 ] && termux-open-url "https://appgallery.huawei.com"
  [ $isMacOS -eq 1 ] && open "https://appgallery.huawei.com"
  while true; do read -r -p ">> Enter appId: " appId; [[ "$appId" =~ ^[Qq] ]] && appId=; break; [ -n "$appId" ] && break || echo -e "$notice Please enter a valid appId!"; done
  if [ -n "$appId" ]; then
    dlUrl=$(curl -sL --doh-url "$cloudflareDOH" -D - -o /dev/null "https://appgallery.cloud.huawei.com/appdl/$appId" | grep -i "location:" | head -1 | sed 's/location: //i' | tr -d '\r')  # make GET request but only show response headers
    echo -e "$info dlUrl: ${Blue}$dlUrl${Reset}"
    fileName=$(echo "$dlUrl" | sed 's/.*\///; s/\?.*//')  # extract everything between last / and ?
    filePath="$Download/$fileName"
    [ -n "$dlUrl" ] && return 0 || return 1
  else
    return 1
  fi
}

sf() {
  sfDomain="https://sourceforge.net"
  while true; do read -r -p ">> Enter projectName: " projectName; [[ "$projectName" =~ ^[Qq] ]] && projectName=; break; [ -n "$projectName" ] && break || echo -e "$notice Please enter a valid projectName!"; done
  if [ -n "$projectName" ]; then
    #$sfDomain/projects/$projectName/rss?path=/
    baseUrl="$sfDomain/projects"
    filesUrl="$baseUrl/$projectName/files"
    while true; do
      curl -fsL "$filesUrl" >/dev/null 2>&1 || { [ $isAndroid -eq 1 ] && termux-open-url "$filesUrl"; [ $isMacOS -eq 1 ] && open "$filesUrl"; return 1; break; }
      filesHtml=$(curl -sL "$filesUrl")
      filesJson=$(pup '#files_list tbody tr[class^="folder"], #files_list tbody tr[class^="file"] json{}' <<< "$filesHtml")

      filesTitle=($(jq -r '.[].title' <<< "$filesJson"))
      filesUrls=($(jq -r '.[].children[0].children[0].href' <<< "$filesJson"))
      fileTypes=($(jq -r '.[].class' <<< "$filesJson"))
      mapfile -t modifiedTime < <(jq -r '.[].children[1].children[0].title' <<< "$filesJson")
      downloadsCount=($(jq -r '.[] | .children[3].children[1].children[0].children[0].text? // .children[3].children[1].children[0].text? // "0"' <<< "$filesJson"))
      parentFolder=$(pup '#parent_folder a attr{href}' <<< "$filesHtml")
      
      [ -n "$parentFolder" ] && items=("Parent folder") || items=()
      for ((i=0; i<${#filesTitle[@]}; i++)); do
        items+=("${filesTitle[i]} | ${fileTypes[i]} | ${modifiedTime[i]} | ${downloadsCount[i]}")
      done

      buttons=("<Select>" "<Back>")
      if menu items buttons; then
        if [ "${items[selected]}" == "Parent folder" ]; then
          filesUrl="$(dirname "$filesUrl")/"
          echo -e "parentFolderUrl: ${Blue}$filesUrl${Reset}"
          continue
        else
          [ -n "$parentFolder" ] && selected=$((selected-1))
          fileTitle="${filesTitle[selected]}"
          fileType="${fileTypes[selected]}"
          filesUrl="${filesUrls[selected]}"
          if [ "$fileType" == "file" ]; then
            fileSize=$(jq --arg filename "$fileTitle" -r '.[] | select(.title == $filename) | .children[2].text' <<< "$filesJson")
            dlUrl=$(curl -sL -I "$filesUrl" | grep -i "location:" | tail -1 | sed 's/location: //i' | tr -d '\r')
            fileName="$fileTitle"
            filePath="$Download/$fileName"
            echo -e "fileSize: $fileSize\ndlUrl: ${Blue}$dlUrl${Reset}\nfileName: $fileName"
            return
            break
          else
            filesUrl="$sfDomain/$filesUrl"
            echo -e "folderUrl: ${Blue}$filesUrl${Reset}"
            continue
          fi
        fi
      else
        return 1
      fi
    done
  else
    return 1
  fi
}

APKComboVariants() {
  variantsJson=$(curl -sL --doh-url "$cloudflareDOH" "$versionUrl" | pup '#variants-tab json{}') #> variants.json
  mapfile -t versionNames < <(jq -r '.[] | .. | select(.class? == "vername") | .text' <<< "$variantsJson")
  mapfile -t versionNamesN < <(jq -r '.[] | .. | select(.class? == "vername") | .text | match("[0-9.]+")?.string' <<< "$variantsJson")
  mapfile -t versionCodes < <(jq -r '.[] | .. | select(.class? == "vercode") | .text | gsub("[()]"; "")' <<< "$variantsJson")
  archs=($(jq -r '.[] | .children[]? | select(.class == "tree") | ((.. | objects | select(.tag? == "code") | .text) as $arch | .. | objects | select(.class == "file-list") | .children[] | $arch)' <<< "$variantsJson"))
  mapfile -t minsdks < <(jq -r '.. | select(.text? | strings | test("Android")) | .text' <<< "$variantsJson")
  mapfile -t dpis < <(jq -r '.. | select(.text? | strings | test("dpi")) | .text' <<< "$variantsJson")
  vtypes=($(jq -r '.. | select(.class? == "vtype") | .children[0].text' <<< "$variantsJson"))
  mapfile -t ltrs < <(jq -r '.. | select(.class? == "spec ltr") | .text' <<< "$variantsJson")
  dlUrls=($(jq --arg domain "$baseUrl" -r '.. | select(.tag? == "a" and .class? == "variant") | $domain + .href' <<< "$variantsJson"))
  declare -a variantsList
  for ((i=0; i<${#versionNames[@]}; i++)); do
    variantsList+=("${versionNamesN[i]} (${versionCodes[i]}) | ${minsdks[i]} | ${archs[i]} | ${dpis[i]} | ${vtypes[i]} | ${ltrs[i]}")
  done
  buttons=("<Select>" "<Back>")
  if menu variantsList buttons; then
    versionNameN="${versionNamesN[selected]}"
    arch="${archs[selected]}"
    dlUrl="${dlUrls[selected]}"
    echo -e "dlUrl: ${Blue}$dlUrl${Reset}"
    fileName="${appName}_v$versionNameN-$arch.apk"
    filePath="$Download/$fileName"
    return
  else
    return 1
  fi
}

APKComboVersions() {
  oldVersionsUrl="${appUrl}old-versions/"
  versionsJson=$(curl -sL --doh-url "$cloudflareDOH" "$oldVersionsUrl" | pup 'ul.list-versions li json{}') #> versions.json
  mapfile -t versions < <(jq -r '.[].children[0].children[1].children[0].children[0].text' <<< "$versionsJson")
  mapfile -t versionsN < <(jq -r '.[].children[0].children[1].children[0].children[0].text | match("[0-9.]+")?.string' <<< "$versionsJson")
  fileTypes=($(jq -r '.[].children[0].children[1].children[0].children[1].children[0].text' <<< "$versionsJson"))
  mapfile -t dates < <(jq -r '.[].children[0].children[1].children[1].text | split(" · ")[0]' <<< "$versionsJson")
  mapfile -t minAndroids < <(jq -r '.[].children[0].children[1].children[1].text | split(" · ")[1]' <<< "$versionsJson")
  versionsUrl=($(jq --arg domain "$baseUrl" -r '$domain + .[].children[0].href' <<< "$versionsJson"))
  declare -a versionsList
  for ((i=0; i<${#versions[@]}; i++)); do
    versionsList+=("${versionsN[i]} | ${minAndroids[i]} | ${fileTypes[i]} | ${dates[i]}")
  done
  buttons=("<Select>" "<Back>")
  if menu versionsList buttons; then
    versionUrl="${versionsUrl[selected]}"
    echo -e "versionUrl: ${Blue}$versionUrl${Reset}"
    APKComboVariants
    return
  else
    return 1
  fi
}

APKComboSearch() {
  baseUrl="https://apkcombo.com"
  while true; do read -r -p ">> Enter appName: " appName; [[ "$appName" =~ ^[Qq] ]] && appName=; break; [ -n "$appName" ] && break || echo -e "$notice Please enter a valid appName!"; done
  if [ -n "$appName" ]; then
    app_name=$(echo "$appName" | sed 's/ /-/g')
    #https://suggestv2.apkcombo.org/search?q=instagram
    searchUrl="$baseUrl/search/$app_name"
    searchJson=$(curl -sL --doh-url "$cloudflareDOH" "$searchUrl" | pup 'a.l_item json{}') #> search.json
    totalApps=$(jq 'length' <<< "$searchJson")
    mapfile -t appNames < <(jq -r '.[].children[1].children[0].text' <<< "$searchJson")  # appName
    mapfile -t developers < <(jq -r '.[].children[1].children[1].text | split("·")[0]' <<< "$searchJson")  # developer
    mapfile -t categorys < <(jq -r '.[].children[1].children[1].text | split("·")[1]' <<< "$searchJson")  # category
    mapfile -t dlCounts < <(jq -r '.[].children[1].children[2].children[0].text' <<< "$searchJson")  # dlCounts
    mapfile -t ratings < <(jq -r '.[].children[1].children[2].children[1].text' <<< "$searchJson")  # ratings
    mapfile -t dlSizes < <(jq -r '.[].children[1].children[2].children[2].text' <<< "$searchJson")  # dlSizes
    pkgs=($(jq -r '.[].href | split("/")[2]' <<< "$searchJson"))  # pkgname
    appUrls=($(jq --arg domain "$baseUrl" -r '$domain + .[].href' <<< "$searchJson"))  # appUrl
    declare -a appsList
    for ((i=0; i<${totalApps}; i++)); do
      appsList+=("${appNames[i]} | ${developers[i]} | ${dlCounts[i]} | ${ratings[i]} | ${dlSizes[i]}")
    done
    buttons=("<Select>" "<Back>")
    if menu appsList buttons; then
      appName="${appNames[selected]}"
      appUrl="${appUrls[selected]}"
      echo -e "appUrl: ${Blue}$appUrl${Reset}"
      APKComboVersions
      return
    else
      return 1
    fi
  else
    return 1
  fi
}

aptoideSearch() {
  # baseUrl: https://github.com/Aptoide/aptoide-client-v8/blob/master/gradle.properties#L31 + https://github.com/Aptoide/aptoide-client-v8/blob/master/gradle.properties#L26 | https + ws75.aptoide.com
  # apiUrl: baseUrl + https://github.com/Aptoide/aptoide-client-v8/blob/master/dataprovider/src/main/java/cm/aptoide/pt/dataprovider/ws/v7/V7.java | https://ws75.aptoide.com + /api/7/ 
  aptoideApi="https://ws75.aptoide.com/api/7"
  # src: https://github.com/Aptoide/aptoide-client-v8/blob/master/dataprovider/src/main/java/cm/aptoide/pt/dataprovider/ws/v7/ListSearchAppsRequest.java
  aptoideSearchAPI="$aptoideApi/listSearchApps"
  while true; do read -r -p ">> Enter appName: " appName; [[ "$appName" =~ ^[Qq] ]] && appName=; break; [ -n "$appName" ] && break || echo -e "$notice Please enter a valid appName!"; done
  if [ -n "$appName" ]; then
    app_name=$(echo "$appName" | sed 's/ /-/g')
    searchJson=$(curl -sL "$aptoideSearchAPI?query=$app_name")
    appsCount=$(jq -r '.datalist.count' <<< "$searchJson")
    appsId=($(jq -r '.datalist.list.[].id' <<< "$searchJson"))
    mapfile -t appNames < <(jq -r '.datalist.list.[].name' <<< "$searchJson")
    packages=($(jq -r '.datalist.list.[].package' <<< "$searchJson"))
    sizes=($(jq -r '.datalist.list.[].size' <<< "$searchJson"))
    icons=($(jq -r '.datalist.list.[].icon' <<< "$searchJson"))
    mapfile -t addedTimes < <(jq -r '.datalist.list.[].added' <<< "$searchJson")
    mapfile -t modifiedTimes < <(jq -r '.datalist.list.[].modified' <<< "$searchJson")
    mapfile -t updatedTimes < <(jq -r '.datalist.list.[].updated' <<< "$searchJson")
    developerIds=($(jq -r '.datalist.list.[].developer.id' <<< "$searchJson"))
    mapfile -t developerNames < <(jq -r '.datalist.list.[].developer.name' <<< "$searchJson")
    mapfile -t vernames < <(jq -r '.datalist.list.[].file.vername' <<< "$searchJson")
    vercodes=($(jq -r '.datalist.list.[].file.vercode' <<< "$searchJson"))
    md5sums=($(jq -r '.datalist.list.[].file.md5sum' <<< "$searchJson"))  # file integrity
    filesizes=($(jq -r '.datalist.list.[].file.filesize' <<< "$searchJson"))
    sha1s=($(jq -r '.datalist.list.[].file.signature.sha1' <<< "$searchJson"))  # file signature
    mapfile -t owners < <(jq -r '.datalist.list.[].file.signature.owner' <<< "$searchJson")  # signature owner
    paths=($(jq -r '.datalist.list.[].file.path' <<< "$searchJson"))
    malwareRanks=($(jq -r '.datalist.list.[].file.malware.rank' <<< "$searchJson"))
    downloads=($(jq -r '.datalist.list.[].stats.pdownloads' <<< "$searchJson"))
    avgRatings=($(jq -r '.datalist.list.[].stats.prating.avg' <<< "$searchJson"))
    totalRatings=($(jq -r '.datalist.list.[].stats.prating.total' <<< "$searchJson"))
    mapfile -t obbs < <(jq -r '.datalist.list.[].obb' <<< "$searchJson")
    appsList=()
    for ((i=0; i<$appsCount; i++)); do
      Trusted=
      [ "${malwareRanks[i]}" == "TRUSTED" ] && Trusted="✔" || Trusted="✘"
      appsList+=("${appNames[i]} | ⚒ ${developerNames[i]} | ${downloads[i]}↓ | ${avgRatings[i]}★ | ⬆ ${totalRatings[i]} | $Trusted")
    done
    buttons=("<Select>" "<Back>")
    if menu appsList buttons; then
      appId="${appsId[selected]}"
      appName="${appNames[selected]}"
      echo "appName: $appName"
      return
    else
      return 1
    fi
  else
    return 1
  fi
}

aptoideListAppVersions() {
  # src: https://github.com/Aptoide/aptoide-client-v8/blob/master/dataprovider/src/main/java/cm/aptoide/pt/dataprovider/ws/v7/listapps/ListAppVersionsRequest.java
  aptoideListAppVersionsAPI="$aptoideApi/listAppVersions"
  listAppVersionsJson=$(curl -sL "$aptoideListAppVersionsAPI/app_id=$appId" | jq -r '.list.[]') #> listAppVersions.json
  fileIds=($(jq -r '.id' <<< "$listAppVersionsJson"))
  mapfile -t vernames < <(jq -r '.file.vername' <<< "$listAppVersionsJson")
  vercodes=($(jq -r '.file.vercode' <<< "$listAppVersionsJson"))
  md5sums=($(jq -r '.file.md5sum' <<< "$listAppVersionsJson"))
  filesizes=($(jq -r '.file.filesize' <<< "$listAppVersionsJson"))
  mapfile -t addeds < <(jq -r '.file.added' <<< "$listAppVersionsJson")
  malwareRanks=($(jq -r '.file.malware.rank' <<< "$listAppVersionsJson"))
  sdks=($(jq -r '.file.hardware.sdk' <<< "$listAppVersionsJson"))
  mapfile -t screens < <(jq -r '.file.hardware.screen' <<< "$listAppVersionsJson")
  mapfile -t cpus < <(jq -r '.file.hardware.cpus.[]' <<< "$listAppVersionsJson")
  mapfile -t densities < <(jq -r '.file.hardware.densities.[]' <<< "$listAppVersionsJson")
  downloads=($(jq -r '.stats.downloads' <<< "$listAppVersionsJson"))
  mapfile -t obbs < <(jq -r '.obb' <<< "$listAppVersionsJson")
  declare -a versionsList
  for ((i=0; i<${#fileIds[@]}; i++)); do
    [ "${malwareRanks[i]}" == "TRUSTED" ] && Trusted="✔" || Trusted="✘"
    versionsList+=("${vernames[i]} (${vercodes[i]}) | ${sdks[i]} | ${cpus[i]} | ${densities[i]} | ${addeds[i]} | ${filesizes[i]} B | $Trusted")
  done
  buttons=("<Select>" "<Back>")
  if menu versionsList buttons; then
    appId="${fileIds[selected]}"
    vername="${vernames[selected]}"
    vercode="${vercodes[selected]}"
    echo "selected: $vername ($vercode)"
    return
  else
    return 1
  fi
}

aptoideAppInfo() {
  # src: https://github.com/Aptoide/aptoide-client-v8/blob/master/dataprovider/src/main/java/cm/aptoide/pt/dataprovider/ws/v7/GetAppRequest.java
  aptoideAppInfoAPI="$aptoideApi/getApp"
  appNodesJson=$(curl -sL "$aptoideAppInfoAPI?app_id=$appId" | jq -r '.nodes') #> appInfo.json
  appMetaDataJson=$(jq -r '.meta.data' <<< "$appNodesJson")
  id=$(jq -r '.id' <<< "$appMetaDataJson")
  name=$(jq -r '.name' <<< "$appMetaDataJson")
  package=$(jq -r '.package' <<< "$appMetaDataJson")
  size=$(jq -r '.size' <<< "$appMetaDataJson")
  icon=$(jq -r '.icon' <<< "$appMetaDataJson")
  added=$(jq -r '.added' <<< "$appMetaDataJson")
  modified=$(jq -r '.modified' <<< "$appMetaDataJson")
  updated=$(jq -r '.updated' <<< "$appMetaDataJson")
  age=$(jq -r '.age.pegi' <<< "$appMetaDataJson" | cut -d '-' -f 2)
  developerId=$(jq -r '.developer.id' <<< "$appMetaDataJson")
  developerName=$(jq -r '.developer.name' <<< "$appMetaDataJson")
  developerWebsite=$(jq -r '.developer.website' <<< "$appMetaDataJson")
  developerEmail=$(jq -r '.developer.email' <<< "$appMetaDataJson")
  userPrivacy=$(jq -r '.developer.privacy' <<< "$appMetaDataJson")
  vername=$(jq -r '.file.vername' <<< "$appMetaDataJson")
  vercode=$(jq -r '.file.vercode' <<< "$appMetaDataJson")
  md5sum=$(jq -r '.file.md5sum' <<< "$appMetaDataJson")
  filesize=$(jq -r '.file.filesize' <<< "$appMetaDataJson")
  sha1=$(jq -r '.file.signature.sha1' <<< "$appMetaDataJson")
  owner=$(jq -r '.file.signature.owner' <<< "$appMetaDataJson")
    CN=$(echo "$owner" | cut -d= -f2 | cut -d, -f1)
    OU=$(echo "$owner" | cut -d= -f3 | cut -d, -f1)
    O=$(echo "$owner" | cut -d= -f4 | cut -d, -f1)
    L=$(echo "$owner" | cut -d= -f5 | cut -d, -f1)
    ST=$(echo "$owner" | cut -d= -f6 | cut -d, -f1)
    C=$(echo "$owner" | cut -d= -f7)
  path=$(jq -r '.file.path' <<< "$appMetaDataJson")
  sdk=$(jq -r '.file.hardware.sdk' <<< "$appMetaDataJson")
  screen=$(jq -r '.file.hardware.screen' <<< "$appMetaDataJson")
  cpus=$(jq -r '.file.hardware.cpus.[]' <<< "$appMetaDataJson")
  densities=$(jq -r '.file.hardware.densities.[]' <<< "$appMetaDataJson")
  dependencies=$(jq -r '.file.hardware.dependencies.[].type' <<< "$appMetaDataJson")
  malwareRank=$(jq -r '.file.malware.rank' <<< "$appMetaDataJson")
  malwareValidatedDate=$(jq -r '.file.malware.reason.signature_validated.date' <<< "$appMetaDataJson")
  used_features=$(jq -r '.file.used_features.[]' <<< "$appMetaDataJson")
  used_permissions=$(jq -r '.file.used_permissions.[]' <<< "$appMetaDataJson")
  tags=$(jq -r '.media.keywords.[]' <<< "$appMetaDataJson")
  description=$(jq -r '.media.description' <<< "$appMetaDataJson")
  descSummary=$(jq -r '.media.summary' <<< "$appMetaDataJson")
  changelog=$(jq -r '.media.news' <<< "$appMetaDataJson")
  avg=$(jq -r '.stats.prating.avg' <<< "$appMetaDataJson")
  total=$(jq -r '.stats.prating.total' <<< "$appMetaDataJson")
  pdownloads=$(jq -r '.stats.pdownloads' <<< "$appMetaDataJson")
  aab=$(jq -r '.aab' <<< "$appMetaDataJson")
    [ $aab == null ] && ext="apk" || ext="aab"
  obb=$(jq -r '.obb' <<< "$appMetaDataJson")
    [ $obb == null ] && TYPE="APPLICATION" || TYPE="GAME"
  pay=$(jq -r '.pay' <<< "$appMetaDataJson")
  advertising=$(jq -r '.appcoins.advertising' <<< "$appMetaDataJson")
  billing=$(jq -r '.appcoins.billing' <<< "$appMetaDataJson")
  appVersionsListJson=$(jq -r '.versions.list' <<< "$appNodesJson")
  
  echo "$name - APK Information"
  [ $pay == null ] && echo "Free: Yes" || echo "Free: No"
  [ $advertising == false ] && echo "containsAds: No" || echo "containsAds: Yes"
  [ $billing == false ] && echo "InAppPurchases: No" || echo "InAppPurchases: $billing"
  echo "APK Version: $vername"
  echo "Package: $package"
  echo "Android compatability: $sdk"
  echo -e "Developer: [$developerName](${Blue}$developerWebsite${Reset})"
  echo -e "Privacy Policy: ${Blue}$userPrivacy${Reset}"
  #echo -e "Permissions:\n${used_permissions}"
  echo "Size: $size B"
  echo "Age: $age"
  echo "Downloads: $pdownloads"
  echo "Rating: ${avg}★"
  echo "Release Date: $added"
  echo "Min Screen: $screen"
  echo "Supported CPU: $cpus"
  echo "SHA1 Signature: $sha1"
  echo "Developer (CN): $CN"
  echo "Organizational Unit (OU): $OU"
  echo "Organization (O): $O"
  echo "Local (L): $L"
  echo "State/City (ST): $ST"
  echo "Country (C): $C"
  dlUrl="$path"
  echo -e "dlUrl: ${Blue}$dlUrl${Reset}"
  fileName="${name}_v$vername-$vercode.$ext"
  filePath="$Download/$fileName"
}
# curl -sL "https://ws75.aptoide.com/api/7/apps/getRecommended" | jq  # https://github.com/Aptoide/aptoide-client-v8/blob/master/dataprovider/src/main/java/cm/aptoide/pt/dataprovider/ws/v7/GetRecommendedRequest.java
# curl -sL "https://ws75-cache.aptoide.com/api/7/listApps?sort=latest&limit=10" | jq  # https://github.com/Aptoide/aptoide-client-v8/blob/master/dataprovider/src/main/java/cm/aptoide/pt/dataprovider/ws/v7/ListAppsRequest.java

# top_post_id=$(curl -sL "https://apkdone.com/wp-json/elasticpress/autosuggest?q=picsart" | jq -r '.list.[].post_id' | head -1)
# https://apkdone.com/wp-json/wp/v2/posts/$top_post_id
liteapksSearch() {
  liteapksWPPostsAPI="https://liteapks.com/wp-json/wp/v2/posts"
  while true; do read -r -p ">> Enter appName: " appName; [[ "$appName" =~ ^[Qq] ]] && appName=; break; [ -n "$appName" ] && break || echo -e "$notice Please enter a valid appName!"; done
  if [ -n "$appName" ]; then
    app_name=$(echo "$appName" | sed 's/ /-/g')
    page=1
    items_per_page=30
    while true; do
      searchUrl="$liteapksWPPostsAPI?search=${app_name}&page=${page}&per_page=${items_per_page}"
      searchJson=$(curl -sL "$searchUrl" | jq -r '.[]')
      postsId=($(jq -r '.id' <<< "$searchJson"))
      dates=($(jq -r '.date' <<< "$searchJson"))
      slugs=($(jq -r '.slug' <<< "$searchJson"))
      links=($(jq -r '.link' <<< "$searchJson"))
      mapfile -t titles < <(jq -r '.title.rendered' <<< "$searchJson")
      icons=($(jq -r '.yoast_head_json.og_image.[].url' <<< "$searchJson"))
      mapfile -t authors < <(jq -r '.yoast_head_json.author' <<< "$searchJson")
      authorsImages=($(jq -r '.yoast_head_json.schema."@graph".[].image.url' <<< "$searchJson"))
      thumbnails=($(jq -r '.thumbnail' <<< "$searchJson"))
      mapfile -t mods < <(jq -r '.mod' <<< "$searchJson")
      mapfile -t versions < <(jq -r '.version' <<< "$searchJson")
      mapfile -t sizes < <(jq -r '.size' <<< "$searchJson")
      views=($(jq -r '.views' <<< "$searchJson"))
      rating_avgs=($(jq -r '.rating_avg' <<< "$searchJson"))
      appsList=()
      for ((i=0; i<${#postsId[@]}; i++)); do
        appsList+=("${titles[i]} | ${mods[i]} | v${versions[i]} | ${rating_avgs[i]}★")
      done
      [ $page -ne 1 ] && appsList+=("<")
      appsList+=(">")
      buttons=("<Select>" "<Back>")
      if menu appsList buttons; then
        if [ "${appsList[selected]}" == "<" ]; then
          ((page--))
        elif [ "${appsList[selected]}" == ">" ]; then
          ((page++))
        else
          postId="${postsId[selected]}"
          slug="${slugs[selected]}"
          link="${links[selected]}"
          title="${titles[selected]}"
          echo -e "$info selected: $title\n$info appUrl: ${Blue}$link${Reset}"
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

liteapksAppDetails() {
  slugUrl="$liteapksWPPostsAPI?slug=$slug"
  slugJson=$(curl -sL "$slugUrl" | jq -r '.[]')
  postId=$(jq -r '.id' <<< "$slugJson")
  date=$(jq -r '.date' <<< "$slugJson")
  slug=$(jq -r '.slug' <<< "$slugJson")
  link=$(jq -r '.link' <<< "$slugJson")
  title=$(jq -r '.title.rendered' <<< "$slugJson")
  icon=$(jq -r '.yoast_head_json.og_image.[].url' <<< "$slugJson")
  author=$(jq -r '.yoast_head_json.author' <<< "$slugJson")
  authorsImage=$(jq -r '.yoast_head_json.schema."@graph".[].image.url' <<< "$slugJson")
  thumbnail=$(jq -r '.thumbnail' <<< "$slugJson")
  mod=$(jq -r '.mod' <<< "$slugJson")
  version=$(jq -r '.version' <<< "$slugJson")
  size=$(jq -r '.size' <<< "$slugJson")
  view=$(jq -r '.views' <<< "$slugJson")
  rating_avg=$(jq -r '.rating_avg' <<< "$slugJson")
  category=$(jq -r '._links."wp:term"[] | select(.taxonomy == "category") | .href' <<< "$slugJson")
  developer=$(jq -r '._links."wp:term"[] | select(.taxonomy == "developer") | .href' <<< "$slugJson")
  app_type=$(jq -r '._links."wp:term"[] | select(.taxonomy == "app_type") | .href' <<< "$slugJson")
  categoryName=$(curl -sL "$category" | jq -r '.[].name')
  developerName=$(curl -sL "$developer" | jq -r '.[].name')
  app_type_name=$(curl -sL "$app_type" | jq -r '.[].name')
  echo -e "$info appName: $title"
  echo -e "$info Publisher: $developerName"
  echo -e "$info Author: $author"
  echo -e "$info Genre: $categoryName"
  echo -e "$info Type: $app_type_name"
  echo -e "$info Size: $size"
  echo -e "$info latestVersion: $version"
  echo -e "$info MODInfo: $mod"
  echo -e "$info starRating: ${rating_avg}★"
}

# method to generate expiration time encoded download url for LITEAPK.COM
genExpiryTimestampUrl() {
  # src: https://liteapks.com/wp-content/themes/new-theme-k/js/site.js?ver=2.2  # JavaScript generates token (CLIENT-SIDE)
  timestamp=$(date +%s)  # get current system time in seconds
  expiry=$((timestamp + 10800))  # adds 3 hours (10,800 seconds) in system time to create an token with 3H expiry time
  first_encode=$(echo -n "$expiry" | base64)  # prints int time w/o new line then converts it to a Base64 encoded string for Url compatibility
  token=$(echo -n "$first_encode" | base64 | sed 's/=/%3D/g')  # base64 generate twice equal sign due to twice base64 command. so, replace == with 3D3D (= is ASCII 61 → 0x3D in hex) using stream editor for Url encoding
  finalUrl="${version_download_link}?token=${token}"  # final download url pattern for LITEAPK.COM
  echo "$finalUrl"
}

liteapksVersionsUrl() {
  liteapksPostsAPI="https://liteapks.com/wp-json/v2/posts"
  versionsUrl="$liteapksPostsAPI/$postId"
  versionsJson=$(curl -sL "$versionsUrl")
  original_download_url=$(jq -r '.data.original_download_url' <<< "$versionsJson")
  name=$(jq -r '.data.name' <<< "$versionsJson")
  mapfile -t versions < <(jq -r '.data.versions.[].version' <<< "$versionsJson")
  version_download_types=($(jq -r '.data.versions.[].version_downloads.[].version_download_type' <<< "$versionsJson"))
  mapfile -t version_download_sizes < <(jq -r '.data.versions.[].version_downloads.[].version_download_size' <<< "$versionsJson")
  version_download_links=($(jq -r '.data.versions.[].version_downloads.[].version_download_link' <<< "$versionsJson"))
  mapfile -t version_download_notes < <(jq -r '.data.versions.[].version_downloads.[].version_download_note' <<< "$versionsJson")
  echo -e "$info Get it On: ${Blue}$original_download_url${Reset}"
  declare -a versionsList
  for ((i=0; i<${#version_download_links[@]}; i++)); do
    versionsList+=("${versions[i]} | ${version_download_sizes[i]}")
  done
  buttons=("<Select>" "<Back>")
  if menu versionsList buttons; then
    version="$(cut -d' ' -f1 <<< "${versions[selected]}" | cut -d'"' -f2)"
    version_download_type="${version_download_types[selected]}"
    version_download_size="${version_download_sizes[selected]}"
    version_download_link="${version_download_links[selected]}"
    version_download_note="${version_download_notes[selected]}"
    dlUrl=$(genExpiryTimestampUrl)
    echo -e "$info dlUrl: ${Blue}$dlUrl${Reset}"
    fileName="$name-${version_download_note}_$version.$version_download_type"
    filePath="$Download/$fileName"
    return
  else
    return 1
  fi
}

APIKey() {
  echo -e "${running} Creating VirusTotal API Key.."
  echo -e "$info sign up or sign in to VirusTotal Community > avatar menu > API Key > API KEY > Copy key to clipboard"
  VirusTotalMyApiKeyUrl="https://www.virustotal.com/gui/my-apikey"  # access your API key
  if [ $isAndroid -eq 1 ]; then
    termux-open-url "$VirusTotalMyApiKeyUrl"
  elif [ $isMacOS -eq 1 ]; then
    open "$VirusTotalMyApiKeyUrl"
  fi
  echo -n "KEY: "  # Display prompt
  # Read characters one by one
  while IFS= read -rsn 1 char; do
    # Handle Enter key (newline)
    if [[ "$char" == $'\0' || "$char" == $'\n' || "$char" == $'\r' ]]; then
      # Only break if input is not empty, input not start with space, input doesn't contain space & pat is valid
      if [[ -n "$input" && ! "$input" =~ ^[[:space:]] && ! "$input" =~ [[:space:]] ]]; then
        curl -fsL "https://www.virustotal.com/api/v3/users/${input}/overall_quotas" -H "x-apikey: ${input}" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
          echo -e "\n$good ${Green}Successfully added your VirusTotal API Key!${Reset}"
          break
        else
          echo -ne "\r\033[K"  # Clear previous prompt line
          echo -e "$notice ${Yellow}Invalid API Key!${Reset}"  # Display messages if pat is not valid
          input=""  # Clear input variable's value
          echo -n "KEY: "  # Display prompt
        fi
      else
        continue
      fi
    fi
    # Handle backspace ($'\177')
    if [[ "$char" == $'\177' ]]; then
      if [ -n "$input" ]; then
        input="${input%?}"  # Remove last char from input & store in input
        echo -ne "\b \b"  # Move cursor back, print space, move cursor back again
      fi
      continue
    fi
    # Handle delete ($'\E[3~')
    # /bin/bash -c 'read -r -p "Type any ESC key: " input && printf "You Entered: %q\n" "$input"'  # q=safelyQuoted
    if [[ "$char" == $'\E' ]]; then
      read -rsn1 -t 0.1 seq1
      if [[ "$seq1" == '[' ]]; then
        read -rsn2 -t 0.1 seq2
        case "$seq2" in
          '3~')  # Delete key
            if [ -n "$input" ]; then
              input="${input%?}"
              echo -ne "\b \b"
            fi
            ;;
        esac
      fi
      continue
    fi
    # Only add printable characters (excluding control characters)
    if [[ "$char" =~ [[:print:]] ]]; then
      input+="$char"  # Add character to input
      echo -n "*"  # Display asterisk
    fi
  done
  config "VirusTotalAPIKey" "$input"
}

virustotalScanUrl() {
  # https://docs.virustotal.com/reference/scan-url
  base64EncodedUrl=$(echo -n "$dlUrl" | base64 | tr -d '\n' | tr -d '=' | tr '/+' '_-')
  analysis_data=$(curl -sL "https://www.virustotal.com/api/v3/urls/$base64EncodedUrl" -H "x-apikey: $API_KEY" | jq -r '.data.attributes')
  last_analysis_stats=$(jq -r '.last_analysis_stats' <<< "$analysis_data")
  malicious=$(jq -r '.malicious' <<< "$last_analysis_stats")
  suspicious=$(jq -r '.suspicious' <<< "$last_analysis_stats")
  if [ $malicious -ne 0 ] || [ $suspicious -ne 0 ]; then
    last_analysis_results=$(jq '.last_analysis_results | to_entries | map(select(.value.category == "malicious" or .value.category == "suspicious" or .value.result == "suspicious" or .value.result == "phishing")) | from_entries' <<< "$analysis_data")
    jq <<< "$last_analysis_results"
    buttons=("<Download anyway>" "<Got it>"); confirmPrompt "This app repored as malicious or suspicious by virustotal. Downloading this app may put your device at risk." "buttons" "1" && return 0 || return 1
  else
    return 0
  fi
}

dlOther() {
  while true; do
    if [ $isAndroid -eq 1 ]; then
      aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" "$dlUrl"
      exitStatus=$?
    elif [ $isMacOS -eq 1 ]; then
      aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" --ca-certificate="/etc/ssl/cert.pem" "$dlUrl"
      exitStatus=$?
    fi
    echo
    [ $exitStatus -eq 0 ] && break || sleep 5
  done
}

LITEAPKSdl() {
  while true; do
    if [ $isAndroid -eq 1 ]; then
      aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" --header="Referer: $link" "$dlUrl"
      exitStatus=$?
    elif [ $isMacOS -eq 1 ]; then
      aria2c -x 16 -s 16 --continue=true --console-log-level=error --download-result=hide --summary-interval=0 -d "$Download" -o "$fileName" --referer="$link" --ca-certificate="/etc/ssl/cert.pem" "$dlUrl"
      exitStatus=$?
    fi
    echo
    [ $exitStatus -eq 0 ] && break || sleep 5
  done
}

options=(Codeberg IzzyOnDroid AppGallery SourceForge APKCombo Aptoide LITEAPKS)
while true; do
  buttons=("<Select>" "<Back>"); if menu "options" "buttons" "${#options[@]}"; then selected="${options[$selected]}"; else break; fi
  case "$selected" in
    Codeberg)
      codebergSearch
      [ $? -ne 0 ] && continue
      
      curl -fsL "$codebergReposUrl/${full_name}/releases/latest" >/dev/null 2>&1
      if [ $? -ne 0 ]; then
        codebergReleases
        [ $? -ne 0 ] && continue
      else
        buttons=("<Latest>" "<Releases>"); confirmPrompt "Please Select release type" "buttons" && opt=Latest || opt=Releases
        if [ "$opt" == "Latest" ]; then
          codebergLatestReleases
          [ $? -ne 0 ] && continue
        else
          codebergReleases
          [ $? -ne 0 ] && continue
        fi
      fi
      dlOther
      if [ $? -eq 0 ]; then
        if { [ $isMacOS -eq 1 ] && [ -n "$serial" ]; } || [ $isAndroid -eq 1 ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt="Yes" || opt="No"
          if [ "$opt" == "Yes" ]; then
            [ $isMacOS -eq 1 ] && adbInstall "$filePath"
            [ $isAndroid -eq 1 ] && apkInstall "$filePath"
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    IzzyOnDroid)
      IzzyOnDroidSearch
      [ $? -ne 0 ] && continue
      dlOther
      if [ $? -eq 0 ]; then
        if { [ $isMacOS -eq 1 ] && [ -n "$serial" ]; } || [ $isAndroid -eq 1 ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt="Yes" || opt="No"
          if [ "$opt" == "Yes" ]; then
            [ $isMacOS -eq 1 ] && adbInstall "$filePath"
            [ $isAndroid -eq 1 ] && apkInstall "$filePath"
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    AppGallery)
      dlAppGallery
      [ $? -ne 0 ] && continue
      dlOther
      if [ $? -eq 0 ]; then
        if { [ $isMacOS -eq 1 ] && [ -n "$serial" ]; } || [ $isAndroid -eq 1 ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt="Yes" || opt="No"
          if [ "$opt" == "Yes" ]; then
            [ $isMacOS -eq 1 ] && adbInstall "$filePath"
            [ $isAndroid -eq 1 ] && apkInstall "$filePath"
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    SourceForge)
      sf
      [ $? -ne 0 ] && continue
      dlOther
      if [ $? -eq 0 ]; then
        ext="${fileName##*.}"
        if { [[ $isMacOS -eq 1 && ( ( "$ext" == "apk" && -n "$serial" ) || "$ext" == "dmg" || "$ext" == "pkg" ) ]]; } || [[ $isAndroid -eq 1 ]]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt="Yes" || opt="No"
          if [ "$opt" == "Yes" ]; then
            if [ $isAndroid -eq 1 ]; then
              apkInstall "$filePath"
            elif [ $isMacOS -eq 1 ]; then
              ([ "$ext" == "apk" ] && [ -n "$serial" ]) && adbInstall "$filePath"
              ([ "$ext" == "dmg" ] || [ "$ext" == "pkg" ]) && open "$filePath"
            fi
          fi
        fi
        echo; read -p "Press Enter to continue..."
        { [[ $isMacOS -eq 1 && ( "$ext" == "dmg" || "$ext" == "pkg" ) && $RmFileAfterInstallation -eq 1 ]]; } && rm -f "$filePath"
      fi
      ;;
    APKCombo)
      APKComboSearch
      [ $? -ne 0 ] && continue
      dlOther
      if [ $? -eq 0 ]; then
        if { [ $isMacOS -eq 1 ] && [ -n "$serial" ]; } || [ $isAndroid -eq 1 ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt="Yes" || opt="No"
          if [ "$opt" == "Yes" ]; then
            [ $isMacOS -eq 1 ] && adbInstall "$filePath"
            [ $isAndroid -eq 1 ] && apkInstall "$filePath"
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    Aptoide)
      aptoideSearch
      [ $? -ne 0 ] && continue

      aptoideListAppVersions
      [ $? -ne 0 ] && continue

      aptoideAppInfo
      [ $? -ne 0 ] && continue
      dlOther
      if [ $? -eq 0 ]; then
        if { [ $isMacOS -eq 1 ] && [ -n "$serial" ]; } || [ $isAndroid -eq 1 ]; then
          buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt="Yes" || opt="No"
          if [ "$opt" == "Yes" ]; then
            [ $isMacOS -eq 1 ] && adbInstall "$filePath"
            [ $isAndroid -eq 1 ] && apkInstall "$filePath"
          fi
        fi
        echo; read -p "Press Enter to continue..."
      fi
      ;;
    LITEAPKS)
      jq -e '.VirusTotalAPIKey != null' "$apkdlJson" >/dev/null 2>&1 && API_KEY="$(jq -r '.VirusTotalAPIKey' "$apkdlJson" 2>/dev/null)" || API_KEY=
      if [ -n "$API_KEY" ]; then
        liteapksSearch
        [ $? -ne 0 ] && continue

        liteapksAppDetails
        [ $? -ne 0 ] && continue

        liteapksVersionsUrl
        [ $? -ne 0 ] && continue

        virustotalScanUrl
        [ $? -ne 0 ] && continue

        LITEAPKSdl
        if [ $? -eq 0 ]; then
          if { [ $isMacOS -eq 1 ] && [ -n "$serial" ]; } || [ $isAndroid -eq 1 ]; then
            buttons=("<Yes>" "<No>"); confirmPrompt "Do you want to install $fileName" "buttons" && opt="Yes" || opt="No"
            if [ "$opt" == "Yes" ]; then
              [ $isMacOS -eq 1 ] && adbInstall "$filePath"
              [ $isAndroid -eq 1 ] && apkInstall "$filePath"
            fi
          fi
        fi
      else
        APIKey
      fi
      echo; read -p "Press Enter to continue..."
      ;;
  esac
done
###############################################################################################################################################################################################################