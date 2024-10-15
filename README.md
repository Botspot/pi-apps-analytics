# pi-apps-analytics

This repository is used to host the installation statistics for every app in the [Pi-Apps](https://github.com/Botspot/pi-apps) app store.
With this data, everybody using Pi-Apps can see how popular any particular app is.

Analytics data can not possibly be used to track you (only the time at which the link was clicked is stored).

When installing, updating, or uninstalling an app in Pi-Apps, a special shlink link is "clicked" by a background process.
A pi-apps server runnning an instance of [shlink](https://shlink.io/) counts the number of "clicks" per day, and with that information we can calculate how many users each app has.  
We have written [a complicated bash script](https://github.com/Botspot/pi-apps-analytics/blob/main/.github/workflows/getclicks.sh) to use [shlink's API](https://api-spec.shlink.io/#/) and collect the data.

The data is stored and visualized in this repo in a few places:
- In the `daily clicks` folder, you can see the number of clicks, for every app, on every day.
- In the `package_data_v2.json` file, automatic metadata is generated for each application in pi-apps using a standard format. This is for easy use by other projects. (`package_data.json` is deprecated and should not be used by other projects)
- In the `clicklist` and `clicklist_sorted` that tally up the total number of net installs an application has.
- In the `Net-Install-Graphs.md` and `Update-Graphs.md` where the Net installs and Updates over time are plotted for easy viewing.
