#! /bin/bash

#Identify identical pair with swapped ID order in name

dir=$1
pairlist=$(ls -d *00)
dupes=''
for pair in $pairlist
do
    if ! $(echo $dupes | grep -q $pair) ; then
        pairswap=$(echo $pair | awk -F'_' '{print $1 "_" $2 "_" $4 "_" $3}')
        if [ -d $pairswap ] ; then
            echo $pair $pairswap
            dupes+=" $pairswap"
        fi
    fi
done
