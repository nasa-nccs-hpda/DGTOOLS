#! /bin/bash

#David Shean
#dshean@gmail.com
#4/3/15

#NOTE: can now do this with GDAL vrt
#http://www.gdal.org/gdal_vrttut.html
#http://www.gdal.org/gdal_pansharpen.html

#Sample data in /scr/pansharpen_test

#Pansharpen WorldView-2 imagery
#See: https://github.com/NeoGeographyToolkit/StereoPipeline/blob/ad918ff5fb94ff1f93689982f8a736f0112ba43b/src/asp/Tools/pansharp.cc

gdal_opt='-co COMPRESS=LZW -co TILED=YES -co BIGTIFF=IF_SAFER'
threads=20

dir=$1
lfs setstripe -c 20 $dir

cd $dir

#Run wv_correct to shift CCD boundaries
#echo ntfmos.sh
#ntfmos.sh . 

res='nat'
res=4
extent=''
proj=EPSG:32610
rpcdir=/nobackup/deshean/rpcdem
dem=$rpcdir/ned1/ned1_tiles_glac24k_115kmbuff.vrt

#Find ids in dir, identify smallest off nadir
#id=1030010027BE9000
id=$(nadir_id.sh .)
if [ "$res" == "nat" ] ; then
    res=$(echo $id | awk '{print $NF}')
fi
id=$(echo $id | awk '{print $1}')

#Standard RGB is 532
#False color NIR is 753
band_list='7 5 3 2'

cmd_list=''
echo -n > cmdlist.txt

#MS
m1bs=$(find . -name "*M1BS*${id}*.ntf")
for b in $band_list
do
    for i in $m1bs
    do
        if [ ! -e ${i%.*}_b${b}.tif ] ; then 
            cmd="gdal_translate -ot UInt16 $gdal_opt -b $b -a_nodata 0 $i ${i%.*}_b${b}.tif; cp ${i%.*}.xml ${i%.*}_b${b}.xml"
            echo $cmd >> cmdlist.txt
            #cmd_list+=" \"$cmd\""
        fi
    done
done

echo $cmd_list
#Need to get quoting right here
#parallel -v ::: $(eval $cmd_list)
if [ -s cmdlist.txt ] ; then
    parallel -v -a cmdlist.txt
fi

echo -n > cmdlist.txt

#PAN
p1bs=$(ls *P1BS*${id}.ntf)
if [ ! -e ${id}_p.r100.tif ] ; then
    #echo "Mosaicing PAN"
    cmd="dg_mosaic --input-nodata-value 5 --output-prefix ${id}_p $p1bs"
    echo $cmd >> cmdlist.txt
    cmd_list+=" \'$cmd\'"
fi

for b in $band_list
do
    m1bs=$(find . -name "*M1BS*${id}*_b${b}.tif")
    if [ ! -e ${id}_b${b}.r100.tif ] ; then
        cmd="dg_mosaic --input-nodata-value 0 --output-prefix ${id}_b${b} $m1bs"
        echo $cmd >> cmdlist.txt
        #cmd_list+=" \'$cmd\'"
    fi
done

echo $cmd_list
if [ -s cmdlist.txt ] ; then 
    parallel -v -a cmdlist.txt
fi

#parallel "$gdal_translate -b {2} -a_nodata 0 {1} {1.}_b{2}.tif" ::: $m1bs ::: $band_list

#Should scale to TOA reflectance - note, this requires float32 as values are 0-1

#When mapping at lower res, mapproject efficiency decreases significantly
if [ ! -e ${id}_p_ortho.tif ] ; then
    echo "Mapping PAN"
    mapproject --tr $res --threads $threads --t_srs $proj $dem ${id}_p.r100.tif ${id}_p.r100.xml ${id}_p_ortho.tif
    #Note: output is float32 - need to convert to UInt16
fi
#pan_res=$(gdalinfo ${id}_p_ortho.tif | grep 'Pixel Size' | awk -F'\\(|,' '{print $2}')
pan_ext=$(get_extent.py ${id}_p_ortho.tif)

#Now mosaic and map each band
for b in $band_list
do
    #May want to combine and map once, rather than map individually
    if [ ! -e ${id}_b${b}_ortho.tif ] ; then
        echo "Mapping MS band $b"
        #mapproject --t_srs $proj $dem ${id}_b${b}.r100.tif ${id}_b${b}.r100.xml ${id}_b${b}_ortho.tif
        mapproject --tr $res --threads $threads --t_projwin $pan_ext --t_srs $proj $dem ${id}_b${b}.r100.tif ${id}_b${b}.r100.xml ${id}_b${b}_ortho.tif
    fi
done

#echo "Converting to UInt16"
#if [ ! -e ${id}_p_ortho_16b.tif ] ; then
#    parallel -v "gdal_translate $gdal_opt -ot UInt16 {} {.}_16b.tif" ::: ${id}_b{7,5,3,2}_ortho.tif ${id}_p_ortho.tif
#fi

echo "Scaling to TOA reflectance, converting to UInt16"
if [ ! -e ${id}_p_ortho_toa.tif ] ; then
    parallel -v "toa.sh {}" ::: ${id}_b{7,5,3,2}_ortho.tif ${id}_p_ortho.tif
fi

echo "Building vrt"
gdalbuildvrt -separate -vrtnodata 0 ${id}_ms_ortho_toa_RGB.vrt ${id}_b{5,3,2}_ortho_toa.tif
gdalbuildvrt -separate -vrtnodata 0 ${id}_ms_ortho_toa_NIR.vrt ${id}_b{7,5,3}_ortho_toa.tif

echo "Running pansharp"
pansharp --threads $threads --nodata-value 0 --min-value 1 --max-value 2048 ${id}_p_ortho_toa.tif ${id}_ms_ortho_toa_RGB.vrt ${id}_ms_ortho_toa_RGB_pansharp.tif
pansharp --threads $threads --nodata-value 0 --min-value 1 --max-value 2048 ${id}_p_ortho_toa.tif ${id}_ms_ortho_toa_NIR.vrt ${id}_ms_ortho_toa_NIR_pansharp.tif

copyproj.py ${id}_p_ortho.tif ${id}_ms_ortho_toa_RGB_pansharp.tif
copyproj.py ${id}_p_ortho.tif ${id}_ms_ortho_toa_NIR_pansharp.tif

#Convert to 8-bit
#gdal_translate -ot Byte

gdaladdo -ro -r gauss --config COMPRESS_OVERVIEW LZW --config BIGTIFF_OVERVIEW IF_NEEDED ${id}_ms_ortho_16b_RGB_pansharp.tif 2 4 8 16 32 64
gdaladdo -ro -r gauss --config COMPRESS_OVERVIEW LZW --config BIGTIFF_OVERVIEW IF_NEEDED ${id}_ms_ortho_16b_NIR_pansharp.tif 2 4 8 16 32 64

#Convert to JPEG2000?
#Must add overviews
#gdaladdo
