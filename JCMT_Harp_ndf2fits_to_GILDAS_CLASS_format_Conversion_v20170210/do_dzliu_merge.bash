#!/bin/bash
#

source ~/Softwares/GILDAS/SETUP.bash

List_of_Spec=($(ls -1d ../tagged/a*.jcmt_tag_base.jcmt))


rm "Scan_merged.30m" 2>/dev/null


echo ""                                                 >  "do_dzliu_merge.class"
echo "file out Scan_merged single"                      >> "do_dzliu_merge.class"
echo "define double linefreq"                           >> "do_dzliu_merge.class"
echo "define double linewidth"                          >> "do_dzliu_merge.class"
echo "let linefreq '354.5054779/(1.0+0.000811)'"        >> "do_dzliu_merge.class"
echo "let linewidth 400"                                >> "do_dzliu_merge.class"
echo ""                                                 >> "do_dzliu_merge.class"


for (( i=0; i<${#List_of_Spec[@]}; i++ )); do
    ln -fs "${List_of_Spec[i]}" "Scan_${i}.30m"
    echo ""                                             >> "do_dzliu_merge.class"
    echo "file in Scan_${i}"                            >> "do_dzliu_merge.class"
    echo "find"                                         >> "do_dzliu_merge.class"
    echo "for i 1 to found"                             >> "do_dzliu_merge.class"
    echo "    if i.EQ.1 then"                           >> "do_dzliu_merge.class"
    echo "        get first"                            >> "do_dzliu_merge.class"
    echo "    else"                                     >> "do_dzliu_merge.class"
    echo "        get next"                             >> "do_dzliu_merge.class"
    echo "    end if"                                   >> "do_dzliu_merge.class"
    echo "    set unit V"                               >> "do_dzliu_merge.class"
    printf "    say window '%s' '%s' '%s' '%s' '%s' '%s'\n" \
           "(-R%HEAD%SPE%NCHAN*abs(R%HEAD%SPE%FRES)/2+00)/abs(R%HEAD%SPE%FRES)*abs(R%HEAD%SPE%VRES)+R%HEAD%SPE%VOFF" \
           "(-R%HEAD%SPE%NCHAN*abs(R%HEAD%SPE%FRES)/2+30)/abs(R%HEAD%SPE%FRES)*abs(R%HEAD%SPE%VRES)+R%HEAD%SPE%VOFF" \
           "(+R%HEAD%SPE%NCHAN*abs(R%HEAD%SPE%FRES)/2-30)/abs(R%HEAD%SPE%FRES)*abs(R%HEAD%SPE%VRES)+R%HEAD%SPE%VOFF" \
           "(+R%HEAD%SPE%NCHAN*abs(R%HEAD%SPE%FRES)/2-00)/abs(R%HEAD%SPE%FRES)*abs(R%HEAD%SPE%VRES)+R%HEAD%SPE%VOFF" \
           "(linefreq*1e3-linewidth/2.99792458e5*linefreq*1e3/2-R%HEAD%SPE%RESTF)/sqrt(R%HEAD%SPE%FRES*R%HEAD%SPE%FRES)*sqrt(R%HEAD%SPE%VRES*R%HEAD%SPE%VRES)+R%HEAD%SPE%VOFF" \
           "(linefreq*1e3+linewidth/2.99792458e5*linefreq*1e3/2-R%HEAD%SPE%RESTF)/sqrt(R%HEAD%SPE%FRES*R%HEAD%SPE%FRES)*sqrt(R%HEAD%SPE%VRES*R%HEAD%SPE%VRES)+R%HEAD%SPE%VOFF" \
           >> "do_dzliu_merge.class"
           # left +00 channels
           # left +30 channels
           # right -30 channels
           # right -00 channels
           # line center - line width/2.0
           # line center + line width/2.0
    printf "    set window '%s' '%s' '%s' '%s' '%s' '%s'\n" \
           "(-R%HEAD%SPE%NCHAN*abs(R%HEAD%SPE%FRES)/2+00)/abs(R%HEAD%SPE%FRES)*abs(R%HEAD%SPE%VRES)+R%HEAD%SPE%VOFF" \
           "(-R%HEAD%SPE%NCHAN*abs(R%HEAD%SPE%FRES)/2+30)/abs(R%HEAD%SPE%FRES)*abs(R%HEAD%SPE%VRES)+R%HEAD%SPE%VOFF" \
           "(+R%HEAD%SPE%NCHAN*abs(R%HEAD%SPE%FRES)/2-30)/abs(R%HEAD%SPE%FRES)*abs(R%HEAD%SPE%VRES)+R%HEAD%SPE%VOFF" \
           "(+R%HEAD%SPE%NCHAN*abs(R%HEAD%SPE%FRES)/2-00)/abs(R%HEAD%SPE%FRES)*abs(R%HEAD%SPE%VRES)+R%HEAD%SPE%VOFF" \
           "(linefreq*1e3-linewidth/2.99792458e5*linefreq*1e3/2-R%HEAD%SPE%RESTF)/sqrt(R%HEAD%SPE%FRES*R%HEAD%SPE%FRES)*sqrt(R%HEAD%SPE%VRES*R%HEAD%SPE%VRES)+R%HEAD%SPE%VOFF" \
           "(linefreq*1e3+linewidth/2.99792458e5*linefreq*1e3/2-R%HEAD%SPE%RESTF)/sqrt(R%HEAD%SPE%FRES*R%HEAD%SPE%FRES)*sqrt(R%HEAD%SPE%VRES*R%HEAD%SPE%VRES)+R%HEAD%SPE%VOFF" \
           >> "do_dzliu_merge.class"
    echo "    set unit F"                                                                                                     >> "do_dzliu_merge.class"
    echo "    draw window"                                                                                                    >> "do_dzliu_merge.class"
    echo "    base /continuum /pl ! /continuum"                                                                               >> "do_dzliu_merge.class"
    echo "    resample 1024 512 'linefreq*1e3' 0.9 FREQUENCY ! channel number 1024, channel ref 512, channel width 0.9MHz"   >> "do_dzliu_merge.class"
    echo "    write"                                >> "do_dzliu_merge.class"
    echo "next"                                     >> "do_dzliu_merge.class"
    echo ""                                         >> "do_dzliu_merge.class"
done

echo "class @do_dzliu_merge.class"
echo "@do_dzliu_merge.class" | class


cp "/Users/dzliu/Work/SpireLines/Works/MALATANG_JCMT_to_GILDAS/JCMT_Harp_ndf2fits_to_GILDAS_CLASS_format_Conversion_v20170210/gildas-class-autoclick.greg" \
   .

echo ""                                 >  "do_dzliu_autoclick.class"
echo "let name Scan_merged"             >> "do_dzliu_autoclick.class"
echo "@gildas-class-autoclick"          >> "do_dzliu_autoclick.class"
echo ""                                 >> "do_dzliu_autoclick.class"


rm "Scan_gridded.30m" 2>/dev/null


echo ""                                                                             >  "do_dzliu_xymap.class"
echo "file in Scan_merged"                                                          >> "do_dzliu_xymap.class"
echo "find"                                                                         >> "do_dzliu_xymap.class"
echo "consist /nocheck pos"                                                         >> "do_dzliu_xymap.class"
echo ""                                                                             >> "do_dzliu_xymap.class"
echo "let name Scan_gridded"                                                        >> "do_dzliu_xymap.class"
echo "let type lmv"                                                                 >> "do_dzliu_xymap.class"
echo "TABLE 'name' NEW /FREQUENCY \"HCN(3-2)\" '354.5054779/(1.0+0.000811)*1e3'"    >> "do_dzliu_xymap.class"
echo "XY_MAP 'name'"                                                                >> "do_dzliu_xymap.class"
echo "go view"                                                                      >> "do_dzliu_xymap.class"
echo "hardcopy 'name'.hardcopy.eps /overwrite"                                      >> "do_dzliu_xymap.class"
echo ""                                                                             >> "do_dzliu_xymap.class"
echo ""                                                                             >> "do_dzliu_xymap.class"








