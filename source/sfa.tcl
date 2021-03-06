# This software was developed at the National Institute of Standards and Technology by employees of 
# the Federal Government in the course of their official duties.  Pursuant to Title 17 Section 105 
# of the United States Code this software is not subject to copyright protection and is in the 
# public domain. This software is an experimental system.  NIST assumes no responsibility whatsoever 
# for its use by other parties, and makes no guarantees, expressed or implied, about its quality, 
# reliability, or any other characteristic.  We would appreciate acknowledgement if the software is 
# used.
# 
# This software can be redistributed and/or modified freely provided that any derivative works bear 
# some notice that they are derived from it, and any modified versions bear some notice that they 
# have been modified. 

# The latest version of the source code is available at: https://github.com/usnistgov/SFA

# ----------------------------------------------------------------------------------------------
# The STEP File Analyzer can only be built with Tcl 8.5.15 or earlier
# More recent versions are incompatibile with the IFCsvr toolkit that is used to read STEP files
# ----------------------------------------------------------------------------------------------
# This is the main routine for the STEP File Analyzer GUI version

global env tcl_platform

set scriptName [info script]
set wdir [file dirname $scriptName]
set auto_path [linsert $auto_path 0 $wdir]

# for building your own version without Tcl Dev Kit, uncomment and modify C:/Tcl/lib/teapot directory if necessary
# lappend commands add package locations to auto_path, must be before package commands
#lappend auto_path C:/Tcl/lib/teapot/package/win32-ix86/lib/tcom3.9
#lappend auto_path C:/Tcl/lib/teapot/package/win32-ix86/lib/twapi3.0.32
#lappend auto_path C:/Tcl/lib/teapot/package/win32-ix86/lib/Tclx8.4
#lappend auto_path C:/Tcl/lib/teapot/package/win32-ix86/lib/Itk3.4
#lappend auto_path C:/Tcl/lib/teapot/package/win32-ix86/lib/Itcl3.4
#lappend auto_path C:/Tcl/lib/teapot/package/tcl/lib/Iwidgets4.0.2

# Tcl packages, check if they will load
if {[catch {
  package require tcom
  package require twapi
  package require Tclx
  package require Iwidgets 4.0.2
} emsg]} {
  set dir $wdir
  set c1 [string first [file tail [info nameofexecutable]] $dir]
  if {$c1 != -1} {set dir [string range $dir 0 $c1-1]}
  set choice [tk_messageBox -type ok -icon error -title "ERROR" -message "ERROR: $emsg\n\nThere might be a problem running this program from a directory with accented, non-English, or symbol characters in the pathname.\n\n     [file nativename $dir]\n\nRun the software from a directory without any of the special characters in the pathname.\n\nPlease contact Robert Lipman (robert.lipman@nist.gov) for other problems."]
  exit
}

catch {
  #lappend auto_path C:/Tcl/lib/teapot/package/win32-ix86/lib/vfs1.4.2
  package require vfs::zip
}

catch {
  #lappend auto_path C:/Tcl/lib/teapot/package/tcl/lib/tooltip1.4.4
  package require tooltip
}

# -----------------------------------------------------------------------------------------------------
# set drive, myhome, mydocs, mydesk
setHomeDir

# set program files
set pf32 "C:\Program Files (x86)"
if {[info exists env(ProgramFiles)]}  {set pf32 $env(ProgramFiles)}
if {[string first "x86" $pf32] == -1} {append pf32 " (x86)"}
set pf64 "C:\Program Files"
if {[info exists env(ProgramW6432)]} {set pf64 $env(ProgramW6432)}

# detect if NIST version
set nistVersion 0
foreach item $auto_path {if {[string first "STEP-File-Analyzer" $item] != -1} {set nistVersion 1}}

# -----------------------------------------------------------------------------------------------------
# initialize variables
foreach id {XL_OPEN XL_KEEPOPEN XL_LINK1 XL_FPREC XL_SORT LOGFILE \
            VALPROP PMIGRF PMISEM VIZPMI VIZFEA VIZTES VIZPMIVP VIZFEALVS INVERSE DEBUG1 \
            PR_STEP_AP242 PR_USER PR_STEP_KINE PR_STEP_COMP PR_STEP_COMM PR_STEP_GEOM PR_STEP_QUAN \
            PR_STEP_FEAT PR_STEP_PRES PR_STEP_TOLR PR_STEP_REPR PR_STEP_CPNT PR_STEP_SHAP} {set opt($id) 1}

set opt(CRASH) 0
set opt(DEBUG1) 0
set opt(DEBUGINV) 0
set opt(DISPGUIDE1) 1
set opt(FIRSTTIME) 1
set opt(gpmiColor) 2
set opt(indentGeometry) 0
set opt(indentStyledItem) 0
set opt(INVERSE) 0
set opt(PR_STEP_CPNT) 0
set opt(PR_STEP_GEOM)  0
set opt(PR_USER) 0
set opt(VIZFEALVS) 0
set opt(VIZPMIVP) 0
set opt(writeDirType) 0
set opt(XL_KEEPOPEN) 0
set opt(XL_ROWLIM) 1048576
set opt(XL_SORT) 0
set opt(XLSBUG1) 30
set opt(XLSCSV) Excel

set coverageSTEP 0
set dispCmd "Default"
set dispCmds {}
set edmWhereRules 0
set edmWriteToFile 0
set eeWriteToFile  0
set excelYear ""
set lastX3DOM ""
set lastXLS  ""
set lastXLS1 ""
set openFileList {}
set pointLimit 2
set sfaVersion 0
set upgrade 0
set userXLSFile ""
set x3dFileName ""
set x3dStartFile 1

set fileDir  $mydocs
set fileDir1 $mydocs
set userWriteDir $mydocs
set writeDir $userWriteDir

set developer 0
if {$env(USERNAME) == "lipman"} {set developer 1}

# initialize data
initData
initDataInverses

# -----------------------------------------------------------------------------------------------------
# check for options file and read (source)
set optionsFile [file nativename [file join $fileDir STEP-File-Analyzer-options.dat]]
if {[file exists $optionsFile]} {
  if {[catch {
    source $optionsFile

# rename and unset old variable names from old options file
    if {[info exists verite]} {set sfaVersion $verite; unset verite}
    if {[info exists indentStyledItem]} {set opt(indentStyledItem) $indentStyledItem; unset indentStyledItem}
    if {[info exists indentGeometry]}   {set opt(indentGeometry)   $indentGeometry;   unset indentGeometry}
    if {[info exists writeDirType]}     {set opt(writeDirType)     $writeDirType;     unset writeDirType}
  
    if {[info exists gpmiColor]} {set opt(gpmiColor) $gpmiColor; unset gpmiColor}
    if {[info exists row_limit]} {set opt(XL_ROWLIM) $row_limit; unset row_limit}
    if {[info exists firsttime]} {set opt(FIRSTTIME) $firsttime; unset firsttime}
    if {[info exists ncrash]}    {set opt(CRASH)     $ncrash;    unset ncrash}
  
    if {[info exists flag(CRASH)]}      {set opt(CRASH)      $flag(CRASH);      unset flag(CRASH)}
    if {[info exists flag(FIRSTTIME)]}  {set opt(FIRSTTIME)  $flag(FIRSTTIME);  unset flag(FIRSTTIME)}
    if {[info exists flag(DISPGUIDE1)]} {set opt(DISPGUIDE1) $flag(DISPGUIDE1); unset flag(DISPGUIDE1)}
  
    foreach item {PR_STEP_BAD PR_STEP_UNIT PR_TYPE XL_XLSX COUNT EX_A2P3D FN_APPEND XL_LINK2 XL_LINK3 XL_ORIENT \
                  XL_SCROLL PMIVRML PMIPROP SEMPROP PMIP EX_ANAL EX_ARBP EX_LP VPDBG \
                  PR_STEP_AP242_QUAL PR_STEP_AP242_CONS PR_STEP_AP242_MATH PR_STEP_AP242_KINE PR_STEP_AP242_OTHER PR_STEP_AP242_GEOM \
                  PR_STEP_AP209 PR_STEP_AP210 PR_STEP_AP238 PR_STEP_AP239 PR_STEP_AP203 PR_STEP_AP214 PR_STEP_OTHER \
                  PR_STEP_GEO PR_STEP_REP PR_STEP_ASPECT ROWLIM SORT GENX3DOM VIZ209 feaNodeType XLSBUG} {
      catch {unset opt($item)}
    }
  } emsg]} {
    set endMsg "Error reading options file: [truncFileName $optionsFile]\n $emsg\nFix or delete the file."
  }
}
set opt(XL_KEEPOPEN) 0

# check some directory variables
if {[info exists userWriteDir]} {if {![file exists $userWriteDir]} {set userWriteDir $mydocs}}
if {[info exists fileDir]}      {if {![file exists $fileDir]}      {set fileDir      $mydocs}}
if {[info exists fileDir1]}     {if {![file exists $fileDir1]}     {set fileDir1     $mydocs}}
if {[info exists userEntityFile]} {
  if {![file exists $userEntityFile]} {
    set userEntityFile ""
    set opt(PR_USER) 0
  }
}

# fix row limit
if {$opt(XL_ROWLIM) < 103 || ([string range $opt(XL_ROWLIM) end-1 end] != "03" && \
   [string range $opt(XL_ROWLIM) end-1 end] != "76" && [string range $opt(XL_ROWLIM) end-1 end] != "36")} {set opt(XL_ROWLIM) 103}

# for output format buttons
set ofExcel 0
set ofCSV 0
set ofNone 0
switch $opt(XLSCSV) {
  Excel   {set ofExcel 1}
  CSV     {set ofExcel 1; set ofCSV 1}
  None    {set ofNone 1}
  default {set ofExcel 1}
}

# -------------------------------------------------------------------------------
# get programs that can open STEP files
getOpenPrograms

# -------------------------------------------------------------------------------
# user interface
guiStartWindow

# top menu
set Menu [menu .menubar]
. config -men .menubar
foreach m {File Websites Examples Help} {
  set $m [menu .menubar.m$m -tearoff 1]
  .menubar add cascade -label $m -menu .menubar.m$m
}

# check if menu font is Segoe UI for windows 7 or greater
catch {
  if {$tcl_platform(osVersion) >= 6.0} {
    set ff [join [$File cget -font]]
    if {[string first "Segoe" $ff] == -1} {
      $File     configure -font [list {Segoe UI}]
      $Websites configure -font [list {Segoe UI}]
      $Examples configure -font [list {Segoe UI}]
      $Help     configure -font [list {Segoe UI}]
    }
  }
}

# File menu
guiFileMenu

# What's New
set progtime 0
foreach fname [glob -nocomplain -directory $wdir *.tcl] {
  set mtime [file mtime $fname]
  if {$mtime > $progtime} {set progtime $mtime}
}

# -------------------------------------------------------------------------------
proc whatsNew {} {
  global progtime sfaVersion
  
  if {$sfaVersion > 0 && $sfaVersion < [getVersion]} {outputMsg "\nThe previous version of the STEP File Analyzer was: $sfaVersion" red}

outputMsg "\nWhat's New (Version: [getVersion]  Updated: [string trim [clock format $progtime -format "%e %b %Y"]])" blue
outputMsg "- Improved reporting of Associated Geometry
- Improved visualization of AP209 boundary conditions and loads (Help > AP209 Finite Element Model)
- Explanation of Report errors (Help > Syntax Errors)
- Support for repetitive hole and radius dimensions, e.g, '4X' R10.5
- Detect unexpected Associated Geometry for hole and radius dimensions
- Bug fixes and minor improvements"

if {$sfaVersion <= 2.60} {
  outputMsg "\nRenamed output files:\n Spreadsheets from  myfile_stp.xlsx  to  myfile-sfa.xlsx\n Visualizations from  myfile-x3dom.html  to  myfile-sfa.html" red
}

  .tnb select .tnb.status
  update idletasks
}

# -------------------------------------------------------------------------------
# Help and Websites menu
guiHelpMenu
guiWebsitesMenu

# tabs
set nb [ttk::notebook .tnb]
pack $nb -fill both -expand true

# status tab
guiStatusTab

# options tab
guiProcessAndReports

# inverse relationships
guiInverse

# open option, output format
guiOpenSTEPFile
pack $fopt -side top -fill both -expand true -anchor nw

# spreadsheet tab
guiSpreadsheet

# generate logo, progress bars
guiButtons

# switch to options tab (any text output will switch back to the status tab)
.tnb select .tnb.options

#-------------------------------------------------------------------------------
# first time user
set copyrose 0
set ask 0

if {$opt(FIRSTTIME)} {
  whatsNew
  if {$nistVersion} {showDisclaimer}
  
  set sfaVersion [getVersion]
  set opt(FIRSTTIME) 0
  
  after 1000
  showUsersGuide
  set opt(DISPGUIDE1) 0
  
  saveState
  set copyrose 1
  setShortcuts
  
  outputMsg " "
  errorMsg "Use F6 and F5 to change the font size."
  saveState

# what's new message
} elseif {$sfaVersion < [getVersion]} {
  whatsNew
  if {$sfaVersion < [getVersionUG]} {
    errorMsg "- A new version of the User's Guide is now available"
    showUsersGuide
  }
  if {$sfaVersion < 2.30} {
    errorMsg "- The command-line version has been renamed: sfa-cl.exe  The old version STEP-File-Analyzer-CL.exe can be deleted."
  }
  set sfaVersion [getVersion]
  saveState
  set copyrose 1
  setShortcuts

} elseif {$sfaVersion > [getVersion]} {
  set sfaVersion [getVersion]
  saveState
}
  
if {$developer} {set copyrose 1}

#-------------------------------------------------------------------------------
# crash recovery message
if {$opt(CRASH) < 2} {
  showCrashRecovery
  incr opt(CRASH)
  saveState
}

#-------------------------------------------------------------------------------
# check for update every 30 days
if {$nistVersion} {
  if {$upgrade > 0} {
    set lastupgrade [expr {round(([clock seconds] - $upgrade)/86400.)}]
    if {$lastupgrade > 30} {
      set choice [tk_messageBox -type yesno -default yes -title "Check for Update" \
        -message "Do you want to check for a newer version of the STEP File Analyzer?\n \nThe last check for an update was $lastupgrade days ago.\n \nYou can always check for an update with Help > Check for Update" -icon question]
      if {$choice == "yes"} {
        set url "https://concrete.nist.gov/cgi-bin/ctv/sfa_upgrade.cgi?version=[getVersion]&auto=$lastupgrade"
        if {[info exists excelYear]} {if {$excelYear != ""} {append url "&yr=[expr {$excelYear-2000}]"}}
        openURL $url
      }
      set upgrade [clock seconds]
      saveState
    }
  } else {
    set upgrade [clock seconds]
    saveState
  }
}

# open user's guide if it hasn't already
if {$opt(DISPGUIDE1)} {
  showUsersGuide
  set opt(DISPGUIDE1) 0
  saveState
}

#-------------------------------------------------------------------------------
# install IFCsvr
set sfaType "GUI"
set ifcsvrDir [file join $pf32 IFCsvrR300 dll]
if {![file exists [file join $ifcsvrDir IFCsvrR300.dll]]} {installIFCsvr} 

focus .

# check command line arguments or drag-and-drop
if {$argv != ""} {
  set localName [lindex $argv 0]
  if {[file dirname $localName] == "."} {
    set localName [file join [pwd] $localName]
  }
  if {$localName != ""} {
    .tnb select .tnb.status
    if {[file exists $localName]} {
      set localNameList [list $localName]
      outputMsg "Ready to process: [file tail $localName] ([expr {[file size $localName]/1024}] Kb)" blue
      if {[info exists buttons(appOpen)]} {$buttons(appOpen) configure -state normal}
      if {[info exists buttons(genExcel)]} {
        $buttons(genExcel) configure -state normal
        focus $buttons(genExcel)
      }
    } else {
      errorMsg "File not found: [truncFileName [file nativename $localName]]"
    }
  }
}

set writeDir $userWriteDir
checkValues

# other STEP File Analyzers already running
set pid2 [twapi::get_process_ids -name "STEP-File-Analyzer.exe"]
set pid2 [concat $pid2 [twapi::get_process_ids -name "sfa.exe"]]

if {[llength $pid2] > 1} {
  set msg "There are ([expr {[llength $pid2]-1}]) other instances of the STEP File Analyzer already running.\nThe windows for the other instances might not be visible but will show up in the Windows Task Manager as STEP-File-Analyzer.exe"
  append msg "\n\nDo you want to close the other instances of the STEP File Analyzer?"
  set choice [tk_messageBox -type yesno -default yes -message $msg -icon question -title "Close the other STEP File Analyzer?"]
  if {$choice == "yes"} {
    foreach pid $pid2 {
      if {$pid != [pid]} {catch {twapi::end_process $pid -force}}
    }
    outputMsg "Other STEP File Analyzers closed" red
    .tnb select .tnb.status
  }
}
set sfaPID [twapi::get_process_ids -name "STEP-File-Analyzer.exe"]

# copy schema rose files that are in the Tcl Virtual File System (VFS) or STEP Tools runtime to the IFCsvr dll directory
if {$copyrose} {copyRoseFiles}

# warn if spreadsheets not written to default directory
if {$opt(writeDirType) == 1} {
  outputMsg " "
  errorMsg "Spreadsheets will be written to a user-defined file name (Spreadsheet tab)"
  .tnb select .tnb.status
} elseif {$opt(writeDirType) == 2} {
  outputMsg " "
  errorMsg "Spreadsheets will be written to a user-defined directory (Spreadsheet tab)"
  .tnb select .tnb.status
}

# warn about output type
if {$opt(XLSCSV) == "CSV"} {
  outputMsg " "
  errorMsg "CSV files will be generated (Options tab)"
  .tnb select .tnb.status
} elseif {$opt(XLSCSV) == "None"} {
  outputMsg " "
  errorMsg "No spreadsheet will be generated, only visualizations (Options tab)"
  .tnb select .tnb.status
}

# error messages from before GUI was available
if {[info exists endMsg]} {
  outputMsg " "
  errorMsg $endMsg
  .tnb select .tnb.status
}
  
# set window minimum size
update idletasks
wm minsize . [winfo reqwidth .] [expr {int([winfo reqheight .]*1.05)}]

# debug
#compareLists "AP242" $ap242all $ap242e2
#set apcat {}
#foreach idx [array names entCategory] {set apcat [concat $apcat $entCategory($idx)]}
#compareLists "cat" $apcat [lrmdups [concat $ap203all $ap214all $ap242all]]
