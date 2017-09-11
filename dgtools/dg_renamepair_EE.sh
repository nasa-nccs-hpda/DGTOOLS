#! /bin/bash

#CD to top dir
#USGS
#for i in WORLDVIEW-* ; do mv "$i" $(echo "$i" | sed 's/ /_/g') ; done
#parallel --verbose 'unzip -d {.} {}; rm -r {.}/license' ::: */*zip
#for i in WORLDVIEW-* ; do mkdir $i/zip ; mv $i/*.zip $i/zip ; done
#for i in WORLDVIEW-* ; do mkdir $i/M1BS ; mv $i/*M* $i/M1BS ; done

#Set output directory
#outdir=/Volumes/500GB_1/DG_DVD/rename
#outdir=/Volumes/e/SnowEx/SnowEx_DG_DVD/rename
outdir="./rename"

#To run:
#list=$(ls -d */*PAN)
#list=$(ls -d */*/*{p1bs,P1BS}*)
#for i in $list; do dg_renamepair.sh $i; done

indir=$1
#pushd $indir

#The iname here ignores case
ntflist=$(find $indir -iname '*.ntf' -o -iname '*.tif' -o -iname '*.xml' -not -path './WV0*' -not -path './rename' -not -path '*M1BS*')

for i in $ntflist 
do
    #This will always create output with lowercase extension
    dg_rename.py $i
done

exit

#This was for deliveries with everything neatly contained in pair subdir
#ntf1=$(ls *ntf | head -1)
ntf1=$(find $indir -iname 'WV*.ntf' -o -iname 'WV*.tif' | head -1)
echo $ntf1
ntf1_str=$(echo $ntf1 | awk -F'/' '{print $NF}' | cut -c 1-13)
echo $ntf1_str
ids=($(dg_get_ids.py $indir))
echo $ids
if [ ! -d $outdir ] ; then
    mkdir $outdir
fi
pairdir=$outdir/${ntf1_str}_${ids[0]}_${ids[1]}
mkdir -pv $pairdir
ntflist=$(find $indir -iname '*.ntf' -o -iname '*.tif' -o -iname '*.xml' -not -path './WV0*' -not -path './rename' -not -path '*M1BS*')
mv $ntflist $pairdir

sensordate=$(ls *{ntf,tif,xml} | cut -c 1-13 | sort -u)
for i in $sensordate
do
    mkdir $i
    mv ${i}*.* $i/
    ids=($(dg_get_ids.py $i))
    pairdir=${i}_${ids[0]}_${ids[1]}
    mv $i $pairdir
done
