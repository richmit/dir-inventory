#!/usr/bin/env -S ruby -W0 -E utf-8
# -*- Mode:Ruby; Coding:us-ascii-unix; fill-column:158 -*-
################################################################################################################################################################
##
# @file      cmpCSUM.rb
# @author    Mitch Richling <https://www.mitchr.me>
# @brief     Print checksum metadata.@EOL
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
outputFmt   = :of_human
debug       = 3
opts = OptionParser.new do |opts|
  opts.banner = "Usage: dcsumMeta.rb [options] [file ...]                                                               "
  opts.separator "                                                                                                      "
  opts.separator "Reports various metadata for provided checksum file(s)                                                "
  opts.separator "If no files are provided, then use the *TWO* most recient .dircsum DBs (newest one first).            "
  opts.separator "                                                                                                      "
  opts.separator "Options:                                                                                              "
  opts.on("-h",        "--help",             "Show this message") { puts opts; exit;                                    }
  opts.on("-v",        "--debug INT",        "Set debug level")   { |v| debug=v.to_i;                                   }
  opts.separator "                                       1 .. Print meta data report                                    "
  opts.separator "                                       2 .. Print delta report                                        "
  opts.separator "                                       3 .. Print ERRORS (default)                                    "
  opts.separator "                                       4 .. Print WARNING                                             "
  opts.separator "                                       5 .. Print INFO                                                "
  opts.separator "                                       6 .. Print DEBUG                                               "
  opts.separator "                                                                                                      "
end
opts.parse!(ARGV)
files = ARGV.clone

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if (files.empty?) then
  if (FileTest.exist?('.dircsum')) then
    oldFileFiles = Dir.glob('.dircsum/??????????????_dircsum.sqlite').sort
    if (oldFileFiles.length() >= 2) then
      files = [ oldFileFiles[-2], oldFileFiles[-1] ]
    elsif (oldFileFiles.length() >= 1) then
      files = [ oldFileFiles[-1] ]
    else
      if(debug>=3) then STDERR.puts("ERROR: No DB files provided, and .dircsum contains no DB files!") end
      exit
    end
  else
    if(debug>=3) then puts("ERROR: No DB files provided, and .dircsum missing.") end
    exit
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
def n2cn (nOs) 
  nOs.to_s.reverse.scan(/\d{1,3}/).join(",").reverse;
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
intKeys = Set.new(['processStart', 'processEnd', 'dumpFinish:rusers', 'dumpStart:users', 'dumpFinish:rgroups', 'dumpStart:rgroups', 'scanFinish', 'scanStart',
                   'dumpAndCsumStart:files', 'dumpAndCsumFinish:files', 'cntRegFile', 'cntDirectories', 'cntSymLinks', 'cntFunnyFiles', 'objCnt']);
metaData = Hash.new
newestScanStartIdx = -1
oldestScanStartIdx = -1
newestScanStartTim = nil
oldestScanStartTim = nil
files.each_with_index do |fileName, fileIdx|
  metaData[fileName] = Hash.new
  SQLite3::Database.new(fileName) do |dbCon|
    dbCon.execute("SELECT mkey, mvalue FROM meta;").each do |mkey, mvalue|
      if (intKeys.member?(mkey)) then
        mvalue = mvalue.to_i
      end
      metaData[fileName][mkey]  = mvalue
      if ((mkey == 'processStart') && ((newestScanStartIdx < 0) || (newestScanStartTim < mvalue))) then
        newestScanStartTim = mvalue
        newestScanStartIdx = fileIdx
      end
      if ((mkey == 'processStart') && ((oldestScanStartIdx < 0) || (oldestScanStartTim > mvalue))) then
        oldestScanStartTim = mvalue
        oldestScanStartIdx = fileIdx
      end
    end
    dbCon.execute("SELECT SUM(bytes) AS sizeingb FROM fsobj WHERE ftype = 'r';").each do |tfs|
      metaData[fileName]["FAKE_tfs"] = tfs[0].to_i;
    end
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
files.each_with_index do |fileName, fileIdx|
  fileMetaData = metaData[fileName];
  if (debug>= 1) then
    puts("================================================================================")
    puts("Checksum file: #{fileName}  #{(newestScanStartIdx == fileIdx ? '-- (Newest File)' : '')}#{(oldestScanStartIdx == fileIdx ? '-- (Oldest File)' : '')}")
    puts("================================================================================")
    puts("Scan Engine: #{fileMetaData['engine']}  Version: #{fileMetaData['engine version']}")
    puts("DB Options: BLKnFSOBJ: #{fileMetaData['BLKnFSOBJ']}   DEVnFSOBJ: #{fileMetaData['DEVnFSOBJ']}   EXTnFSOBJ: #{fileMetaData['EXTnFSOBJ']}")
    puts("Directory Scanned: #{fileMetaData['dirToScan']}")
    puts("Original checksum file: #{fileMetaData['outDBfile']}")
    if (fileMetaData['oldFileFile']) then
      puts("Precursor checksum data")
      puts("   Precursor checksum file: #{fileMetaData['oldFileFile']}")
      puts("   Precursor criteria: Size: #{fileMetaData['oldFileSize']}   Mtime: #{fileMetaData['oldFileMtime']}   Ctime: #{fileMetaData['oldFileCtime']}")
      puts("   Checksums avoided: #{n2cn(fileMetaData['checksumAvoided'])}")
    end
    puts("Process Started at: #{Time.at(fileMetaData['processStart'])}")
    puts("Process Completed at: #{Time.at(fileMetaData['processEnd'])}")
    puts("   Total process runtime .. #{n2cn(fileMetaData['processEnd'] - fileMetaData['processStart'])} seconds")
    puts("   User Scan took ......... #{n2cn(fileMetaData['dumpFinish:rusers'] - fileMetaData['dumpStart:users'])} seconds")
    puts("   Group Scan took ........ #{n2cn(fileMetaData['dumpFinish:rgroups'] - fileMetaData['dumpStart:rgroups'])} seconds")
    puts("   File Scan took ......... #{n2cn(fileMetaData['scanFinish'] - fileMetaData['scanStart'])} seconds")
    puts("   CSUM & DB dump took .... #{n2cn(fileMetaData['dumpAndCsumFinish:files'] - fileMetaData['dumpAndCsumStart:files'])} seconds")
    puts("     Checksum type: #{fileMetaData['csum']}")
    puts("     Number of checksums: #{n2cn(fileMetaData['cntCsumFiles'])}")
    puts("     Bytes checksumed: #{n2cn(fileMetaData['cntCsumByte'])} bytes")
    puts("Scanned Object Counts")
    puts("   Files ........ #{n2cn(fileMetaData['cntRegFile'])}  (#{n2cn(fileMetaData['FAKE_tfs'])} bytes)")
    puts("   Directories .. #{n2cn(fileMetaData['cntDirectories'])}")
    puts("   Symlinks ..... #{n2cn(fileMetaData['cntSymLinks'])}")
    puts("   Special ...... #{n2cn(fileMetaData['cntFunnyFiles'])}")
    puts("   Total ........ #{n2cn(fileMetaData['objCnt'])}")
    puts("================================================================================")
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
if (debug>= 2) then
  if (files.length > 1) then
    fileNameFrom = files[oldestScanStartIdx]
    fileNameTo   = files[newestScanStartIdx]
    puts("================================================================================")
    puts("Object Count Change (from #{fileNameFrom}")
    puts("                       to #{fileNameTo})")
    puts("   Files ........ #{n2cn(metaData[fileNameTo]['cntRegFile'] - metaData[fileNameFrom]['cntRegFile'])}  (#{n2cn(metaData[fileNameTo]['FAKE_tfs'] - metaData[fileNameFrom]['FAKE_tfs'])} bytes)")
    puts("   Directories .. #{n2cn(metaData[fileNameTo]['cntDirectories'] - metaData[fileNameFrom]['cntDirectories'])}")
    puts("   Symlinks ..... #{n2cn(metaData[fileNameTo]['cntSymLinks'] - metaData[fileNameFrom]['cntSymLinks'])}")
    puts("   Special ...... #{n2cn(metaData[fileNameTo]['cntFunnyFiles'] - metaData[fileNameFrom]['cntFunnyFiles'])}")
    puts("   Total ........ #{n2cn(metaData[fileNameTo]['objCnt'] - metaData[fileNameFrom]['objCnt'])}")
    puts("Time Between Scans: #{((metaData[fileNameTo]['processStart'] - metaData[fileNameFrom]['processStart'])/(60*60*24.0)).round(4)} days")
    puts("================================================================================")
  end
end
