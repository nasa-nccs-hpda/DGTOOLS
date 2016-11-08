#! /bin/bash

#Extract specified tag from xml file
function gettag() {
    xml=$1
    tag=$2
    echo $(grep "$tag" $xml | awk -F'[<>]' '{print $3}')
}

dir=$1

#This will pull out unique catalog IDs from all filenames in a dir
ids=($(dg_get_ids.py $dir))

#if [ ${#ids[@]} -ne 2 ] ; then
#    echo "Incorrect number of unique ids in $dir:"
#    echo ${ids[@]}
#    exit 1
#fi

#Determine L and R based on resolution
#Better to go through all xml files, find avg MEANPRODUCTGSD, but this works
#Note: this has trouble with other xml files in the dir, like gdalinfo -stats .aux.xml
#Note: can't use P1BS here when we use existing r100.xml files
#res1=$(printf '%.3f' $(gettag $(ls *P1BS*${ids[0]}*.xml | grep -v 'aux.xml' | head -1) 'MEANPRODUCTGSD'))
#res2=$(printf '%.3f' $(gettag $(ls *P1BS*${ids[1]}*.xml | grep -v 'aux.xml' | head -1) 'MEANPRODUCTGSD'))
#res1=$(printf '%.3f' $(gettag $(ls *${ids[0]}*.xml | grep -v 'aux.xml' | head -1) 'MEANPRODUCTGSD'))
#res2=$(printf '%.3f' $(gettag $(ls *${ids[1]}*.xml | grep -v 'aux.xml' | head -1) 'MEANPRODUCTGSD'))

xml1=$(ls -t $dir/*${ids[0]}*.xml | grep P1BS | head -1) 
xml2=$(ls -t $dir/*${ids[1]}*.xml | grep P1BS | head -1) 

#This extracts mean GSD for the mosaiced products
#Note: some older deliveries are missing MEANPRODUCT tags
if grep -q MEANPRODUCTGSD $xml1 ; then
    res1=$(printf '%.2f' $(gettag $xml1 'MEANPRODUCTGSD'))
else
    res1=$(printf '%.2f' $(gettag $xml1 'MEANCOLLECTEDGSD'))
fi

if grep -q MEANPRODUCTGSD $xml2 ; then
    res2=$(printf '%.2f' $(gettag $xml2 'MEANPRODUCTGSD'))
else
    res2=$(printf '%.2f' $(gettag $xml2 'MEANCOLLECTEDGSD'))
fi

#echo "Input MEANPRODUCTGSD res"
#echo "${ids[0]}: $res1 GSD"
#echo "${ids[1]}: $res2 GSD"

#Set L to the image with higher res
#Note: bc true=1, false=0; bash true=0, false=1
#if [ $(echo "a=($res1 < $res2); a" | bc -l) ]; then
if [ $(echo "a=($res1 < $res2); a" | bc -l) -eq 1 ]; then
    imgL=${ids[0]}
    imgR=${ids[1]}
    res=$res1
else
    imgL=${ids[1]}
    imgR=${ids[0]}
    res=$res2
fi

echo $imgL $res
