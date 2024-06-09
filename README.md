[Autohotkey](https://www.autohotkey.com/download/ahk-v2.exe) script to automatically lock the camera behind de player on VRising (Windows)  
Uses memory or pixel detection to check when to unhide the mouse.
Also has some quality of life features like changing the pitch of the camera or making more complex hotkeys.

> Tested up until 1.0.6

# Install
 
Download the latest zip from github [here](https://github.com/tekert/VRisingCameraScript/archive/refs/heads/master.zip)

Start the script using [Autohotkey](https://www.autohotkey.com/download/ahk-v2.exe) v2  
> Double click vrising_camera.ahk 


# Config
Edit `vrising_camera.ahk` you can find the options near the top of the script.

For using pixel detection you need the [ImagePut](https://github.com/iseahound/ImagePut) external library
It's not need if using the standard memory detection but the memory method may stop working on future game updates.
Also, pixel detection is currently only working for 1920x1080 resolutions (you can add support easily tough if you like coding)

# Hotkeys

| Hotkey | Description |
| :--- | ----------- |
| **Left Shift** | Unhides the mouse while pressing it down |
| **F1** | Toggles suspension of the script, cancels any manipulation of the mouse and hotkeys | 
| **F2** | Changes de pitch of the camera <br> NOTE: for now it only works when inside the game (not from the main menu). <br> Takes 10-20s to take effect (have to scan the entire memory, maybe in the future someone will help here)| 
| **F4** | Open the console on any keyboard language.| 


Hope one day the devs add these options to the game.  
