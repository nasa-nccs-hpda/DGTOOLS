#! /bin/bash

#After downloading new mono delivery, run dg_mosaic to create r100.tif on ldan nodes
#From lfe, stage ntf/xml on spinning disks
#cd /u/deshean/hma/2018jun18/imagery
#dmget */*ntf
#Can check out 2 ldan simultaneously
#qsub -I -q ldan -lselect=1:ncpus=16:mem=250GB -lwalltime=16:00:00
#cd /u/deshean/hma/2018jun18/imagery
#n=$(ls -d 1* | wc -l)
#n=548
#list1=$(ls -d 1* | head -$n)
#parallel --verbose -j 16 'ntfmos.sh {}' ::: $list1
#list2=$(ls -d 1* | tail -$n)
#parallel --verbose -j 16 'ntfmos.sh {}' ::: $list2
#Do final sweep to clean up errors
#parallel --verbose -j 16 'ntfmos.sh {}' ::: $list2
#Move r100 to /u/deshean/hma/mono/r100
#Clean up
#rm */*corr.{tif,xml}
#Tar up directories
#parallel --verbose --j 6 'mtar -cvf {}.tar {}' ::: 1*

#This is output from validpairs, contains pair names
outdir=/nobackup/deshean/hma/crosstrack_20180720
pairlist=$outdir/dg_archive_2018jun11_dg_imagery_index_all_HMA_rgi_CC25_validpairs_pairname.txt

#Generate list of ID subdir
r100_dir=/u/deshean/hma/mono/r100_mono
pushd $r100_dir > /dev/null
r100list=$(ls -d *r100.tif | sed 's/.r100.tif//')

#Generate list of finished pairs
done_dir=/nobackup/deshean/hma/crosstrack
pushd $done_dir > /dev/null
donelist=$(ls -d *00)

if [ ! -d $outdir ] ; then
    mkdir -pv $outdir
fi

shiftc_list=""

#For each valid pairname
for i in $(cat $pairlist)
do 
    #Extract catalog ids
    id1=$(echo $i | awk -F'_' '{print $3}')
    id2=$(echo $i | awk -F'_' '{print $4}')
    #Check to see if pair is done
    if ! $(echo $donelist | grep -q ${id1}_${id2}) && ! $(echo $donelist | grep -q ${id2}_${id1}) ; then
        #Check to see if both IDs have been delivered and mosaicked 
        if $(echo $r100list | grep -q $id1) && $(echo $r100list | grep -q $id2) ; then
            if [ ! -d $outdir/$i ] ; then
                mkdir -v $outdir/$i
            fi
            pushd $outdir/$i > /dev/null
            #Only do ntf and xml
            #list=$(ls ../../${id1}/*${id1}*.{ntf,xml} ../../${id2}/*${id2}*.{ntf,xml})
            #If initiating transfer on lfe
            shiftc_list+=" ${id1}.r100.tif ${id2}.r100.tif ${id1}.r100.xml ${id2}.r100.xml"
            #If initiating transfer on pfe
            #shiftc_list+=" $r100_dir/${id1}.r100.tif $r100_dir/${id2}.r100.tif $r100_dir/${id1}.r100.xml $r100_dir/${id2}.r100.xml"
            ln_list="../r100/${id1}.r100.tif ../r100/${id1}.r100.xml ../r100/${id2}.r100.tif ../r100/${id2}.r100.xml"
            for j in $ln_list 
            do 
                ln -sf $j . 
            done
            pushd > /dev/null
        fi
    #else
        #echo "$i done"
    fi
done

if [[ ! -z "$shiftc_list" ]] ; then
    if [ ! -d $outdir/r100 ] ; then
        mkdir $outdir/r100
    fi
    shiftc_list_uniq=$(echo $shiftc_list | sort -u)
    pushd $r100_dir > /dev/null
    echo shiftc -L -R $shiftc_list $outdir/r100/ > $outdir/shiftc_r100_cmd.sh
    shiftc -L -R $shiftc_list $outdir/r100/
fi
