#! /bin/bash

#CD to top dir
#list=$(ls -d */*PAN)
#for i in $list; do dg_renamepair.sh $i; done

indir=$1
pushd $indir

for i in *NTF *XML
do
dg_rename.py $i
done

ntf1=$(ls *ntf | head -1)
ntf1_str=$(echo $ntf1 | cut -c 1-13)
ids=($(dg_get_ids.py .))

outdir=/Volumes/500GB_1/DG_DVD/rename
pairdir=$outdir/${ntf1_str}_${ids[0]}_${ids[1]}

mkdir -pv $pairdir
mv *ntf *xml *rename $pairdir
