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
touch "$root/target/testfile"
echo ------BEFORE CLEANUP------
ls -R "$root"

bash cleanup.bash "${args[@]}" -c "$root" "$root/target"

echo ------AFTER CLEANUP-------
ls -R "$root"

rm -R "$root"
