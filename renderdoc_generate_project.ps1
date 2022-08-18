# GameMaker: Studio 2 RenderDoc settings generator script.
# By @odditica. 10/04/20.
# 
# https://github.com/odditica/renderdoc-gms2-kit/
#
# 1) Place this script in the project folder (where the *.yyp file is)
# 2) Start (build) the game in GMS2 and close it.
# 3) Run this script.
# 4) In RenderDoc, load the generated settings file and launch the game.

function bail($message) {
        Write-Host "$message"
        Read-Host -Prompt "Press Enter to exit"
        exit
}

$MODE_NONE=-1
$MODE_VM=0
$MODE_YYC=1

$MODE=$MODE_NONE

cd "$PSScriptRoot"

# Figure out the project name

$PROJECT_NAME=(Get-ChildItem -Path *.yyp -Name) | Sort-Object LastWriteTime -Descending | Select-Object -first 1 | sed 's/.yyp//'
if (! $PROJECT_NAME) { 
    bail("*.yyp file not found!")
}

# Find .win file

$TEMP_PATH="$env:LOCALAPPDATA\GameMakerStudio2\GMS2TEMP\"
if (! (Test-Path -Path "$TEMP_PATH")) {
    bail("Base data path not found!`n(Expected: $TEMP_PATH)")    
}

$BUILD_PATH=Get-ChildItem -Path $TEMP_PATH -Recurse -Include "$($PROJECT_NAME).exe", "$($PROJECT_NAME).win" | Sort-Object LastWriteTime -Descending | Select-Object -first 1 | select -ExpandProperty FullName
if ($BUILD_PATH -match '.exe$') {
    $MODE=$MODE_YYC
} else {
    if ($BUILD_PATH -match '.win$') {
        $MODE=$MODE_VM
    }
}

if ($MODE -eq $MODE_VM) {

    # Find the runner

    $RUNTIME_PATH="$env:ProgramData\GameMakerStudio2\Cache\runtimes\"
    if (! (Test-Path -Path "$RUNTIME_PATH")) {
        bail("Runtime path not found!`n(Expected: $RUNTIME_PATH)")
    }
    $RUNNER_PATH=Get-ChildItem -Path $RUNTIME_PATH -Recurse -Filter "Runner.exe" | Sort-Object LastWriteTime -Descending | Select-Object -first 1 | select -ExpandProperty FullName
    if (! (Test-Path -Path $RUNNER_PATH)) { 
        bail("No runner found!`n(Expected: $RUNNER_PATH)") 
    }
} else {
    if ($MODE -eq $MODE_NONE) {  
        bail("No compatible build found (neither YYC nor VM).")  
    }
}

# Template used to generate the settings file.

$RENDERDOC_JSON_TEMPLATE='{
    "rdocCaptureSettings": 1,
    "settings": {
        "autoStart": false,
        "commandLine": "",
        "environment": [
        ],
        "executable": "",
        "inject": false,
        "numQueuedFrames": 0,
        "options": {
            "allowFullscreen": true,
            "allowVSync": true,
            "apiValidation": false,
            "captureAllCmdLists": false,
            "captureCallstacks": false,
            "captureCallstacksOnlyDraws": false,
            "debugOutputMute": true,
            "delayForDebugger": 0,
            "hookIntoChildren": false,
            "refAllResources": false,
            "verifyBufferAccess": false
        },
        "queuedFrameCap": 0,
        "workingDir": ""
    }
}'

$RENDERDOC_SETTINGS_FILENAME=".\renderdoc_settings_$($PROJECT_NAME).cap"

# If the settings file already exists, only change the required values, otherwise create a new one.

if (Test-Path -Path "$RENDERDOC_SETTINGS_FILENAME") {
    $RENDERDOC_SETTINGS_JSON = Get-Content -Raw -Path "$RENDERDOC_SETTINGS_FILENAME" | ConvertFrom-Json
    if (( $RENDERDOC_SETTINGS_JSON.settings.commandLine -eq $Null ) -or ( $RENDERDOC_SETTINGS_JSON.settings.executable -eq $Null ) ) {
        bail("Existing RenderDoc settings file doesn't contain expected fields. This is likely due to a recent RenderDoc update, meaning this script will need to be updated - please report on GitHub.")
    } 
} else {
    $RENDERDOC_SETTINGS_JSON = $RENDERDOC_JSON_TEMPLATE | ConvertFrom-Json
}

if ($MODE -eq $MODE_VM) {
    $RENDERDOC_SETTINGS_JSON.settings.commandLine="-game `"$($BUILD_PATH)`""
    $RENDERDOC_SETTINGS_JSON.settings.executable = "$RUNNER_PATH"
} else {
    if ($MODE -eq $MODE_YYC) {
        $RENDERDOC_SETTINGS_JSON.settings.commandLine=""
        $RENDERDOC_SETTINGS_JSON.settings.executable = "$BUILD_PATH"
    }
}

$RENDERDOC_SETTINGS_JSON | ConvertTo-Json | Out-File -encoding ascii "$RENDERDOC_SETTINGS_FILENAME"