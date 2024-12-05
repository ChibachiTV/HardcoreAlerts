# Hardcore Alerts
A lightweight World of Warcraft addon to track and display player deaths.
This addon parses the information from the HardcoreDeaths chat channel giving instant customizable alerts, level filtering, (zone filtering coming), and an on-screen log of who has died so far.

This addon does not track statistics. There is no heatmap nor is there any tracking for the class someone was. This is purely to give a customizable alternative to the default Blizzard implementation instead of the DeathLog addon.

## Features
- Track Player Deaths: Automatically logs the name, cause of death, and the zone where each death occurred.
- Death Alert: Automatically show a customizable on-screen alert of a death on your realm.
- Guild member deaths have their name highlighted in green.
- Minimal UI Footprint: A clean and lightweight design that integrates seamlessly with your WoW interface.

## Installation
1. Download the files into your addon folder (/AddOns/HardcoreAlerts/)
2. Restart / Reload WoW and enable the addon in the Addons menu.

## How to Use
1. Enable Hardcore Death Announcements and set them to ALL DEATHS.
    * (Hardcore Death Alerts can be 'never' and it still works fine.)
3. Join the 'HardcoreDeaths' channel. You can hide this channel in your chat settings.
### Options > Interface > Display
![image](https://github.com/user-attachments/assets/5d481e34-d880-4dc5-bd1f-8e48ec20e4ad)
### Chat Settings > Global Channels
![image](https://github.com/user-attachments/assets/fb209a31-9a47-41dc-9106-59eb49ea1838)

## Screenshots
### Alert Style
![image](https://github.com/user-attachments/assets/536af257-bbd0-482c-91b0-e3d06cfa3fcd)
### Death Tracker UI
![image](https://github.com/user-attachments/assets/d3bbfdd5-9c96-4a90-9cea-225f1320bdd7)
### Settings UI
![image](https://github.com/user-attachments/assets/0aad7f81-3cfb-4bf1-a36d-9eb1da798e8c)


## License
This project is licensed under the GPL-3.0 license.

## TODO
- [x] Settings Menu (with customizable sounds, fonts, graphics, etc.)
- [x] Setting for level filtering
- [ ] Setting for zone filtering (Maybe like /hcalerts zone ZONENAME or something)
- [ ] Death Tracker UI formatted like a table instead of the string-based UI
- [ ] Release on addon hosting websites!

If you enjoy this addon, consider leaving a star ⭐ on GitHub! Feedback and suggestions are always welcome.
