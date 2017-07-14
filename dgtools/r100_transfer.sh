#! /bin/bash

#Transfer mono r100.tif to lou

#On lfe
r100dir=~/hma/mono/r100_mono
cd $r100dir
done=$(ls 1*r100.tif | awk -F'.' '{print $1}')
nbdir=/nobackup/deshean/hma/validpairs_20170711
cd $nbdir
#Get finished dir
dem=$(ls *00/dem*/*-DEM_32m.tif | awk -F'/' '{print $1}')
tlist=''
for i in $dem
do
    r100=$(ls $i/*r100.tif 2>/dev/null | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}')
    #echo $r100
    if [ ! -z "$r100" ] ; then 
        for j in $r100
        do
            if $(echo $done | grep -q $j) ; then
                rm -v $i/$j.r100.{tif,xml}
            else
                if ! $(echo $tlist | grep -q $j) ; then
                    tlist+=" $(ls $i/$j.r100.{tif,xml})"
                fi
            fi
        done
    fi
done

echo $tlist | wc -w

#Now transfer to lfe
shiftc $tlist $r100dir/

#avail=$(ls *00/1*r100.tif | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}' | sort -u)
