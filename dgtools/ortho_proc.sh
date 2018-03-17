#! /bin/bash

#Use this to create 16-bit version of more nadir orthoimage, free up space

#qsub -I -q devel -lselect=1:model=bro,walltime=2:00:00
#parallel --jobs 14 --delay 1 --verbose --progress 'ortho_proc.sh {}' ::: *00

dir=$1

id=$(nadir_id.sh $dir | awk '{print $1}')
#The m_ excludes the 30m.tif products
ortho=$(ls $dir/${id}_ortho*m.tif 2>/dev/null | grep -v 'm_')

if [ -z "$ortho" ] ; then 
    echo "Unable to find input ortho tif"
    exit
fi

ortho_prefix=$(echo $ortho | awk -F'/' '{print $NF}')
#Don't necessarily have a DEM written yet
dem_prefix=$(ls $dir/dem*/*DEM_32m.tif 2>/dev/null | awk -F'/' '{print $NF}' | cut -c 1-13)

if [ -z "$dem_prefix" ] ; then
    echo "Unable to find final DEM"
    exit
fi

#Extract output prefix
#dem_prefix=$(ls $dir/dem*/[12]*.tif | head -1 | awk -F'/' '{print $NF}' | cut -c 1-13)
out=$dir/${dem_prefix}_${ortho_prefix%.*}_16b.tif

set -e

#Write out 16-bit, LZW-compressed tif
if [ ! -e $out ] ; then 
    echo "Creating $out"
    gdal_translate -ot UInt16 -a_nodata 0 -co TILED=YES -co COMPRESS=LZW -co PREDICTOR=2 -co BIGTIFF=YES $ortho $out
    gdaladdo_ro.sh $out
else
    echo "Found existing 16b ortho: $out"
fi

ortho=$(ls $dir/1*_ortho*m.tif | grep -v 'm_' | grep -v _30m)
#echo $ortho
#rm -v $ortho

#JPEG2000
#Need to use ASP GDAL, which is compiled against OpenJPEG
#~/sw/asp/latest/bin/gdal_translate -of JP2OpenJPEG -ot UInt16 -a_nodata 0 -co QUALITY=100 -co REVERSIBLE=YES $ortho ${out%.*}.jp2

#Can also do 12-bit JPEG compressed tif
#gdal_translate -a_nodata 0 -co TILED=YES -co COMPRESS=JPEG -co NBITS=12 -co BIGTIFF=YES $ortho $out

#Now delete existing orthoimages (large filesize)
#list=$(ls */*ortho_*m.tif | grep -v _30m)
#rm $list

