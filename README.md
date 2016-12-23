# STEP File Analyzer

The following are instructions for building the [STEP File Analyzer](http://go.usa.gov/yccx) (SFA).  The SFA reads an ISO 10303 Part 21 STEP file and generates a spreadsheet.  More information, sample spreadsheets, and documentation about the SFA is available on the website including the [STEP File Analyzer User's Guide](http://dx.doi.org/10.6028/NIST.IR.8122).

##Prerequisites

The STEP File Analyzer can only be built and run on Windows computers.  [Microsoft Excel](https://products.office.com/excel) is required to generate spreadsheets.  CSV (comma-separated values) files will be generated if Excel is not installed.  

**You must install and run the NIST version of the STEP File Analyzer before running your own version.**

- Go to <http://go.usa.gov/yccx> and click on the link to Download the STEP File Analyzer
- Submit the form to get a link to download SFA.zip
- Extract STEP-File-Analyzer.exe from the zip file and run it.  This will install the IFCsvr toolkit that is used to read STEP files.
- Generate a spreadsheet or CSV files for at least one STEP file.  This will install the STEP schema files for the IFCsvr toolkit.  

Download the SFA files from the GitHub 'source' directory to a directory on your computer.  The source code is based on version 1.94 of the NIST-built version.

- The name of the directory is not important
- The STEP File Analyzer is written in [Tcl](https://www.tcl.tk/)

freeWrap wraps the SFA Tcl code to create an executable.

- Download freewrap651.zip from <https://sourceforge.net/projects/freewrap/files/freewrap/freeWrap%206.51/>.  More recent versions of freeWrap will **not** work with the SFA.
- Extract freewrap.exe and put it in the same directory as the SFA files that were downloaded from the 'source' directory.

Download the ActiveTcl Community Edition 8.5.\* pre-built Tcl distribution from <http://www.activestate.com/activetcl/downloads>.

- Scroll down to 'Download Tcl: Other Platforms and Versions' and download the latest **Windows (x86) 8.5.x** version.  Do **not** download the 8.6 version or the 64-bit version.
- Run the installer and use the default installation folders
- Several Tcl packages from ActiveTcl also need to be installed.  Open a command prompt window, change to C:\\Tcl\\bin and enter the following three commands:

```
teacup install tcom
teacup install twapi
teacup install Iwidgets
```

##Build the STEP File Analyzer

Open a command prompt window and change to the directory with the SFA Tcl files and freewrap.  To create the executable sfa.exe, enter the command:

```
freewrap -f sfa-files.txt
```

**Optionally, build the STEP File Analyzer command-line version**

- Download freewrapTCLSH.zip from <https://sourceforge.net/projects/freewrap/files/freewrap/freeWrap%206.51/>
- Extract freewrapTCLSH.exe to the directory with the SFA Tcl files
- Edit sfa-files.txt and change the first line 'sfa.tcl' to 'sfa-cl.tcl'
- To create sfa-cl.exe, enter the command: freewrapTCLSH -f sfa-files.txt

##Differences from the NIST-built version of STEP File Analyzer

Some features are not available in the user-built version including: tooltips, unzipping compressed STEP files, automated PMI checking for the [NIST CAD models](<http://go.usa.gov/mGVm>), and inserting images of the NIST test cases in the spreadsheets.  Some of the features are restored if the NIST-built version is run first.

##Alternate build methods

The STEP File Analyzer can also be built with the commercial toolkit [Tcl Dev Kit](<http://www.activestate.com/tcl-dev-kit>) or by using Tcl Starkits.  The NIST version is built with Tcl Dev Kit.

However, either method requires a version of ActiveTcl (8.5.15) that was released in 2013 and is not available anymore, at least as an ActiveTcl distribution.  The reason why version 8.5.15 or earlier has to be used is related to how STEP schema files are written to and read from the IFCsvr/dll directory.  Changes to the ActiveTcl distribution prevent this from working with newer versions.

An alternative might be to build the STEP File Analyzer with a version of Tcl/Tk built from source code available at <http://www.tcl.tk/software/tcltk/>.  It is unclear whether this would still require Tcl 8.5.15 or if a newer version can be used.

##Possible improvements

The IFCsvr toolkit used to read STEP files should be replaced.  IFCsvr toolkit is a wrapper around an old version of [STEPtools ST-Developer](http://www.steptools.com/products/stdev/).  The IFCsvr toolkit is the reason why versions of Tcl greater than 8.5.15 cannot be used.

- The free [personal edition of ST-Developer](http://www.steptools.com/products/stdev/personal.html) could replace the IFCsvr toolkit.  The personal edition of ST-Developer also includes some useful STEP utility programs.
- The [STEPcode toolkit](http://stepcode.org/) could also be used to replace the IFCsvr toolkit.

The Tcl package [tcom](http://wiki.tcl.tk/1821) (COM) is used to connect with a STEP file and with Excel.  tcom could be replaced with the COM features in [twapi](http://twapi.magicsplat.com/).

No toolkit is used to interact with Excel spreadsheets.  The home-grown code could be replaced with [CAWT](http://www.posoft.de/html/extCawt.html).

##Contact

[Robert Lipman](https://www.nist.gov/people/robert-r-lipman), <robert.lipman@nist.gov>, 301-975-3829

##Disclaimers

[NIST Disclaimer](http://www.nist.gov/public_affairs/disclaimer.cfm)