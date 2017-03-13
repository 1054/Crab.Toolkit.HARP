#!/bin/bash
#

set -e

for datagroup in 2015raw 2016raw; do
    echo "**************"
    echo "* $datagroup *"
    echo "**************"
    if [[ ! -f "list_obs_info_$datagroup.txt" ]]; then
        cat "/malatang/$datagroup/obs_info.txt" | grep -i "^IC342" > list_obs_info_$datagroup.txt
    fi
    listobsdate=($(cat list_obs_info_$datagroup.txt | tr -s ' ' | cut -d ' '  -f 2))
    listobscode=($(cat list_obs_info_$datagroup.txt | tr -s ' ' | cut -d ' '  -f 3))
    listobstype=($(cat list_obs_info_$datagroup.txt | tr -s ' ' | cut -d ' '  -f 4))
    for (( i=0; i<${#listobsdate[@]}; i++ )); do
        # 
        # change directory into each data set
        # 
        tempobsdir="dataset_${listobsdate[$i]}_${listobscode[$i]}_${listobstype[$i]}"
        echo "$tempobsdir"
        if [[ ! -d "$tempobsdir" ]]; then
            mkdir "$tempobsdir"
        else
            if [[ -f "$tempobsdir/b_receptors_class_tagged.30m" ]]; then
                echo ""
                echo "Warning! \"$tempobsdir/b_receptors_class_tagged.30m\" exists! We will not reprocess this data set!"
                echo ""
                continue
            else
                echo "Warning! \"$tempobsdir\" exists! Backup as \"$tempobsdir.backup\"!"
                rm -rf "$tempobsdir.backup" 2>/dev/null
                mv "$tempobsdir" "$tempobsdir.backup"
                mkdir "$tempobsdir"
            fi
        fi
        cd "$tempobsdir"
        # 
        # link each data file in each data set
        # 
        tempobsfile=$(ls /malatang/$datagroup/${listobsdate[$i]}/a${listobsdate[$i]}_*${listobscode[$i]}_*.sdf)
        if [[ x"${tempobsfile}" == x ]]; then 
            echo "Error! Failed to find \"${tempobsfile}\"!"
        fi
        # 
        # prepare data reduction script
        # 
        echo "#!/bin/bash"                                                                                                  >  "run_sdf_convert_script.bash"
        echo "# "                                                                                                           >> "run_sdf_convert_script.bash"
        echo "ln -fs \"${tempobsfile}\" a.sdf"                                                                              >> "run_sdf_convert_script.bash"
        echo -n "/home/dzliu/Work/20160325-JCMT-HARP-HCN/JCMT_Harp_ndf2fits_to_GILDAS_CLASS_Conversion/do_sdf_convert "     >> "run_sdf_convert_script.bash"
        echo -n "-input a -out b "                                                                                          >> "run_sdf_convert_script.bash"
        echo -n "-linefreq 354.5 "                                                                                          >> "run_sdf_convert_script.bash"
        echo ""                                                                                                             >> "run_sdf_convert_script.bash"
        echo ""                                                                                                             >> "run_sdf_convert_script.bash"
        chmod +x "run_sdf_convert_script.bash"
        cat "run_sdf_convert_script.bash"
        ./"run_sdf_convert_script.bash" | tee "run_sdf_convert_script.log"
        # 
        # cd back
        # 
        cd ".."
        #break #<TODO><DEBUG>#
    done
done

