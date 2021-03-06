# generate an Excel spreadsheet from a STEP file

proc genExcel {{numFile 0}} {
  global allEntity ap203all ap214all ap242all badAttributes buttons
  global cells cells1 col col1 count coverageLegend readPMI csvdirnam csvfile
  global developer dim dimRepeatDiv editorCmd entCategories entCategory entColorIndex entCount entityCount entsIgnored entsWithErrors env errmsg
  global excel excelVersion excelYear extXLS fcsv feaElemTypes File fileEntity skipEntities skipPerm gpmiTypesInvalid gpmiTypesPerFile idxColor ifcsvrDir inverses
  global lastXLS lenfilelist localName localNameList logFile multiFile multiFileDir mytemp nistName nistVersion nprogBarEnts nshape
  global ofExcel ofCSV
  global opt p21e3 p21e3Section pmiCol pmiMaster recPracNames row rowmax
  global savedViewButtons savedViewName savedViewNames scriptName sheetLast spmiEntity spmiSumName spmiSumRow spmiTypesPerFile startrow stepAP
  global thisEntType tlast tolNames tolStandard totalEntity userEntityFile userEntityList userXLSFile useXL virtualDir
  global workbook workbooks worksheet worksheet1 worksheets writeDir wsCount wsNames
  global x3dAxes x3dColor x3dColors x3dCoord x3dFile x3dFileName x3dStartFile x3dIndex x3dMax x3dMin
  global xlFileName xlFileNames xlFormat xlInstalled
  global objDesign
  
  if {[info exists errmsg]} {set errmsg ""}
  #outputMsg "genExcel" red

# initialize for X3DOM geometry
  if {$opt(VIZPMI) || $opt(VIZFEA) || $opt(VIZTES)} {
    set x3dStartFile 1
    set x3dAxes 1
    set x3dFileName ""
    set x3dColor ""
    set x3dColors {}
    set x3dMax(x) -1.e10
    set x3dMax(y) -1.e10
    set x3dMax(z) -1.e10
    set x3dMin(x)  1.e10
    set x3dMin(y)  1.e10
    set x3dMin(z)  1.e10
  }

# check if IFCsvr is installed
  if {![file exists [file join $ifcsvrDir IFCsvrR300.dll]]} {
    if {[info exists buttons]} {$buttons(genExcel) configure -state disable}
    installIFCsvr
    return
  } 

# check for ROSE files
  if {![file exists [file join $ifcsvrDir  automotive_design.rose]] && \
      ![file exists [file join $virtualDir automotive_design.rose]]} {copyRoseFiles}
  set env(ROSE_RUNTIME) $ifcsvrDir
  set env(ROSE_SCHEMAS) $ifcsvrDir

  if {[info exists buttons]} {
    $buttons(genExcel) configure -state disable
    .tnb select .tnb.status
  }
  set lasttime [clock clicks -milliseconds]

  set multiFile 0
  if {$numFile > 0} {set multiFile 1}
  
# -------------------------------------------------------------------------------------------------
# connect to IFCsvr
  if {[catch {
    if {![info exists buttons]} {outputMsg "\n*** Begin ST-Developer messages"}
    set objIFCsvr [::tcom::ref createobject IFCsvr.R300]
    if {![info exists buttons]} {outputMsg "*** End ST-Developer messages"}
    
# print errors
  } emsg]} {
    errorMsg "\nERROR connecting to the IFCsvr software that is used to read STEP files: $emsg"
    catch {raise .}
    return 0
  }

# -------------------------------------------------------------------------------------------------
# open STEP file
  if {[catch {
    set nprogBarEnts 0
    set fname $localName  
    
# for STEP, get AP number, i.e. AP203   
    set stepAP [getStepAP $fname]
    set str "STEP"
    if {[string first "AP" $stepAP] == 0} {
      set str "STEP [string range $stepAP 0 4]"
    } elseif {$stepAP != ""} {
      set str $stepAP
    }
    outputMsg "\nOpening $str file"

# check for Part 21 edition 3 files and strip out sections
    set fname [checkP21e3 $fname]
    
# add file name and size to multi file summary
    if {$numFile != 0 && [info exists cells1(Summary)]} {
      set dlen [expr {[string length [truncFileName $multiFileDir]]+1}]
      set fn [string range [file nativename [truncFileName $fname]] $dlen end]
      set fn1 [split $fn "\\"]
      set fn2 [lindex $fn1 end]
      set idx [string first $fn2 $fn]
      if {[string length $fn2] > 40} {
        set div [expr {int([string length $fn2]/2)}]
        set fn2 [string range $fn2 0 $div][format "%c" 10][string range $fn2 [expr {$div+1}] end]
        set fn  [file nativename [string range $fn 0 $idx-1]$fn2]
      }
      regsub -all {\\} $fn [format "%c" 10] fn

      set colsum [expr {$col1(Summary)+1}]
      set range [$worksheet1(Summary) Range [cellRange 4 $colsum]]
      $cells1(Summary) Item 4 $colsum $fn
      if {$opt(XL_LINK1)} {[$worksheet1(Summary) Hyperlinks] Add $range [join $fname] [join ""] [join "Link to STEP file"]}
    }

# open file with IFCsvr
    if {![info exists buttons]} {outputMsg "\n*** Begin ST-Developer messages"}
    set objDesign [$objIFCsvr OpenDesign [file nativename $fname]]
    if {![info exists buttons]} {outputMsg "*** End ST-Developer messages\n"}

# count entities
    set entityCount [$objDesign CountEntities "*"]
    outputMsg " $entityCount entities\n"
    if {$entityCount == 0} {errorMsg "There are no entities in the STEP file."}

# add AP, file size, entity count to multi file summary
    if {$numFile != 0 && [info exists cells1(Summary)]} {
      $cells1(Summary) Item [expr {$startrow-2}] $colsum $stepAP
    
      set fsize [expr {[file size $fname]/1024}]
      if {$fsize > 10240} {
        set fsize "[expr {$fsize/1024}] Mb"
      } else {
        append fsize " Kb"
      }
      $cells1(Summary) Item [expr {$startrow-1}] $colsum $fsize
      $cells1(Summary) Item $startrow $colsum $entityCount
    }
    
# open file of entities (-skip.dat) not to process (skipEntities), skipPerm are entities always to skip
    set cfile [file rootname $fname]
    append cfile "-skip.dat"
    set skipPerm {}
    set skipEntities $skipPerm
    if {[file exists $cfile]} {
      set skipFile [open $cfile r]
      while {[gets $skipFile line] >= 0} {
        if {[lsearch $skipEntities $line] == -1 && $line != "" && ![info exists badAttributes($line)]} {
          lappend skipEntities $line
        }
      }
      close $skipFile

# old skip file name (_fix.dat), delete
    } else {
      set cfile1 [file rootname $fname]
      append cfile1 "_fix.dat"
      if {[file exists $cfile1]} {
        set skipFile [open $cfile1 r]
        while {[gets $skipFile line] >= 0} {
          if {[lsearch $skipEntities $line] == -1 && $line != "" && ![info exists badAttributes($line)]} {
            lappend skipEntities $line
          }
        }
        close $skipFile
        file delete -force $cfile1
        errorMsg "File of entities to skip '[file tail $cfile1]' renamed to '[file tail $cfile]'."
      }
    }
    
# open log file
    if {$opt(LOGFILE)} {
      set lfile [file rootname $fname]
      append lfile "-sfa.log"
      set logFile [open $lfile w]
      puts $logFile "NIST STEP File Analyzer (v[getVersion])  [clock format [clock seconds]]\n"
    }

# check if a file generated from a NIST test case is being processed
    set nistName ""
    set ftail [string tolower [file tail $localName]]
    set ctcftc 0
    set filePrefix [list sp4_ sp5_ sp6_ sp7_ tgp1_ tgp2_ tgp3_ tgp4_ tp3_ tp4_ tp5_ tp6_ lsp_ lpp_ ltg_ ltp_]

    set ok  0
    set ok1 0
    foreach prefix $filePrefix {
      if {[string first $prefix $ftail] == 0 || [string first "nist" $ftail] != -1 || \
          [string first "ctc" $ftail] != -1 || [string first "ftc" $ftail] != -1} {
        set tmp "nist_"
        foreach item {ctc ftc} {
          if {[string first $item $ftail] != -1} {
            append tmp "$item\_"
            set ctcftc 1
          }
        }

# find nist_ctc_01 directly        
        if {$ctcftc} {
          for {set i 1} {$i <= 11} {incr i} {
            set i1 $i
            if {$i < 10} {set i1 "0$i"}
            set tmp1 "$tmp$i1"
            if {[string first $tmp1 $ftail] != -1 && !$ok1} {
              set nistName $tmp1
              #outputMsg $nistName blue
              set ok1 1
            }
          }
        }

# find the number in the string            
        if {!$ok1} {
          for {set i 1} {$i <= 11} {incr i} {
            if {!$ok} {
              set i1 $i
              if {$i < 10} {set i1 "0$i"}
              set c {""}
              #outputMsg "$i1  [string first $i1 $ftail]  [string last $i1 $ftail]" blue
              if {[string first $i1 $ftail] != [string last $i1 $ftail]} {set c {"_" "-"}}
              foreach c1 $c {
                for {set j 0} {$j < 2} {incr j} {
                  if {$j == 0} {set i2 "$c1$i1"}
                  if {$j == 1} {set i2 "$i1$c1"}
                  #outputMsg "[string first $i2 $ftail]  $i2  $ftail" green
                  if {[string first $i2 $ftail] != -1 && !$ok} {
                    if {$ctcftc} {
                      append tmp $i1
                    } elseif {$i <= 5} {
                      append tmp "ctc_$i1"
                    } else {
                      append tmp "ftc_$i1"
                    }
                    set nistName $tmp
                    set ok 1
                    #outputMsg $nistName red
                  }
                }
              }
            }
          }
        }
      }
    }
    
# other files
    if {!$ok} {
      if {[string first "332211_qif_bracket" $ftail] != -1} {set nistName "332211_qif_bracket_revh"}
      if {[string first "sp3" $ftail] == 0} {
        if {[string first "1101"  $ftail] != -1} {set nistName "sp3-1101"}
        if {[string first "16792" $ftail] != -1} {set nistName "sp3-16792"}
        if {[string first "box"   $ftail] != -1} {set nistName "sp3-box"}
      }
    }
    if {$developer && [string first "step-file-analyzer" $ftail] == 0} {set nistName "nist_ctc_01"}
    
# error opening file, report the schema
  } emsg]} {
    errorMsg "ERROR opening STEP file"
    getSchemaFromFile $fname 1

    if {!$p21e3} {
      errorMsg "Possible causes of the ERROR:\n- Syntax errors in the STEP file\n- STEP schema is not supported, see Help > Supported STEP APs\n- File or directory name contains accented, non-English, or symbol characters\n- File extension is not '.stp', '.step', '.p21', '.stpZ', or '.ifc'\n- Multiple schemas are used\n- File is not an ISO 10303 Part 21 STEP file" red
    
# part 21 edition 3
    } else {
      outputMsg " "
      errorMsg "The STEP file uses Edition 3 of Part 21 and cannot be processed by the STEP File Analyzer.\n Edit the STEP file to delete the Edition 3 content such as the ANCHOR, REFERENCE, and SIGNATURE sections."
    }
    if {!$nistVersion} {
      outputMsg " "
      errorMsg "You must process at least one STEP file with the NIST version of the STEP File Analyzer\n before using a user-built version."
    }
    
# open STEP file in editor
    if {[info exists editorCmd]} {
      errorMsg "Opening file in editor"
      exec $editorCmd $localName &
    }

    if {[info exists errmsg]} {unset errmsg}
    catch {
      $objDesign Delete
      unset objDesign
      unset objIFCsvr
    }
    catch {raise .}
    return 0
  }

# -------------------------------------------------------------------------------------------------
# connect to Excel
  #set comma 0
  set useXL 1
  set xlInstalled 1
  if {$opt(XLSCSV) != "None"} {
    if {[catch {
      set pid1 [checkForExcel $multiFile]
      set excel [::tcom::ref createobject Excel.Application]
      set pidExcel [lindex [intersect3 $pid1 [twapi::get_process_ids -name "EXCEL.EXE"]] 2]
      [$excel ErrorCheckingOptions] TextDate False
  
# version and year
      set excelVersion [expr {int([$excel Version])}]
      set excelYear ""
      switch $excelVersion {
        9  {set excelYear 2000}
        10 {set excelYear 2002}
        11 {set excelYear 2003}
        12 {set excelYear 2007}
        default {
          if {$excelVersion > 8 && $excelVersion < 50} {
            set excelYear [expr {2010+3*($excelVersion-14)}]
          } else {
            set excelYear $excelVersion
          }
        }
      }

# file format, max rows
      set extXLS "xlsx"
      set xlFormat [expr 51]
      set rowmax [expr {2**20}]

# older Excel
      if {$excelVersion < 12} {
        set extXLS "xls"
        set xlFormat [expr 56]
        set rowmax [expr {2**16}]
        errorMsg "Some spreadsheet features used by the STEP File Analyzer are not compatible with Excel $excelYear."
      }
  
# generate with Excel but save as CSV
      set saveCSV 0
      if {$opt(XLSCSV) == "CSV"} {
        set saveCSV 1
        catch {$buttons(ofExcel) configure -state disabled}
      } else {
        catch {$buttons(ofExcel) configure -state normal}
      }

# turning off ScreenUpdating, saves A LOT of time
      if {$opt(XL_KEEPOPEN) && $numFile == 0} {
        $excel Visible 1
      } else {
        $excel Visible 0
        catch {$excel ScreenUpdating 0}
      }
      
      set rowmax [expr {$rowmax-2}]
      if {$opt(XL_ROWLIM) < $rowmax} {set rowmax $opt(XL_ROWLIM)}
    
# no Excel, use CSV instead
    } emsg]} {
      set useXL 0
      set xlInstalled 0
      if {$opt(XLSCSV) == "Excel"} {
        errorMsg "Excel is not installed or cannot start Excel: $emsg\n CSV files will be generated instead of a spreadsheet.  See the Output Format option.  Some options are disabled."
        set opt(XLSCSV) "CSV"
        catch {raise .}
      }
      checkValues
      set ofExcel 0
      set ofCSV 1
      catch {$buttons(ofExcel) configure -state disabled}
    }

# visualization only
  } else {
    set useXL 0
  }

# -------------------------------------------------------------------------------------------------
# start worksheets
  if {$useXL} {
    if {[catch {
      set workbooks  [$excel Workbooks]
      set workbook   [$workbooks Add]
      set worksheets [$workbook Worksheets]
  
# delete all but one worksheet
      catch {$excel DisplayAlerts False}
      set sheetCount [$worksheets Count]
      for {set n $sheetCount} {$n > 1} {incr n -1} {[$worksheets Item [expr $n]] Delete}
      set sheetLast [$worksheets Item [$worksheets Count]]
      catch {$excel DisplayAlerts True}
      [$excel ActiveWindow] TabRatio [expr 0.7]

# determine decimal separator
      set sheet [$worksheets Item [expr 1]]
      set cell  [$sheet Cells]
  
      #set A1 12345,67890
      #$cell Item 1 A $A1
      #set range [$sheet Range "A1"]
      #if {[$range Value] == 12345.6789} {
      #  set comma 1
      #  errorMsg "Using comma \",\" as the decimal separator for numbers" red
      #}
  
# print errors
    } emsg]} {
      errorMsg "ERROR opening Excel workbooks and worksheets: $emsg"
      catch {raise .}
      return 0
    }

# CSV files or viz only
  } else {
    set rowmax [expr {2**20}]
    if {$opt(XL_ROWLIM) < $rowmax} {set rowmax $opt(XL_ROWLIM)}
  }
  
# -------------------------------------------------------------------------------------------------
# add header worksheet, for CSV files create directory and header file
  addHeaderWorksheet $numFile $fname

# -------------------------------------------------------------------------------------------------
# set Excel spreadsheet name, delete file if already exists

# user-defined file name
  if {$useXL} {
    set xlsmsg ""
    if {$opt(writeDirType) == 1} {
      if {$userXLSFile != ""} {
        set xlFileName [file nativename $userXLSFile]
      } else {
        append xlsmsg "User-defined Spreadsheet file name is not valid.  Spreadsheet directory and\n file name will be based on the STEP file. (Options tab)"
        set opt(writeDirType) 0
      }
    }
    
# same directory as file
    if {$opt(writeDirType) == 0} {
      set xlFileName "[file nativename [file join [file dirname $fname] [file rootname [file tail $fname]]]]-sfa.$extXLS"
      set xlFileNameOld "[file nativename [file join [file dirname $fname] [file rootname [file tail $fname]]]]_stp.$extXLS"
  
# user-defined directory
    } elseif {$opt(writeDirType) == 2} {
      set xlFileName "[file nativename [file join $writeDir [file rootname [file tail $fname]]]]-sfa.$extXLS"
      set xlFileNameOld "[file nativename [file join $writeDir [file rootname [file tail $fname]]]]_stp.$extXLS"
    }
    
# file name too long
    if {[string length $xlFileName] > 218} {
      if {[string length $xlsmsg] > 0} {append xlsmsg "\n\n"}
      append xlsmsg "Pathname of Spreadsheet file is too long for Excel ([string length $xlFileName])"
      set xlFileName "[file nativename [file join $writeDir [file rootname [file tail $fname]]]]-sfa.$extXLS"
      set xlFileNameOld "[file nativename [file join $writeDir [file rootname [file tail $fname]]]]_stp.$extXLS"
      if {[string length $xlFileName] < 219} {
        append xlsmsg "\nSpreadsheet file written to User-defined directory (Spreadsheet tab)"
      }
    }
  
# delete existing file
    if {[file exists $xlFileNameOld]} {catch {file delete -force $xlFileNameOld}}
    if {[file exists $xlFileName]} {
      if {[catch {
        file delete -force $xlFileName
      } emsg]} {
        if {[string length $xlsmsg] > 0} {append xlsmsg "\n"}
        append xlsmsg "ERROR deleting existing Spreadsheet: [truncFileName $xlFileName]"
        catch {raise .}
      }
    }
  }
    
# add file name to menu
  set ok 0
  if {$numFile <= 1} {set ok 1}
  if {[info exists localNameList]} {if {[llength $localNameList] > 1} {set ok 1}}
  if {$ok} {addFileToMenu}

# set types of entities to process
  set entCategories {}
  foreach pr [array names entCategory] {
    set ok 1
    if {[info exists opt($pr)] && [info exists entCategory($pr)] && $ok} {
      if {$opt($pr)} {set entCategories [concat $entCategories $entCategory($pr)]}
    }
  }
  
# -------------------------------------------------------------------------------------------------
# set which entities are processed and which are not
  set entsToProcess {}
  set entsToIgnore {}
  set numEnts 0
  
# user-defined entity list
  catch {set userEntityList {}}
  if {$opt(PR_USER) && [llength $userEntityList] == 0 && [info exists userEntityFile]} {
    set userEntityList {}
    set fileUserEnt [open $userEntityFile r]
    while {[gets $fileUserEnt line] != -1} {
      set line [split [string trim $line] " "]
      foreach ent $line {lappend userEntityList [string tolower $ent]}
    }
    close $fileUserEnt
    if {[llength $userEntityList] == 0} {
      set opt(PR_USER) 0
      checkValues
    }
  }
  
# get totals of each entity in file
  set fixlist {}
  if {![info exists objDesign]} {return}
  catch {unset entCount}

  set entityTypeNames [$objDesign EntityTypeNames [expr 2]]
  foreach entType $entityTypeNames {
    set entCount($entType) [$objDesign CountEntities "$entType"]

    if {$entCount($entType) > 0} {
      if {$numFile != 0} {
        set idx [setColorIndex $entType]
        if {$idx == -2} {set idx 99}
        lappend allEntity "$idx$entType"
        lappend fileEntity($numFile) "$entType $entCount($entType)"
        if {![info exists totalEntity($entType)]} {
          set totalEntity($entType) $entCount($entType)
        } else {
          incr totalEntity($entType) $entCount($entType)
        }
      }

# user-defined entities
      set ok 0
      if {$opt(PR_USER) && [lsearch $userEntityList $entType] != -1} {set ok 1}
      
# STEP entities that are translated depending on the options
      set ok1 [setEntsToProcess $entType]
      if {$ok == 0} {set ok $ok1}
      
# entities in unsupported APs that are not AP203, AP214, AP242 - if not using a user-defined list
      if {!$opt(PR_USER)} {
        if {[string first "AP203" $stepAP] == -1 && [string first "AP214" $stepAP] == -1 && $stepAP != "AP242"} {
          set et $entType
          set c1 [string first "_and_" $et]
          if {$c1 != -1} {set et [string range $et 0 $c1-1]}
          if {[lsearch $ap203all $et] == -1 && [lsearch $ap214all $et] == -1 && [lsearch $ap242all $et] == -1} {
            if {$c1 == -1} {
              set ok 1
            } else {
              if {[lsearch $ap203all $entType] == -1 && [lsearch $ap214all $entType] == -1 && [lsearch $ap242all $entType] == -1} {
                set ok 1
              }
            }
          }
        }
      }
  
# AP209 nodes
      if {[string first "AP209" $stepAP] != -1} {
        if {$entType == "node" && $opt(PR_STEP_CPNT) == 0 && $opt(XLSCSV) != "None"} {
          set ok 0
          outputMsg " For AP209 files, to write 'node' entities to the spreadsheet, select Coordinates in the Options tab" red
        }
      }
      
# new AP242 entities in a ROSE file, but not yet in ap242all or any entity category, for testing new schemas
      #if {$developer} {if {$stepAP == "AP242" && [lsearch $ap242all $entType] == -1} {set ok 1}}

# handle '_and_' due to a complex entity, entType_1 is the first part before the '_and_'
      set entType_1 $entType
      set c1 [string first "_and_" $entType_1]
      if {$c1 != -1} {set entType_1 [string range $entType_1 0 $c1-1]}
      
# check for entities that cause crashes
      set noSkip 1
      if {[info exists skipEntities]} {if {[lsearch $skipEntities $entType] != -1} {set noSkip 0}}

# add to list of entities to process (entsToProcess), uses color index to set the order
      if {([lsearch $entCategories $entType_1] != -1 || $ok)} {
        if {$noSkip} {
          lappend entsToProcess "[setColorIndex $entType]$entType"
          incr numEnts $entCount($entType)
        } else {
          lappend fixlist $entType
          lappend entsToIgnore $entType
          set entsIgnored($entType) $entCount($entType)
        }
      } elseif {[lsearch $entCategories $entType] != -1} {
        if {$noSkip} {
          lappend entsToProcess "[setColorIndex $entType]$entType"
          incr numEnts $entCount($entType)
        } else {
          lappend fixlist $entType
          lappend entsToIgnore $entType
          set entsIgnored($entType) $entCount($entType)
        }
      } else {
        lappend entsToIgnore $entType
        set entsIgnored($entType) $entCount($entType)
      }
    }
  }
    
# open expected PMI worksheet (once) if PMI representation and correct file name
  if {$opt(PMISEM) && $stepAP == "AP242" && $nistName != ""} {
    set tols $tolNames
    concat $tols [list dimensional_characteristic_representation datum datum_feature datum_reference_compartment datum_reference_element datum_system placed_datum_target_feature]
    set ok 0
    foreach tol $tols {if {[info exist entCount($tol)]} {set ok 1; break}}
    if {$ok && ![info exists pmiMaster($nistName)]} {spmiGetPMI}
  }
    
# filter inverse relationships to check only by entities in file
    if {$opt(INVERSE)} {
      if {$entityTypeNames != ""} {
        initDataInverses
        set invNew {}
        foreach item $inverses {
          if {[lsearch $entityTypeNames [lindex $item 0]] != -1} {lappend invNew $item}
        }
        set inverses $invNew
      }
    }
  
# list entities not processed based on fix file
  if {[llength $fixlist] > 0} {
    outputMsg " "
    if {[file exists $cfile]} {
      set ok 0
      foreach item $fixlist {if {[lsearch $skipPerm $item] == -1} {set ok 1}}
    }
    if {$ok && $opt(XLSCSV) != "None"} {
      if {$useXL} {
        set msg "Worksheets"
      } else {
        set msg "CSV files"
      }
      append msg " will NOT be generated for entities listed in\n [truncFileName [file nativename $cfile]]:"
      errorMsg $msg
      foreach item [lsort $fixlist] {outputMsg "  $item" red}
      errorMsg " See Help > Crash Recovery"
    }
  }
  
# sort entsToProcess by color index
  set entsToProcess [lsort $entsToProcess]
  
# for STEP process datum* and dimensional* entities before specific *_tolerance entities
  if {$opt(PMISEM)} {
    if {[info exists entCount(angularity_tolerance)] || \
        [info exists entCount(circular_runout_tolerance)] || \
        [info exists entCount(coaxiality_tolerance)] || \
        [info exists entCount(concentricity_tolerance)] || \
        [info exists entCount(cylindricity_tolerance)]} {
      set entsToProcessTmp(0) {}
      set entsToProcessTmp(1) {}
      set entsToProcessDatum {}
      set itmp 0
      for {set i 0} {$i < [llength $entsToProcess]} {incr i} {
        set str1 [lindex $entsToProcess $i]
        set tc [string range [lindex $entsToProcess $i] 0 1]
        if {$tc == $entColorIndex(PR_STEP_TOLR)} {set itmp 1}
        if {[string first $entColorIndex(PR_STEP_TOLR) $str1] == 0 && ([string first "datum" $str1] == 2 || [string first "dimensional" $str1] == 2)} {
          lappend entsToProcessDatum $str1
        } else {
          lappend entsToProcessTmp($itmp) $str1
        }
      }
      if {$itmp && [llength $entsToProcessDatum] > 0} {
        set entsToProcess [concat $entsToProcessTmp(0) $entsToProcessDatum $entsToProcessTmp(1)]
      }
    }

# move dimensional_characteristic_representation to the beginning  
    if {[info exists entCount(dimensional_characteristic_representation)]} {
      set dcr "$entColorIndex(PR_STEP_TOLR)\dimensional_characteristic_representation"
      set c1 [lsearch $entsToProcess $dcr]
      set entsToProcess [lreplace $entsToProcess $c1 $c1]
      set entsToProcess [linsert $entsToProcess 0 $dcr]
    }
  }
  
# move some AP209 entities to end
  if {$opt(VIZFEA)} {
    foreach ent {nodal_freedom_action_definition single_point_constraint_element_values} {
      if {[info exists entCount($ent)]} {
        set spc "19$ent"
        set c1 [lsearch $entsToProcess $spc]
        set entsToProcess [lreplace $entsToProcess $c1 $c1]
        set entsToProcess [linsert $entsToProcess end $spc]
      }
    }
  }
  
# then strip off the color index
  for {set i 0} {$i < [llength $entsToProcess]} {incr i} {
    lset entsToProcess $i [string range [lindex $entsToProcess $i] 2 end]
  }

# max progress bar - number of entities or finite elements 
  if {[info exists buttons]} {
    $buttons(pgb) configure -maximum $numEnts
    if {[string first "AP209" $stepAP] == 0 && $opt(XLSCSV) == "None"} {
      set n 0
      foreach elem {curve_3d_element_representation surface_3d_element_representation volume_3d_element_representation} {
        if {[info exists entCount($elem)]} {incr n $entCount($elem)}
      }
      $buttons(pgb) configure -maximum $n
    }
  }
      
# check for ISO/ASME standards on product_definition_formation, document, product
  set tolStandard(type) ""
  set tolStandard(num)  ""
  set stds {}
  foreach item {product_definition_formation product} {
    ::tcom::foreach thisEnt [$objDesign FindObjects $item] {
      ::tcom::foreach attr [$thisEnt Attributes] {
        if {[$attr Name] == "id"} {
          set val [$attr Value]
          if {([string first "ISO" $val] == 0 || [string first "ASME" $val] == 0) && [string first "NIST" [string toupper $val]] == -1} {
            if {[string first "ISO" $val] == 0} {
              set tolStandard(type) "ISO"
              if {[string first "1101" $val] != "" || [string first "16792" $val] != ""} {if {[string first $val $tolStandard(num)] == -1} {append tolStandard(num) "$val    "}}
            }
            if {[string first "ASME" $val] == 0 && [string first "NIST" [string toupper $val]] == -1} {
              set tolStandard(type) "ASME"
              if {[string first "Y14." $val] != ""} {if {[string first $val $tolStandard(num)] == -1} {append tolStandard(num) "$val    "}}
            }
            set ok 1
            foreach std $stds {if {[string first $val $std] != -1} {set ok 0}}
            if {$ok} {lappend stds $val}
          }
        }
      }
    }
  }
  if {[llength $stds] > 0} {
    outputMsg "\nStandards:" blue
    foreach std $stds {outputMsg " $std"}
  }
  if {$tolStandard(type) == "ISO"} {
    set fn [string toupper [file tail $localName]]
    if {[string first "NIST_" $fn] == 0 && [string first "ASME" $fn] != -1} {errorMsg "All of the NIST models use ASME Y14.5 tolerance standard."}
  }

# -------------------------------------------------------------------------------------------------
# generate worksheet for each entity
  outputMsg " "
  if {$useXL} {
    outputMsg "Generating STEP Entity worksheets" blue
  } elseif {$opt(XLSCSV) == "CSV"} {
    outputMsg "Generating STEP Entity CSV files" blue
  } elseif {$opt(XLSCSV) == "None"} {
    outputMsg "Generating Visualization"
  }
  
# initialize variables
  if {[catch {
    set coverageLegend 0
    set entsWithErrors {}
    set gpmiTypesInvalid {}
    set idxColor 0
    set inverseEnts {}
    set lastEnt ""
    set nprogBarEnts 0
    set nshape 0
    set ntable 0
    set savedViewName {}
    set savedViewNames {}
    set savedViewButtons {}
    set spmiEntity {}
    set spmiSumRow 1
    set stat 1
    set wsCount 0
    foreach f {elements mesh meshIndex faceIndex} {
      catch {file delete -force [file join $mytemp $f.txt]}
    }

    if {[info exists dim]} {unset dim}
    set dim(prec,max) 0
    set dim(unit) ""
    set dimRepeatDiv 2
    #set dim(name) ""
    
# find camera models used in draughting model items and annotation_occurrence used in property_definition and datums
    if {$opt(PMIGRF) || $opt(VIZPMI)} {pmiGetCamerasAndProperties}

    if {[llength $entsToProcess] == 0} {
      if {$opt(XLSCSV) != "None"} {
        errorMsg " No entities are selected to Process (Options tab)."
      } else {
        errorMsg " There is nothing to Visualize (Options tab)."
      }
      break
    }
    set tlast [clock clicks -milliseconds]
    #getTiming "start entity processing"
    
# loop over list of entities in file
    foreach entType $entsToProcess {
      if {$opt(XLSCSV) != "None"} {
        set nerr1 0
        set lastEnt $entType
      
# decide if inverses should be checked for this entity type
        set checkInv 0
        if {$opt(INVERSE)} {set checkInv [invSetCheck $entType]}
        if {$checkInv} {lappend inverseEnts $entType}
        set badAttr [info exists badAttributes($entType)]

# process the entity type
        ::tcom::foreach objEntity [$objDesign FindObjects [join $entType]] {
          if {$entType == [$objEntity Type]} {
            incr nprogBarEnts
            if {[expr {$nprogBarEnts%1000}] == 0} {update}
  
            if {[catch {
              if {$useXL} {
                set stat [getEntity $objEntity $checkInv]
              } else {
                set stat [getEntityCSV $objEntity]
              }
            } emsg1]} {

# process errors with entity
              if {$stat != 1} {break}
  
              set msg "ERROR processing " 
              if {[info exists objEntity]} {
                if {[string first "handle" $objEntity] != -1} {
                  append msg "\#[$objEntity P21ID]=[$objEntity Type] (row [expr {$row($thisEntType)+2}]): $emsg1"

# handle specific errors
                  if {[string first "Unknown error" $emsg1] != -1} {
                    errorMsg $msg
                    catch {raise .}
                    incr nerr1
                    if {$nerr1 > 20} {
                      errorMsg "Processing of $entType entities has stopped" red
                      set nprogBarEnts [expr {$nprogBarEnts + $entCount($thisEntType) - $count($thisEntType)}]
                      break
                    }
  
                  } elseif {[string first "Insufficient memory to perform operation" $emsg1] != -1} {
                    errorMsg $msg
                    errorMsg "Several options are available to reduce memory usage:\nUse the option to limit the Maximum Rows"
                    if {$opt(INVERSE)} {errorMsg "Turn off Inverse Relationships and process the file again" red}
                    catch {raise .}
                    break
                  }
                  errorMsg $msg 
                  catch {raise .}
                }
              }
            }
          
# max rows exceeded          
            if {$stat != 1} {
              set ok 1
              if {[string first "element_representation" $thisEntType] != -1 && $opt(VIZFEA)} {set ok 0}
              if {$ok} {set nprogBarEnts [expr {$nprogBarEnts + $entCount($thisEntType) - $count($thisEntType)}]}
              break
            }
          }
        }

# close CSV file
        if {!$useXL} {catch {close $fcsv}}
      }
      
# check for reports (validation properties, PMI presentation and representation, tessellated geometry, AP209)
      checkForReports $entType
    }

  } emsg2]} {
    catch {raise .}
    if {[llength $entsToProcess] > 0} {
      set msg "ERROR processing STEP file: "
      if {[info exists objEntity]} {if {[string first "handle" $objEntity] != -1} {append msg " \#[$objEntity P21ID]=[$objEntity Type]"}}
      append msg "\n $emsg2"
      append msg "\nProcessing of the STEP file has stopped"
      errorMsg $msg
    } else {
      return
    }
  }

# -------------------------------------------------------------------------------------------------
# check fix file
  if {[info exists cfile]} {
    set fixtmp {}
    if {[file exists $cfile]} {
      set skipFile [open $cfile r]
      while {[gets $skipFile line] >= 0} {
        if {[lsearch $fixtmp $line] == -1 && $line != $lastEnt} {lappend fixtmp $line}
      }
      close $skipFile
    }

    if {[join $fixtmp] == ""} {
      catch {file delete -force $cfile}
    } else {
      set skipFile [open $cfile w]
      foreach item $fixtmp {puts $skipFile $item}
      close $skipFile
    }
  }

# -------------------------------------------------------------------------------------------------
# set viewpoints and close X3DOM geometry file 
  if {($opt(VIZPMI) || $opt(VIZFEA) || $opt(VIZTES)) && $x3dFileName != ""} {x3dFileEnd}

# -------------------------------------------------------------------------------------------------
# add summary worksheet
  if {$useXL} {
    set tmp [sumAddWorksheet] 
    set sumLinks  [lindex $tmp 0]
    set sheetSort [lindex $tmp 1]
    set sumRow    [lindex $tmp 2]
    set sum "Summary"
  
# add file name and other info to top of Summary
    set sumHeaderRow [sumAddFileName $sum $sumLinks]

# freeze panes (must be before adding color and hyperlinks below)
    [$worksheet($sum) Range "A[expr {$sumHeaderRow+3}]"] Select
    catch {[$excel ActiveWindow] FreezePanes [expr 1]}
    [$worksheet($sum) Range "A1"] Select

# -------------------------------------------------------------------------------------------------
# format cells on each entity worksheets
    formatWorksheets $sheetSort $sumRow $inverseEnts
    #getTiming "done formatting spreadsheets"
  
# add Summary color and hyperlinks
    sumAddColorLinks $sum $sumHeaderRow $sumLinks $sheetSort $sumRow
    #getTiming "done generating summary worksheet"
  
# -------------------------------------------------------------------------------------------------
# add PMI Rep. Coverage Analysis worksheet for a single file
    if {$opt(PMISEM)} {
      if {[info exists spmiTypesPerFile]} {
        set sempmi_coverage "PMI Representation Coverage"
        if {![info exists worksheet($sempmi_coverage)]} {
          outputMsg " Adding PMI Representation Coverage worksheet" blue
          spmiCoverageStart 0
          spmiCoverageWrite "" "" 0
          spmiCoverageFormat "" 0
        }
      }

# format PMI Representation Summary worksheet
      if {[info exists spmiSumName]} {spmiSummaryFormat}
    }
  
# add PMI Pres. Coverage Analysis worksheet for a single file
    if {$opt(PMIGRF)} {
      if {[info exists gpmiTypesPerFile]} {
        set pmi_coverage "PMI Presentation Coverage"
        if {![info exists worksheet($pmi_coverage)]} {
          outputMsg " Adding PMI Presentation Coverage worksheet" blue
          gpmiCoverageStart 0
          gpmiCoverageWrite "" "" 0
          gpmiCoverageFormat "" 0
        }
      }
    }
  
# add ANCHOR and other sections from Part 21 Edition 3
    if {[info exists p21e3Section]} {
      if {[llength $p21e3Section] > 0} {addP21e3Section}
    }    
# -------------------------------------------------------------------------------------------------
# select the first tab
    [$worksheets Item [expr 1]] Select
    [$excel ActiveWindow] ScrollRow [expr 1]
  }

# -------------------------------------------------------------------------------------------------
# quit IFCsvr, but not sure how to do it properly
  if {[catch {
    #outputMsg "\nClosing IFCsvr" green
    $objDesign Delete
    unset objDesign
    unset objIFCsvr
    
# errors
  } emsg]} {
    errorMsg "ERROR closing IFCsvr: $emsg"
    catch {raise .}
  }

# processing time
  set cc [clock clicks -milliseconds]
  set proctime [expr {($cc - $lasttime)/1000}]
  if {$proctime <= 60} {set proctime [expr {(($cc - $lasttime)/100)/10.}]}
  outputMsg "Processing time: $proctime seconds"
  update idletasks

# -------------------------------------------------------------------------------------------------
# save spreadsheet
  set csvOpenDir 0
  if {$useXL} {
    if {[catch {
      #getTiming "save spreadsheet"
      outputMsg " "
      if {$xlsmsg != ""} {errorMsg $xlsmsg}
      if {[string first "\[" $xlFileName] != -1} {
        regsub -all {\[} $xlFileName "(" xlFileName
        regsub -all {\]} $xlFileName ")" xlFileName
        errorMsg "In the spreadsheet file name, the characters \'\[\' and \'\]\' have been\n substituted by \'\(\' and \'\)\'"
      }

# always save as spreadsheet
      outputMsg "Saving Spreadsheet as:"
      outputMsg " [truncFileName $xlFileName 1]" blue
      if {[catch {
        catch {$excel DisplayAlerts False}
        $workbook -namedarg SaveAs Filename $xlFileName FileFormat $xlFormat
        catch {$excel DisplayAlerts True}
        set lastXLS $xlFileName
        lappend xlFileNames $xlFileName
      } emsg1]} {
        errorMsg "ERROR Saving Spreadsheet: $emsg1"
      }

# save worksheets as CSV files
      if {$saveCSV} {
        if {[catch {
          set csvdirnam "[file join [file dirname $localName] [file rootname [file tail $localName]]]-sfa-csv"
          file mkdir $csvdirnam
          outputMsg "Saving Spreadsheet as multiple CSV files to:"
          outputMsg " [truncFileName [file nativename $csvdirnam]]" blue
          set csvFormat [expr 6]
          if {$excelYear >= 2016} {set csvFormat [expr 62]}
          
          set nprogBarEnts 0
          for {set i 1} {$i <= [$worksheets Count]} {incr i} {
            set ws [$worksheets Item [expr $i]]
            set wsn [$ws Name]
            if {[info exists wsNames($wsn)]} {
              set wsname $wsNames($wsn)
            } else {
              set wsname $wsn
            }
            $worksheet($wsname) Activate
            regsub -all " " $wsname "-" wsname
            set csvfname [file nativename [file join $csvdirnam $wsname.csv]]
            if {[file exists $csvfname]} {file delete -force $csvfname}
            if {[string first "PMI-Representation" $csvfname] != -1 && $excelYear < 2016} {
              errorMsg "PMI symbols written to CSV files will look correct only with Excel 2016 or newer." red
            }
            $workbook -namedarg SaveAs Filename [file rootname $csvfname] FileFormat $csvFormat
            incr nprogBarEnts
            update
          }
        } emsg2]} {
          errorMsg "ERROR Saving CSV files: $emsg2"
        }
      }
      
# close log file
      if {[info exists logFile]} {
        outputMsg "Saving Log file as:"
        outputMsg " [truncFileName [file nativename $lfile]]" blue
        close $logFile
        unset lfile
        unset logFile
      }
  
      catch {$excel ScreenUpdating 1}

# close Excel
      $excel Quit
      set openxl 1
      catch {unset excel}
      catch {if {[llength $pidExcel] == 1} {twapi::end_process $pidExcel -force}}
      #getTiming "save done"

# add Link(n) text to multi file summary
      if {$numFile != 0 && [info exists cells1(Summary)]} {
        set colsum [expr {$col1(Summary)+1}]
        if {$opt(XL_LINK1)} {
          $cells1(Summary) Item 3 $colsum "Link ($numFile)"
          set range [$worksheet1(Summary) Range [cellRange 3 $colsum]]
          regsub -all {\\} $xlFileName "/" xls
          [$worksheet1(Summary) Hyperlinks] Add $range [join $xls] [join ""] [join "Link to Spreadsheet"]
        } else {
          $cells1(Summary) Item 3 $colsum "$numFile"
        }
      }
      update idletasks

# errors
    } emsg]} {
      errorMsg "ERROR: $emsg"
      catch {raise .}
      set openxl 0
    }
    
# -------------------------------------------------------------------------------------------------
# open spreadsheet or directory of CSV files
    set ok 0
    if {$openxl && $opt(XL_OPEN)} {
      if {$numFile == 0} {
        set ok 1
      } elseif {[info exists lenfilelist]} {
        if {$lenfilelist == 1} {set ok 1}
      }
    }

# open spreadsheet
    if {$useXL} {
      if {$ok} {
        openXLS $xlFileName
      } elseif {!$opt(XL_OPEN) && $numFile == 0 && [string first "STEP-File-Analyzer.exe" $scriptName] != -1} {
        outputMsg " Use F2 to open the Spreadsheet (see Spreadsheet tab)" red
      }
    }

# CSV files generated too
    if {$saveCSV} {set csvOpenDir 1}

# open directory of CSV files
  } elseif {$opt(XLSCSV) != "None"} {
    set csvOpenDir 1
    unset csvfile
    outputMsg "\nCSV files written to:"
    outputMsg " [truncFileName [file nativename $csvdirnam]]" blue
  }
  
  if {$opt(XLSCSV) == "None"} {set useXL 1}  
  
# open directory of CSV files
  if {$csvOpenDir} {
    set ok 0
    if {$opt(XL_OPEN)} {
      if {$numFile == 0} {
        set ok 1
      } elseif {[info exists lenfilelist]} {
        if {$lenfilelist == 1} {set ok 1}
      }
    }
    if {$ok} {
      set dir [file nativename $csvdirnam]
      if {[string first " " $dir] == -1} {
        outputMsg "Opening CSV file directory"
        exec {*}[auto_execok start] $dir
      } else {
        exec C:/Windows/explorer.exe $dir &
      }
      
    }
  }

# -------------------------------------------------------------------------------------------------
# open X3DOM file of graphical PMI or FEM
  openX3DOM

# -------------------------------------------------------------------------------------------------
# save state
  if {[info exists errmsg]} {unset errmsg}
  saveState
  if {!$multiFile && [info exists buttons]} {$buttons(genExcel) configure -state normal}
  update idletasks

# unset variables to release memory and/or to reset them
  global colColor invCol currx3dPID dimrep dimrepID entName gpmiID gpmiIDRow gpmiRow
  global heading invGroup feaNodes nrep numx3dPID pmiColumns pmiStartCol 
  global propDefID propDefIDRow propDefName propDefOK propDefRow syntaxErr
  global shapeRepName tessRepo tessPlacement dimtolGeom dimtolEntID datumGeom datumSymbol
  global savedViewFileName savedViewFile feaDOFT feaDOFR

  foreach var {cells colColor invCol count currx3dPID dimrep dimrepID entName entsIgnored \
              gpmiID gpmiIDRow gpmiRow heading invGroup nrep feaNodes numx3dPID \
              pmiCol pmiColumns pmiStartCol pmivalprop propDefID propDefIDRow propDefName propDefOK propDefRow \
              syntaxErr workbook workbooks worksheet worksheets \
              x3dCoord x3dFile x3dFileName x3dStartFile x3dIndex x3dMax x3dMin \
              shapeRepName tessRepo tessPlacement dimtolGeom dimtolEntID datumGeom datumSymbol\
              savedViewNames savedViewFileName savedViewFile x3dFileName feaDOFT feaDOFR} {
    if {[info exists $var]} {unset $var}
  }
  if {!$multiFile} {
    foreach var {gpmiTypesPerFile spmiTypesPerFile} {if {[info exists $var]} {unset $var}}
  }
  update idletasks
  return 1
}
  
# -------------------------------------------------------------------------------------------------
proc addHeaderWorksheet {numFile fname} {
  global objDesign
  global excel worksheets worksheet cells row timeStamp fileSchema cadApps cadSystem opt localName p21e3
  global excel1 worksheet1 cells1 col1 legendColor syntaxErr
  global csvdirnam useXL
   
  if {[catch {
    set cadSystem ""
    set timeStamp ""
    set p21e3 0

    set hdr "Header"
    if {$useXL} { 
      outputMsg "Generating Header worksheet" blue
      set worksheet($hdr) [$worksheets Item [expr 1]]
      $worksheet($hdr) Activate
      $worksheet($hdr) Name $hdr
      set cells($hdr) [$worksheet($hdr) Cells]

# create directory for CSV files
    } elseif {$opt(XLSCSV) != "None"} {
      outputMsg "Generating Header CSV file" blue
      foreach var {csvdirnam csvfname fcsv} {catch {unset $var}}
      set csvdirnam "[file join [file dirname $localName] [file rootname [file tail $localName]]]-sfa-csv"
      file mkdir $csvdirnam
      set csvfname [file join $csvdirnam $hdr.csv]
      if {[file exists $csvfname]} {file delete -force $csvfname}
      set fcsv [open $csvfname w]
      #outputMsg $fcsv red
    }

    set row($hdr) 0
    foreach attr {Name FileDirectory FileDescription FileImplementationLevel FileTimeStamp FileAuthor \
                  FileOrganization FilePreprocessorVersion FileOriginatingSystem FileAuthorisation SchemaName} {
      incr row($hdr)
      if {$useXL} { 
        $cells($hdr) Item $row($hdr) 1 $attr
      } elseif {$opt(XLSCSV) != "None"} {
        set csvstr $attr
      }
      set objAttr [string trim [join [$objDesign $attr]]]

# FileDirectory
      if {$attr == "FileDirectory"} {
        if {$useXL} { 
          $cells($hdr) Item $row($hdr) 2 [$objDesign $attr]
        } elseif {$opt(XLSCSV) != "None"} {
          append csvstr ",[$objDesign $attr]"
          puts $fcsv $csvstr
        }
        outputMsg "$attr:  [$objDesign $attr]"

# SchemaName
      } elseif {$attr == "SchemaName"} {
        set sn [getSchemaFromFile $fname]
        if {$useXL} { 
          $cells($hdr) Item $row($hdr) 2 $sn
        } elseif {$opt(XLSCSV) != "None"} {
          append csvstr ",$sn"
          puts $fcsv $csvstr
        }
        outputMsg "$attr:  $sn" blue
        if {[string first "_MIM" $sn] != -1 && [string first "_MIM_LF" $sn] == -1} {
          errorMsg " SchemaName (FILE_SCHEMA) should end with '_MIM_LF', see Header worksheet"
          if {$useXL} {[[$worksheet($hdr) Range B11] Interior] Color $legendColor(red)}
        }
        if {[string first "AUTOMOTIVE_DESIGN_CC2" $sn] == 0} {
          errorMsg " This file uses an older version of STEP AP214.  See Help > Supported STEP APs"
        }

        set fileSchema [string toupper [string range $objAttr 0 5]]
        if {[string first "IFC" $fileSchema] == 0} {
          errorMsg " Use the IFC File Analyzer with IFC files."
          after 1000
          openURL https://www.nist.gov/services-resources/software/ifc-file-analyzer
        } elseif {$objAttr == "STRUCTURAL_FRAME_SCHEMA"} {
          errorMsg " This is a CIS/2 file that can be visualized with SteelVis.\n https://www.nist.gov/services-resources/software/steelvis-aka-cis2-viewer"
        }

# other File attributes
      } else {
        if {$attr == "FileDescription" || $attr == "FileAuthor" || $attr == "FileOrganization"} {
          set str1 "$attr:  "
          set str2 ""
          foreach item [$objDesign $attr] {
            append str1 "[string trim $item], "
            if {$useXL} { 
              append str2 "[string trim $item][format "%c" 10]"
            } elseif {$opt(XLSCSV) != "None"} {
              append str2 ",[string trim $item]"
            }
          }
          outputMsg [string range $str1 0 end-2]
          if {$useXL} { 
            $cells($hdr) Item $row($hdr) 2 "'[string trim $str2]"
            set range [$worksheet($hdr) Range "$row($hdr):$row($hdr)"]
            $range VerticalAlignment [expr -4108]
          } elseif {$opt(XLSCSV) != "None"} {
            append csvstr [string trim $str2]
            puts $fcsv $csvstr
          }
        } else {
          outputMsg "$attr:  $objAttr"
          if {$useXL} { 
            $cells($hdr) Item $row($hdr) 2 "'$objAttr"
            set range [$worksheet($hdr) Range "$row($hdr):$row($hdr)"]
            $range VerticalAlignment [expr -4108]
          } elseif {$opt(XLSCSV) != "None"} {
            append csvstr ",$objAttr"
            puts $fcsv $csvstr
          }
        }

# check implementation level        
        if {$attr == "FileImplementationLevel"} {
          if {[string first "\;" $objAttr] == -1} {
            errorMsg "FileImplementationLevel is usually '2\;1', see Header worksheet"
            if {$useXL} {[[$worksheet($hdr) Range B4] Interior] Color $legendColor(red)}
          } elseif {$objAttr == "4\;1"} {
            set p21e3 1
          }
        }

# check and add time stamp to multi file summary
        if {$attr == "FileTimeStamp"} {
          if {([string first "-" $objAttr] == -1 || [string length $objAttr] < 17 || [string length $objAttr] > 25) && $objAttr != ""} {
            errorMsg "FileTimeStamp has the wrong format, see Header worksheet"            
            if {$useXL} {[[$worksheet($hdr) Range B5] Interior] Color $legendColor(red)}
          }
          if {$numFile != 0 && [info exists cells1(Summary)] && $useXL} {
            set timeStamp $objAttr
            set colsum [expr {$col1(Summary)+1}]
            set range [$worksheet1(Summary) Range [cellRange 5 $colsum]]
            catch {$cells1(Summary) Item 5 $colsum "'[string range $timeStamp 2 9]"}
          }
        }
      }
    }

    if {$useXL} { 
      [[$worksheet($hdr) Range "A:A"] Font] Bold [expr 1]
      [$worksheet($hdr) Columns] AutoFit
      [$worksheet($hdr) Rows] AutoFit
      catch {[$worksheet($hdr) PageSetup] Orientation [expr 2]}
      catch {[$worksheet($hdr) PageSetup] PrintGridlines [expr 1]}
    }
      
# check for CAx-IF Recommended Practices in the file description
    set caxifrp {}
    foreach fd [$objDesign "FileDescription"] {
      set c1 [string first "CAx-IF Rec." $fd]
      if {$c1 != -1} {lappend caxifrp [string trim [string range $fd $c1+20 end]]}
    }
    if {[llength $caxifrp] > 0} {
      outputMsg "\nCAx-IF Recommended Practices: (www.cax-if.org/joint_testing_info.html#recpracs)" blue
      foreach item $caxifrp {
        outputMsg " $item"
        if {[string first "AP242" $fileSchema] == -1 && [string first "Tessellated" $item] != -1} {
          errorMsg "  Error: Recommended Practices related to 'Tessellated' only apply to AP242 files."
        }
      }
    }

# set the application from various file attributes, cadApps is a list of all apps defined in sfa-data.tcl, take the first one that matches
    set ok 0
    set app2 ""
    foreach attr {FileOriginatingSystem FilePreprocessorVersion FileDescription FileAuthorisation FileOrganization} {
      foreach app $cadApps {
        set app1 $app
        if {$cadSystem == "" && [string first [string tolower $app] [string tolower [join [$objDesign $attr]]]] != -1} {
          set cadSystem [join [$objDesign $attr]]

# for multiple files, modify the app string to fit in file summary worksheet
          if {$app == "3D_Evolution"}           {set app1 "CT 3D_Evolution"}
          if {$app == "CoreTechnologie"}        {set app1 "CT 3D_Evolution"}
          if {$app == "DATAKIT"}                {set app1 "Datakit"}
          if {$app == "EDMsix"}                 {set app1 "Jotne EDMsix"}
          if {$app == "Implementor Forum Team"} {set app1 "CAx-IF"}
          if {$app == "PRO/ENGINEER"}           {set app1 "Pro/E"}
          if {$app == "SOLIDWORKS"}             {set app1 "SolidWorks"}
          if {$app == "SOLIDWORKS MBD"}         {set app1 "SolidWorks MBD"}
          if {$app == "3D Reviewer"}            {set app1 "TechSoft3D 3D_Reviewer"}

          if {$app == "UGS - NX"}                {set app1 "UGS-NX"}
          if {$app == "UNIGRAPHICS"}             {set app1 "Unigraphics"}
          if {$app == "jt_step translator"}      {set app1 "Siemens NX"}
          if {$app == "SIEMENS PLM Software NX"} {set app1 "Siemens NX"}

          if {[string first "CATIA Version" $app] == 0}      {set app1 "CATIA V[string range $app 14 end]"}
          if {$app == "3D EXPERIENCE"} {set app1 "3D Experience"}
          if {[string first "CATIA V5" [$objDesign FileDescription]] != -1} {set app1 "CATIA V5"}
          if {[string first "CATIA V6" [$objDesign FileDescription]] != -1} {set app1 "CATIA V6"}

          if {[string first "CATIA SOLUTIONS V4" [$objDesign FileOriginatingSystem]] != -1} {set app1 "CATIA V4"}
          if {[string first "Autodesk Inventor"  [$objDesign FileOriginatingSystem]] != -1} {set app1 [$objDesign FileOriginatingSystem]}
          if {[string first "FreeCAD"            [$objDesign FileOriginatingSystem]] != -1} {set app1 "FreeCAD"}
          if {[string first "SIEMENS PLM Software NX" [$objDesign FileOriginatingSystem]] == 0} {set app1 "Siemens NX_[string range [$objDesign FileOriginatingSystem] 24 end]"}

          if {[string first "THEOREM"   [$objDesign FilePreprocessorVersion]] != -1} {set app1 "Theorem"}
          if {[string first "T-Systems" [$objDesign FilePreprocessorVersion]] != -1} {set app1 "T-Systems"}

# set caxifVendor based on CAx-IF vendor notation used in testing rounds, use for app if appropriate
          set caxifVendor [setCAXIFvendor]
          if {$caxifVendor != ""} {
            if {[string first [lindex [split $caxifVendor " "] 0] $app1] != -1} {
              if {[string length $caxifVendor] > [string length $app1]} {set app1 $caxifVendor}
            } elseif {[string first [lindex [split $app1 " "] 0] $caxifVendor] != -1} {
              if {[string length $caxifVendor] < [string length $app1]} {set app1 "$app1 ($caxifVendor)"}
            }
          }
          set ok 1
          set app2 $app1
          break
        }
      }
    }
    
# add app2 to multiple file summary worksheet    
    if {$numFile != 0 && $useXL && [info exists cells1(Summary)]} {
      if {$ok == 0} {set app2 [setCAXIFvendor]}
      set colsum [expr {$col1(Summary)+1}]
      if {$colsum > 16} {[$excel1 ActiveWindow] ScrollColumn [expr {$colsum-16}]}
      regsub -all " " $app2 [format "%c" 10] app2
      $cells1(Summary) Item 6 $colsum [string trim $app2]
    }
    set cadSystem $app2
    if {$cadSystem == ""} {set cadSystem [setCAXIFvendor]}

# close csv file
    if {!$useXL && $opt(XLSCSV) != "None"} {close $fcsv} 

  } emsg]} {
    errorMsg "ERROR adding Header worksheet: $emsg"
    catch {raise .}
  }
}

#-------------------------------------------------------------------------------------------------
# add summary worksheet
proc sumAddWorksheet {} {
  global worksheet cells sum sheetSort sheetLast col worksheets row entCategory opt entsIgnored excel
  global x3dFileName spmiEntity entCount gpmiEnts spmiEnts nistVersion
  global propDefRow

  outputMsg "\nGenerating Summary worksheet" blue
  set sum "Summary"
  #getTiming "done processing entities"

  set sheetSort {}
  foreach entType [lsort [array names worksheet]] {
    if {$entType != "Summary" && $entType != "Header" && $entType != "Section"} {
      lappend sheetSort "[setColorIndex $entType]$entType"
    }
  }
  set sheetSort [lsort $sheetSort]
  for {set i 0} {$i < [llength $sheetSort]} {incr i} {
    lset sheetSort $i [string range [lindex $sheetSort $i] 2 end]
  }
  #set ws_nsort [lsort $sheetSort]

  if {[catch {
    set worksheet($sum) [$worksheets Add [::tcom::na] $sheetLast]
    $worksheet($sum) Activate
    $worksheet($sum) Name $sum
    set cells($sum) [$worksheet($sum) Cells]
    $cells($sum) Item 1 1 "Entity"
    $cells($sum) Item 1 2 "Count"
    set ncol 2
    set col($sum) $ncol
    set sumLinks [$worksheet($sum) Hyperlinks]
  
    set wsCount [$worksheets Count]
    [$worksheets Item [expr $wsCount]] -namedarg Move Before [$worksheets Item [expr 1]]

# Summary of entities in column 1 and count in column 2
    set x3dLink 1
    set row($sum) 1
    foreach entType $sheetSort {
      incr row($sum)
      set sumRow [expr {[lsearch $sheetSort $entType]+2}]

# check if entity is compound as opposed to an entity with '_and_'
      set ok 0
      if {[string first "_and_" $entType] == -1} {
        set ok 1
      } else {
        foreach item [array names entCategory] {if {[lsearch $entCategory($item) $entType] != -1} {set ok 1}}
      }
      if {$ok} {
        $cells($sum) Item $sumRow 1 $entType
        
# for STEP add [Properties], [PMI Presentation], [PMI Representation] text string
        set okao 0
        if {$entType == "property_definition" && $col($entType) > 4 && $opt(VALPROP)} {
          $cells($sum) Item $sumRow 1 "property_definition  \[Properties\]"
        } elseif {$entType == "dimensional_characteristic_representation" && $col($entType) > 3 && $opt(PMISEM)} {
          $cells($sum) Item $sumRow 1 "dimensional_characteristic_representation  \[PMI Representation\]"
        } elseif {[lsearch $spmiEntity $entType] != -1 && $opt(PMISEM)} {
          $cells($sum) Item $sumRow 1 "$entType  \[PMI Representation\]"
        } elseif {[string first "annotation" $entType] != -1 && $opt(PMIGRF)} {
          if {$gpmiEnts($entType) && $col($entType) > 5} {set okao 1}
        }
        if {$okao} {
          $cells($sum) Item $sumRow 1 "$entType  \[PMI Presentation\]"
        }

# for '_and_' (complex entity) split on multiple lines
# '10' is the ascii character for a linefeed          
      } else {
        regsub -all "_and_" $entType ")[format "%c" 10][format "%c" 32][format "%c" 32][format "%c" 32](" entType_multiline
        set entType_multiline "($entType_multiline)"
        $cells($sum) Item $sumRow 1 $entType_multiline

# for STEP add [Properties] or [PMI Presentation] text string
        set okao 0
        if {[string first "annotation" $entType] != -1} {
          if {$gpmiEnts($entType) && $col($entType) > 7} {set okao 1}
        } elseif {[lsearch $spmiEntity $entType] != -1} {
          $cells($sum) Item $sumRow 1 "$entType_multiline  \[PMI Representation\]"
        }
        if {$okao} {
          $cells($sum) Item $sumRow 1 "$entType_multiline  \[PMI Presentation\]"
        }
        set range [$worksheet($sum) Range $sumRow:$sumRow]
        $range VerticalAlignment [expr -4108]
      }

# entity count in column 2
      $cells($sum) Item $sumRow 2 $entCount($entType)
    }

# entities not processed
    set rowIgnored [expr {[array size worksheet]+2}]
    $cells($sum) Item $rowIgnored 1 "Entity types not processed ([array size entsIgnored])"

    foreach ent [lsort [array names entsIgnored]] {
      set ok 0
      if {[string first "_and_" $ent] == -1} {
        set ok 1
      } else {
        foreach item [array names entCategory] {if {[lsearch $entCategory($item) $ent] != -1} {set ok 1}}
      }
      if {$ok} {
        $cells($sum) Item [incr rowIgnored] 1 $ent
      } else {
# '10' is the ascii character for a linefeed          
        regsub -all "_and_" $ent ")[format "%c" 10][format "%c" 32][format "%c" 32][format "%c" 32](" ent1
        $cells($sum) Item [incr rowIgnored] 1 "($ent1)"
        set range [$worksheet($sum) Range $rowIgnored:$rowIgnored]
        $range VerticalAlignment [expr -4108]
      }
      $cells($sum) Item $rowIgnored 2 $entsIgnored($ent)
    }
    set row($sum) $rowIgnored
    [$excel ActiveWindow] ScrollRow [expr 1]

# autoformat entire summary worksheet
    set range [$worksheet($sum) Range [cellRange 1 1] [cellRange $row($sum) $col($sum)]]
    $range AutoFormat
    
# name and link to program website that generated the spreadsheet
    set str "NIST "
    set url "https://www.nist.gov/services-resources/software/step-file-analyzer"
    if {!$nistVersion} {
      set str ""
      set url "https://github.com/usnistgov/SFA"
    }
    $cells($sum) Item [expr {$row($sum)+2}] 1 "$str\STEP File Analyzer (v[getVersion])"
    set anchor [$worksheet($sum) Range [cellRange [expr {$row($sum)+2}] 1]]
    [$worksheet($sum) Hyperlinks] Add $anchor [join $url] [join ""] [join "Link to $str\STEP File Analyzer"]
    $cells($sum) Item [expr {$row($sum)+3}] 1 "[clock format [clock seconds]]"

# print errors
  } emsg]} {
    errorMsg "ERROR adding Summary worksheet: $emsg"
    catch {raise .}
  }
  return [list $sumLinks $sheetSort $sumRow]
  #return [list $sumLinks $sumDocCol $sheetSort $sumRow]
}

#-------------------------------------------------------------------------------------------------
# add file name and other info to top of Summary
proc sumAddFileName {sum sumLinks} {
  global worksheet cells timeStamp cadSystem xlFileName localName opt entityCount stepAP schemaLinks
  global tolStandard dim fileSchema1

  set sumHeaderRow 0
  if {[catch {
    $worksheet($sum) Activate
    [$worksheet($sum) Range "1:1"] Insert

    if {[info exists dim(unit)] && $dim(unit) != ""} {
      [$worksheet($sum) Range "1:1"] Insert
      $cells($sum) Item 1 1 "Dimension Units"
      $cells($sum) Item 1 2 "$dim(unit)"
      set range [$worksheet($sum) Range "B1:K1"]
      $range MergeCells [expr 1]
      incr sumHeaderRow
    }

    if {$tolStandard(type) != ""} {
      [$worksheet($sum) Range "1:1"] Insert
      $cells($sum) Item 1 1 "Standards"
      if {$tolStandard(num) != ""} {
        $cells($sum) Item 1 2 [string trim $tolStandard(num)]
        #set range [$worksheet($sum) Range "1:1"]
        #$range VerticalAlignment [expr -4108]
      } else {
        $cells($sum) Item 1 2 [string trim $tolStandard(type)]
      }
      set range [$worksheet($sum) Range "B1:K1"]
      $range MergeCells [expr 1]
      incr sumHeaderRow
    }
  
    if {$stepAP != ""} {
      [$worksheet($sum) Range "1:1"] Insert
      $cells($sum) Item 1 1 "Schema"
      $cells($sum) Item 1 2 "'$stepAP"
      set range [$worksheet($sum) Range "B1:K1"]
      $range MergeCells [expr 1]
      if {[info exists schemaLinks($stepAP)]} {
        set anchor [$worksheet($sum) Range "B1"]
        $sumLinks Add $anchor $schemaLinks($stepAP) [join ""] [join "Link to $stepAP schema documentation"]
      }
      incr sumHeaderRow
    } else {
      [$worksheet($sum) Range "1:1"] Insert
      $cells($sum) Item 1 1 "Schema"
      $cells($sum) Item 1 2 "'$fileSchema1"
      set range [$worksheet($sum) Range "B1:K1"]
      $range MergeCells [expr 1]
      incr sumHeaderRow
    }

    [$worksheet($sum) Range "1:1"] Insert
    $cells($sum) Item 1 1 "Total Entities"
    $cells($sum) Item 1 2 "'$entityCount"
    set range [$worksheet($sum) Range "B1:K1"]
    $range MergeCells [expr 1]
    incr sumHeaderRow

    if {$timeStamp != ""} {
      [$worksheet($sum) Range "1:1"] Insert
      $cells($sum) Item 1 1 "Timestamp"
      $cells($sum) Item 1 2 [join $timeStamp]
      set range [$worksheet($sum) Range "B1:K1"]
      $range MergeCells [expr 1]
      incr sumHeaderRow
    }

    if {$cadSystem != ""} {
      [$worksheet($sum) Range "1:1"] Insert
      $cells($sum) Item 1 1 "Application"
      $cells($sum) Item 1 2 [join $cadSystem]
      set range [$worksheet($sum) Range "B1:K1"]
      $range MergeCells [expr 1]
      incr sumHeaderRow
    }

    [$worksheet($sum) Range "1:1"] Insert
    $cells($sum) Item 1 1 "Excel File"
    if {[file dirname $localName] == [file dirname $xlFileName]} {
      $cells($sum) Item 1 2 [file tail $xlFileName]
    } else {
      $cells($sum) Item 1 2 [truncFileName $xlFileName]
    }
    set range [$worksheet($sum) Range "B1:K1"]
    $range MergeCells [expr 1]
    incr sumHeaderRow

    [$worksheet($sum) Range "1:1"] Insert
    $cells($sum) Item 1 1 "STEP File"
    $cells($sum) Item 1 2 [file tail $localName]
    set range [$worksheet($sum) Range "B1:K1"]
    $range MergeCells [expr 1]
    set anchor [$worksheet($sum) Range "B1"]
    if {$opt(XL_LINK1)} {$sumLinks Add $anchor [join $localName] [join ""] [join "Link to STEP file"]}
    incr sumHeaderRow

    [$worksheet($sum) Range "1:1"] Insert
    $cells($sum) Item 1 1 "STEP Directory"
    $cells($sum) Item 1 2 [file nativename [file dirname [truncFileName $localName]]]
    set range [$worksheet($sum) Range "B1:K1"]
    $range MergeCells [expr 1]
    incr sumHeaderRow

    set range [$worksheet($sum) Range [cellRange 1 1] [cellRange $sumHeaderRow 1]]
    [$range Font] Bold [expr 1]

  } emsg]} {
    errorMsg "ERROR adding File Names to Summary: $emsg"
    catch {raise .}
  }
  return $sumHeaderRow
}

#-------------------------------------------------------------------------------------------------
# add file name and other info to top of Summary
proc sumAddColorLinks {sum sumHeaderRow sumLinks sheetSort sumRow} {
  global worksheet cells row excel entName xlFileName col entsIgnored entsWithErrors

  if {[catch {
    #outputMsg " Adding links on Summary to Entity worksheets"
    set row($sum) [expr {$sumHeaderRow+2}]

    foreach ent $sheetSort {
      update idletasks

      incr row($sum)
      set nrow [expr {20-$sumHeaderRow}]
      if {$row($sum) > $nrow} {[$excel ActiveWindow] ScrollRow [expr {$row($sum)-$nrow}]}

      set sumRow [expr {[lsearch $sheetSort $ent]+3+$sumHeaderRow}]

# link from summary to entity worksheet
      set anchor [$worksheet($sum) Range "A$sumRow"]
      set hlsheet $ent
      if {[string length $ent] > 31} {
        foreach item [array names entName] {
          if {$entName($item) == $ent} {set hlsheet $item}
        }
      }
      $sumLinks Add $anchor $xlFileName "$hlsheet!A4" "Go to $ent"

# color cells
      set cidx [setColorIndex $ent]
      if {$cidx > 0} {

# color entities on summary if no errors or warnings and add comment that there are CAx-IF RP errors    
        if {[lsearch $entsWithErrors [formatComplexEnt $ent]] == -1} {
          [$anchor Interior] ColorIndex [expr $cidx]

# color entities on summary gray and add comment that there are CAx-IF RP errors    
        } else {
          [$anchor Interior] ColorIndex [expr 15]
          if {$ent != "dimensional_characteristic_representation"} {
            addCellComment $sum $sumRow 1 "There are errors or warnings for this entity based on CAx-IF Recommended Practices.  See Help > Syntax Errors." 300 25
          } else {
            addCellComment $sum $sumRow 1 "There are errors or warnings for this entity based on CAx-IF Recommended Practices.  Check for cell comments in the Associated Geometry column.  See Help > Syntax Errors." 300 50
          }
        }
        catch {
          [[$anchor Borders] Item [expr 8]] Weight [expr 1]
          [[$anchor Borders] Item [expr 9]] Weight [expr 1]
        }
      }

# bold entities for reports
      if {[string first "\[" [$anchor Value]] != -1} {[$anchor Font] Bold [expr 1]}

      set ncol [expr {$col($sum)-1}]
    }

# add links for entsIgnored entities, find row where they start
    set i1 [expr {max([array size worksheet],9)}]
    for {set i $i1} {$i < 1000} {incr i} {
      if {[string first "Entity types" [[$cells($sum) Item $i 1] Value]] == 0} {
        set rowIgnored $i
        break
      }
    }
    set range [$worksheet($sum) Range "A$rowIgnored"]
    [$range Font] Bold [expr 1]

    set i1 0
    set range [$worksheet($sum) Range [cellRange $rowIgnored 1] [cellRange $rowIgnored [expr {$col($sum)+$i1}]]]
    catch {[[$range Borders] Item [expr 8]] Weight [expr -4138]}

    foreach ent [lsort [array names entsIgnored]] {
      incr rowIgnored
      set nrow [expr {20-$sumHeaderRow}]
      if {$rowIgnored > $nrow} {[$excel ActiveWindow] ScrollRow [expr {$rowIgnored-$nrow}]}
      set ncol [expr {$col($sum)-1}]

      set range [$worksheet($sum) Range [cellRange $rowIgnored 1]]
      set cidx [setColorIndex $ent]
      if {$cidx > 0} {[$range Interior] ColorIndex [expr $cidx]}      
    }
    [$worksheet($sum) Columns] AutoFit
    [$worksheet($sum) Rows] AutoFit
    [$worksheet($sum) PageSetup] PrintGridlines [expr 1]
    
  } emsg]} {
    errorMsg "ERROR adding Summary colors and links: $emsg"
    catch {raise .}
  }
}

#-------------------------------------------------------------------------------------------------
# format worksheets
proc formatWorksheets {sheetSort sumRow inverseEnts} {
  global buttons worksheet worksheets excel cells opt count entCount col row rowmax xlFileName thisEntType schemaLinks stepAP syntaxErr
  global gpmiEnts spmiEnts nprogBarEnts excelVersion
  
  outputMsg "Formatting Worksheets" blue

  if {[info exists buttons]} {$buttons(pgb) configure -maximum [llength $sheetSort]}
  set nprogBarEnts 0
  set nsort 0

  foreach thisEntType $sheetSort {
    #getTiming "START FORMATTING $thisEntType"
    #outputMsg $thisEntType
    incr nprogBarEnts
    update idletasks
    
    if {[catch {
      $worksheet($thisEntType) Activate
      [$excel ActiveWindow] ScrollRow [expr 1]

# move some worksheets to the correct position, originally moved to process semantic PMI data in the necessary order
      set moveWS 0
      if {$opt(PMISEM)} {
        foreach item {angularity_tolerance circular_runout_tolerance coaxiality_tolerance \
                      concentricity_tolerance cylindricity_tolerance dimensional_characteristic_representation} {
          if {[info exists entCount($item)] && $item == $thisEntType} {set moveWS 1}
        }
      }
      
      if {$moveWS} {
        if {[string first "dimensional_characteristic_repr" $thisEntType] == 0} {
          set n 0
          set p1 0
          set p2 1000
          foreach item {dimensional_characteristic_repr dimensional_location dimensional_size} {
            incr n
            for {set i 1} {$i <= [$worksheets Count]} {incr i} {
              if {$item == [[$worksheets Item [expr $i]] Name]} {
                if {$n == 1} {
                  set p1 $i
                } else {
                  set p2 [expr {min($p2,$i)}]
                }
              }
            }
          }
          if {$p1 != 0 && $p2 != 1000} {[$worksheets Item [expr $p1]] -namedarg Move Before [$worksheets Item [expr $p2]]}
        }

        foreach item {angularity_tolerance circular_runout_tolerance coaxiality_tolerance concentricity_tolerance cylindricity_tolerance} {
          if {$item == $thisEntType} {
            set n 0
            set p1 0
            set p2 1000
            foreach ent [list $item datum] {
              incr n
              for {set i 1} {$i <= [$worksheets Count]} {incr i} {
                if {$ent == [[$worksheets Item [expr $i]] Name]} {
                  if {$n == 1} {
                    set p1 $i
                  } else {
                    set p2 [expr {min($p2,$i)}]
                  }
                }
              }
            }
            if {$p1 != 0 && $p2 != 1000} {[$worksheets Item [expr $p1]] -namedarg Move Before [$worksheets Item [expr $p2]]}
          }
        }
      }
      
# find extent of columns
      set rancol $col($thisEntType)
      for {set i 1} {$i < 10} {incr i} {
        if {[[$cells($thisEntType) Item 3 [expr {$col($thisEntType)+$i}]] Value] != ""} {
          incr rancol
        } else {
          break
        }
      }
      #getTiming " column extent"

# find extent of rows
      set ranrow [expr {$row($thisEntType)+2}]
      if {$ranrow > $rowmax} {set ranrow [expr {$rowmax+2}]}
      set ranrow [expr {$ranrow-2}]
      #getTiming " row extent"
      #outputMsg "$thisEntType  $ranrow  $rancol  $col($thisEntType)"

# autoformat
      set range [$worksheet($thisEntType) Range [cellRange 3 1] [cellRange $ranrow $rancol]]
      $range AutoFormat
      #getTiming " autoformat"

# freeze panes
      [$worksheet($thisEntType) Range "B4"] Select
      catch {[$excel ActiveWindow] FreezePanes [expr 1]}
      
# set A4 as default cell
      [$worksheet($thisEntType) Range "A4"] Select

# set column color, border, group for INVERSES and Used In
      if {$opt(INVERSE)} {if {[lsearch $inverseEnts $thisEntType] != -1} {invFormat $rancol}}
      #getTiming " format inverses"

# STEP Property_definition (Validation Properties)
      if {$thisEntType == "property_definition" && $opt(VALPROP)} {
        valPropFormat
        #getTiming " format valprop"

# color STEP annotation occurrence (Graphical PMI)
      } elseif {$gpmiEnts($thisEntType) && $opt(PMIGRF)} {
        pmiFormatColumns "PMI Presentation"
        #getTiming " format gpmi"

# color STEP semantic PMI
      } elseif {$spmiEnts($thisEntType) && $opt(PMISEM)} {
        pmiFormatColumns "PMI Representation"

# add PMI Representation Summary worksheet
        spmiSummary
        #getTiming " format spmi"
      }

# -------------------------------------------------------------------------------------------------
# link back to summary on entity worksheets
      set hlink [$worksheet($thisEntType) Hyperlinks]
      set txt "[formatComplexEnt $thisEntType]  "
      set row1 [expr {$row($thisEntType)-3}]
      if {$row1 == $count($thisEntType) && $row1 == $entCount($thisEntType)} {
        append txt "($row1)"
      } elseif {$row1 > $count($thisEntType) && $count($thisEntType) < $entCount($thisEntType)} {
        append txt "($count($thisEntType) of $entCount($thisEntType))"
      } elseif {$row1 < $entCount($thisEntType)} {
        if {$count($thisEntType) == $entCount($thisEntType)} {
          append txt "($row1 of $entCount($thisEntType))"
        } else {
          append txt "([expr {$row1-3}] of $count($thisEntType))"
        }
      }
      $cells($thisEntType) Item 1 1 $txt
      set range [$worksheet($thisEntType) Range "A1:H1"]
      $range MergeCells [expr 1]

# link back to summary
      set anchor [$worksheet($thisEntType) Range "A1"]
      $hlink Add $anchor $xlFileName "Summary!A$sumRow" "Return to Summary"
      #getTiming " insert links in first two rows"

# check width of columns, wrap text
      if {[catch {
        set widlim 400.
        for {set i 2} {$i <= $rancol} {incr i} {
          if {[[$cells($thisEntType) Item 3 $i] Value] != ""} {
            set wid [[$cells($thisEntType) Item 3 $i] Width]
            if {$wid > $widlim} {
              set range [$worksheet($thisEntType) Range [cellRange -1 $i]]
              $range ColumnWidth [expr {[$range ColumnWidth]/$wid * $widlim}]
              $range WrapText [expr 1]
            }
          }
        }
      } emsg]} {
        errorMsg "ERROR setting column widths: $emsg\n  $thisEntType"
        catch {raise .}
      }
      #getTiming " check column width"
      
# color red for syntax errors
      if {[info exists syntaxErr($thisEntType)]} {colorBadCells $thisEntType}
      #getTiming " color bad syntax"
  
# -------------------------------------------------------------------------------------------------
# add table for sorting and filtering
      if {$excelVersion >= 12} {
        if {[catch {
          if {$opt(XL_SORT) && $thisEntType != "property_definition"} {
            if {$ranrow > 8} {
              set range [$worksheet($thisEntType) Range [cellRange 3 1] [cellRange $ranrow $rancol]]
              set tname [string trim "TABLE-$thisEntType"]
              [[$worksheet($thisEntType) ListObjects] Add 1 $range] Name $tname
              [[$worksheet($thisEntType) ListObjects] Item $tname] TableStyle "TableStyleLight1" 
              if {[incr ntable] == 1 && $opt(XL_SORT)} {outputMsg " Generating Tables for Sorting" blue}
            }
          }
        } emsg]} {
          errorMsg "ERROR adding Tables for Sorting: $emsg"
          catch {raise .}
        }
      }

# errors
    } emsg]} {
      errorMsg "ERROR formatting Spreadsheet for: $thisEntType\n$emsg"
      catch {raise .}
    }
  }
}

# -------------------------------------------------------------------------------------------------
proc addP21e3Section {} {
  global objDesign
  global p21e3Section worksheets legendColor
  
  foreach line $p21e3Section {
    if {$line == "ANCHOR" || $line == "REFERENCE" || $line == "SIGNATURE"} {
      set sect $line
      set worksheet($sect) [$worksheets Add [::tcom::na] [$worksheets Item [$worksheets Count]]]
      set n [$worksheets Count]
      [$worksheets Item [expr $n]] -namedarg Move Before [$worksheets Item [expr 3]]
      $worksheet($sect) Activate
      $worksheet($sect) Name $sect
      set cells($sect) [$worksheet($sect) Cells]
      set r 0
      outputMsg " Adding $line worksheet" green
    }

    incr r
    $cells($sect) Item $r 1 $line

    if {$sect == "ANCHOR"} {
      if {$r == 1} {$cells($sect) Item $r 2 "Entity"}
      set c2 [string first ";" $line]
      if {$c2 != -1} {set line [string range $line 0 $c2-1]}

      set c1 [string first "\#" $line]
      if {$c1 != -1} {
        set badEnt 0
        set anchorID [string range $line $c1+1 end]
        if {[string is integer $anchorID]} {
          set anchorEnt [$objDesign FindObjectByP21Id [expr {int($anchorID)}]]
          if {$anchorEnt != ""} {
            $cells($sect) Item $r 2 [[$objDesign FindObjectByP21Id [expr {int($anchorID)}]] Type]
          } else {
            set badEnt 1
          }
        } else {
          set badEnt 1
        }
        if {$badEnt} {
          [[$worksheet($sect) Range [cellRange $r 1] [cellRange $r 1]] Interior] Color $legendColor(red)
          errorMsg "Syntax Error: Bad format for entity ID in ANCHOR section."
        }
      }
    }
    
    if {$line == "ENDSEC"} {[$worksheet($sect) Columns] AutoFit}
  }
}
