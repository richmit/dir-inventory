#!/bin/bash /home/richmit/bin/ruby20
# -*- Mode:Ruby; Coding:us-ascii-unix; fill-column:158 -*-
################################################################################################################################################################
##
# @file      cmpCSUM.rb
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
################################################################################################################################################################

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
require 'optparse'
require 'optparse/time'

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
allCols     = ['NL', 'NR', 'H', 'CT', 'MT', 'SZ', 'HASH', 'NAME']
srchArgPat  = Regexp.new('-+s(' + allCols.join('|') + ')=(.+)$')

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
pColTitles  = true
searchArg   = [[ 'H'  , '!=' ],
               [ 'CT' , '!=' ],
               [ 'MT' , '!=' ],
               [ 'SZ' , '!=' ]]
searchArgD  = true
csumToRep   = [ 0, 1 ]
csumFiles   = Array.new
pCols       = Array.new(allCols)
pPrefix     = true
pDups       = false
doPrefix    = true
debug       = 0
csumType    = 'md5'
pColsFmt    = { 'NL'   => "-3", 
                'NR'   => "-3",
                'H'    => "-1",
                'CT'   => "-2",
                'MT'   => "-2",
                'SZ'   => "-2",
                'HASH' => "-36",
                'NAME' => 0 }
opts = OptionParser.new do |opts|
  opts.banner = "Usage: cmpCSUM.rb [options] files [files...]"
  opts.separator ""
  opts.separator "Options:"
  opts.on("-h",        "--help",             "Show this message")                 { puts opts; exit; }
  opts.on(             "--debug INT",        "Set debug level")                   { |v| debug=v.to_i; }
  opts.on(             "--doPrefix Y/N",     "Compute filename prifex")           { |v| doPrefix=(v.match(/^(Y|y|T|t)/)); }
  opts.on(             "--pDups Y/N",        "Print files with same content")     { |v| pDups=(v.match(/^(Y|y|T|t)/)); }
  opts.on(             "--pPrefix Y/N",      "Print found prefixes (if -p)")      { |v| pPrefix=(v.match(/^(Y|y|T|t)/)); }
  opts.on(             "--csum  <md5|sha1>", "The checksum to use")               { |v| csumType=v; 
                                                                                        pColsFmt['HASH'] = ( csumType == 'md5' ? "-31" : "-40" ); }
  opts.on(             "--pCols COLS",       "Cols to print (comma seporated)")   { |v| pCols = v.split(/\s*,\s*/); }
  opts.on(             "--pColTitles Y/N",   "Print col titles")                  { |v| pColTitles=(v.match(/^(Y|y|T|t)/)); }
  opts.on(             "--sALL",             "Show all patterns")                 { |v| searchArg = nil; s
                                                                                        earchArgD = false; }
  opts.on(             "--backup",           'Usefull for backups')               { |v| pPrefix = false; 
                                                                                        pColTitles = false; 
                                                                                        searchArg = [ ['H', '|'],  ['H', '>'] ]; 
                                                                                        searchArgD = false;                                                                                         pCols = [ 'NAME' ]; }
  allCols.each do |colName|
    opts.on("--s#{colName} REGEX", "Regex for #{colName} column") { |v| if (searchArgD) then
                                                                          searchArg = Array.new
                                                                          searchArgD = false
                                                                          searchArg = [ [ colName, v ] ]
                                                                        else
                                                                          searchArg.push([ colName, v ])
                                                                        end }    
  end
  opts.separator ""
  opts.separator ""
  opts.separator "  The '-sCOL' options are search criteria on output columns. Search criteria -- i.e. which file data lines to"
  opts.separator "  print. 'COL' is the name of a column, or the keyword 'ALL'. When a column other than NAME is given, then it"
  opts.separator "  will be used to match the first part of the printed output for that column.  When NAME is the column, it"
  opts.separator "  will be used as a regexp against the NAME col.  When appearing multiple times, these options combine with"
  opts.separator "  'OR'.  The ALL keyword directs the script to display a line for Every file -- even the ones that are the"
  opts.separator "  same on both sides. The default is to print if anything is different.  Any option of this type will destroy"
  opts.separator "  the default setting."
  opts.separator ""
  opts.separator "  The -backup option produces output useful for backups"
  opts.separator "  This is useful when one wishes to have a list of 'new' files or files that have 'changed' in the case when"
  opts.separator "  the first checksum file is assumed to be for the backup directory while the second is assumed to be the"
  opts.separator "  current working directory from which the backup was generated."
  opts.separator "  This option is equivalent to the following options: -pPrefix N -pColTitles N -pCols NAME -sH \\| -sH \\>"
  opts.separator ""
  opts.separator "  Output:"
  opts.separator ""
  opts.separator "  One file-name per line."
  opts.separator "    * NL: Number of copies on left with same check-sum"
  opts.separator "    * NR: Number of copies on right with same check-sum"
  opts.separator "    * CS: Checksum (content) difference between current file and file on other side of same name:"
  opts.separator "      = same"
  opts.separator "      | different"
  opts.separator "      < name on left only (but if NR>0, then a copy exists on right with different name)"
  opts.separator "      > name on right only (but if NL>0, then a copy exists on left with different name)"
  opts.separator "    * ctime: Create time"
  opts.separator "      .. N/A -- file is missing on one side"
  opts.separator "      == same"
  opts.separator "      <U left older"
  opts.separator "      >U left newer"
  opts.separator "         Where U is one of: (s)econds, (h)ours, (d)ays, (w)eeks, (m)onths, (y)ears"
  opts.separator "    * mtime: Modify Time"
  opts.separator "      same notation as ctime "
  opts.separator "    * size: File Size"
  opts.separator "      .. N/A -- file is missing on one side"
  opts.separator "      == same"
  opts.separator "      <U left smaller"
  opts.separator "      >U left bigger"
  opts.separator "         Where U is one of: (B)ytes, (K)ilobytes, (M)egabytes, (G)igabytes"
  opts.separator ""
  opts.separator ""
end
opts.parse!(ARGV)
csumFiles=Array.new(ARGV)

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Make sure the arguments are OK
if (csumFiles.length > 2) then
  STDERR.puts("ERROR: too many checksum files to process: #{csumFiles.inspect}!")
  exit
elsif (csumFiles.length < 2) then
  STDERR.puts("ERROR: too few checksum files to process: #{csumFiles.inspect}!")
  exit
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
if(debug>0) then STDERR.puts("INFO: File Read") end
fileInfo  = Hash.new
['N2SN', 'N2H', 'N2CT', 'N2MT', 'N2SZ', 'H2N', 'PFIX'].each do |key|          # Create all the arrays
  fileInfo[key]  = Array.new
end
csumFiles.each_with_index do |fileName, i|
  if(debug>0) then STDERR.puts("INFO:    Reading file: #{fileName}") end
  ['N2SN', 'N2H', 'N2CT', 'N2MT', 'N2SZ', 'H2N'].each do |key|                # Init all the fileInfo members
    fileInfo[key][i]  = Hash.new
  end
  open(fileName, 'r') do |file|
    fileFormat = nil
    file.each_line do |line|
      timeStamp, atime, ctime, mtime, md5, sha1, prtCharCnt, lineCnt, charCnt, fname = line.chomp.split(/ /, 10)
      if (doPrefix) then                                                      # Find the maximal path-name prefix
        if (fileInfo['PFIX'][i]) then
          fileInfo['PFIX'][i].length.downto(0) do |j|
            if (fileInfo['PFIX'][i].start_with?(fname[0,j])) then
              fileInfo['PFIX'][i] = fname[0,j]
              break
            end
          end
        else
          fileInfo['PFIX'][i] = fname;
        end
      end
      csum = ( csumType=='md5' ? md5 : sha1 )
      fileInfo['N2H'][i][fname]  = csum                                       # Store away the data...
      fileInfo['N2SN'][i][fname] = fname
      fileInfo['N2CT'][i][fname] = ctime.to_i
      fileInfo['N2MT'][i][fname] = mtime.to_i
      fileInfo['N2SZ'][i][fname] = charCnt.to_i
      fileInfo['H2N'][i][csum]   = (fileInfo['H2N'][i][csum] || Array.new).push(fname)
    end
  end
end
if(debug>0) then STDERR.puts("INFO:    File Reads complete") end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Post-process the data
if (doPrefix) then
  if(debug>0) then STDERR.puts("INFO: Computing short names") end
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
if(debug>0) then STDERR.puts("INFO: Build up the search patterns from the inputs") end
searchCriteria = nil
if ( !(searchArg.nil?)) then
  searchCriteria = Array.new
  searchArg.each do |tag, pat| 
    if    (tag.upcase == 'NAME') then
      searchCriteria.push( [ tag, Regexp.new(pat) ] )
    elsif (tmp=pat.match(/^(!{0,1})(.+)$/i)) then
      searchCriteria.push([tag, [ (tmp[1].upcase == '!'), tmp[2]] ])
    else
      STDERR.puts("ERROR: Bad search argument: #{tag.inspect} => #{pat.inspect}!")
      exit
    end
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if(debug>0) then STDERR.puts("INFO: Printing report") end
if (pPrefix && doPrefix) then
  puts("< Prefix: #{fileInfo['PFIX'][0].inspect}")
  puts("> Prefix: #{fileInfo['PFIX'][1].inspect}")
end
if (pColTitles) then
  pCols.each { |ct| printf("%#{pColsFmt[ct]}s ", ct) }
  printf("\n")
end
fnameSeenInBigList = Hash.new
fnameSeenInDupList = Hash.new
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
      theCols['NL'] = sprintf('%03d', numFnd[0])
      theCols['NR'] = sprintf('%03d', numFnd[1])

      theCols['H']  = ''
      if(inFile[0] && inFile[1]) then
        if(curHash == fileInfo['N2H'][j][fnames[j]]) then
          theCols['H'] = '='
        else
          theCols['H'] = '|'
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
      theCols['SZ']  = deltaUnits(fileInfo['N2SZ'][0][fnames[0]], fileInfo['N2SZ'][1][fnames[1]], 'size')

      theCols['HASH'] = fileInfo['N2H'][i][fnames[i]]
      theCols['NAME'] = shortName

      # Evaluate search criteria
      printThisOne = false
      if (searchCriteria.nil?) then
        printThisOne = true
      else
        searchCriteria.each do |tag, pat|
          if (printThisOne) then
            break
          end
          if (pat.class == Regexp) then
            if (theCols[tag].match(pat)) then
              printThisOne = true
            end
          else
            tmp = (theCols[tag].slice(0, pat[1].length) == pat[1])
            printThisOne = ( pat[0] ? !tmp : tmp )
          end
        end
      end

      if (printThisOne) then
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
                printf("%s %s %s\n", ' '*53, locs, dshortName)
                fnameSeenInDupList[dshortName] = 1
              end
            end
          end
        end
      end
    end
  end
end
