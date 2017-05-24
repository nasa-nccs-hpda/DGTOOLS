#! /bin/bash 

#Check PGC delivery for problem pairs

#Todo
#Compute extent/area from xml - use geom
#group by PRODUCTORDERID
#Search for identical FIRSTLINETIME
#NUMROWS
#NUMCOLUMNS

#Note:
#The current appraoch blindly summing rows won't work if there are slightly different ntf files
#Also, DG sometimes shoots a long strip and short strip for a stereopair
#Should probably do imglen_diff as a percentage of each input

#Want to check the seconds in the individual ntf filenames for difference
#Want to use the PRODUCTORDERID to group files

#Extract specified tag from xml file
function gettag() {
    xml=$1
    tag=$2
    echo $(grep "$tag" $xml | awk -F'[<>]' '{print $3}')
}

#dir=/u/deshean/2013dec19
dir=$1
pushd $dir

#Remove unnecessary files
#mtar -c -v --index-file=${dir}_browse_etc.idx -f ${dir}_browse_etc.tar *00/*.jpg *00/*.tar *00/*.rename
#rm *00/*.jpg *00/*.tar *00/*.rename

list=$(ls -d {GE,WV}*)

#This will fetch all xml files from tape
#dmget ntf*/*/*xml
#Check status
#dmls -al ntf*/*/*xml

outdir=check_delivery
mkdir $outdir

#Generate lists
missing_ids=$outdir/pairs_missing_ids
inconsistent_ntfcount=$outdir/pairs_inconsistent_ntfcount
inconsistent_xml_ntf=$outdir/pairs_inconsistent_xml_ntf
inconsistent_imglen=$outdir/pairs_inconsistent_imglen
tiled_combo=$outdir/pairs_tiled_untiled_combo
duplicate_xml=$outdir/pairs_duplicate_xml
bad_xml_id=$outdir/pairs_bad_xml_id
no_meanproductgsd=$outdir/pairs_no_meanproductgsd

outlist=($missing_ids $tiled_combo $duplicate_xml $bad_xml_id $inconsistent_xml_ntf $inconsistent_ntfcount $inconsistent_imglen $no_meanproductgsd)
for i in ${outlist[@]} 
do
    echo -n > $i
done

for i in $list
do
    echo $i
    #ids=($(ls $i/*.ntf | awk -F'/' '{print $NF}' | awk -F'[-.]' '{print $3}' | sort -u))
    #This works for new filenames 
    ids=($(ls $i/*P1BS*.{tif,ntf} | awk -F'/' '{print $NF}' | awk -F'[-._]' '{print $3}' | sort -u))
    #This works for old filenames
    #ids=($(ls $i/*P1BS*.{tif,ntf} | awk -F'/' '{print $NF}' | awk -F'[-.]' '{print $3}' | sort -u))
    #ids=($(ls $i/*P1BS*.ntf | awk -F'/' '{print $NF}' | awk -F'[-.]' '{print $3}' | sort -u))
    #Check for two unique ids
    if [ "${#ids[@]}" -ne "2" ] ; then
        echo "Incorrect number of catids: ${ids[@]}"
        echo $i ${ids[@]} >> $missing_ids
        continue
    fi
    ntfcount=()
    imglen=()
    for id in ${ids[@]}
    do
        ntf_list=($(ls $i/{GE,WV}*${id}*.ntf))
        #tif_list=($(ls $i/WV*${id}.tif))
        xml_list=($(ls $i/{GE,WV}*${id}*.xml))
        id_imglen_list=()
        #Check for consistent number of ntf and xml files
        if [ "${#ntf_list[@]}" -ne "${#xml_list[@]}" ] ; then
            echo "Inconsistent n_xml and n_ntf: $id ${#ntf_list[@]} ${#xml_list[@]}"
            echo "$i $id ntf: ${#ntf_list[@]} xml: ${#xml_list[@]}" >> $inconsistent_xml_ntf
        fi
        #Check for mixed r1c1 and "subscene" ntf files
        n_rc=$(echo ${ntf_list[@]} | sed 's/ /\n/g' | egrep -e 'R[0-9]*C[0-9]*' | wc -l)
        n_sub=$(echo ${ntf_list[@]} | sed 's/ /\n/g' | egrep -v -e 'R[0-9]*C[0-9]*' | wc -l)
        ntfcount+=($n_rc $n_sub)
        if [ "$n_rc" -gt "0" ] && [ "$n_sub" -gt "0" ] ; then
            echo "Tiled/Untiled combo: $id $n_rc $n_sub"
            echo $i $id $n_rc $n_sub >> $tiled_combo
            #grep MEANPRODUCTGSD *xml
            #grep NUMROWS *xml
            #mkdir bad_fn; mv *-P1BS-* bad_fn
        fi
        #Should do cksum to check for duplicate ntf files
        #Check for identical xml files
        for xml1 in ${xml_list[@]}
        do
            #Check for xml files with different catid in the filename
            xmlid=$(gettag $xml1 "CATID")
            #Convert e to E
            rowgsd=$(gettag $xml1 "MEANPRODUCTROWGSD")
            mpgsd=$(gettag $xml1 "MEANPRODUCTGSD")
            if [ -z "$mpgsd" ] ; then
                echo "Missing MEANPRODUCTGSD: $id"
                echo $i $id >> $no_meanproductgsd 
            fi
            printf -v rowgsd '%f' "$rowgsd"
            rows=$(gettag $xml1 "NUMROWS")
            rowlen=$(echo "$rowgsd * $rows" | bc -l)
            id_imglen_list+=($rowlen)
            if [ $xmlid != $id ] ; then
                echo "Bad xml id: ${xml1##*/} $xmlid"
                echo $i ${xml1##*/} $xmlid >> $bad_xml_id
            fi
            #shift $xml_list
            unset xml_list[0]
            xml_list=("${xml_list[@]}")
            for xml2 in ${xml_list[@]}
            do
                if diff -q $xml1 $xml2 > /dev/null ; then
                    echo "Duplicate xml files: ${xml1##*/} ${xml2##*/}"
                    echo $i ${xml1##*/} ${xml2##*/} >> $duplicate_xml
                    #Need check for full-image ntfs here - these should be priority
                    #Preserve R1C1 over subscenes
                    #Note: 2013dec19 delivery has many R1C1 mod times of Dec 20
                    #mkdir bad_fn; mv $(ll -t WV* | grep -v 'Dec 20' | awk '{print $NF}') bad_fn/
                fi
            done
        done
        my_imglen=$(echo ${id_imglen_list[@]} | tr ' ' '\n' | awk '{sum+=$1} END {print sum}')
        imglen+=($my_imglen)
        echo "$id n_rc: $n_rc n_sub: $n_sub imglen: $my_imglen"
    done
    imglen_thresh=12000
    ntfdiff=$((${ntfcount[1]} - ${ntfcount[3]}))
    imglen_diff=$(echo "${imglen[0]} - ${imglen[1]}" | bc)
    printf -v imglen_diff '%.0f' "$imglen_diff"
    if (("${imglen_diff#-}" >= "$imglen_thresh")) ; then
        echo "Inconsistent imglen (nrows * rowgsd)"
        echo $i ${ids[0]} ${ntfcount[0]} ${ntfcount[1]} ${imglen[0]} ${ids[1]} ${ntfcount[2]} ${ntfcount[3]} ${imglen[1]} ${ntfdiff#-} ${imglen_diff#-} >> $inconsistent_imglen
    fi
#    ntfdiff_thresh=3
#    if (("${ntfdiff#-}" >= "$ntfdiff_thresh")) ; then
#        echo "Inconsistent number of mono ntf for ids"
#        echo $i ${ids[0]} ${ntfcount[1]} ${ids[1]} ${ntfcount[3]} >> $inconsistent_ntfcount 
#    fi
    rcdiff_thresh=1
    rcdiff=$((${ntfcount[0]} - ${ntfcount[2]}))
    if (("${rcdiff#-}" >= "$rcdiff_thresh")) ; then
        echo "Inconsistent number of rc ntf for ids"
        echo $i ${ids[0]} ${ntfcount[0]} ${ids[1]} ${ntfcount[2]} >> $inconsistent_ntfcount 
    fi
    echo
done

pushd
