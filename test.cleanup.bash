#!/bin/bash
args=(-v)
while getopts dg option; do
    case "$option"
    in
        d) set -ex; args+=(-b);;
        g) args+=(-g);;
       \?) exit 1;;
   esac
done

root="Test-$$"
mkdir -p "$root"/{Cleanup,target}
touch "$root/target/"{.leavealone,testfile{1..10}}
echo ------BEFORE CLEANUP------
ls -AR "$root"

bash cleanup.bash "${args[@]}" -c "$root" "$root/target"

echo ------AFTER CLEANUP-------
ls -AR "$root"

rm -R "$root"
