#!/bin/bash

function error {
  echo -e "\e[91m$1\e[39m" 1>&2
  exit 1
}

#get days since pi-apps epoch
daysince="$((($(date +%s)-$(date +%s --date "9/22/2020"))/(3600*24)))"

applist="$(ls /tmp/pi-apps/apps | grep .)"
# temporarily add apps back to applist that have been removed
# applist="$(echo -e "$applist\nTeamViewer Host\nMinecraft Java")"
#debug output applist
echo "$applist"

rm -f "$GITHUB_WORKSPACE/clicklist"
rm -f "$GITHUB_WORKSPACE/Net-Install-Graphs.md"
mkdir /tmp/graphs

total_shlink=0
total_bitly=0

get_clicks() {
  
  while true;do
    #create bitly api url
    url="https://api-ssl.bitly.com/v4/bitlinks/bit.ly/${1}/clicks/summary?unit=day&units=1&size=0&unit_reference=${2}T00:00:00-0000"
    url_shlink="https://analytics.pi-apps.io/rest/v2/short-urls/${1}/visits?startDate=${2}T00%3A00%3A00&endDate=${3}T00%3A00%3A00"
    
    #get the data
    output="$(curl -sH "Authorization: Bearer $BITLY_KEY" -X GET "$url")"
    
    #exit if curl failed
    if [ $? != 0 ];then
      echo -e "\e[91mget_clicks: curl exited with an error\noutput: $output\e[39m\nWaiting 5 mins..." 1>&2
      sleep 5m
    fi
    
    #determine number of clicks
    clickstoday="$(echo "$output" | tr ',' '\n' | grep total_clicks | awk -F: '{print $2}')"

    # get clicks for 1 day range from pi-apps shlink server
    clickstoday_shlink="$(curl -s -X 'GET' "$url_shlink" -H 'accept: application/json' -H "X-Api-Key: $SHLINK_KEY" | jq -r 'first( .visits | .pagination | .totalItems )')"

    # for debuggging/testing print clickstoday_shlink to stderr (should not affect calculations)
    # remove once testing has been completed
    echo "$1 (date range: $2 to $3) $clickstoday_shlink" >/dev/stderr    

    # null output can only mean that the URL does not exist and is not a valid endpoint
    # untill all URLs are added, set this as a 0 output
    # for testing, pi-apps-(un)install-Snapdrop pi-apps-(un)install-StackEdit and pi-apps-(un)install-template have been created at shlink
    if [ "$clickstoday_shlink" == "null" ]; then
      clickstoday_shlink=0
    fi  
    
    if [ -z "$clickstoday" ];then
      echo -e "\e[91mClicks not found for $name\nURL: $url\nOutput: $output\e[39m\nWaiting 20 mins..." 1>&2
      sleep 20m
    else
      #clicks acquired.
      break #exit the loop
    fi
  done
  #echo "$url"

  # combined shlink and bitly install/uninstall daily numbers (used for transition period and eventually bitly will be removed)
  total_clickstoday=$(($clickstoday + $clickstoday_shlink))
  echo "$total_clickstoday"
  #echo "$output"

  # for debug purposes, track the total number of clicks on shlink and bitly
  # when the number of click on bitly have dropped to a very low ammount, it can be removed from this script
  total_shlink=$(($total_shlink + $clickstoday_shlink))
  total_bitly=$(($total_bitly + $clickstoday))
  echo "$total_shlink"
  echo "$total_bitly"

  #on fourth line, return if bitly can't return daily metrics anymore
  echo "$output" | grep -o limited
  true
}
[ "$1" == source ] && return 0

# add pi-apps function (this is all that is needed so don't source the whole api)
list_subtract() { #Outputs a list of apps from stdin, minus the ones that appear in $1
  # for example, the following two inputs will be a match
  # Audacity
  # Audacity
  # while these two will NOT be a match
  # Multimedia/Audacity
  # .*/Audacity
  comm -23 - <(echo "$1" | sort)
}

daysadd=0
while [ $daysadd -lt $daysince ];do #repeat until days offset is greater than days since pi-apps epoch
  #generate date to check for. This adds days to the pi-apps epoch until we reach the present.
  date="$(date --date "9/22/2020+${daysadd} days" '+%C%y-%m-%d')"
  echo "$date" >> "$GITHUB_WORKSPACE/datelist"
  #check the next day's clicks
  daysadd=$((daysadd+1))
done
unset daysadd

#install links
IFS=$'\n'
for app in $applist ;do
  
  name="$(echo "$app" | tr -d ' ' | sed 's/[^a-zA-Z0-9]//g')"
  #example value of link variable: 'VisualStudioCode'
  
  #if the link is mentioned in linklist
  if cat "$GITHUB_WORKSPACE/.github/workflows/linklist" | grep -q "pi-apps-uninstall-$name"'$' ;then
    #app was found in linklist
    
    #for every day since pi-apps epoch, a file is placed in this folder:
    folder="$GITHUB_WORKSPACE/daily clicks/${app}"
    mkdir -p "$folder/install"
    mkdir -p "$folder/uninstall"

    if [ ! -f "$folder/data.csv" ]; then
      # create folder header
      echo "Date,Net Clicks,Install Clicks,Uninstall Clicks" > "$folder/data.csv"
    fi
    
    install_clicks=0
    uninstall_clicks=0
    net_clicks=0
    
    #get number of clicks, 1 at a time.
    daysadd=0

    # only check for clicks if date is not in CSV
    click_dates_needed="$(cat $GITHUB_WORKSPACE/datelist | list_subtract "$(cat "$folder/data.csv" | awk -F"," '{print $1}' | tail -n +2)")"

    IFS=$'\n'
    for date in $click_dates_needed;do
      
      #generate end date to check for. This adds days to the pi-apps epoch until we reach the present.
      date_end="$(date --date "$date+1 days" '+%C%y-%m-%d')"
      
      unset output
      output="$(get_clicks "pi-apps-install-$name" "$date" "$date_end")"
      if [ $? == 0 ];then
        today_install_clicks="$(sed -n 1p <<<"$output")"
        total_shlink="$(sed -n 2p <<<"$output")"
        total_bitly="$(sed -n 3p <<<"$output")"
        limited="$(sed -n 4p <<<"$output")"
        
        #if bitly says "Metrics data limited to after", then $installclicks is a total, not a one-day count
        if [ "$limited" == limited ];then
          today_install_clicks=$((today_install_clicks - install_clicks))
        fi
      else
        exit 1
      fi
      unset output
      output="$(get_clicks "pi-apps-uninstall-$name" "$date" "$date_end")"
      if [ $? == 0 ];then
        today_uninstall_clicks="$(sed -n 1p <<<"$output")"
        total_shlink="$(sed -n 2p <<<"$output")"
        total_bitly="$(sed -n 3p <<<"$output")"
        limited="$(sed -n 4p <<<"$output")"
        
        #if bitly says "Metrics data limited to after", then $installclicks is a total, not a one-day count
        if [ "$limited" == limited ];then
          today_uninstall_clicks=$((today_uninstall_clicks - uninstall_clicks))
        fi
      else
        exit 1
      fi
      echo "$app $date $today_install_clicks,$today_uninstall_clicks"
      # generate CSV of the data (data, net clicks, install clicks, uninstall clicks)
      net_clicks=$((today_install_clicks - today_uninstall_clicks))
      echo "$date,$net_clicks,$today_install_clicks,$today_uninstall_clicks" >> "$folder/data.csv"
    done
    # save net clicks to plot
    app_simple=$(echo "$app" | sed -r "s/['\" ]+/-/g" | sed -r "s/[()]+//g")
    app_no_quote=$(echo "$app" | sed -r "s/['\"]+/-/g")
    cd "$folder" && gnuplot -e "set terminal svg size 1000,300; 
      set output '/tmp/graphs/$app_simple-net-installs-graph.svg'; 
      set xdata time; 
      set timefmt '%Y-%m-%d'; 
      set xrange ['2020-09-22':'$date']; 
      set autoscale y; 
      set title '$app_no_quote'; 
      set xlabel 'Date'; 
      set ylabel 'Net Installs'; 
      set datafile separator ','; 
      p 'data.csv' using 1:2 w l lc rgb \"forest-green\" t 'Net Installs'"
    echo '![logo-64.svg](https://github.com/Botspot/pi-apps-analytics/releases/download/net-install-graphs/'"$app_simple-net-installs-graph.svg)" >> "$GITHUB_WORKSPACE/Net-Install-Graphs.md"
    cd "$GITHUB_WORKSPACE"

    # obtain the install clicks and uninstall clicks by summing the column of the CSV
    install_clicks="$(cat "$folder/data.csv" | tail +2 | awk -F , '{print $3}' | xargs | sed -e 's/\ /+/g' | bc)"
    uninstall_clicks="$(cat "$folder/data.csv" | tail +2 | awk -F , '{print $4}' | xargs | sed -e 's/\ /+/g' | bc)"

    echo "$((install_clicks - uninstall_clicks)) $app" >> "$GITHUB_WORKSPACE/clicklist"
    
    echo "$app done. $install_clicks installs, $uninstall_clicks uninstalls"
    echo
  else
    echo -e "\e[91m$app not found in linklist\e[39m"
  fi
  
done

# print debug output for total bitly and shlink clicks
echo "total_shlink: $total_shlink, total_bitly: $total_bitly"

# FIXME: total numbers can no longer be collected in this way. we need to read from all the CSVs and combine their data and plot the sum
# paste -d+ $GITHUB_WORKSPACE/daily\ clicks/*/net-installs-numbers | bc > $GITHUB_WORKSPACE/net-installs-total
# paste -d ' ' $GITHUB_WORKSPACE/datelist $GITHUB_WORKSPACE/net-installs-total > $GITHUB_WORKSPACE/net-installs-total-data
# gnuplot -e "set terminal svg size 1000,300; set output '/tmp/graphs/net-installs-graph.svg'; set xdata time; set timefmt '%Y-%m-%d'; set xrange ['2020-09-22':'$date']; set autoscale y; set title 'Total Pi-Apps Net-Installs'; set xlabel 'Date'; set ylabel 'Net Installs'; plot '$GITHUB_WORKSPACE/net-installs-total-data' using 1:2 title ''"
# echo '![logo-64.svg](https://github.com/Botspot/pi-apps-analytics/releases/download/net-install-graphs/'"net-installs-graph.svg)" >> "$GITHUB_WORKSPACE/Net-Install-Graphs.md"

rm -f $GITHUB_WORKSPACE/daily\ clicks/*/net-installs-numbers
rm -f $GITHUB_WORKSPACE/datelist
rm -f $GITHUB_WORKSPACE/net-installs-total
rm -f $GITHUB_WORKSPACE/net-installs-total-data

#write results to file
#sort the results by number of clicks
cat "$GITHUB_WORKSPACE/clicklist" | sort -rn > "$GITHUB_WORKSPACE/clicklist_sorted"
