# pi-apps-analytics

This repository is used to host the installation statistics for every app in the [Pi-Apps](https://github.com/Botspot/pi-apps) app store. With this data, everybody using Pi-Apps can see how popular any particular app has.  
When installing an app, a special bit.ly link is "clicked" by a background process. Bitly counts the number of "clicks" per day. I've written a complicated bash script to use Bitly's API and collect the data. (The script runs whenever I turn on my RPi) Once the data-collection is done, the script will tally up how many people have installed every app, subtract that by the number of uninstalls, and create the `clicklist` file. It then pushes the new file to Github.  
I recently re-wrote the script to work around a Bitly API issue that was artificially inflating the numbers. Now, the results are accurate, and in the `daily clicks` folder, you can see the number of clicks, for every app, on every day.
