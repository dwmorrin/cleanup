#!/bin/bash
#   Cleanup script for MacOS.
#   used for classroom workstation computers that had a shared, passwordless
#   "user" account that would quickly become gunked up with random projects
#   about the Desktop and elsewhere.
#
#   If the target directory for files to be "cleaned up" to is on an external
#   hardrive, there is a section below that will attempt to wait for the drive
#   to mount in case this is run on startup, and will attempt to rename the
#   drive (in use, the external drive would often be accidentally renamed
#   gibberish, or sometimes even a null string!).
#   That section is quite experimental and any suggestion on improving it are
#   most welcome.
#
#   This can be run from the command line, but the intended use is to be coupled
#   with a launchd .plist and setup to run as a user agent from
#   ~/Library/LaunchAgents upon every aqua (GUI) login.  The `onlyOnce` option
#   limits the script to running once per day.
#
#   david morrin <dwmorrin@gmail.com>
#   github.com/dwmorrin

# set defaults
progname=$(basename "$0")
cleanupDirName="Cleanup"
cleanupParent="$HOME/Desktop"
today=$(date '+%m-%d-%y')
dailyDir="$cleanupParent/$cleanupDirName/$today"
daysUntilDelete=7
tries=0
emptyDownloads=false;
emptyTrash=false
guiMode=false
onlyOnce=false
sortDesktop=false
verbose=false

while getopts c:d:eD:glm:ost:v option; do
    case "$option"
    in
        c) cleanupParent="$OPTARG";;
        d) externalDiskUUID="$OPTARG";;
        D) correctDriveName="$OPTARG";;
        e) emptyTrash=true;;
        g) guiMode=true;;
        l) emptyDownloads=true;;
        m) mailto="$OPTARG";;
        o) onlyOnce=true;;
        s) sortDesktop=true;;
        t) daysUntilDelete="$OPTARG";;
        v) verbose=true;;
       \?) cat <<EOF
Usage: $progname [-eglosv][-c path][-t days][-d UUID][-D name][-m email]
  -c Path to the cleanup directory (defaults to current users Desktop)
  -d External hard drive UUID (only if -c points to external device)
  -D Name of the external hard drive (only if -c points to external device)
  -e empty Trash
  -g GUI mode; gives user a chance to cancel and progress updates
  -l delete everything in Downloads
  -m email address for error reporting
  -o run only once per day
  -s set desktop sorting to "by kind"
  -t Time in days before cleanup files are purged (default: $daysUntilDelete)
  -v verbode; will announce actions
EOF
            exit 1;;
    esac
done
shift $((OPTIND - 1))

# fatalMsg [errorMsg]
fatalMsg() {
    echo "$(date): Fatal Error: $1"
    if [[ -n "$mailto" ]]; then
        echo "$1" | mail -s "$progname error $(date)" "$mailto"
    fi
    if [[ -n "$guiAlertWindow" ]]; then
        disown "$guiAlertWindow"
        kill "$guiAlertWindow"
    fi
    exit 1
}

# This `if` block will try to fix the name of the target disk
# only if externalDiskUUID (-d option) is set
# also tries to wait until disk mounts on startup
if [[ -n "$externalDiskUUID" ]]; then
    if [[ -z "$correctDriveName" ]]; then
        fatalMsg "UUID set without name of drive (opt -D)"
    fi

    # Give the disk a chance to mount
    while [[ ! -d /Volumes/"$correctDriveName" ]] && [[ $tries -lt 3 ]]; do
        tries=$((tries + 1))
        sleep 15
    done

    if diskutil info "$externalDiskUUID" &> /dev/null; then
        currentDriveName=$(diskutil info "$externalDiskUUID" | grep "Volume Name" | cut -d':' -f2 | sed -e 's/^[[:space:]]*//')
    else
        msg="Bad UUID: check diskutil info -all and reset UUID "
        msg+="and check that drive is connected to Mac"
        fatalMsg "$msg"
    fi

    if [[ "$currentDriveName" != "$correctDriveName" ]]; then
        echo "$(date) found drive named $currentDriveName"
        diskutil rename "$externalDiskUUID" "$correctDriveName"
    fi
fi

# path error guards
if [[ -z "$cleanupParent" ]]; then
    fatalMsg "Init err: Cleanup directory not set"
fi

if [[ ! -d "$cleanupParent"  ]]; then
    fatalMsg "$cleanupParent is not a directory"
fi

if [[ ! -d "$HOME" ]]; then
    fatalMsg "$HOME is not a valid directory"
fi

# FUNCTIONS
################

# cleanUp path [exclude...]
# Moves everything but locked and hidden items from $HOME/path
cleanUp() {
    set -x
    directory="$1"
    # build string of things to exclude from remaining arguments
    exclude=(-flags uchg -or -name '.*' -or -name "$cleanupDirName")
    shift
    for arg do
        exclude+=(-or -name "$arg")
    done

    if $verbose; then
        echo "Moving files into Desktop Cleanup from $directory"
        echo "(Please be patient - this can take awhile!)"
    fi

    if [[ ! -d "$HOME/$directory" ]]; then
        fatalMsg "$HOME/$directory does not exist"
    fi

    find "$HOME/$directory" \! \( "${exclude[@]}" \) -d 1 -print0 \
    | xargs -0 -n1 -I {} \
    mv {} "$cleanupParent/$cleanupDirName/$today"
}

# Deletes old Desktop Cleanup/date directories
deleteOldCleanups() {
    if $verbose; then
        echo "Deleting desktop archives not modified in the past" \
             "$daysUntilDelete days"
    fi

    find "$cleanupParent/$cleanupDirName" \
        -maxdepth 1 -mtime +"$daysUntilDelete" -print0 \
        | xargs -0 -n1 -I {} \
        rm -R {}
}

# deleteContentsOf [directory]
# Deletes $HOME/[directory] contents
deleteContentsOf() {
    if $verbose; then
        echo "Deleting ~/$1 contents"
    fi

    if [[ ! -d "$HOME/$1" ]]; then
        fatalMsg "$HOME/$1 does not exist"
    fi

    if [[ "$(find "$HOME/$1" \! -name ".*" -d 1)" ]]; then
      rm -r "$HOME/${1:?}/"*
    fi
}

sortDesktopByKind() {
  local applescript
  read -r -d '' applescript <<EOF
tell application "Finder" to tell window of desktop to
tell its icon view options to
set arrangement to arranged by kind
EOF
  osascript -e "$applescript"
  killall "Finder"
}

# START SCRIPT
#########################

# Check if cleanup has already run today.
if $onlyOnce; then
    if [[ -d $dailyDir ]]; then
        exit 0 # maint has already ran once today
    fi
fi

# Give the user a chance to cancel
if $guiMode; then
    read -r -d '' applescript <<\EOF
display alert "Cleanup is about to start.
You should not use the computer while it is running
and it may take a few minutes to run.
Please hit cancel now to use the computer immediately."
buttons {"Cleanup", "Cancel"} giving up after 30
EOF
    response=$(osascript -e "$applescript")

    if [[ $response = "button returned:Cancel, gave up:false" ]]; then
        fatalMsg "User cancelled"
    fi

    message='"cleanup is running... '
    message+='do not use computer until this message goes away"'
    osascript -e "display alert $message buttons \"\"" &> /dev/null &
    guiAlertWindow=$!
fi

mkdir -p "$dailyDir"
for dir do
    cleanUp "$dir"
done
#   TODO make use of the optional exclusion arguments to cleanUp
#   on the command line, example for hardcoding here below
# cleanUp "Documents/SomeDir" "*.jpg" # means don't touch jpgs

deleteOldCleanups
if $emptyDownloads; then
    deleteContentsOf "Downloads"
fi
if $emptyTrash; then
    deleteContentsOf ".Trash"
fi
if $sortDesktop; then
    sortDesktopByKind
fi

# Dismiss alert window
if [[ $guiAlertWindow ]]; then
    disown $guiAlertWindow # else kill produces output
    kill $guiAlertWindow
    osascript -e 'display alert "Cleanup finished." giving up after 5' \
        &> /dev/null
fi

exit 0
