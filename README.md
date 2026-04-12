#  GPS Team Tracker

### *Real-Time Location Intelligence & Team Coordination*

A professional, full-stack location-sharing ecosystem built with **Flutter**, **Firebase**, and **PHP**. This application provides sub-second synchronization for group travelers, field teams, or friends, featuring live road-network routing and dynamic session management.

-----

##  Core Functionalities

  * ** Sub-Second Sync:** Powered by Firebase Realtime Database for near-zero latency location updates across all peers.
  * ** Dynamic Session Logic:** Create or join private tracking "Rooms" using unique 6-digit alpha-numeric codes.
  * **🛣Smart Routing:** Integrated **OSRM (Open Source Routing Machine)** API to draw real-road paths between users, not just "as the crow flies."
  * ** Hybrid Backend:** \* **Firebase:** Handles high-velocity ephemeral data (Live Lat/Lng).
      * **PHP/MySQL:** Manages persistent metadata and landmark indexing.
  * ** Robust Permissions:** Handles complex Android/iOS location permission states (Denied, DeniedForever, WhileInUse) with automated user redirection.
-----

## 📸Interface Preview

| Live Map Tracking | Dynamic Session Sharing | Team Management Drawer |
| :---: | :---: | :---: |
| <img width="799" height="1280" alt="image" src="https://github.com/user-attachments/assets/62b42a60-d56f-4088-a72f-3a33f5d4bf9f" />|<img width="799" height="1280" alt="image" src="https://github.com/user-attachments/assets/c09df41f-dedd-4ba5-8b05-716a49ff6c03" /> | <img width="799" height="1280" alt="image" src="https://github.com/user-attachments/assets/0ef0e600-ff90-400f-bd4b-1948e1cf82f7" /> |

-----

## 🛠 Tech Stack

  * **Frontend:** Flutter (Dart)
  * **Map Engine:** [Flutter Map](https://pub.dev/packages/flutter_map) / OpenStreetMap
  * **Real-time Layer:** Firebase Realtime Database
  * **State Management:** Optimized lifting with `setState` & `GlobalKeys`
  * **Local Storage:** Hive (for session persistence)
  * **Communication:** `share_plus` & `clipboard` for group invitations

-----

 
##  Architecture Summary

The app uses a **Dual-Stream Architecture**. Live coordinates are pushed to Firebase and streamed via `.onValue.listen()`. Simultaneously, the app polls a local PHP-based search index to provide rapid landmark discovery without incurring high Firebase costs.

-----
## get the APP 
#  GPS Team Tracker 

[![Release](https://img.shields.io/github/v/release/abukiw86-oss/?label=Download%20APK&style=for-the-badge&color=green)](https://github.com/abukiw86-oss/GPS-Team-Tracker/releases/latest)
## 👨‍💻 Developed By

**Abubeker** 
-----
