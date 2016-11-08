#! /bin/bash

#Check out devel node
#qsub ~/bin/devel.pbs
#parallel 'toa.sh {}' ::: WV*

#For a stereo directory
#dir=$1
#cd $dir
#nadir_id=$(nadir_id.sh . | awk '{print $1}')

#For an individual image
nadir_id=$1
ortho=$(ls ${nadir_id}_ortho_*m.tif | sort -n | head -1)
img=$ortho

#Lowres
#res=30
#if [ ! -e ${ortho%.*}_${res}m.tif ] ; then
#    gdalwarp -overwrite -r cubic -dstnodata 0 -tr $res $res $ortho ${ortho%.*}_${res}m.tif 
#fi
#img=${ortho%.*}_${res}m.tif

#Note: this doesn't contain MEANSUNEL
#xml=${ortho%.*}.xml
#Should really take average of all xml
#xml=$(ls *${nadir_id}*.xml | grep P1BS | tail -n 1)
xml=$(ls *${nadir_id}*.xml | grep P1BS | head -1)
band='P'
toa.py $xml $band
c=$(toa.py $xml $band | tail -n 1)

#For 30 m image, don't need 20 threads
image_calc --output-nodata-value 0 -d float32 -c "$c*var_0" $img -o ${img%.*}_toa.tif
#If doing fullres, should scale by 1000, then output uint16
minval=1
#maxval=2048
maxval=1000
#TOA reflectance is scaled range is from 0-1, want to scale back to 0-2048
#image_calc -d uint16 -c "(${c}*var_0)*(${maxval}-${minval})" $img -o ${img%.*}_toa.tif
