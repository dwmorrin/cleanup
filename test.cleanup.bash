#!/bin/bash
if [[ $1 = debug ]]; then
    set -x
fi
root="Test-$$"
mkdir -p "$root/target"
mkdir "$root/Cleanup"
touch "$root/target/testfile"
echo ------BEFORE CLEANUP------
ls -R "$root"

bash cleanup.bash -v -c "$root" "cleanup/$root/target"

echo ------AFTER CLEANUP-------
ls -R "$root"

rm -R "$root"
