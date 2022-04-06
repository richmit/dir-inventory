#!/bin/env ruby
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
require 'optparse'
require 'optparse/time'
require 'sqlite3'
require 'set'

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
allCols     = ['NL', 'NR', 'H', 'CT', 'MT', 'SZ', 'HASH', 'NAME']
srchArgPat  = Regexp.new('-+s(' + allCols.join('|') + ')=(.+)$')

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
fileName    = nil
outputFmt   = :of_human
debug       = 3
dircsumMode = false
opts = OptionParser.new do |opts|
  opts.banner = "Usage: metaCSUM.rb [options] [file1]"
  opts.separator ""
  opts.separator "Reports various checksum file metadata"
  opts.separator ""
  opts.separator "Options:"
  opts.on("-h",        "--help",             "Show this message")                 { puts opts; exit;                           }
  opts.on("-U",        "--dircsum",          "Set dircsum mode")                  { dircsumMode = true;                        }
  opts.separator "                                       Uses the most recient .dircsum DB.                                    "
  opts.separator "                                                                                                             "
end
opts.parse!(ARGV)

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Populate csumFiles & check that we got the correct number of files
fileName = ARGV.pop
if(dircsumMode) then
  if (! (fileName.nil?)) then
    if(debug>=1) then STDERR.puts("ERROR: Command line file argument (#{fileName}) not allowed -U mode!") end
    exit
  end
  if(FileTest.exist?('.dircsum')) then
    oldFileFiles = Dir.glob('.dircsum/??????????????_dircsum.sqlite').sort
    fileName = oldFileFiles.pop
    if (fileName.nil?) then
      if(debug>=1) then STDERR.puts("ERROR: No DB files found in .dircsum directory in -U mode!") end
      exit
    end
  else
    if(debug>=1) then STDERR.puts("ERROR: Missing .dircsum direcotyr in -U mode!") end
    exit
  end
else
  if (ARGV.length > 0) then
    if(debug>=1) then STDERR.puts("ERROR: Only one checksum file argument allowed!") end
    exit
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
metaData = Hash.new
SQLite3::Database.new(fileName) do |dbCon|
  # Collect scan meta data
  dbCon.execute("SELECT mkey, mvalue FROM meta;").each do |mkey, mvalue|
    metaData[mkey]  = mvalue;
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
puts("================================================================================")
puts("Checksum file: #{fileName}")
puts("================================================================================")
puts("Scan Engine: #{metaData['engine']}  Version: #{metaData['engine version']}")
puts("DB Options: BLKnFSOBJ: #{metaData['BLKnFSOBJ']}   DEVnFSOBJ: #{metaData['DEVnFSOBJ']}   EXTnFSOBJ: #{metaData['EXTnFSOBJ']}")
puts("Directory Scanned: #{metaData['dirToScan']}")
puts("Original checksum file: #{metaData['outDBfile']}")
if (metaData['oldFileFile']) then
  puts("Precursor checksum data")
  puts("   Precursor checksum file: #{metaData['oldFileFile']}")
  puts("   Precursor criteria: Size: #{metaData['oldFileSize']}   Mtime: #{metaData['oldFileMtime']}   Ctime: #{metaData['oldFileCtime']}")
  puts("   Checksums avoided: #{metaData['checksumAvoided']}")
end
puts("Process Started at: #{Time.at(metaData['processStart'].to_i)}")
puts("Process Completed at: #{Time.at(metaData['processEnd'].to_i)}")
puts("   Total process runtime .. #{metaData['processEnd'].to_i - metaData['processStart'].to_i} seconds")
puts("   User Scan took ......... #{metaData['dumpFinish:rusers'].to_i - metaData['dumpStart:users'].to_i} seconds")
puts("   Group Scan took ........ #{metaData['dumpFinish:rgroups'].to_i - metaData['dumpStart:rgroups'].to_i} seconds")
puts("   File Scan took ......... #{metaData['scanFinish'].to_i - metaData['scanStart'].to_i} seconds")
puts("   CSUM & DB dump took .... #{metaData['dumpAndCsumFinish'].to_i - metaData['dumpAndCsumStart'].to_i} seconds")
puts("     Checksum type: #{metaData['csum']}")
puts("     Number of checksums: #{metaData['cntCsumFiles']}")
puts("     Bytes checksumed: #{metaData['cntCsumByte']} bytes")
puts("Scanned Object Counts")
puts("   Files ........ #{metaData['cntRegFile']}")
puts("   Directories .. #{metaData['cntDirectories']}")
puts("   Symlinks ..... #{metaData['cntSymLinks']}")
puts("   Special ...... #{metaData['cntFunnyFiles']}")
puts("   Total ........ #{metaData['objCnt']}")
puts("================================================================================")
