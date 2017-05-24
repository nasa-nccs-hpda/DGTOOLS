#! /bin/bash

#Run in directory containing subdir of mono IDs
#This contains links to all mono
imgdir=/u/deshean/hma/mono

#This is output from validpairs, contains pair names
pairlist=dg_imagery_index_20161128_all_dg_imagery_index_20161128_all_CC20_rgi50_32644_validpairs_pairname.txt
outdir=/nobackup/deshean/hma/hma2

cd $imgdir 
#Generate list of ID subdir
idlist=$(ls -d *00)

mkdir validpairs

for i in $(cat $pairlist)
do 
    id1=$(echo $i | awk -F'_' '{print $3}')
    id2=$(echo $i | awk -F'_' '{print $4}')
    if $(echo $idlist | grep -q $id1) && $(echo $idlist | grep -q $id2) ; then
        mkdir -v validpairs/$i
        pushd validpairs/$i > /dev/null
        #Only do ntf and xml
        list=$(ls ../../${id1}/*${id1}*.{ntf,xml} ../../${id2}/*${id2}*.{ntf,xml})
        for j in $list 
        do 
            ln -s $j . 
        done
        pushd > /dev/null
        echo
    fi
done

exit

shiftc -L -R validpairs $outdir 

