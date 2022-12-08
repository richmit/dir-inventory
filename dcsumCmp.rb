#!/usr/bin/env -S ruby -W0 -E utf-8
# -*- Mode:Ruby; Coding:us-ascii-unix; fill-column:158 -*-
################################################################################################################################################################
##
# @file      dcsumCmp.rb
# @author    Mitch Richling <https://www.mitchr.me>
# @brief     Compare checksum files.@EOL
# @std       Ruby1.9
# @copyright 
#  @parblock
#  Copyright (c) 1997,2005,2013,2016, Mitchell Jay Richling <https://www.mitchr.me> All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
#  1. Redistributions of source code must retain the above copyright notice, this list of conditions, and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions, and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#
#  3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without
#     specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
#  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
#  TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  @endparblock
# @filedetails
#
#  Based on an older perl version.
#
#   Find PDF files that were in the older scan but are not in the new scan.
#     dcsumCmp.rb --sNR '=0' --sNAME 'pdf$' --soAND    
#
################################################################################################################################################################

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
Encoding.default_external="utf-8";

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
require 'optparse'
require 'optparse/time'
require 'sqlite3'
require 'set'

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
allCols     = ['NL', 'NR', 'H', 'CT', 'MT', 'SZ', 'HASH', 'NAME']
srchArgPat  = Regexp.new('-+s(' + allCols.join('|') + ')=(.+)$')

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
pColTitles  = true
searchArg   = Array.new
searchArgD  = [[  'H',  '!='   ],
               [ 'CT',  '!='   ],
               [ 'MT',  '!='   ],
               [ 'SZ',  '!='   ],
               ['SOP',  :sop_or],
               ['SOP',  :sop_or],
               ['SOP',  :sop_or]]
csumToRep   = [ 0, 1 ]
csumFiles   = Array.new
pCols       = Array.new()
encodeFN    = false
pPrefix     = true
pDups       = false
doPrefix    = true
debug       = 3
dircsumMode = false
pColsFmt    = { 'NL'   => "-3", 
                'NR'   => "-3",
                'H'    => "-1",
                'CT'   => "-2",
                'MT'   => "-2",
                'SZ'   => "-2",
                'HASH' => "-36",
                'NAME' => 0 }
opts = OptionParser.new do |opts|
  opts.banner = "Usage: dcsumCmp [options] [file1 [file2]]                                                                     "
  opts.separator "                                                                                                             "
  opts.separator "General Options:                                                                                             "
  opts.on("-h",        "--help",             "Show this message")                 { puts opts; exit;                           }
  opts.on("-v",        "--debug INT",        "Set debug level")                   { |v| debug=v.to_i;                          }
  opts.separator "                                       0 .. Print report                                                     "
  opts.separator "                                       1 .. Print ERRORS                                                     "
  opts.separator "                                       2 .. Print WARNING                                                    "
  opts.separator "                                       3 .. Print INFO (default)                                             "
  opts.separator "                                       4 .. Print STATUS                                                     "
  opts.separator "                                       5 .. Print Scan Meta Data                                             "
  opts.separator "                                       6 .. Print DEBUG                                                      "
  opts.on("-U",        "--dircsum",          "Set dircsum mode")                  { dircsumMode = true;                        }
  opts.separator "                                       If no files are provided, then the last two .dircsum DBs are used.    "
  opts.separator "                                       If a single file is provided, then the last .dircsum DB is used as    "
  opts.separator "                                         the left file while the named file is used as the right one.        "
  opts.separator "                                       If no directory-to-traverse is provided on the command line           "
  opts.separator "                                       and the .dircsum directory exists, then -U is assumed                 "
  opts.on(             "--doPrefix Y/N",     "Compute filename prefix")           { |v| doPrefix=(v.match(/^(Y|y|T|t)/));      }
  opts.separator "Report Tweek Options:"
  opts.on(             "--encodeFN Y/N",     "Encode filenames")                  { |v| encodeFN=(v.match(/^(Y|y|T|t)/));      }
  opts.separator "                                       Printed filenames are transformed via .dump, and spaces are           "
  opts.separator "                                       replaced with \\x20.                                                  "
  opts.on(             "--pDups Y/N",        "Print files with same content")     { |v| pDups=(v.match(/^(Y|y|T|t)/));         }
  opts.separator "                                       Requies valid & consistant checksums. Incompatable with --pCols       "
  opts.on(             "--pPrefix Y/N",      "Print found prefixes (if -p)")      { |v| pPrefix=(v.match(/^(Y|y|T|t)/));       }
  opts.on(             "--pCols COLS",       "Cols to print (comma separated)")   { |v| pCols = v.split(/\s*,\s*/);            }
  opts.on(             "--pColTitles Y/N",   "Print col titles")                  { |v| pColTitles=(v.match(/^(Y|y|T|t)/));    }
  opts.separator "Search Options:"
  opts.on(             "--sNL INT_COMPARE",  "Search criteria for NL column")     { |v| searchArg.push(['NL',   v]);           }
  opts.on(             "--sNR INT_COMPARE",  "Search criteria for NR column")     { |v| searchArg.push(['NR',   v]);           }
  opts.separator "                                       The INT_COMPARE used for --sNL & --sNR is an integer string           "
  opts.separator "                                       like 'o#' where 'o' is a comparison operator and '#' is an integer.   "
  opts.separator "                                       The operator, 'o', may be one of '!', '=', '<', or '>'.               "
  opts.separator "                                       Ex: --sNL '!1' lists lines for which NL != 1                          "
  opts.on(             "--sH PATTERN",       "Search criteria for H column")      { |v| searchArg.push(['H',    v]);           }
  opts.on(             "--sCT PATTERN",      "Search criteria for CT column")     { |v| searchArg.push(['CT',   v]);           }
  opts.on(             "--sMT PATTERN",      "Search criteria for MT column")     { |v| searchArg.push(['MT',   v]);           }
  opts.on(             "--sSZ PATTERN",      "Search criteria for SZ column")     { |v| searchArg.push(['SZ',   v]);           }
  opts.separator "                                       The PATTERN used for --sH, --sCT, --sMT, & --sSZ are used to match    "
  opts.separator "                                       the starting bytes of the corresponding column. If the PATTERN        "
  opts.separator "                                       starts with an exclamation point (!), then the match is reversed.     "
  opts.separator "                                       Ex: --sH '!=' matches lines not starting with '=' in the 'H' column.   "
  opts.on(             "--sHASH REGEX",      "Search criteria for HASH column")   { |v| searchArg.push(['HASH', v]);           }
  opts.separator "                                       Select lines for which the REGEX matches the HASH column.             "
  opts.on(             "--sNAME REGEX",      "Search criteria for NAME column")   { |v| searchArg.push(['NAME', v]);           }
  opts.separator "                                       Select lines for which the REGEX matches the NAME column.             "
  opts.on(             "--sALL",             "Search criteria matching anything") { searchArg.push(['TRUE', true]);            }
  opts.on(             "--soAND",            "Boolean search operator")           { searchArg.push(['SOP', :sop_and]);         }
  opts.on(             "--soNOT-AND",        "Boolean search operator")           { searchArg.push(['SOP', :sop_not]);        
                                                                                    searchArg.push(['SOP', :sop_and]);         }
  opts.separator "                                       Equivalent of --soNOT --soAND                                         "
  opts.on(             "--soOR",             "Boolean search operator")           { searchArg.push(['SOP', :sop_or]);          }
  opts.on(             "--soNOT",            "Boolean search operator")           { searchArg.push(['SOP', :sop_not]);         }
  opts.separator "                                       The --soAND & --soOR arguments change the way search criteria are     "
  opts.separator "                                       used.  Without them all search criteria are ORed together. With       "
  opts.separator "                                       them the search criteria and operators are evaluated as an RPN        "
  opts.separator "                                       expression with a FORTH-like stack.                                   "
  opts.on(             "--smCHANGE",         "Macro: Show changes")               { searchArg.push([ 'H',   '!=' ]);
                                                                                    searchArg.push([ 'CT',  '!=' ]);
                                                                                    searchArg.push([ 'MT',  '!=' ]);
                                                                                    searchArg.push([ 'SZ',  '!=' ]);
                                                                                    searchArg.push(['SOP',  :sop_or]);         
                                                                                    searchArg.push(['SOP',  :sop_or]);         
                                                                                    searchArg.push(['SOP',  :sop_or]);         }
  opts.separator "                                       What you get if you don't provide search criteria.  Option only       "
  opts.separator "                                       exists for UI uniformity. Equivalent to adding the following options: "
  opts.separator "                                          --sH '!=' --sSZ '!=' --sCT '!=' --sMT '!=' --soOR --soOR --soOR    "
  opts.on(             "--smCHnoCTIME",      "Macro: Changes but ignore ctime")   { searchArg.push([ 'H',   '!=' ]);
                                                                                    searchArg.push([ 'MT',  '!=' ]);
                                                                                    searchArg.push([ 'SZ',  '!=' ]);
                                                                                    searchArg.push(['SOP',  :sop_or]);         
                                                                                    searchArg.push(['SOP',  :sop_or]);         }
  opts.separator "                                       Show files with any change except ctime differences.                  "
  opts.separator "                                       Handy for comparing csum DBs from before and after a copy.            "
  opts.separator "                                       Equivalent to adding the following options:                           "
  opts.separator "                                          --sH '!=' --sSZ '!=' --sMT '!=' --soOR --soOR                      "
  opts.on(             "--smSAME",           "Macro: Stuff that's the same")      { searchArg.push([ 'H',   '=' ]);
                                                                                    searchArg.push([ 'CT',  '=' ]);
                                                                                    searchArg.push([ 'MT',  '=' ]);
                                                                                    searchArg.push([ 'SZ',  '=' ]);
                                                                                    searchArg.push(['SOP',  :sop_or]);         
                                                                                    searchArg.push(['SOP',  :sop_or]);         
                                                                                    searchArg.push(['SOP',  :sop_or]);         }
  opts.separator "                                       Show files with any change unless the path contains a /.git/          "
  opts.separator "                                       component.  Equivalent to adding the following options:               "
  opts.separator "                                          --sH '=' --sSZ '=' --sCT '=' --sMT '=' --soOR --soOR --soOR        "
  opts.on(             "--smGone",           "Macro: Stuff gone missing")         { searchArg.push(['NR', '=0']);
                                                                                    searchArg.push(['NL', '>0']);              
                                                                                    searchArg.push(['SOP',  :sop_and]);     }
  opts.separator "                                       Show files with content only in left file.  Equivalent to:            "
  opts.separator "                                          --sNR '=0' --sNL '>0' --soAND                                      "
  opts.on(             "--smNew",            "Macro: New Stuff")                  { searchArg.push(['NR', '>0']);                                                                                         
                                                                                    searchArg.push(['NL', '=0']);
                                                                                    searchArg.push(['SOP',  :sop_and]);        }
  opts.separator "                                       Show files with content only on right file.  Equivalent to:           "
  opts.separator "                                          --sNL '=0' --sNR '>0' --soAND                                      "
  opts.on(             "--smIMAGE",          "Macro: IMAGE files")                { searchArg.push(['NAME', '\.(ai|avi|bmp|gif|jpeg|jpg|m4v|mov|mp4|mpg|mrd|png|svg|tif|tiff|webm|xbm|xpm)$']); }
  opts.separator "                                       Show image files, equivalent to:                                      "
  opts.separator "                                          --sNAME A_BIG_REGEX                                                "
  opts.on(             "--smPDF",            "Macro: PDF file")                   { searchArg.push(['NAME', '\\.pdf$']);       }
  opts.separator "                                       Match PDF file names. Equivalent to:          "
  opts.separator "                                          --sNAME 'pdf$'                                                     "
  opts.on(             "--smNoGIT",          "And Macro: Ignore GIT")             { if (searchArg.empty?) then 
                                                                                      searchArg = searchArgD.clone
                                                                                    end
                                                                                    searchArg.push(['NAME', '\\/\\.git\\/']);
                                                                                    searchArg.push(['SOP',  :sop_not]);        
                                                                                    searchArg.push(['SOP',  :sop_and]);        }
  opts.separator "                                       If search criteria appear before this option, equivalent to:          "
  opts.separator "                                          --sNAME '\\/\\.git\\/' --soNOT --soAND                             "
  opts.separator "                                       Otherwise equivalent to adding the following options:                 "
  opts.separator "                                          --smCHANGE --sNAME '\\/\\.git\\/' --soNOT --soAND                  "
  opts.on(             "--smNoBAK",          "And Macro: Ignore backup files")    { if (searchArg.empty?) then 
                                                                                      searchArg = searchArgD.clone
                                                                                    end
                                                                                    searchArg.push(['NAME', '~$']);
                                                                                    searchArg.push(['NAME', '\\.bak$']);
                                                                                    searchArg.push(['NAME', '\\.BAK$']);
                                                                                    searchArg.push(['SOP',  :sop_or]);         
                                                                                    searchArg.push(['SOP',  :sop_or]);         
                                                                                    searchArg.push(['SOP',  :sop_not]);        
                                                                                    searchArg.push(['SOP',  :sop_and]);        }
  opts.separator "                                       If search criteria appear before this option, equivalent to:          "
  opts.separator "                                          --sNAME '(~|\\.bak|\\.BAK)$' --soNOT --soAND                       "
  opts.separator "                                       Otherwise equivalent to adding the following options:                 "
  opts.separator "                                          --smCHANGE --sNAME '(~|\\.bak|\\.BAK)$' --soNOT --soAND            "
  opts.separator "                  If no command line search options are present, then lines with changes will be selected    "
  opts.separator "                  as if the following options had been used: --sH '!=' --sSZ '!=' --sCT '!=' --sMT '!='      "
  opts.separator "                                                                                                             "
  opts.separator "Output:                                                                                                      "
  opts.separator "  The output generated on STDOUT is designed to be easily consumable by traditional UNIX tools like grep     "
  opts.separator "  and AWK.  Accordingly the format is line based with a single line per file.  Each line consists of eight   "
  opts.separator "  columns separated by a single space.  The columns:                                                         "
  opts.separator "    - NL .... Number of copies on left with same check-sum.                                                  "
  opts.separator "    - NR .... Number of copies on right with same check-sum.                                                 "
  opts.separator "              Both NL & NR are normally 3 digit, zero padded integers; however, they may be longer.          "
  opts.separator "              Both NL & NR will be '???' if hashes in the DBs are not usable.                                "
  opts.separator "                NOTE: Usually the reason hashes are not usable is the two files use different hash types.    "
  opts.separator "                      It can also happen that one of the files is simply missing hash values altogether      "
  opts.separator "                      or that the hashes are unreliable (dcsumNew used with '-k name' or '-k 1k').           "
  opts.separator "    - H ..... Checksum (content) difference between current file and file on other side of same name:        "
  opts.separator "              This field is precisely one character:                                                         "
  opts.separator "                - = file name exists on left & right and hashes are the same                                 "
  opts.separator "                - | file name exists on left & right and hashes are different                                "
  opts.separator "                - ? file name exists on left & right and hashes are not usable                               "
  opts.separator "                - < name on left only (but if NR>0, then a copy exists on right with different name)         "
  opts.separator "                - > name on right only (but if NL>0, then a copy exists on left with different name)         "
  opts.separator "    - CT .... Create time                                                                                    "
  opts.separator "              This field is precisely two characters:                                                        "
  opts.separator "                - .. N/A -- file is missing on one side                                                      "
  opts.separator "                - == same                                                                                    "
  opts.separator "                - <U left older                                                                              "
  opts.separator "                - >U left newer                                                                              "
  opts.separator "                -    Where U is one of: (s)econds, (h)ours, (d)ays, (w)eeks, (m)onths, (y)ears               "
  opts.separator "    - MT .... Modify Time                                                                                    "
  opts.separator "              Same notation as ctime                                                                         "
  opts.separator "    - SZ .... File Size                                                                                      "
  opts.separator "              This field is precisely two characters:                                                        "
  opts.separator "              .. N/A -- file is missing on one side                                                          "
  opts.separator "              == same                                                                                        "
  opts.separator "              <U left smaller                                                                                "
  opts.separator "              >U left bigger                                                                                 "
  opts.separator "                 Where U is one of: (B)ytes, (K)ilobytes, (M)egabytes, (G)igabytes                           "
  opts.separator "    - HASH .. File Content Hash (in hex)                                                                     "
  opts.separator "              This field will be the same length for all files listed:                                       "
  opts.separator "                 Unusable hash ... 4 question mark characters                                                "
  opts.separator "                 SHA1 ............ 40 characters                                                             "
  opts.separator "                 SHA256 .......... 64 characters                                                             "
  opts.separator "                 MD5 ............. 32 characters                                                             "
  opts.separator "    - NAME .. File Name                                                                                      "
  opts.separator "  When --pDups is turned on, the report is augmented by printing duplicate files on lines immediately        "
  opts.separator "  following each normal report line.  These duplicate file names are aligned with the rest of the file       "
  opts.separator "  names in the report.  Each duplicate is preceded by a character identifying where the file name was        "
  opts.separator "  found (< in the left checksum file, > in the right checksum file, or = if it was in both).  Note ALL       "
  opts.separator "  files are listed in this duplicate section -- including the one on the report line before the              "
  opts.separator "  duplicates.  Also note that duplicate sections are only printed if the current file has not already        "
  opts.separator "  been included in a previous duplicate file listing.                                                        "
  opts.separator "                                                                                                             "
  opts.separator "Examples:                                                                                                    "
  opts.separator "  - Check out the --smXXX options for some ideas about how to combine search options.                        "
  opts.separator "  - List file names for new files and files with content changes.  Useful for a dynamic backup scheme.       "
  opts.separator "      --pPrefix N --pColTitles N --pCols NAME --sH '|' --sH '>' --soOR                                       "
  opts.separator "                                                                                                             "
end
opts.parse!(ARGV)
csumFiles=Array.new(2)

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Populate pCols & check for pDups/pCols conflict
if (pCols.empty?) then
  pCols = allCols.clone();
else
  if (pDups) then
    if(debug>=1) then STDERR.puts("ERROR: The --pDups option can not be used with --pCols option!") end
    exit
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if ( !(dircsumMode) && ARGV.empty? ) then
  if (FileTest.exist?('.dircsum')) then
    dircsumMode = true;
    #puts("WARNING: No directory provided, but .dircsum found -- running in -U mode")
  else
    puts("ERROR: No directory provided, and .dircsum missing.  Run with -U to force dircsum mode!")
    exit
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Populate csumFiles & check that we got the correct number of files
if(dircsumMode) then
  if(FileTest.exist?('.dircsum')) then
    oldFileFiles = Dir.glob('.dircsum/??????????????_dircsum.sqlite').sort
    dircsumModeLastFile       = oldFileFiles.pop
    if (dircsumModeLastFile == nil) then
      if(debug>=1) then STDERR.puts("ERROR: No DB files found in .dircsum directory in -U mode!") end
      exit
    end
    dircsumModeNextToLastFile = oldFileFiles.pop
    if (ARGV.length == 0) then
      if (dircsumModeNextToLastFile == nil) then
        if(debug>=1) then STDERR.puts("ERROR: At least two DB required in .dircsum directory in -U mode and no file arguments!") end
        exit
      end
      csumFiles[0] = dircsumModeNextToLastFile
      csumFiles[1] = dircsumModeLastFile
    elsif (ARGV.length == 1) then
      csumFiles[0] = dircsumModeLastFile
      csumFiles[1] = ARGV[0]; 
    else 
      if(debug>=1) then STDERR.puts("ERROR: only one file may be listed on the command line in -U mode!") end
      exit
    end
  else
    if(debug>=1) then STDERR.puts("ERROR: Missing .dircsum direcotyr in -U mode!") end
    exit
  end
else
  if (csumFiles.length ==  2) then
    csumFiles[0] = ARGV[0]; 
    csumFiles[1] = ARGV[1]; 
  elsif (csumFiles.length > 2) then
    if(debug>=1) then STDERR.puts("ERROR: too many checksum files to process: #{ARGV.inspect}!") end
    exit
  elsif (csumFiles.length < 2) then
    if(debug>=1) then STDERR.puts("ERROR: too few checksum files to process: #{ARGV.inspect}!") end
    exit
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Compute units on a delta
def deltaUnits(a, b, utype)
  if(a.nil? || b.nil?) then
    return '..'
  end
  if(a==b) then
    return '=='
  else
    { 'time' => [ [ 31536000,   'y' ], [ 2592000, 'm' ], [ 604800, 'w' ], [ 86400, 'd' ], [3600, 'h' ], [ 1, 's' ] ],
      'size' => [ [ 1073741824, 'G' ], [ 1048576, 'M' ], [ 1024,   'K' ], [ 1,     'B' ] ]
    }[utype].each do |sz, lb|
      if((a-b).abs>=sz) then
        return (if (a<b) then '<' else '>' end)  + lb
      end
    end
    return 'ER'
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Read in the data files...
if(debug>=4) then STDERR.puts("STATUS: File Read") end
fileInfo  = Hash.new
['N2SN', 'N2H', 'N2CT', 'N2MT', 'N2SZ', 'H2N', 'PFIX', 'META'].each do |key|          # Create all the arrays
  fileInfo[key]  = Array.new
end
csumFiles.each_with_index do |fileName, fileIdx|
  if(debug>=4) then STDERR.puts("STATUS:    Reading file: #{fileName}") end
  ['N2SN', 'N2H', 'N2CT', 'N2MT', 'N2SZ', 'H2N', 'META'].each do |key|                # Init all the fileInfo hash members
    fileInfo[key][fileIdx]  = Hash.new
  end
  SQLite3::Database.new(fileName) do |dbCon|
    # Collect scan meta data
    dbCon.execute("SELECT mkey, mvalue FROM meta;").each do |mkey, mvalue|
      fileInfo['META'][fileIdx][mkey]  = mvalue;
    end
    # Collect scan file data
    dbCon.execute("SELECT ctime, mtime, csum, bytes, relpn FROM annofsobj WHERE ftype = 'r';").each do |row|
      ctime, mtime, csum, charCnt, fname = row
      if (doPrefix) then                                                      # Find the maximal path-name prefix
        if (fileInfo['PFIX'][fileIdx]) then
          fileInfo['PFIX'][fileIdx].length.downto(0) do |j|
            if (fileInfo['PFIX'][fileIdx].start_with?(fname[0,j])) then
              fileInfo['PFIX'][fileIdx] = fname[0,j]
              break
            end
          end
        else
          fileInfo['PFIX'][fileIdx] = fname;
        end
      end
      fileInfo['N2H'][fileIdx][fname]  = csum                                       # Store away the data...
      fileInfo['N2SN'][fileIdx][fname] = fname
      fileInfo['N2CT'][fileIdx][fname] = ctime.to_i
      fileInfo['N2MT'][fileIdx][fname] = mtime.to_i
      fileInfo['N2SZ'][fileIdx][fname] = charCnt.to_i
      fileInfo['H2N'][fileIdx][csum]   = (fileInfo['H2N'][fileIdx][csum] || Array.new).push(fname)
    end
  end      
end
if(debug>=4) then STDERR.puts("STATUS:    File Reads complete") end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Post-process the data
if (doPrefix) then
  if(debug>=4) then STDERR.puts("STATUS: Computing short names") end
  fileInfo['N2H'].each_index do |i|
    if (fileInfo['PFIX'][i].length > 0) then
      prefixRe = Regexp.new('^' + fileInfo['PFIX'][i])
      fileInfo['N2H'][i].keys.each do |fname|
        fileInfo['N2SN'][i][fname] = fname.sub(prefixRe, '')
      end
    end
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if(debug>=4) then STDERR.puts("STATUS: Build up the search patterns from the inputs") end
haveSearchExpr = false;
searchCriteria = Array.new
if (searchArg.length == 0) then
  searchArg = searchArgD
end
searchArg.each do |tag, pat| 
  if    ((tag.upcase == 'NAME') || (tag.upcase == 'HASH')) then
    searchCriteria.push( [ tag, Regexp.new(pat) ] )
  elsif (tag.upcase == 'SOP') then
    searchCriteria.push([ tag, pat ])
    haveSearchExpr = true;
  elsif ((tag.upcase == 'NL') || (tag.upcase == 'NR')) then
    if (tmp=pat.match(/^([!=<>])([0-9]+)$/i)) then
      searchCriteria.push([tag, [ tmp[1], tmp[2].to_i ] ])
    else
      if(debug>=1) then STDERR.puts("ERROR: Bad numeric search argument: #{tag.inspect} => #{pat.inspect}!") end
      exit
    end
  elsif (tag == 'TRUE') then
    searchCriteria.push([ tag, pat ]);
  else
    if (tmp=pat.match(/^(!{0,1})(.+)$/i)) then
      searchCriteria.push([tag, [ (tmp[1].upcase == '!'), tmp[2] ] ])
    else
      if(debug>=1) then STDERR.puts("ERROR: Bad search argument: #{tag.inspect} => #{pat.inspect}!") end
      exit
    end
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if(debug>=4) then STDERR.puts("STATUS: Checking checksums") end
csumsGood = true;
csumList = csumToRep.map { |fileIdx| fileInfo['META'][fileIdx]['csum'] }
if (csumList.uniq.length != 1) then
  if(debug>=2) then STDERR.puts("WARNING: File checksums are inconsistant: #{csumList[0]} vs #{csumList[1]}") end
  csumsGood = false;
else
  if (csumList[0] == "csum_1k") then
    if(debug>=2) then STDERR.puts("WARNING: File checksums in use are unreliable: #{csumList[0]}") end
    csumsGood = false;
  elsif (["csum_name", "csum_nil"].member?(csumList[0])) then
    if(debug>=2) then STDERR.puts("WARNING: File checksums are missing") end
    csumsGood = false;
  end
end

if ( !(csumsGood) && pDups ) then
  if(debug>=1) then STDERR.puts("ERROR: The --pDups option can not be used with inconsistant checksums!") end
  exit
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if (debug>=5) then
  mkeys = Set.new
  csumToRep.each do |fileIdx| 
    mkeys.merge(fileInfo['META'][fileIdx].keys())
  end
  mkeys.each do |mkey|
    csumToRep.each do |fileIdx|
      STDERR.puts("SCAN META: #{(fileIdx == 0 ? '<' : '>')} #{mkey} ::: #{fileInfo['META'][fileIdx][mkey]}")
    end
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if(debug>=4) then STDERR.puts("STATUS: Printing report") end
if(debug>=3) then STDERR.puts("INFO: < File: #{csumFiles[0].inspect}") end
if(debug>=3) then STDERR.puts("INFO: > File: #{csumFiles[1].inspect}") end
if (pPrefix && doPrefix) then
  if(debug>=3) then STDERR.puts("INFO: < Prefix: #{fileInfo['PFIX'][0].inspect}") end
  if(debug>=3) then STDERR.puts("INFO: > Prefix: #{fileInfo['PFIX'][1].inspect}") end
end
fnameSeenInBigList = Hash.new
fnameSeenInDupList = Hash.new
reportLineNumber   = 0
csumToRep.each do |i|
  j = (i-1).abs # Index of the other file (0=>1, 1=>0)
  fileInfo['N2H'][i].keys.sort.each do |fnamei|
    shortName = fileInfo['N2SN'][i][fnamei]

    if (! (fnameSeenInBigList.member?(shortName))) then
      theCols = Hash.new
      fnameSeenInBigList[shortName] = 1;

      fnames = Array.new
      fnames[i] = fnamei
      fnames[j] = ( fileInfo['PFIX'][j] ? fileInfo['PFIX'][j] + shortName : fnamei )

      inFile  = [0, 1].map { |k| fileInfo['N2H'][k].member?(fnames[k]) }             # What sides is file name on
      curHash = fileInfo['N2H'][i][fnames[i]]                                        # Hash of current file
      numFnd  = [0, 1].map { |k| (fileInfo['H2N'][k][curHash] || Array.new).length } # Number of times has appears on each side
      theCols['NL'] = (csumsGood ? sprintf('%03d', numFnd[0]) : "???")
      theCols['NR'] = (csumsGood ? sprintf('%03d', numFnd[1]) : "???")

      theCols['H']  = ''
      if(inFile[0] && inFile[1]) then
        if (csumsGood) then
          if(curHash == fileInfo['N2H'][j][fnames[j]]) then
            theCols['H'] = '='
          else
            theCols['H'] = '|'
          end
        else
          theCols['H'] = '?'
        end
      else
        if(inFile[0]) then
          theCols['H'] = '<'
        else
          theCols['H'] = '>'
        end
      end

      theCols['CT'] = deltaUnits(fileInfo['N2CT'][0][fnames[0]], fileInfo['N2CT'][1][fnames[1]], 'time')
      theCols['MT'] = deltaUnits(fileInfo['N2MT'][0][fnames[0]], fileInfo['N2MT'][1][fnames[1]], 'time')
      theCols['SZ'] = deltaUnits(fileInfo['N2SZ'][0][fnames[0]], fileInfo['N2SZ'][1][fnames[1]], 'size')

      theCols['HASH'] = (csumsGood ? fileInfo['N2H'][i][fnames[i]] : "????")
      theCols['NAME'] = ( encodeFN ? shortName.dump.gsub(' ', "\\\\x20") : shortName)

      # Evaluate search criteria
      printThisOneStack = Array.new
      searchCriteria.each do |tag, pat|
        if (pat.class == Regexp) then
          printThisOneStack.push( !(!(theCols[tag].match(pat))))
        elsif (pat.class == TrueClass) then
          printThisOneStack.push(true);
        elsif (pat.class == Symbol) then
          numArgs = ( pat == :sop_not ? 1 : 2)
          if (printThisOneStack.length < numArgs) then
            if(debug>=1) then STDERR.puts("ERROR: Search operator (#(#{pat}) requires at least #{numArgs} arguments!") end
            exit
          end
          if (numArgs == 1) then
            opARG = printThisOneStack.pop();
            printThisOneStack.push(!(opARG)) # Only have one op that takes one arg
          else
            opRHS = printThisOneStack.pop();
            opLHS = printThisOneStack.pop();
            if (pat == :sop_and) then
              printThisOneStack.push(opLHS && opRHS)
            else
              printThisOneStack.push(opLHS || opRHS)
            end
          end
        elsif (pat[1].class == Integer) then
          printThisOneStack.push(((pat[0] == '!') && (theCols[tag].to_i != pat[1])) ||
                                 ((pat[0] == '=') && (theCols[tag].to_i == pat[1])) ||
                                 ((pat[0] == '<') && (theCols[tag].to_i <  pat[1])) ||
                                 ((pat[0] == '>') && (theCols[tag].to_i >  pat[1])))
        else
          tmp = (theCols[tag].slice(0, pat[1].length) == pat[1])
          printThisOneStack.push( ( pat[0] ? !tmp : tmp ) );
        end
        if ( (!(haveSearchExpr)) && printThisOneStack.last()) then
          break
        end
      end

      if (printThisOneStack.last()) then
        reportLineNumber+=1
        pColsFmt['HASH'] = - (csumsGood ? curHash.length : 4)
        if( (reportLineNumber == 1) && (pColTitles)) then
          pCols.each { |ct| printf("%#{pColsFmt[ct]}s ", ct) }
          printf("\n")
        end
        pCols.each { |ct| printf("%#{pColsFmt[ct]}s ", theCols[ct]) }
        printf("\n")
        if(pDups) then
          sameContentFileList = Hash.new
          [0, 1].each do |k|
            if(fileInfo['H2N'][k].member?(curHash)) then
              fileInfo['H2N'][k][curHash].sort.each do |dfname|
                dshortName = fileInfo['N2SN'][k][dfname]
                if (sameContentFileList.member?(dshortName)) then
                  sameContentFileList[dshortName] = '='
                else
                  if (k == 0)
                    sameContentFileList[dshortName] = '<'
                  else
                    sameContentFileList[dshortName] = '>'
                  end
                end
              end
            end
          end
          if (sameContentFileList.keys.length > 1) then
            sameContentFileList.each do |dshortName, locs|
              if ( !(fnameSeenInDupList.member?(dshortName))) then
                printf("%s %s %s\n", ' '*(curHash.length+17), locs, dshortName)
                fnameSeenInDupList[dshortName] = 1
              end
            end
          end
        end
      end
    end
  end
end
