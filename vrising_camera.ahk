; VRising mouse lock script (improves aim and reaction times for some people)
; https://github.com/tekert/VRisingCameraScript/
; v0.9.6

; CHANGELOG

; ver 0.9.6
; Added support for version v1.1.8.0 (will not work on older saves pre v1.1)

; ver 0.9.5
; Found how to change the pitch from memory (press F2 and wait 20s), sadly using AOBs,
;   maybe in the future I will find where cameraState object is populated.

; ver 0.9
; Almost a complete rewrite using classes, many refactors for scans.
; Added memory scan and pixelget options
; Overall better handling of inputs and window change using windows events hooks instead of autohotkey timers
;
; ver 0.8.
; Better handling of key inputs and camera logic. Tested many hours ingame.
;
; ver 0.7:
; I prefer to use screenshots for menu detection, it's a bit cumbersome but works once set
; Since ahk is slow for screenshots and getting pixel data, I use an external lib for that that is 50% or more faster.
;   depends on how many pixelGets are done on base ahk, 1 ImageSearch = 2 PixelGetColor (yeah.. that bad)
;   the ImagePut lib 1 to X PixelGet = 1 PixelGetColor because is uses a buffer, this should be in the standard lib of ahk really.
; if I use memory scans it will work on all resolutions but may break on an update. (I made it, works better,
;   but if game updates it may break or change behaviour, discarded the code :( stick with pixels..
; Now using ImagePut library, to use buffers when scanning for pixels, it uses basic C, so it's fast.

; ========================
; User Options
; ========================

useMemScan := True
; Default: True
; Uses memory scans to check for open menus to unlock and lock the mouse, works on all resolutions but may break on a future update.
;   It's faster and can use lower scanMenuInterval
; False uses ImagePut library to buffer screenshots to analyze the image for pixels belonging to menus,
;   it may not be that reliable on some menus when overlay effects like tooltips or text cover the screen UI, but works pretty good overall.
; False may need a larger scanMenuInterval (150ms is fine when using ImagePut library, the default PixelGet of autohotkey takes a screenshot per each Get)
; There are many ways to scan for something, like FindText library, ImageSearch (need external images) or simply scanning specific pixels on resolutions.
; Default is true but it needs pointer values, using CheatEngine and comparing pointer maps can get you some results,
;    UnityPlayer.dll changes less often it contains the core unity 3d engine.
; <more notes on pointers below>.

scanMenuInterval := 150 ; milliseconds (don't go lower than 100ms for now if useMemScan = False)
; Default: 150ms

lockMouseOnYaxis := 0.27
; Default: 0.27
; Use 0.45 to 0.0 (Y axis % on where the mouse will center, 0 is top of the screen)
; Don't use more than ~30% for the Y axis or you can't use the maximum distance on ground abilities.
;   For throwing area abilities closer to you there are two ingame methods, one is tilting the camera to the ground, it helps but is not enough
;  *The other is zooming the camera with the mousewheel before launching the ability and tilting the camera.. a bit cumbersome but doable with practice. (not too bad)
;   The last is, pressing <script_key=shift> before throwing the ability so you can move the cursor, if the ability is on Q and the script key is shift, this is not ideal.
;     (instead of shift we could use a mouse side button if available, but it may not be ideal for all players)
; If using a pitch float value of 0.4, then we can increase the Y axis to 0.3 - 0.38 (we have greater angle play with ranged abilities)
; TODO: make it so we can move the mouse on the Y axis from 0.45 to 0.25 (uhm, is possible but don't know if it's ideal, check other options)

restoreMousePosition := False
; Default: False
; True = Restores the original mouse position from before after unlocking the mouse.
; False = Don't

pitchValue := 0.4
; Default: 0.4
; Default in engine is 0.6632251143
; Used when F2 is pressed, this is the value that will be set to the camera pitch.
; Most npcs disappear at ~50 meters or so
; so Ranges from 0.0 to 0.3 are a bit dizzy for pvp

; ---------------------------------
; Please don't edit below this line unless you know what you are doing (except maybe the hotkeys section)
; ---------------------------------

; (Address will be cached and scanned every scanMenuInterval to check the current state of menus ingame)
; Array of pointer offsets taken from pointers maps where the menu state byte is stored:
; Tested from [1.1.8.0] to [v1.1.8.0]
menuModuleName := "UnityPlayer.dll"
menuModuleOffset := 0x01CF7AC0
menuModulePointerOffsets := [0x238, 0x100, 0x498, 0x20, 0x18]
; NOTE:
; To find the menuAddress manually, go to main menu (not ESC menu but main menu), Using CheatEngine search for a byte value of 0x05
; (mark Hex and put 05), finally go to the cinematic menu, play a cinematic and while it's playing search for 0x03
; Repeat multiple times until one value remains.
; (optionally go to Load menu and search for 0x04)
;
; That is your menuAddress, now repeat this a bunch of times after closing/start the game, generating pointer maps each time.
; after 2 or 3 times, scan and compare the prior pointer scans against the current most recent scan and pick some pointers
; from UnityPlayer.dll.

; Pitch cameraState structure
; This value gets created dynamically each time a world is loaded, the final value of the pitch is always a float = 0,6632251143 or AOB = 1F C9 29 3F little endian
; AOB of structure: 1F C9 29 3F 00 00 60 41 00 00 A0 40 00 00 78 41 36 8D A7 3F DB 0F 49 3F 01 00 00 00 00 00 78 41 00 00 00 00
; "??" may be used for wildcards, like "01 02 ?? 04 05"
; Tested Working in  [v1.06] to [v1.1.8.0]
pitchAOB :=
    "1F C9 29 3F 00 00 60 41 00 00 A0 40 00 00 78 41 36 8D A7 3F DB 0F 49 3F 01 00 00 00 00 00 78 41 00 00 00 00"
pitchOffset := 0x0 ; 1F C9 29 3F is our pitch so offset is 0
/*
NOTE:

    To find this struct on Cheat Engine, activate mono features and set a breakpoint on ProjectM.Camera.dll -> ProjectM.TopdownCameraSystem -> UpdateCameraInputs method.
    Load a game.
    Look for the TopDownCameraState parameter, on v1.0.6 is the 3rd one, for example the rdx register, that's the address of this struct.

    cameraState structure
    dynamically allocated
    some values like pitch derived from other values.
    This gets created somewhere by the unity engine on game world load
    TODO: check what the other values do. (already did it last year, now i forgot :| but nothing interesting.

    52 B8 9E 3F 6F 12 03 3B
    6F 12 03 3C 6F 12 03 3B
    6F 12 03 3C 00 00 C8 42
    00 00 E1 43 00 00 48 42
    00 00 16 43 00 00 00 00
    ?? ?? ?? ?? ?? ?? ?? ??   Pointer
    9A 99 19 3F 00 00 00 00
    ?? ?? ?? ?? ?? ?? ?? ??   Pointer
    9A 99 99 3E 00 00 F0 40
    ?? ?? ?? ?? ?? ?? ?? ??   Pointer
    00 00 00 41 66 66 66 3F
    00 00 40 41 00 00 40 41
    00 00 40 40 00 00 60 41
    C0 92 81 3F
    1F C9 29 3F               <- Here is our pitch (float)
    00 00 60 41 00 00 A0 40
    00 00 78 41 36 8D A7 3F
    DB 0F 49 3F 01 00 00 00
    00 00 78 41 00 00 00 00
*/

; =====================================================
; END User Options
; =====================================================

#Requires AutoHotkey >=2.0

; https://github.com/Kalamity/classMemory  (converted to v2 by github.com/tekert)
#Include %A_ScriptDir%\classMemory\classMemoryv2.ahk
if (_ClassMemory.Prototype.__Class != "_ClassMemory")
{
    MsgBox(
        "Class memory not correctly installed, or the (global class) variable `"_ClassMemory`" has been overwritten.")
    ExitApp()
}

; https://github.com/iseahound/ImagePut (only needed if we want to use pixels instead of memory for detection)
#Include *i %A_ScriptDir%\ImagePut\ImagePut.ahk

Thread "Interrupt", 0 ; Make all threads always-interruptible. instead of minimum runtime (slice) of 15ms, useful for heavy timers.
SetWorkingDir(A_ScriptDir)
#SingleInstance Force
SendMode("Input")
Persistent
#MaxThreadsPerHotkey 1 ; Important, default.
#HotIf WinActive("ahk_exe VRising.exe") ; By default only enable hotkeys when game window is active. may cause weird problems when window is out of focus and hooks are disabled. TEST
CoordMode("Mouse", "Window") ; To support the game if its in window mode

;WinWait("ahk_exe VRising.exe")

; Make all newly launched threads (hotkeys) higher priority, (not interruptible by timers)
; https://www.autohotkey.com/docs/v2/lib/Thread.htm#NoTimers
Thread "NoTimers", True

; Create the main object, this will handle everything
vrObj := VRising("VRising.exe", useMemScan)
vrObj.setMenuAddresses(menuModuleName, menuModuleOffset, menuModulePointerOffsets)
vrObj.restoreMousePosition := restoreMousePosition
vrObj.setPitchAOB(pitchAOB, pitchOffset)
vrObj.lockAxysLevel := lockMouseOnYaxis

;---------------
;--- HOTKEYS ---
;---------------
;
; All these hotkeys only work when the game window is active so no need to check on every key press.
;

; F1 or End key: Enables or disables the script, disabling timers and hotkeys except for F1 and End keys
; https://www.autohotkey.com/docs/v2/lib/Suspend.htm
#SuspendExempt
~End::
~F1::
{
    if (A_IsSuspended)
        vrObj.SuspendScript(False, True)
    else
        vrObj.SuspendScript(True, True)
}
#SuspendExempt False

; This may take up to 1sec to 20sec to have effect, don't spam it :)
~F2::
{
    static canSpam := 1
    if (canSpam)
    {
        canSpam := 0
        vrObj.setPitch(pitchValue)
        canSpam := 1
    }
}

; Temporarily disables auto mouse lock when shift is pressed.
$LShift::
{
    vrObj.DisableScanTimer()
    SendEvent("{Lshift down}")
}

$LShift Up::
{
    SendEvent("{Lshift up}")
    vrObj.EnableScanTimer()
}

; Play nicely with real right mouse clicks when this script is enabled.
RButton::
{
    ; Disable reading right clicks when the camera is locked (so we don't unlock it involuntarily)
    if (vrObj.isCameraLocked())
    {
        ; *You can send another key here to trigger an ability with the right mouse when in the field.
        return
    }
    Send("{RButton down}")
}
RButton Up::
{
    ; Disable reading right clicks when the camera is locked (so we don't unlock it involuntarily)
    if (vrObj.isCameraLocked())
    {
        ; *You can release the above key here to trigger an ability with the right mouse when in the field.
        return
    }
    Send("{RButton up}")
}

; Action wheel
$Ctrl::
{
    vrObj.DisableScanTimer() ; key spam is controlled inside this function.
    SendEvent("{Ctrl down}")
}
$Ctrl Up::
{
    SendEvent("{Ctrl up}")
    vrObj.EnableScanTimer()
}

; Emote Wheel
$LAlt::
{
    vrObj.DisableScanTimer() ; key spam is controlled inside this function.
    SendEvent("{LAlt down}")
}
$LAlt Up::
{
    SendEvent("{LAlt up}")
    vrObj.EnableScanTimer()
}

; Keyboard for console
;SC029:: ; This is the key above "TAB" left of "1"

F4:: ; <- put here your favorite key to open the console, we use the default SC029
{
    Send '{U+0060}' ;"`" <- back accent: https://kbdlayout.info/how/%60
}

; ------------
; HOTKEYS END
; ------------

class VRising
{
    processName := "VRising.exe"

    restoreMousePosition := True

    ; Lock the mouse at this height on the Y axis on the middle of the game window
    ; Percent from 0.0 to 1.0 of the Y axis, 0.0 (0%) being the top and 1.0 (100%) the bottom.
    ; Here we lock it just below 1/4 by default counting from the top of the game window
    lockAxysLevel
    {
        get => this._lockAxysLevel
        set
        {
            if (value > 1.0)
                this._lockAxysLevel := 1.0
            else if (value < 0)
                this._lockAxysLevel := 0
            else
                this._lockAxysLevel := value
        }
    }

    ; Private members start with _

    _hProcess := ""         ; HANDLE of the vrising.exe process               (not used if using pixel scans)
    _vrisingMem := ""       ; _ClassMemory Object                             (not used if using pixel scans)
    _menuAddress := 0       ; Memory address to check for overlay menus       (not used if using pixel scans)
    _pitchAOB := ""
    _pitchAOBOffset := 0x0   ; Offset for the AOB pattern
    _winHooksArray := []
    _timerDisabled := True  ; Enable or disable auto lock with F1 key (also used internally to disable the script when shift or etc)
    _cameraLocked := False  ; True when the camera is currently locked by the script (used to play nicely with real right mouse clicks on menus)
    _isInFocus := ""
    _menuModuleName := ""                   ; Module name of where the menu state pointer is stored.
    _menuModuleOffset := 0              ; Module offset where the menu state pointer is inside the module
    _menuModulePointerOffsets := []     ; Array of offsets in order from pointer scans.
    _useMemScan := True
    _lockAxysLevel := 0.27
    _scanMenusFunc := ""    ; !Important, for SetTimer Off we have to use the same ObjBindMethod that was used to create the timer,
    ;   since its not static, it creates a new object on each call.
    _savedXpos := ""        ; Save mouse X position before locking it with right click
    _savedYpos := ""        ; Save mouse Y position before locking it with right click

    ; Parameters:
    ;   useMemScan  -   If false, uses PixelGet, this will have to be manually verified depending on resolution but works on all versions (if the pixels don't change)
    ;                   If True, uses the values supplied in setMenuAddresses method to scan for menu activity, works on all resolutions but maybe not all versions
    __new(processName := "VRising.exe", useMemScan := True)
    {
        this._useMemScan := useMemScan

        if this._useMemScan
        {
            if (Type(processName) = 'String')
                this.processName := processName
            else
                throw TypeError("Need a String type for processName")
        }
        else
        {
            ; https://github.com/iseahound/ImagePut/wiki/PixelSearch-and-ImageSearch#pixelsearch
            if (ImagePut.Prototype.__Class != "ImagePut")
            {
                MsgBox("class ImagePutBuffer library not correctly installed.")
                ExitApp
            }
        }

        ; Don't do SetTimer(ObjBindMethod(this, "_ScanMenusTimer"), 0), since it creates a new object and the timer won't be cancelled, that's why we set a Func
        ; This is used to suspend or resume the timers that scan for menus ingame.
        this._scanMenusFunc := ObjBindMethod(this, "_ScanMenusTimer")
        this._isInFocus := WinActive("ahk_exe " this.processName)
        this.SuspendScript(True) ; Start suspended by default TODO: check WinActive and set this.

        ; This class will be controlled by external windows events that use WinEventProc calls
        ; We need to enable it when the script starts to detect when the process is closed and when the process is active or restarted

        ; When Foreground event occurs call func ForeGroundChange for any process (basically when any window comes to the foreground the func is called)
        this._winHooksArray.Push(WinHook.Event.Add(3, 3, ObjBindMethod(this, "_WindowChange"), ,)) ; 3 = EVENT_SYSTEM_FOREGROUND
        ; Foreground won't catch some events when the game is in window mode and there are two foreground windows and one them is from the system.
        ; adding focus events complements all cases when the user or the system switch focus from the game window.
        this._winHooksArray.Push(WinHook.Event.Add(0x8005, 0x8005, ObjBindMethod(this, "_WindowChange"), ,)) ; 0x8005 = EVENT_SYSTEM_FOCUS
    }

    ; Disable Timers and events hooks and delete itself.
    __Delete()
    {
        for hWinEventHook in this._winHooksArray
            WinHook.Event.UnHook(hWinEventHook)
        this._winHooksArray := ""

        this._closeMemory()
    }

    ; This Method controls the internal state of this class, script suspension, stopping/resuming timer, and memory rescan/init if handles are no longer valid.
    ; https://learn.microsoft.com/en-us/windows/win32/api/winuser/nc-winuser-wineventproc
    _WindowChange(hWinEventHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime)
    {
        processName := ""
        try
        {
            processName := WinGetProcessName("ahk_id " hwnd)
        }
        catch Error as e
        {
            ; Target could not be found, continue as false , strange, TODO: test this
        }

        if (processName = this.processName)
        {
            if !this._isInFocus
                this._isInFocus := True
            else
                return ; If already in focus return.

            if (this._useMemScan)
            {
                ; If we already have a valid handle (process had not restarted) use the current loaded handle
                if (!this.isMemValid())
                {
                    ; Close old memory and reinit.
                    this._closeMemory()
                    this._initMemory()
                }
            }
            ; Unsuspend hotkeys and resume scan timers
            this.SuspendScript(False)
        }
        else
        {
            if !this._isInFocus
                return ; If already NOT in focus return.

            this._isInFocus := False
            ; Window Loses Focus, suspend hotkeys and pause scan timers
            this.SuspendScript(True)
        }
    }

    ; Check if the process handle we have had not been closed or restarted
    isMemValid()
    {
        if (isObject(this._vrisingMem))
        {
            if (!this._vrisingMem.isHandleValid())
                return False
        }
        else
            return False

        return True
    }

    ; Does a bunch of unit work instead of calling each function directly on event change.
    ; This only gets called from windows events (when the game is on the foreground and focused)
    _initMemory()
    {
        static errors := 0

        if (!ProcessExist(this.processName))
            throw Error("Init Memory failed, process " this.processName " doesn't exist!")

retry:
        this._openMemory()
        menuAddress := this._getMenuAddress()
        if ((menuAddress = "") or (menuAddress <= 0))
        {
            ; An Error, wait more before trying again.
            errors += 1
            if (errors > 10)
            {
                MsgBox "Could not get menu pointer address, maybe UnityPlayer.dll changed, report it on GitHub, menuAddress: " menuAddress
                ExitApp
            }
            this._closeMemory()
            Sleep(1000)
            goto retry
        }
        errors := 0
        this._menuAddress := menuAddress ; Cache the final menu address

        ; TODO: Sadly pitch memory address is dynamically created and its value too, so we have to scan for it every time we want the pitch changed
        ;   no use getting the camera pitch address now, wait until the user asks for it.
    }

    ; Disable Timers and close Memory instance
    _closeMemory()
    {
        this.DisableScanTimer()

        this._vrisingMem := ""
        this._hProcess := "" ; Is closed automatically when the _classMemory object is destroyed so it's invalid now, we delete it.
        this._menuAddress := 0

        this._savedXpos := ""
        this._savedYpos := ""
    }

    ; Opens _ClassMemory object for vrising.exe, if a handle is already opened and valid it does nothing
    _openMemory()
    {
        if (this.isMemValid())
            return

        ; We need write access for changing camera pitch values inside the game.
        dwDesiredAccess := _ClassMemory.aRights.PROCESS_QUERY_INFORMATION | _ClassMemory.aRights.PROCESS_VM_READ |
            _ClassMemory.aRights.PROCESS_VM_WRITE
        hProcessCopy := 0
        vrisingMem := _ClassMemory("ahk_exe " this.processName, dwDesiredAccess, &hProcessCopy)

        if !isObject(vrisingMem)
        {
            msgbox "Failed to open Vrising.exe handle"
            return
        }

        if (hProcessCopy = 0)
            msgbox "The game isn't running (not found) or you passed an incorrect program identifier parameter. In some cases _ClassMemory.setSeDebugPrivilege() may be required."
        else if (hProcessCopy = "")
            msgbox "OpenProcess failed. If the target process has admin rights, then the script also needs to be ran as admin. _ClassMemory.setSeDebugPrivilege() may also be required. Consult <TODO github> for more information."
        if ((hProcessCopy = 0) or (hProcessCopy = ""))
            return

        this._vrisingMem := vrisingMem
        this._hProcess := hProcessCopy
    }

    ; This is used to set the module name and offsets where the menu state is stored.
    setMenuAddresses(menuModuleName := "", menuModuleOffset := 0, menuModulePointerOffsets := [])
    {
        if (menuModuleName = "")
            throw ValueError("Please provide a valid menuModuleName to search for")

        this._menuModuleName := menuModuleName
        this._menuModuleOffset := menuModuleOffset
        this._menuModulePointerOffsets := menuModulePointerOffsets
    }

    setPitchAOB(pitchAOB, pitchAOBOffset := 0x0)
    {
        this._pitchAOB := pitchAOB
        this._pitchAOBOffset := pitchAOBOffset
    }

    ; We have to scan every time this is called, the AOB pattern is dynamically allocated, it changes every time a world is loaded, and the value is computed dynamically.
    ; TODO: check where this value gets computed.
    ;
    ; Parameters:
    ;   pitch             4 byte Float values from 0.0 (full pitch range) to 1.0 (camera pitch locked)
    ;
    ; Return values:
    ;   True -  Success. The memory address of the pitch was written, camera pitch should change
    ;   False - Error.  Something happened and pitch was not changed.
    setPitch(pitch)
    {
        if (!IsFloat(pitch))
        {
            MsgBox "pitch has to be a float value! instead we got " type(pitch)
            return False
        }

        ret := 0
        scanFromAddress := 0
        ; Change all occurrences, this object is created at least 2 times in memory, the first one fades at garbage collection.
        loop
        {
            foundAddress := this._scanCameraPitchAddress(scanFromAddress)
            if ((foundAddress = "") or (foundAddress < 0))
            {
                MsgBox "Could not get pitch address, setPitch error, foundAddress returned: " foundAddress
                return False
            }
            if (foundAddress = 0)
            {
                return ret ? True : False
            }
            scanFromAddress := foundAddress + 4

            try
            {
                ret := this._vrisingMem.write(foundAddress, pitch, "Float")
                ;       Non Zero -  Indicates success.
                ;       Zero     -  Indicates failure. Check errorLevel and A_LastError for more information
                ;       Null    -   An invalid type was passed. this.Errorlevel is set to -2 TODO: throws on v2
                if ((ret = "") or (ret = 0))
                    return False
            }
            catch Error as err
            {
                throw err
                ;return False
            }
        }

        return False
    }

    ; NOTE: We have to compute this every time a world is loaded,
    ;   the only way for now is to create a hotkey to change the pitch wich first scans the AOB using this pitchAddress.
    ;   startAddress -      The memory address from which to begin the search.
    ;   endAddress -        The memory address at which the search ends.
    ;                       Defaults to 0x7FFFFFFF for 32 bit target processes.
    ;                       Defaults to 0xFFFFFFFF for 64 bit target processes when the AHK script is 32 bit.
    ;                       Defaults to 0x7FFFFFFFFFF for 64 bit target processes when the AHK script is 64 bit.
    ;                       0x7FFFFFFF and 0x7FFFFFFFFFF are the maximum process usable virtual address spaces for 32 and 64 bit applications.
    ;                       Anything higher is used by the system (unless /LARGEADDRESSAWARE and 4GT have been modified).
    ;                       Note: The entire pattern must be occur inside this range for a match to be found. The range is inclusive.
    ; Return values:
    ;   Positive integer -  Success. The memory pitchAddress of the found pattern.
    ;   0                   The pattern was not found.
    ;   -1                  VirtualQueryEx() failed.
    ;   -2                  Failed to read a memory region.
    ;   -10                 The aAOBPattern* is invalid. (No bytes were passed)
    ;   -99                 Invalid handle or _ClassMemory Object, reopen handle and try again
    _scanCameraPitchAddress(startAddress := 0, endAddress := "")
    {
        if (!this.isMemValid())
            return -99

        ;if ((this._cameraStateAddress != "") and (this._cameraStateAddress > 0))
        ;    return this._cameraStateAddress

        pitchAddress := ""
        try
        {
            pattern := this._vrisingMem.hexStringToPattern(this._pitchAOB)
            pitchAddress := this._vrisingMem.processPatternScan(, , pattern*) ; Note the '*'
            ; Memory Address are returned as an int decimal
            if (pitchAddress < 0)
            {
                switch pitchAddress
                {
                    case -1: MsgBox "VirtualQueryEx() failed."
                    case -2: MsgBox "Failed to read a memory region"
                    case -10: MsgBox "The aAOBPattern* is invalid. (No bytes were passed)"
                }
            }
            else
                pitchAddress += +this._pitchAOBOffset
        }
        catch Error as err
        {
            Sleep(1000)
            ;throw err
        }

        return pitchAddress
    }

    ; Method:   _getMenuAddress()
    ;            Get the base address of the open/close state of game menus
    ;            Memory Address are returned as an int decimal
    ; Return values:
    ;   Positive integer - The menu/overlay state address (success).
    ;   -1  - Module not found
    ;   -3  - EnumProcessModulesEx failed
    ;   -4  - The AHK script is 32 bit and you are trying to access the modules of a 64 bit target process. Or the target process has been closed.
    ;   -99 - Invalid handle or _ClassMemory Object, reopen handle and try again
    ;
    /*  --------
        POINTERS (UnityEngine.dll: this contains the game 3d engine so it shouldn't change often, GameAssembly.dll contains the actual game code and it changes every update)
        There are like ~300 candidates inside this UnityEngine.dll, I chose the shortest path with the lower base address.

        ["UnityPlayer.dll"+01CEE8E8]+B8]+0]+B0]+F0]+40]+20]+18 = byte value based on which menu is open

        Byte values in game as of v1.1.8.0 [16/5/25]:
        0x18 = action camera with no menus (no inv, loot, build, plant) open
        0x1A = TAB menu, K, J open
        0x19 = ESC menu open
        0x1B = Map menu open

        Byte values in Main Menu:
        0x05 = Main Menu
        0x03 = Cinematic
        0x04 = Options - Play menu - Load game
    */
    _getMenuAddress()
    {
        if (!this.isMemValid())
            return -99

        if ((this._menuAddress != "") and (this._menuAddress > 0))
            return this._menuAddress

        ; Positive integer -The menu/overlay state address (success).
        ;   -1 - Module not found
        ;   -3 - EnumProcessModulesEx failed
        ;   -4 - The AHK script is 32 bit and you are trying to access the modules of a 64 bit target process. Or the target process has been closed.
        moduleBaseAddress := this._vrisingMem.getModuleBaseAddress(this._menuModuleName)
        if (moduleBaseAddress < 0)
        {
            switch moduleBaseAddress
            {
                case -1: MsgBox "Module " this._menuModuleName " not found"
                case -3: MsgBox "EnumProcessModulesEx failed"
                case -4: MsgBox "The AHK script is 32 bit and you are trying to access the modules of a 64 bit target process. Or the target process has been closed."
            }
            return moduleBaseAddress
        }
        ret := ""
        try
        {
            ret := this._vrisingMem.getAddressFromOffsets(moduleBaseAddress + this._menuModuleOffset,
                this._menuModulePointerOffsets*)
            if (ret = "" or ret <= 0)
            {
                ; TODO: url for issues.
                MsgBox "Could not get menu pointer address, maybe UnityPlayer.dll changed, report it on GitHub, ret: " ret
            }
        }
        catch Error as err
        {
            ; Maybe the process is being loaded, wait and try again.
            Sleep(500)
        }

        return ret
    }

    ; Return Values:
    ;   True: if any type of VRising menu is currently opened.
    ;   False: the camera has any type on menu that requires mouse cursor is open.
    ;   -99 - Invalid handle or _ClassMemory Object, reopen handle and try again
    ;
    ;   throws on error.
    isMenuOpen()
    {
        if (this._useMemScan)
        {
            if (!this.isMemValid())
                throw Error("Handle is no longer valid, can't check if menu is open")

            byte := 0
            if (this._menuAddress != "" and this._menuAddress > 0)
            {
                byte := this._vrisingMem.read(this._menuAddress, "UChar") ; We can read from offsets here but better to use the cached menuAddress.

                ; Error
                if (byte = "")
                {
                    if this._vrisingMem.ErrorLevel == -2
                        throw Error("Wrong type passed to _vrisingMem.read() method")

                    throw OSError()
                }

                ;! TODO: when a clan member dies, this no longer works until the player respawns or time passes, investigate.
                if (byte != 0x18) ; 0x18 = means we are fully in action camera v1.1.8.0
                    return True
            }
        }
        else
        {
            ; TODO2: This else block is no longer updated, we leave it here for reference, the memory scan is more reliable and works on all resolutions.

            ; https://github.com/iseahound/ImagePut/wiki/PixelSearch-and-ImageSearch
            ; https://github.com/iseahound/ImagePut/wiki/Input-Types-&-Output-Functions#input-types
            ; add 0xFF to all colors as explained in the doc. https://github.com/iseahound/ImagePut/wiki/PixelSearch-and-ImageSearch#pixelgetcolor--pixelsetcolor
            pic := ImagePutBuffer({ screenshot: "A" }) ; Take screenshot of active window.

            if (pic.width = 1920) and (pic.height = 1080)
            {
                ; Player menu open on 1920x1080
                ; Top left border of equipment tab (has to be left, the entire middle and right sections are overlapped by tooltips sometimes)
                if ((pic[135, 93] = 0xFF414950)
                and (pic[136, 93] = 0xFF414950)
                and (pic[137, 93] = 0xFF3A4047)
                and (pic[138, 93] = 0xFF2F353A))
                    return true

                ; Action bar on 1920x1080 (if action bar is not visible then we are in a fullscreen menu)
                ; (left wings on the health globe)
                if ((pic[888, 961] != 0xFF9EA6AD)
                and (pic[889, 962] != 0xFF98ABB5)
                and (pic[890, 963] != 0xFF92A8BB)
                and (pic[891, 964] != 0xFF91A8B3))
                    return true
            }
            else
            {
                MsgBox "Resolution not supported (try fullscreen), script will pause."
                this.SuspendScript()
                Pause 1
            }
        }

        return False
    }

    ; Suspends the script so that hotkeys are disabled temporarily, and pauses the scan timers too.
    ; Paremeters:
    ;       s           -   Suspends the script so that hotkeys will not have any effect. False unsuspends the script
    ;       userForced  -   Forces the script to stay suspended (e.g will only unsuspend s=False if userForced is True)
    ;
    ; If already suspended or unsuspended does nothing (User manual suspensions take priority)
    ; self note: It's a bit difficult to read, it was merged from two methods, maybe it was not a good idea.
    SuspendScript(s := True, userForced := False)
    {
        static staySuspended := False ; Force script to stay in suspended state

        ; No suspended/unsuspend if the script is currently force suspended and userForced flag = false
        if ((userForced = false) and staySuspended)
            return

        if (s)
        {
            if (!A_IsSuspended)
            {
                if (userForced)
                    staySuspended := True

                Suspend(1)
            }
            this.DisableScanTimer()
        }
        else
        {
            if (A_IsSuspended)
            {
                ; Clear the force flag if we want to unsuspend a forced suspend with userForced = True
                if ((userForced) and staySuspended)
                    staySuspended := False

                Suspend(0)
            }
            this.EnableScanTimer() ; enable scan timer even if the script is not suspended, cold start.
        }
    }

    ; Disable the menu scan timer and unlocks the camera (called internally when suspending the script)
    ; Not interruptable by timers
    DisableScanTimer()
    {
        if (!this._timerDisabled)
        {
            SetTimer(this._scanMenusFunc, 0) ; Delete timer
            this._timerDisabled := true
            this.UnlockCamera()
        }
    }

    ; Called internally when resuming the script from suspension
    ; Not interruptable by timers
    EnableScanTimer()
    {
        if (this._timerDisabled)
        {
            this._timerDisabled := false
            ;this.LockCamera() ; Timer will lock or unlock the camera, don't force it. maybe the player is already on a menu.
            Thread "NoTimers", False
            SetTimer(this._scanMenusFunc, scanMenuInterval, 0)
            Thread "NoTimers", True
        }
    }

    ; Timer runs this every <scanMenuInterval>
    ; This thread may be interrupted at any time. (dont lock it with critical)
    _ScanMenusTimer()
    {
        try
        {
            if (this._timerDisabled)
                return

            menuOpen := this.isMenuOpen()

            if (menuOpen)
            {
                if (this._cameraLocked)
                    this.UnlockCamera() ; execute this line only the first time
                ; (we want to use real right clicks on build menu and this executes every <scanMenuInterval>)
            }
            else
            {
                if (!this._cameraLocked)
                    this.LockCamera()
            }

        }
        catch Error
        {
            MsgBox "Error in _ScanMenusTimer: " Error.Message
            this.UnlockCamera()
            return ; the memory handle is not valid or some other problem
            ; TODO: send a notification to the logs instead of MsgBox.
        }
    }

    ; SendEvents are more reliable, no need to Sleep everywhere.
    UnlockCamera()
    {
        if (GetKeyState("RButton"))
        {
            SendEvent("{RButton up}")
            this._cameraLocked := false
            if (this._savedXpos = "" or this._savedYpos = "") or !restoreMousePosition
                return
            else
                MouseMove(this._savedXpos, this._savedYpos, 0)
        }
    }

    LockCamera()
    {
        if (this._timerDisabled) ; Don't lock if we disabled camera lock (thread may be resumed late)
            return

        if (A_IsSuspended) ; Don't lock the camera if the script is suspended
            return

        if !WinActive("ahk_exe " this.processName) ; Also don't lock it if it's not active.
            return

        if (!GetKeyState("RButton")) ; Don't lock if the user is using the right click, wait until release
        {
            WinGetPos &Window_X, &Window_Y, &Window_Width, &Window_Height, "A"
            MouseGetPos &_savedXpos, &_savedYpos ; Save current mouse position before moving it, so we can restore it later.
            this._savedXpos := _savedXpos, this._savedYpos := _savedYpos
            BlockInput "MouseMove"
            MouseMove(Window_Width * 0.5, Window_Height * this._lockAxysLevel, 0) ; Move the mouse to the top middle
            Sleep(30) ; Needed for some edge cases when releasing some keys rapidly causes mouse to drag the screen.
            this._cameraLocked := true
            SendEvent("{RButton down}") ; SendInput sometimes shifts the mouse before sending rbutton down with the game
            ; if the user moves the mouse too quickly when relocking the camera.
            BlockInput "MouseMoveOff"
        }
    }

    isCameraLocked()
    {
        return this._cameraLocked
    }
}

; Converted to ahk v2 (and fixed some memory managament) by
;   github.com/tekert
;
; https://www.autohotkey.com/boards/viewtopic.php?f=6&t=59149
; Below is the original comment:
;
; [Class] WinHook
; Fanatic Guru
; 2019 02 18 v2
;
; Class to set hooks of windows or processes
;
;{============================
;
;	Class (Nested):		WinHook.Shell
;
;		Method:
; 			Add(Func, wTitle:="", wClass:="", wExe:="", Event:=0)
;
;		Desc: Add Shell Hook
;
;   	Parameters:
;		1) {Func}		Function name or Function object to call on event
;   	2) {wTitle}	window Title to watch for event (default = "", all windows)
;   	3) {wClass}	window Class to watch for event (default = "", all windows)
;   	4) {wExe}		window Exe to watch for event (default = "", all windows)
;   	5) {Event}		Event (default = 0, all events)
;
;		Returns: {Index}	index to hook that can be used to Remove hook
;
;				Shell Hook Events:
;				1 = HSHELL_WINDOWCREATED
;				2 = HSHELL_WINDOWDESTROYED
;				3 = HSHELL_ACTIVATESHELLWINDOW
;				4 = HSHELL_WINDOWACTIVATED
;				5 = HSHELL_GETMINRECT
;				6 = HSHELL_REDRAW
;				7 = HSHELL_TASKMAN
;				8 = HSHELL_LANGUAGE
;				9 = HSHELL_SYSMENU
;				10 = HSHELL_ENDTASK
;				11 = HSHELL_ACCESSIBILITYSTATE
;				12 = HSHELL_APPCOMMAND
;				13 = HSHELL_WINDOWREPLACED
;				14 = HSHELL_WINDOWREPLACING
;				32768 = 0x8000 = HSHELL_HIGHBIT
;				32772 = 0x8000 + 4 = 0x8004 = HSHELL_RUDEAPPACTIVATED (HSHELL_HIGHBIT + HSHELL_WINDOWACTIVATED)
;				32774 = 0x8000 + 6 = 0x8006 = HSHELL_FLASH (HSHELL_HIGHBIT + HSHELL_REDRAW)
;
;		Note: ObjBindMethod(obj, Method) can be used to create a function object to a class method
;					WinHook.Shell.Add(ObjBindMethod(TestClass.TestNestedClass, "MethodName"), wTitle, wClass, wExe, Event)
;
; ----------
;
;		Desc: Function Called on Event
;			FuncOrMethod(Win_Hwnd, Win_Title, Win_Class, Win_Exe, Win_Event)
;
;		Parameters:
;		1) {Win_Hwnd}		window handle ID of window with event
;   	2) {Win_Title}		window Title of window with event
;   	3) {Win_Class}		window Class of window with event
;   	4) {Win_Exe}			window Exe of window with event
;   	5) {Win_Event}		window Event
;
;		Note: FuncOrMethod will be called with DetectHiddenWindows On.
;
; --------------------
;
;		Method: 	Report(ByRef Object)
;
;		Desc: 		Report Shell Hooks
;
;		Returns:	string report
;						ByRef	Object[Index].{Func, Title:, Class, Exe, Event}
;
; --------------------
;
;		Method:		Remove(Index)
;		Method:		Deregister()
;
;{============================
;
;	Class (Nested):		WinHook.Event
;
;		Method:
;			Add(eventMin, eventMax, eventProc, idProcess, WinTitle := "")
;
;		Desc: Add Event Hook
;
;   	Parameters:
;		1) {eventMin}		lowest Event value handled by the hook function
;   	2) {eventMax}		highest event value handled by the hook function
;   	3) {eventProc}		event hook function, call be function name or function object
;   	4) {idProcess}		ID of the process from which the hook function receives events (default = 0, all processes)
;   	5) {WinTitle}			WinTitle to identify which windows to operate on, (default = "", all windows)
;
;		Returns: {hWinEventHook}	handle to hook that can be used to unhook
;
;				Event Hook Events:
;				0x8012 = EVENT_OBJECT_ACCELERATORCHANGE
;				0x8017 = EVENT_OBJECT_CLOAKED
;				0x8015 = EVENT_OBJECT_CONTENTSCROLLED
;				0x8000 = EVENT_OBJECT_CREATE
;				0x8011 = EVENT_OBJECT_DEFACTIONCHANGE
;				0x800D = EVENT_OBJECT_DESCRIPTIONCHANGE
;				0x8001 = EVENT_OBJECT_DESTROY
;				0x8021 = EVENT_OBJECT_DRAGSTART
;				0x8022 = EVENT_OBJECT_DRAGCANCEL
;				0x8023 = EVENT_OBJECT_DRAGCOMPLETE
;				0x8024 = EVENT_OBJECT_DRAGENTER
;				0x8025 = EVENT_OBJECT_DRAGLEAVE
;				0x8026 = EVENT_OBJECT_DRAGDROPPED
;				0x80FF = EVENT_OBJECT_END
;				0x8005 = EVENT_OBJECT_FOCUS
;				0x8010  = EVENT_OBJECT_HELPCHANGE
;				0x8003 = EVENT_OBJECT_HIDE
;				0x8020 = EVENT_OBJECT_HOSTEDOBJECTSINVALIDATED
;				0x8028 = EVENT_OBJECT_IME_HIDE
;				0x8027 = EVENT_OBJECT_IME_SHOW
;				0x8029 = EVENT_OBJECT_IME_CHANGE
;				0x8013 = EVENT_OBJECT_INVOKED
;				0x8019 = EVENT_OBJECT_LIVEREGIONCHANGED
;				0x800B = EVENT_OBJECT_LOCATIONCHANGE
;				0x800C = EVENT_OBJECT_NAMECHANGE
;				0x800F = EVENT_OBJECT_PARENTCHANGE
;				0x8004 = EVENT_OBJECT_REORDER
;				0x8006 = EVENT_OBJECT_SELECTION
;				0x8007 = EVENT_OBJECT_SELECTIONADD
;				0x8008 = EVENT_OBJECT_SELECTIONREMOVE
;				0x8009 = EVENT_OBJECT_SELECTIONWITHIN
;				0x8002 = EVENT_OBJECT_SHOW
;				0x800A = EVENT_OBJECT_STATECHANGE
;				0x8030 = EVENT_OBJECT_TEXTEDIT_CONVERSIONTARGETCHANGED
;				0x8014 = EVENT_OBJECT_TEXTSELECTIONCHANGED
;				0x8018 = EVENT_OBJECT_UNCLOAKED
;				0x800E = EVENT_OBJECT_VALUECHANGE
;				0x0002 = EVENT_SYSTEM_ALERT
;				0x8016 = EVENT_SYSTEM_ARRANGMENTPREVIEW
;				0x0009 = EVENT_SYSTEM_CAPTUREEND
;				0x0008 = EVENT_SYSTEM_CAPTURESTART
;				0x000D = EVENT_SYSTEM_CONTEXTHELPEND
;				0x000C = EVENT_SYSTEM_CONTEXTHELPSTART
;				0x0020 = EVENT_SYSTEM_DESKTOPSWITCH
;				0x0011 = EVENT_SYSTEM_DIALOGEND
;				0x0010 = EVENT_SYSTEM_DIALOGSTART
;				0x000F = EVENT_SYSTEM_DRAGDROPEND
;				0x000E = EVENT_SYSTEM_DRAGDROPSTART
;				0x00FF = EVENT_SYSTEM_END
;				0x0003 = EVENT_SYSTEM_FOREGROUND
;				0x0007 = EVENT_SYSTEM_MENUPOPUPEND
;				0x0006 = EVENT_SYSTEM_MENUPOPUPSTART
;				0x0005 = EVENT_SYSTEM_MENUEND
;				0x0004 = EVENT_SYSTEM_MENUSTART
;				0x0017 = EVENT_SYSTEM_MINIMIZEEND
;				0x0016 = EVENT_SYSTEM_MINIMIZESTART
;				0x000B = EVENT_SYSTEM_MOVESIZEEND
;				0x000A = EVENT_SYSTEM_MOVESIZESTART
;				0x0013 = EVENT_SYSTEM_SCROLLINGEND
;				0x0012 = EVENT_SYSTEM_SCROLLINGSTART
;				0x0001 = EVENT_SYSTEM_SOUND
;				0x0015 = EVENT_SYSTEM_SWITCHEND
;				0x0014 = EVENT_SYSTEM_SWITCHSTART

;
;		Note: ObjBindMethod(obj, Method) can be used to create a function object to a class method
;					WinHook.Event.Add((eventMin, eventMax, ObjBindMethod(TestClass.TestNestedClass, "MethodName"), idProcess, WinTitle := "")
;
; ----------
;
;		Desc: Function Called on Event
;			FuncOrMethod(hWinEventHook, event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime)
;
;		Parameters:
;		1) {hWinEventHook}		Handle to an event hook instance.
;   	2) {event}						Event that occurred. This value is one of the event constants
;   	3) {hwnd}						Handle to the window that generates the event.
;   	4) {idObject}					Identifies the object that is associated with the event.
;   	5) {idChild}					Child ID if the event was triggered by a child element.
;   	6) {dwEventThread}		Identifies the thread that generated the event.
;   	7) {dwmsEventTime}	Specifies the time, in milliseconds, that the event was generated.
;
;		Note: FuncOrMethod will be called with DetectHiddenWindows On.
;
; --------------------
;
;		Method:	Report(ByRef Object)
;
;		Returns:	string report
;						ByRef	Object[hWinEventHook].{eventMin, eventMax, eventProc, idProcess, WinTitle}
;
; --------------------
;
;		Method: 	UnHook(hWinEventHook)
;		Method: 	UnHookAll()
;
;{============================
class WinHook
{
    class Shell
    {
        static Hooks := Map()
        static Events := Map()

        static Add(Func, wTitle := "", wClass := "", wExe := "", Event := 0)
        {
            if !WinHook.Shell.Hooks
            {
                WinHook.Shell.Hooks := Map(), WinHook.Shell.Events := Map()
                DllCall("RegisterShellHookWindow", "UInt", A_ScriptHwnd)
                MsgNum := DllCall("RegisterWindowMessage", "Str", "SHELLHOOK")
                OnMessage(MsgNum, %ObjBindMethod(WinHook.Shell, "Message")%)
            }
            if !IsObject(Func)
                Func := %Func%
            WinHook.Shell.Hooks.Push({ Func: Func, Title: wTitle, Class: wClass, Exe: wExe, Event: Event })
            WinHook.Shell.Events[Event] := true
            return WinHook.Shell.Hooks.Length
        }
        static Remove(Index)
        {
            WinHook.Shell.Hooks.Delete(Index)
            WinHook.Shell.Events[Index] := {}	; delete and rebuild Event list
            for key, Hook in WinHook.Shell.Hooks
                WinHook.Shell.Events[Hook.Event] := true
        }
        static Report(&Obj := "")
        {
            Obj := WinHook.Shell.Hooks
            for key, Hook in WinHook.Shell.Hooks
                Display .= key "|" Hook.Event "|" Hook.Func.Name "|" Hook.Title "|" Hook.Class "|" Hook.Exe "`n"
            return Trim(Display, "`n")
        }
        static Deregister()
        {
            DllCall("DeregisterShellHookWindow", "UInt", A_ScriptHwnd)
            WinHook.Shell.Hooks := "", WinHook.Shell.Events := ""
        }
        static Message(Event, Hwnd) ; Private Method
        {
            DetectHiddenWindows(true)
            if (WinHook.Shell.Events[Event] or WinHook.Shell.Events[0])
            {

                wTitle := WinGetTitle("ahk_id " Hwnd)
                wClass := WinGetClass("ahk_id " Hwnd)
                wExe := WinGetProcessName("ahk_id " Hwnd)
                for key, Hook in WinHook.Shell.Hooks
                    if ((Hook.Title = wTitle or Hook.Title = "") and (Hook.Class = wClass or Hook.Class = "") and (Hook
                        .Exe = wExe or Hook.Exe = "") and (Hook.Event = Event or Hook.Event = 0))
                        return Hook.Func.Call(Hwnd, wTitle, wClass, wExe, Event)
            }
        }
    }
    class Event
    {
        static Hooks := Map()

        static Add(eventMin, eventMax, eventProc, idProcess := 0, WinTitle := "")
        {
            WinEventProcPtr := CallbackCreate(WinHook.Event.Message)
            if !WinHook.Event.Hooks
            {
                WinHook.Event.Hooks := Map()
                OnExit(ObjBindMethod(WinHook.Event, "UnHookAll"))
            }
            hWinEventHook := DllCall("SetWinEventHook"
                , "UInt", eventMin						;  UINT eventMin
                , "UInt", eventMax						;  UINT eventMax
                , "Ptr", 0x0							;  HMODULE hmodWinEventProc
                , "Ptr", WinEventProcPtr				;  WINEVENTPROC lpfnWinEventProc
                , "UInt", idProcess						;  DWORD idProcess
                , "UInt", 0x0							;  DWORD idThread
                , "UInt", 0x0 | 0x2) 					;  UINT dwflags, OutOfContext|SkipOwnProcess
            if !IsObject(eventProc)
                eventProc := %eventProc%
            WinHook.Event.Hooks[hWinEventHook] := {
                eventMin: eventMin,
                eventMax: eventMax,
                eventProc: eventProc,
                idProcess: idProcess,
                WinTitle: WinTitle,
                callback: WinEventProcPtr  ; Save callback pointer
            }
            return hWinEventHook
        }
        static Report(&Obj := "")
        {
            Obj := WinHook.Event.Hooks
            for hWinEventHook, Hook in WinHook.Event.Hooks
                Display .= hWinEventHook "|" Hook.eventMin "|" Hook.eventMax "|" Hook.eventProc.Name "|" Hook.idProcess "|" Hook
                    .WinTitle "`n"
            return Trim(Display, "`n")
        }
        static UnHook(hWinEventHook)
        {
            if !WinHook.Event.Hooks.Has(hWinEventHook)
                return
            ; Get the callback before removing the hook
            local callback := WinHook.Event.Hooks[hWinEventHook].callback
            DllCall("UnhookWinEvent", "Ptr", hWinEventHook)
            CallbackFree(callback)
            WinHook.Event.Hooks.Delete(hWinEventHook)
        }
        static UnHookAll()
        {
            for hWinEventHook, Hook in WinHook.Event.Hooks
            {
                ; Free callback for each hook
                CallbackFree(Hook.callback)
                DllCall("UnhookWinEvent", "Ptr", hWinEventHook)
            }

            WinHook.Event.Hooks := Map()
        }
        static Message(event, hwnd, idObject, idChild, dwEventThread, dwmsEventTime) ; 'Private Method
        {
            DetectHiddenWindows(true)
            Hook := WinHook.Event.Hooks[hWinEventHook := this] ; this' is hidden param1 because method is called as func

            aList := WinGetList(Hook.WinTitle, , ,)
            loop aList.Length
                if (aList[A_Index] = hwnd)
                    return Hook.eventProc.Call(hWinEventHook, event, hwnd, idObject, idChild, dwEventThread,
                        dwmsEventTime)
        }
    }
}

; .. TESTS ..
; uhmm PixelGetColor is slower than ImageSearch if we compare more than 2 pixels... uhmm autohotkey doesn't do this right
/*
F10::
{
  Start := A_TickCount
  global usePixelGet
  if (!usePixelGet)
  {
    if ImageSearch(&FoundX, &FoundY, 0, 0, A_ScreenWidth, A_ScreenHeight, "*TransBlack player_menu2_1080.png") {
      elapsed := A_TickCount - Start
      MsgBox "TEST calls took " elapsed " ms "
      MsgBox "The player_menu2 image was found"
    }
  }
  else
  {
    if ((PixelGetColor(135, 93) = "0x414950")
      and (PixelGetColor(136, 93) = "0x414950")
      and (PixelGetColor(137, 93) = "0x3A4047")
      and (PixelGetColor(138, 93) = "0x2F353A"))
    {
      elapsed := A_TickCount - Start
      MsgBox "F4 calls took " elapsed " ms "
      ;MsgBox "player_menu WORKS"
    }

  }
}
; TEST
F9::
{
  if ((PixelGetColor(888,961) = "0x9EA6AD")
    and (PixelGetColor(889,962) = "0x98ABB5")
    and (PixelGetColor(890,963) = "0x92A8BB")
    and (PixelGetColor(891,964) = "0x91A8B3"))
  {
    MsgBox "action_bar WORKS"
  }

}
*/

F8::
{
    if (!vrObj.isMemValid())
    {
        MsgBox "F2: memory Invalid!"
        return
    }

    byte := ""
    menuAddress := vrObj._menuAddress
    byte := vrObj._vrisingMem.read(menuAddress, "UChar") ; We can read from offsets here but better to cache the final menuAddress.
    MsgBox "F2: byte: " byte

}

/*


F7::
{
    address := 0
    aInfo := ""
    endAddress := vrObj._vrisingMem.isTarget64bit ? (A_PtrSize = 8 ? 0x7FFFFFFFFFF : 0xFFFFFFFF) : 0x7FFFFFFF

    while address <= endAddress
    {
        vrObj._vrisingMem.VirtualQueryEx(address, &aInfo)

        ; First search inside this block, if not there, search entire memory.
        if (aInfo.RegionSize = 100000000)
        {
            break
        }
    }

    ;  address+100000000

}
*/
