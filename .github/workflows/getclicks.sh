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

get_clicks() {
  
  while true;do
    #create bitly api url
    url="https://api-ssl.bitly.com/v4/bitlinks/bit.ly/${1}/clicks/summary?unit=day&units=1&size=0&unit_reference=${2}T00:00:00-0000"
    
    #get the data
    output="$(curl -sH "Authorization: Bearer $BITLY_KEY" -X GET "$url")"
    
    #exit if curl failed
    if [ $? != 0 ];then
      echo -e "\e[91mget_clicks: curl exited with an error\noutput: $output\e[39m\nWaiting 5 mins..." 1>&2
      sleep 5m
    fi
    
    #determine number of clicks
    clickstoday="$(echo "$output" | tr ',' '\n' | grep total_clicks | awk -F: '{print $2}')"
    
    if [ -z "$clickstoday" ];then
      echo -e "\e[91mClicks not found for $name\nURL: $url\nOutput: $output\e[39m\nWaiting 20 mins..." 1>&2
      sleep 20m
    else
      #clicks acquired.
      break #exit the loop
    fi
  done
  #echo "$url"
  echo "$clickstoday"
  #echo "$output"
  
  #on second line, return if bitly can't return daily metrics anymore
  echo "$output" | grep -o limited
  true
}
[ "$1" == source ] && return 0

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
    
    install_clicks=0
    uninstall_clicks=0
    net_clicks=0
    
    #get number of clicks, 1 at a time.
    daysadd=0
    while [ $daysadd -lt $((daysince-1)) ];do #repeat until days offset is greater than days since pi-apps epoch
      
      #generate date to check for. This adds days to the pi-apps epoch until we reach the present.
      date="$(date --date "9/22/2020+${daysadd} days" '+%C%y-%m-%d')"
      # echo -n "$app $date "
      
      if [ ! -f "$folder/install/$date" ];then #only check bitly api if file nonexistant
        output="$(get_clicks "pi-apps-install-$name" "$date")"
        if [ $? == 0 ];then
          today_install_clicks="$(sed -n 1p <<<"$output")"
          limited="$(sed -n 2p <<<"$output")"
          
          #if bitly says "Metrics data limited to after", then $installclicks is a total, not a one-day count
          if [ "$limited" == limited ];then
            today_install_clicks=$((today_install_clicks - install_clicks))
          fi
          echo $today_install_clicks > "$folder/install/$date"
        else
          exit 1
        fi
      else
        today_install_clicks=$(cat "$folder/install/$date")
      fi
      
      
      if [ ! -f "$folder/uninstall/$date" ];then #only check bitly api if file nonexistant
        output="$(get_clicks "pi-apps-uninstall-$name" "$date")"
        if [ $? == 0 ];then
          today_uninstall_clicks="$(sed -n 1p <<<"$output")"
          limited="$(sed -n 2p <<<"$output")"
          
          #if bitly says "Metrics data limited to after", then $installclicks is a total, not a one-day count
          if [ "$limited" == limited ];then
            today_uninstall_clicks=$((today_uninstall_clicks - uninstall_clicks))
          fi
          echo $today_uninstall_clicks > "$folder/uninstall/$date"
          echo "$app $date $today_install_clicks,$today_uninstall_clicks"
        else
          exit 1
        fi
      else
        today_uninstall_clicks=$(cat "$folder/uninstall/$date")
      fi
      
      # echo -en "$today_install_clicks,$today_uninstall_clicks\e[0K\r"
      
      #keep running click totals
      install_clicks=$((today_install_clicks + install_clicks))
      uninstall_clicks=$((today_uninstall_clicks + uninstall_clicks))
      net_clicks=$((today_install_clicks - today_uninstall_clicks))
      echo "$date $net_clicks" >> "$folder/net-installs-data"
      echo "$net_clicks" >> "$folder/net-installs-numbers"
      
      #check the next day's clicks
      daysadd=$((daysadd+1))
    done
    # save net clicks to plot
    app_simple=$(echo "$app" | sed -r "s/['\" ]+/-/g" | sed -r "s/[()]+//g")
    app_no_quote=$(echo "$app" | sed -r "s/['\"]+/-/g")
    cd "$folder" && gnuplot -e "set terminal png size 1000,300; set output '/tmp/graphs/$app_simple-net-installs-graph.png'; set xdata time; set timefmt '%Y-%m-%d'; set xrange ['2020-09-22':'$date']; set autoscale y; set title '$app_no_quote'; set xlabel 'Date'; set ylabel 'Net Installs'; plot 'net-installs-data' using 1:2 title 'Net Installs'"
    echo '![logo-64.png](https://github.com/Botspot/pi-apps-analytics/releases/download/net-install-graphs/'"$app_simple-net-installs-graph.png)" >> "$GITHUB_WORKSPACE/Net-Install-Graphs.md"
    # rm -f "$folder/net-installs-data"
    cd "$GITHUB_WORKSPACE"

    echo "$((install_clicks - uninstall_clicks)) $app" >> "$GITHUB_WORKSPACE/clicklist"
    
    echo "$app done. $install_clicks installs, $uninstall_clicks uninstalls"
    echo
  else
    echo -e "\e[91m$app not found in linklist\e[39m"
  fi
  
done

paste -d+ $GITHUB_WORKSPACE/daily\ clicks/*/net-installs-numbers | bc > $GITHUB_WORKSPACE/net-installs-total
daysadd=0
while [ $daysadd -lt $((daysince-1)) ];do #repeat until days offset is greater than days since pi-apps epoch
  #generate date to check for. This adds days to the pi-apps epoch until we reach the present.
  date="$(date --date "9/22/2020+${daysadd} days" '+%C%y-%m-%d')"
  echo "$date" >> "$GITHUB_WORKSPACE/datelist"
  #check the next day's clicks
  daysadd=$((daysadd+1))
done
paste -d ' ' $GITHUB_WORKSPACE/datelist $GITHUB_WORKSPACE/net-installs-total > $GITHUB_WORKSPACE/net-installs-total-data
gnuplot -e "set terminal png size 1000,300; set output '/tmp/graphs/net-installs-graph.png'; set xdata time; set timefmt '%Y-%m-%d'; set xrange ['2020-09-22':'$date']; set autoscale y; set title 'Total Pi-Apps Net-Installs'; set xlabel 'Date'; set ylabel 'Net Installs'; plot '$GITHUB_WORKSPACE/net-installs-total-data' using 1:2 title ''"
echo '![logo-64.png](https://github.com/Botspot/pi-apps-analytics/releases/download/net-install-graphs/'"net-installs-graph.png)" >> "$GITHUB_WORKSPACE/Net-Install-Graphs.md"

rm -f $GITHUB_WORKSPACE/daily\ clicks/*/net-installs-data
rm -f $GITHUB_WORKSPACE/daily\ clicks/*/net-installs-numbers
rm -f $GITHUB_WORKSPACE/datelist
rm -f $GITHUB_WORKSPACE/net-installs-total
rm -f $GITHUB_WORKSPACE/net-installs-total-data

#write results to file
#sort the results by number of clicks
cat "$GITHUB_WORKSPACE/clicklist" | sort -rn > "$GITHUB_WORKSPACE/clicklist_sorted"
