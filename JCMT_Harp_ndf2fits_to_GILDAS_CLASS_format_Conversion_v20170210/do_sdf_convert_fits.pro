PRO do_sdf_convert_fits, InputFitsFile
    
    ; Aim:
    ;   
    ;   Convert the fits file generated by JCMT starlink ndf2fits task
    ;   to the GILDAS CLASS readable format. 
    ;   
    ;   The input fits file should be single receptor data 
    ;     wcsattrib "aaa.sdf" set sideband USB # (LSB)
    ;     wcsattrib "aaa.sdf" set system freq
    ;     ndfcopy aaa(,0,) bbb.sdf exten trim trimwcs
    ;     fits bbb ccc.fits allowtab comp=d encoding="fits-wcs"
    ;   
    ; Usage:
    ;   idl -e "do_sdf_convert_fits" -args 'ccc.fits'
    ;   
    ; Last update:
    ;   2016-03-04 dzliu
    ;   2016-03-04 dzliu Pointing RA Dec done
    ;   2017-02-11 dzliu Tsys, RXB3I
    ;   
    ; Issue to do: 
    ;   
    
    ; 
    ; Resolve all dependent procedures
    resolve_all, /quiet
    
    ; 
    ; debug_level 0,1,2,3,4,...
    debug_level = 1
    
    ; 
    ; Prepare to read command line arguments
    args = command_line_args(count=nargs)
    IF nargs GT 0 THEN InputFitsFile = args[0]
    
    ; 
    ; Check necessary data files
    ; -- SourceName_receptorXX.fits
    ; -- SourceName_receptors.fits
    ; -- SourceName_receptorXX_wcs.fits
    InputFitsName = FILE_BASENAME(InputFitsFile,'.fits')
    InputReceptor = STRMID(InputFitsName,STRPOS(InputFitsName,'_receptor',/REVERSE_SEARCH)+STRLEN('_receptor'))
    JCMTReceptors = STRMID(InputFitsName,0,STRPOS(InputFitsName,'_',/REVERSE_SEARCH))+'_receptors.fits'
    BaseFitsName  = STRMID(InputFitsName,0,STRPOS(InputFitsName,'_',/REVERSE_SEARCH))
    IF NOT FILE_TEST(InputFitsName+'_wcs.fits') THEN BEGIN
        MESSAGE, 'Error! The receptor wcs catalog file "'+InputFitsName+'_wcs.fits'+'" does not exist!'
        RETURN
    ENDIF
    IF NOT FILE_TEST(JCMTReceptors) THEN BEGIN
        MESSAGE, 'Error! The JCMT receptors catalog fits file "'+JCMTReceptors+'" does not exist!'
    ENDIF
    IF debug_level GE 1 THEN BEGIN
        PRINT, 'Input receptors scan data fits file: '+InputFitsName+'.fits'
        PRINT, 'Input receptors scan wcs fits file: '+InputFitsName+'_wcs.fits'
        PRINT, 'Input receptors catalog fits file: '+JCMTReceptors
    ENDIF
    
    ; 
    ; Read JCMT receptors scan wcs information from InputFitsName+'_wcs.fits'
    IF debug_level GE 1 THEN BEGIN
        PRINT, 'Reading WCS information in '+InputFitsName+'_wcs.fits'
        IF debug_level GE 2 THEN BEGIN 
            fits_info, InputFitsName+'_wcs.fits'
        ENDIF
    ENDIF
    fits_read, InputFitsName+'_wcs.fits', receptors_data, receptors_header
    
    ; 
    ; Read JCMT receptors scan data from InputFitsName+'.fits' (original calibrated scan data)
    IF debug_level GE 1 THEN BEGIN
        PRINT, 'Reading scan data in '+InputFitsName+'.fits'
        IF debug_level GE 2 THEN BEGIN 
            fits_info, InputFitsName+'.fits'
        ENDIF
    ENDIF
    ;data = mrdfits(InputFitsName+'.fits', 0, header) ; this some times does not work
    fits_read, InputFitsName+'.fits', data, header
    
    ; 
    ; Extract telescope pointing (central reference receptors) RA Dec
    IF debug_level GE 1 THEN BEGIN
        PRINT, 'Extracting telescope pointing (central reference receptor) RA Dec '
    ENDIF
    IF FIX(sxpar(header,'NAXIS')) GE 4 THEN BEGIN
        header_RA = double(sxpar(header,'CRVAL3')) ; RA -- this is not current Receptor's RA but central Receptor's RA!
        header_Dec = double(sxpar(header,'CRVAL4')) ; Dec -- this is not current Receptor's Dec but central Receptor's Dec!
        header_dRA = double(sxpar(header,'CDELT3')) ; degree
        header_dDec = double(sxpar(header,'CDELT4')) ; degree
    ENDIF ELSE BEGIN
        IF FIX(sxpar(header,'NAXIS')) EQ 1 AND FIX(sxpar(header,'WCSAXES')) EQ 3 THEN BEGIN
            header_RA = double(sxpar(header,'CRVAL2')) ; RA -- this is not current Receptor's RA but central Receptor's RA!
            header_Dec = double(sxpar(header,'CRVAL3')) ; Dec -- this is not current Receptor's Dec but central Receptor's Dec!
            header_dRA = double(sxpar(header,'CDELT2')) ; degree
            header_dDec = double(sxpar(header,'CDELT3')) ; degree
        ENDIF ELSE $
        IF FIX(sxpar(header,'NAXIS')) EQ 2 AND FIX(sxpar(header,'WCSAXES')) EQ 4 THEN BEGIN
            header_RA = double(sxpar(header,'CRVAL3')) ; RA -- this is not current Receptor's RA but central Receptor's RA!
            header_Dec = double(sxpar(header,'CRVAL4')) ; Dec -- this is not current Receptor's Dec but central Receptor's Dec!
            header_dRA = double(sxpar(header,'CDELT3')) ; degree
            header_dDec = double(sxpar(header,'CDELT4')) ; degree
        ENDIF ELSE $
        BEGIN
            PRINT, "Header NAXIS =", sxpar(header,'NAXIS')
            PRINT, "Header WCSAXES =", sxpar(header,'WCSAXES')
            ;PRINT, header,'NAXIS'
            MESSAGE, 'Error! Could not determine the RA Dec from fits header!'
            ;SPAWN, 'sleep 120'
        ENDELSE
    ENDELSE
    header_text = STRING(format='(A10,A10,A15,A15,A10,A10,A10,A5,A)', "Receptor", "Scan", "RA", "Dec", "OffRA", "OffDec", "Label", " ", InputFitsName+'.fits')
    header_line = STRJOIN(REPLICATE('-',STRLEN(header_text)),'')
    ;print, header_line
    ;print, header_text
    ;print, header_line
    
    ; 
    ; Extract dimensions of the scan data
    ; -- dimension 0 is channel axis
    ; -- dimension 1 is subscan axis
    IF size(data,/n_dim) EQ 1 THEN BEGIN
        data = REFORM(data,[(size(data,/dim))[0],1])
    ENDIF
    naxis1 = (size(data,/dim))[0] ; this is channel axis
    naxis2 = (size(data,/dim))[1] ; this is subscan axis
    IF debug_level GE 1 THEN BEGIN
        PRINT, 'Extracting dimensions of the scan data: '+STRTRIM(naxis1,2)+' x '+STRTRIM(naxis2,2)
    ENDIF
    
    ; 
    ; Convert to double
    data = double(data)
    
    ; 
    ; Extract subscan RA Dec from the scan wcs fits file InputFitsName+'_wcs.fits'
    ; -- by looping subscans
    IF size(receptors_data,/n_dim) EQ 1 THEN BEGIN
        receptors_data = REFORM(receptors_data,[(size(receptors_data,/dim))[0],1])
    ENDIF
    IF debug_level GE 1 THEN BEGIN
        PRINT, 'Extracting RA Dec Label of each subscan data'
    ENDIF
    receptors_naxis1 = (size(receptors_data,/dim))[0] ; this is receptor label ra dec axis
    receptors_naxis2 = (size(receptors_data,/dim))[1] ; this is receptor subscan axis
    receptors_nrecep = 0
    receptors_ID = make_array(receptors_naxis2,/int,value=0)
    receptors_RA = make_array(receptors_naxis2,/double,value=0.0)
    receptors_Dec = make_array(receptors_naxis2,/double,value=0.0)
    receptors_Lab = make_array(receptors_naxis2,/string,value='') ; the Label of the receptor
    ;print, header_line
    ;print, header_text
    ;print, header_line
    j = 0
    for i=0,receptors_naxis2-1 do begin
        ; Extract subscan RA, Dec and Label
        ; -- subscan RA Dec Label data structure
        ; -- receptor_ID: [0:3] bytes
        ; -- receptor_RA: [4:11] bytes
        ; -- receptor_Dec: [12:19] bytes
        ; -- receptor_Label: [20:22] bytes
        IF debug_level GE 5 THEN BEGIN
            PRINT, (receptors_data)
        ENDIF
        receptor_ID   =    (fix(reverse(receptors_data[00:03,i]),0,1))[0]
        receptor_RA   = (double(reverse(receptors_data[04:11,i]),0,1))[0]/!PI*180.0 ; convert byte to double, offset=0byte, length=1number, convert radians to degrees
        receptor_Dec  = (double(reverse(receptors_data[12:19,i]),0,1))[0]/!PI*180.0 ; convert byte to double, offset=0byte, length=1number, convert radians to degrees
        
        ; Extract subscan Label, considering different situations for RxA / HARP
        ;<20160722><dzliu><RxA3-ACSIS>; 
        ;<20170211><dzliu><RXB3I>; 
        receptor_Lab = strtrim(string(receptors_data[20:*,i]),2)
        ;IF N_ELEMENTS(receptors_data) GT 22 THEN BEGIN
        ;    receptor_Lab = strtrim(string(receptors_data[20:22,i]),2)
        ;ENDIF ELSE BEGIN
        ;    receptor_Lab = strtrim(string(receptors_data[20:*,i]),2) ; strtrim(sxpar(header,'INSTRUME'),2) ; 
        ;ENDELSE
        
        receptors_ID[j] = receptor_ID
        receptors_RA[j] = receptor_RA
        receptors_Dec[j] = receptor_Dec
        receptors_Lab[j] = STRING(FORMAT='(A15)',receptor_Lab)
        
        j+=1
        
        ;<20160722>if i lt 14 then begin
          ;if receptor_Lab eq "H00" then print, format='(A50)', '('+STRING(FORMAT='(I0)',receptors_nrecep)+')'
          ;if receptor_Lab eq "H00" then receptors_nrecep=1 else receptors_nrecep+=1
          ;<20160722>print, FORMAT='(A10,I10,F15.7,F15.7,A10)', InputReceptor, receptor_ID, receptor_RA, receptor_Dec, receptor_Lab
        ;<20160722>endif
    endfor
    print, 'Writing to wcs file '+InputFitsName+'_wcs.txt'+' for the record.'
    writecol, InputFitsName+'_wcs.txt', receptors_ID, receptors_RA, receptors_Dec, receptors_Lab
    ;return
    
    ; 
    ; Extract Tsys from "SourceName_receptorHXX_TSYS.txt"
    ; <added><20161101><dzliu><zyzhang>
    ; 
    IF strtrim(string(sxpar(header,'MEDTSYS')),2) NE '' AND strtrim(string(sxpar(header,'MEDTSYS')),2) NE '/' THEN BEGIN
        receptor_Tsys = DOUBLE(sxpar(header,'MEDTSYS'))
    ENDIF ELSE BEGIN
        receptor_Tsys = -99
    ENDELSE
    receptor_Tsys_FileName = BaseFitsName+'_receptor'+receptor_Lab+'_TSYS.txt'
    print, 'Checking Tsys file '+receptor_Tsys_FileName
    IF FILE_TEST(receptor_Tsys_FileName) THEN BEGIN
        print, 'Reading Tsys from '+receptor_Tsys_FileName
        readcol, receptor_Tsys_FileName, format='(d)', temp_col
        receptor_Tsys = temp_col[0]
    ENDIF
    
    ; 
    ; Loop each subscan and change the data format
    ; old data format of each subscan is 
    ; XTENSION= 'BINTABLE'                                                            
    ; BITPIX  =                    8                                                  
    ; NAXIS   =                    2                                                  
    ; NAXIS1  =                 6240                                                  
    ; NAXIS2  =                    1                                                  
    ; PCOUNT  =                    0                                                  
    ; GCOUNT  =                    1                                                  
    ; TFIELDS =                    1                                                  
    ; TFORM1  = '780D    '                                                            
    ; TTYPE1  = 'COORDS2 '                                                            
    ; TUNIT1  = 'd       '                                                            
    ; TDIM1   = '(1,780) '                                                            
    ; new data format of each subscan is:
    ; TTYPE1  = 'TELESCOP'
    ; TFORM1  = '12A'
    ; TTYPE2  = 'CDELT2'
    ; TFORM2  = '1D'
    ; TTYPE3  = 'CDELT3'
    ; TFORM3  = '1D'
    ; TTYPE4  = 'SPECTRUM'
    ; TFORM4  = STRING(naxis1)+'D'
    datanew = make_array(((naxis1+1+1)*8+12),naxis2,/byte,value=0)
    if naxis2 eq 1 then datanew = REFORM(datanew,[N_ELEMENTS(datanew),1]) ;<fixed><20170211><dzliu><RXB3I>;
    for i=0,naxis2-1 do begin
        ; see website: Packing Floats into a Byte Array
        ; see class.pdf 4.4.1 4.4.2
        offset_RA = double(-(receptors_RA[i]-header_RA)*COS(header_Dec/180.0D*!PI)/header_dRA+1) ; Overides CRPIX, in unit of CDELT
        offset_Dec = double(-(receptors_Dec[i]-header_Dec)/header_dDec+1)                        ; Overides CRPIX, in unit of CDELT ;<NOTE>; the minus sign is a bug??? +1 because CRVAL3/4 is 1 not 0
        ;offset_RA = double(-(receptors_RA[i]-header_RA)*COS(header_Dec/180.0D*!PI)/180.0*!PI)   ; Overides CRPIX, in unit of radians
        ;offset_Dec = double(+(receptors_Dec[i]-header_Dec)/180.0*!PI)                           ; Overides CRPIX, in unit of radians ;<NOTE>; the minus sign is a bug??? +1 because CRVAL3/4 is 1 not 0
        ;CDELT_RA = double(receptors_RA[i]-header_RA)*COS(header_Dec/180.0D*!PI)                 ; Overides CDELT
        ;CDELT_Dec = double(receptors_Dec[i]-header_Dec)                                         ; Overides CDELT
        
        ; print message
        IF i EQ 0 THEN print, ''
        IF i EQ 0 THEN print, FORMAT='(A10,A10,A15,A15,A15,A15,A12,A12,A10)', "receptor", "ID", "refRA", "refDec", "subscanRA", "subscanDec", "offRA", "offDec", "Label"
        IF i GE 0 THEN print, FORMAT='(A10,I10,F15.7,F15.7,F15.7,F15.7,F12.3,F12.3,A10)', InputReceptor, receptor_ID, header_RA, header_Dec, receptors_RA[i], receptors_Dec[i], offset_RA, offset_Dec, receptor_Lab
        
        ; store bytes
        ; -- Hex4bit 1,2,3
        ; -- Hex4bit 4,5
        ; -- Hex4bit 6,7
        ; -- Hex4bit 8,9~...
        datanew[00:11,i] = byte(STRING(FORMAT='(A-12)','JCMT')) ;<fixed><20160318><dzliu>; byte(STRING(FORMAT='(A12)','JCMT'))
        datanew[12:19,i] = reverse(byte(offset_RA,0,8,1)) ; offset_RA ; receptors_RA[i]
        datanew[20:27,i] = reverse(byte(offset_Dec,0,8,1)) ; offset_Dec ; receptors_Dec[i]
        IF debug_level GE 5 THEN BEGIN
            PRINT, ''
            PRINT, format='(A10,2A15,A3,A16,A3,A16)', 'receptor', 'offset_RA', 'offset_Dec', ' ', 'offRA_hex', ' ', 'offDec_hex'
            PRINT, format='(I10,2F15.7,A3,8Z02,A3,8Z02)', InputReceptor, offset_RA, offset_Dec, ' ', byte(offset_RA,0,8,1), ' ', byte(offset_Dec,0,8,1)
        ENDIF
        ;datanew[28:((naxis1+1+1)*8+12)-1,i] = byte(data[*,i],0,8,naxis1)
        for j=0,naxis1-1 do begin
            datanew[28+j*8+0:28+j*8+7,i] = reverse(byte(data[j,i],0,8,1)) ; reverse the 8 bytes
            IF debug_level GE 5 THEN BEGIN
                if j EQ 0 THEN PRINT, ''
                if j EQ 0 THEN PRINT, format='(A10,A15,A30,A10,A16)', 'receptor', 'channel', 'value', ' ', 'hex'
                if j GE 0 THEN PRINT, format='(I10,I15,G30,A10,8Z02)', i, j, data[j,i], ' ', byte(data[j,i],0,8,1)
            ENDIF
            ;break
        endfor
        ;break
    endfor
    
    ; 
    ; Modify final header and output
    IF FILE_TEST(InputFitsName+'_class.fits') THEN BEGIN
        spawn, 'mv '+InputFitsName+'_class.fits'+' '+'backup.'+InputFitsName+'_class.fits'
    ENDIF
    
    mkhdr, headernew, 0, /EXTEND
    fits_open, InputFitsName+'_class.fits', fcbnew, /write
    fits_write, fcbnew, 0, headernew, /no_data
    fits_close, fcbnew
    
    fxbhmake, headernew, naxis2, 'MATRIX', ' GILDAS readable format ', extver=1
    ;print, headernew
    sxaddpar, headernew, 'NAXIS', 2    ;<TODO><DELETE>;
    sxaddpar, headernew, 'NAXIS1', ((naxis1+1+1)*8+12) ; bytes    ;<TODO><DELETE>;
    sxaddpar, headernew, 'NAXIS2', 4    ;<TODO><DELETE>;
    sxaddpar, headernew, 'MAXIS', 4
    sxaddpar, headernew, 'MAXIS1', naxis1 ; channels
    sxaddpar, headernew, 'MAXIS2', 1
    sxaddpar, headernew, 'MAXIS3', 1
    sxaddpar, headernew, 'MAXIS4', 1
    sxaddpar, headernew, 'BUNIT', 'K'
    sxaddpar, headernew, 'CTYPE1', 'FREQ'
    sxaddpar, headernew, 'CUNIT1', 'Hz' ; sxpar(header,'CUNIT1') -- sdf CUNIT1 is GHz, here we convert to Hz
    sxaddpar, headernew, 'CDELT1', double(sxpar(header,'CDELT1'))*1d9 ; this is the frequency axis increment in Hz
    sxaddpar, headernew, 'CRPIX1', double(sxpar(header,'CRPIX1')) ;<todo><20160702><dzliu>; REFCHAN !=? CRPIX1 why this can happen in some data?
    ;sxaddpar, headernew, 'CRVAL1', double(sxpar(header,'CRVAL1'))*1d9
    sxaddpar, headernew, 'CRVAL1', 0.0D ;<fixed><20160702><dzliu>; RESTFREQ -- CRVAL1 -- Frequency offset, always 0. See gildas/doc/pdf/class.pdf PDFPage54 BookPage46 Section 4.4.2.
    sxaddpar, headernew, 'CTYPE2', 'RA---TAN' ;<bug><fixed><20160702>; '--TAN'
    sxaddpar, headernew, 'CDELT2', header_dRA
    sxaddpar, headernew, 'CRPIX2', 1.0D ; double(sxpar(header,'CRPIX3')) ; sdf CRPIX3 --> class CRPIX2 ; Overriden by TTYPE2
    sxaddpar, headernew, 'CRVAL2', header_RA
    sxaddpar, headernew, 'CTYPE3', 'DEC--TAN' ;<bug><fixed><20160702>; '--TAN'
    sxaddpar, headernew, 'CDELT3', header_dDec
    sxaddpar, headernew, 'CRPIX3', 1.0D ; double(sxpar(header,'CRPIX4')) ; sdf CRPIX4 --> class CRPIX3 ; Overriden by TTYPE3
    sxaddpar, headernew, 'CRVAL3', header_Dec
    sxaddpar, headernew, 'CTYPE4', 'STOKES'
    sxaddpar, headernew, 'CDELT4', 0.0D ; 
    sxaddpar, headernew, 'CRPIX4', 0.0D ; 
    sxaddpar, headernew, 'CRVAL4', 0.0D ; 
    sxaddpar, headernew, 'PCOUNT', 0
    sxaddpar, headernew, 'GCOUNT', 1
    sxaddpar, headernew, 'TFIELDS', 4
    sxaddpar, headernew, 'TTYPE1', 'TELESCOP'
    sxaddpar, headernew, 'TFORM1', '12A'
    sxaddpar, headernew, 'TTYPE2', 'CRPIX2'
    sxaddpar, headernew, 'TFORM2', '1D'
    sxaddpar, headernew, 'TTYPE3', 'CRPIX3'
    sxaddpar, headernew, 'TFORM3', '1D'
    sxaddpar, headernew, 'TTYPE4', 'SPECTRUM'
    sxaddpar, headernew, 'TFORM4', STRING(FORMAT='(I0)',naxis1)+'D'
    sxaddpar, headernew, 'ORIGIN',   sxpar(header,'ORIGIN')
    sxaddpar, headernew, 'DATE',     sxpar(header,'DATE')
    sxaddpar, headernew, 'TELESCOP', strtrim(sxpar(header,'TELESCOP'),2)
    sxaddpar, headernew, 'LONG-OBS',  sxpar(header,'LONG-OBS'), ' [deg] East longitude of observatory '
    sxaddpar, headernew, 'LAT-OBS',  sxpar(header,'LAT-OBS'), ' [deg] Latitude of Observatory '
    sxaddpar, headernew, 'ALT-OBS',  sxpar(header,'ALT-OBS'), ' [m] Height of observatory above sea level '
    sxaddpar, headernew, 'OBSGEO-X',  sxpar(header,'OBSGEO-X'), ' [m] '
    sxaddpar, headernew, 'OBSGEO-Y',  sxpar(header,'OBSGEO-Y'), ' [m] '
    sxaddpar, headernew, 'OBSGEO-Z',  sxpar(header,'OBSGEO-Z'), ' [m] '
    sxaddpar, headernew, 'BEAMEFF',  sxpar(header,'ETAL'), ' Telescope efficiency '
    sxaddpar, headernew, 'FORWEFF',  1.0D, ' Forward efficiency (TODO) '
    sxaddpar, headernew, 'PROJECT',  STRTRIM(sxpar(header,'PROJECT'),2)
    sxaddpar, headernew, 'OBJECT',   STRTRIM(sxpar(header,'OBJECT'),2)
    sxaddpar, headernew, 'OBSNUM',   sxpar(header,'OBSNUM')
    sxaddpar, headernew, 'SUBSCAN',  sxpar(header,'NSUBSCAN')
    sxaddpar, headernew, 'NSUBSCAN', sxpar(header,'NSUBSCAN')
    sxaddpar, headernew, 'UTDATE',   sxpar(header,'UTDATE')
    sxaddpar, headernew, 'DATE-OBS', sxpar(header,'DATE-OBS')
    sxaddpar, headernew, 'DATE-END', sxpar(header,'DATE-END')
    sxaddpar, headernew, 'ZSOURCE',  sxpar(header,'ZSOURCE')
    ;sxaddpar, headernew, 'VELOSYS',  sxpar(header,'VELOSYS')
    sxaddpar, headernew, 'EPOCH',    2000D
    ;sxaddpar, headernew, 'RESTFREQ', 0.0D, ' Rest frequency (Hz) ' ;<fixed><20160318><dzliu>;
    ;sxaddpar, headernew, 'RESTFREQ', sxpar(header,'RESTFRQ'), ' Rest frequency (Hz) ' ;<fixed><20160702><dzliu>; RESTFREQ -- CRVAL1
    sxaddpar, headernew, 'RESTFREQ', double(sxpar(header,'CRVAL1'))*1d9, ' Rest frequency (Hz) ' ;<fixed><20160702><dzliu>; RESTFREQ -- CRVAL1
    sxaddpar, headernew, 'RESTFRQ',  sxpar(header,'RESTFRQ'), ' Rest frequency (Hz) '
    sxaddpar, headernew, 'IMAGFREQ', sxpar(header,'IMAGFREQ'), ' Image frequency (Hz) '
    ;sxaddpar, headernew, 'DSBCEN_A', sxpar(header,'DSBCEN_A'), ' Central frequency (Hz topo) '
    ;sxaddpar, headernew, 'VLSR',     sxpar(header,'IMAGFREQ'), ' Velocity of ref. channel '
    ;sxaddpar, headernew, 'DELTAV',   sxpar(header,'IMAGFREQ'), ' Velocity resolution '
    sxaddpar, headernew, 'INSTRUME', STRTRIM(sxpar(header,'INSTRUME'),2)
    sxaddpar, headernew, 'BACKEND',  STRTRIM(sxpar(header,'BACKEND'),2)
    sxaddpar, headernew, 'SPECSYS',  STRTRIM(sxpar(header,'SPECSYS'),2)
    sxaddpar, headernew, 'SSYSSRC',  STRTRIM(sxpar(header,'SSYSSRC'),2)
    sxaddpar, headernew, 'SSYSOBS',  STRTRIM(sxpar(header,'SSYSOBS'),2)
    sxaddpar, headernew, 'SB_MODE',  STRTRIM(sxpar(header,'SB_MODE'),2)
    sxaddpar, headernew, 'OBS_SB',   STRTRIM(sxpar(header,'OBS_SB'),2)
    sxaddpar, headernew, 'SAM_MODE', STRTRIM(sxpar(header,'SAM_MODE'),2), ' Sampling Mode '
    sxaddpar, headernew, 'SW_MODE',  STRTRIM(sxpar(header,'SW_MODE'),2), ' Switch Mode: CHOP, PSSW, NONE, etc '
    sxaddpar, headernew, 'OBS_SB',   STRTRIM(sxpar(header,'OBS_SB'),2)
    sxaddpar, headernew, 'DRRECIPE', STRTRIM(sxpar(header,'DRRECIPE'),2), ' ACSIS-DR recipe name '
    sxaddpar, headernew, 'MSROOT',   STRTRIM(sxpar(header,'MSROOT'),2), ' Root name of raw measurement sets '
    sxaddpar, headernew, 'BWMODE',   STRTRIM(sxpar(header,'BWMODE'),2), ' ACSIS total bandwidth set up '
    sxaddpar, headernew, 'SUBSYSNR', sxpar(header,'SUBSYSNR'), ' Sub-system number '
    sxaddpar, headernew, 'SUBBANDS', sxpar(header,'SUBBANDS'), ' ACSIS sub-band set up '
    sxaddpar, headernew, 'NSUBBAND', sxpar(header,'NSUBBAND'), ' Number of subbands '
    sxaddpar, headernew, 'SUBREFP1', sxpar(header,'SUBREFP1'), ' Reference channel for subband1 '
    ;sxaddpar, headernew, 'SUBREFP2', sxpar(header,'SUBREFP2'), ' Reference channel for subband2 '
    sxaddpar, headernew, 'NCHNSUBS', sxpar(header,'NCHNSUBS'), ' No. of channels in this sub-system '
    sxaddpar, headernew, 'REFCHAN',  sxpar(header,'REFCHAN'), ' Reference IF channel No. ' ;<todo><20160702><dzliu>; REFCHAN !=? CRPIX1 why this can happen in some data?
    sxaddpar, headernew, 'IFCHANSP', sxpar(header,'IFCHANSP'), ' [Hz] TOPO IF channel frequency spacing (signed) '
    sxaddpar, headernew, 'DELTAF',   0.0d, ' [Hz] Frequency offset from phase center '
    sxaddpar, headernew, 'FFT_WIN',  STRTRIM(sxpar(header,'FFT_WIN'),2), ' Type of window used for FFT '
    sxaddpar, headernew, 'BEDEGFAC', sxpar(header,'BEDEGFAC'), ' Backend degradation factor '
    sxaddpar, headernew, 'IFFREQ',   sxpar(header,'IFFREQ'), ' [GHz] IF Frequency '
    sxaddpar, headernew, 'N_MIX',    sxpar(header,'N_MIX'), ' No. of mixers '
    sxaddpar, headernew, 'LOFREQS',  sxpar(header,'LOFREQS'), ' [GHz] LO Frequency at start of obs. '
    sxaddpar, headernew, 'LOFREQE',  sxpar(header,'LOFREQE'), ' [GHz] LO Frequency at end of obs. '
    sxaddpar, headernew, 'RECPTORS', STRTRIM(sxpar(header,'RECPTORS'),2), ' Active FE '
    sxaddpar, headernew, 'REFRECEP', STRTRIM(sxpar(header,'REFRECEP'),2), ' Receptor with unit sensitivity '
    sxaddpar, headernew, 'MEDTSYS',  sxpar(header,'MEDTSYS'), ' [K] Median of the T_sys across all pixels '
    ;<updated><20161101><dzliu><zyzhang>; sxaddpar, headernew, 'TSYS',     sxpar(header,'MEDTSYS'), ' [K] Median of the T_sys across all pixels '
    sxaddpar, headernew, 'TSYS',     receptor_Tsys, ' [K] The T_sys of current receptor '
    sxaddpar, headernew, 'TSPSTART', sxpar(header,'TSPSTART'), ' [K] Temperature of the building at start of observation '
    sxaddpar, headernew, 'TSPEND',   sxpar(header,'TSPEND'), ' [K] Temperature of the building at end of observation '
    sxaddpar, headernew, 'TEMPSCAL', STRTRIM(sxpar(header,'TEMPSCAL'),2), ' Temperature scale in use '
    sxaddpar, headernew, 'DOPPLER',  STRTRIM(sxpar(header,'DOPPLER'),2), ' Doppler velocity definition '
    sxaddpar, headernew, 'MOLECULE', STRTRIM(sxpar(header,'MOLECULE'),2)
    sxaddpar, headernew, 'TRANSITI', STRTRIM(sxpar(header,'TRANSITI'),2)
    sxaddpar, headernew, 'LINE',     STRTRIM(sxpar(header,'MOLECULE'),2)+'('+STRJOIN(STRSPLIT(sxpar(header,'TRANSITI'),' ',/EXTRACT),'')+')'
    sxaddpar, headernew, 'INSTAP',   STRTRIM(sxpar(header,'INSTAP'),2), ' Central Receptor '
    sxaddpar, headernew, 'INSTAP_X', sxpar(header,'INSTAP_X'), ' Central Receptor Offset X '
    sxaddpar, headernew, 'INSTAP_Y', sxpar(header,'INSTAP_Y'), ' Central Receptor Offset Y '
    sxaddpar, headernew, 'HUMSTART', sxpar(header,'HUMSTART'), ' Rel. Humidity at start '
    sxaddpar, headernew, 'HUMEND',   sxpar(header,'HUMEND'), ' Rel. Humidity at end '
    sxaddpar, headernew, 'WNDSPDST', sxpar(header,'WNDSPDST'), ' [km/h] Wind Speed at start '
    sxaddpar, headernew, 'WNDSPDEN', sxpar(header,'WNDSPDEN'), ' [km/h] Wind Speed at end '
    sxaddpar, headernew, 'WNDDIRST', sxpar(header,'WNDDIRST'), ' [deg] Wind direction, azimuth at start '
    sxaddpar, headernew, 'WNDDIREN', sxpar(header,'WNDDIREN'), ' [deg] Wind direction, azimuth at end '
    sxaddpar, headernew, 'AMSTART',  sxpar(header,'AMSTART')
    sxaddpar, headernew, 'AMEND',    sxpar(header,'AMEND')
    sxaddpar, headernew, 'AZSTART',  sxpar(header,'AZSTART')
    sxaddpar, headernew, 'ELSTART',  sxpar(header,'ELSTART')
    sxaddpar, headernew, 'ELEND',    sxpar(header,'ELEND')
    sxaddpar, headernew, 'HSTSTART', sxpar(header,'HSTSTART')
    sxaddpar, headernew, 'HSTEND',   sxpar(header,'HSTEND')
    sxaddpar, headernew, 'LSTSTART', sxpar(header,'LSTSTART')
    sxaddpar, headernew, 'LSTEND',   sxpar(header,'LSTEND')
    sxaddpar, headernew, 'INT_TIME', sxpar(header,'INT_TIME'), ' seconds '
    sxaddpar, headernew, 'EXP_TIME', sxpar(header,'EXP_TIME'), ' seconds '
    sxaddpar, headernew, 'OBSTIME',  sxpar(header,'INT_TIME'), ' seconds '
    sxaddpar, headernew, 'TCHOP',  0.0D, ' TODO '
    sxaddpar, headernew, 'TCOLD',  0.0D, ' TODO '
    sxaddpar, headernew, 'TAU225ST', sxpar(header,'TAU225ST'), ' Tau at 225 GHz from CSO at start '
    sxaddpar, headernew, 'TAU225EN', sxpar(header,'TAU225EN'), ' Tau at 225 GHz from CSO at end '
    sxaddpar, headernew, 'TAUDATST', sxpar(header,'TAUDATST'), ' Time of TAU225ST observation '
    sxaddpar, headernew, 'TAUDATEN', sxpar(header,'TAUDATEN'), ' Time of TAU225EN observation '
    sxaddpar, headernew, 'TAUSRC',   sxpar(header,'TAUSRC'),   ' Source of the TAU225 value '
    sxaddpar, headernew, 'TAU-ATM',  sxpar(header,'TAU225ST'), ' Tau at 225 GHz from CSO at start '
    sxaddpar, headernew, 'WVMTAUST', sxpar(header,'WVMTAUST'), ' 183.31 GHz Tau via WVM at start '
    sxaddpar, headernew, 'WVMTAUEN', sxpar(header,'WVMTAUEN'), ' 183.31 GHz Tau via WVM at end '
    sxaddpar, headernew, 'WVMDATST', sxpar(header,'WVMDATST'), ' Time of WVMTAUST '
    sxaddpar, headernew, 'WVMDATEN', sxpar(header,'WVMDATEN'), ' Time of WVMTAUEN '
    sxaddhist, ' ', headernew, /comment
    sxaddhist, 'Converted from JCMT HARP ndf2fits allowtab encoding fits-wcs ', headernew, /comment
    sxaddhist, 'format to GILDAS readable format', headernew, /comment
    sxaddhist, ' ', headernew, /comment
    sxaddhist, 'The full fits header information are in the original fits file ', headernew, /comment
    sxaddhist, InputFitsName+'.fits', headernew, /comment
    sxaddhist, ' ', headernew, /comment
    fits_open, InputFitsName+'_class.fits', fcbnew, /append
    fits_write, fcbnew, datanew, headernew, xtension='BINTABLE'
    ;fits_write_dzliu, fcbnew, datanew, headernew, xtension='BINTABLE', /no_pad
    fits_close, fcbnew
    
    ;PRINT, data
    ;help, datanew
    
    PRINT, ""
    PRINT, "Successfully written "+STRTRIM(naxis2,2)+" subscan ("+STRTRIM(naxis1,2)+" channel) data to "+InputFitsName+'_class.fits'
    ;PRINT, ""
    
    
END
