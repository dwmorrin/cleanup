# cleanup

This script was originally used for classroom workstation computers
that had a shared, passwordless "user" account that would quickly become
gunked up with random projects about the Desktop and elsewhere.

Currently working on generalizing it.  Was written exclusively for MacOS, trying
to make it compatible with GNU/Linux as well.

## external drive option
There is an experimental section that attempts to wait for a hard drive to
connect and will automatically rename the hard drive.
This section may get factored out into its own script that can be run separately
if needed.  That section in particular has not been tested outside of MacOS.

## usage
This can be run from the command line, but the intended use is to be coupled
with a launchd .plist (or crontab on linux) and setup to run as a user agent from
~/Library/LaunchAgents upon every aqua (GUI) login.  The `onlyOnce` option
limits the script to running once per day.

```
Usage: cleanup [-eglosuv][-c path][-n name][-t days][-m email]
               [-d UUID][-D name] dir...
  -c Path to the cleanup directory (defaults to current users Desktop)
  -e empty Trash
  -l delete everything in Downloads
  -m email address for error reporting
  -n cleanup directory name
  -o run only once per day
  -t Time in days before cleanup files are purged (default: $daysUntilDelete)
  -v verbose; will announce actions

dir... - directories to purge files from and move into a cleanup directory

MacOS only:
  -g GUI mode; gives user a chance to cancel and progress updates
  -s set Desktop to "sort by kind"
  -u clean up locked files (cleanup ignores locked files by default)

If the path specificed by -c points to an external drive:
  -d External hard drive UUID
  -D Name of the external hard drive
```
