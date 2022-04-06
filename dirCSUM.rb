#!/bin/bash /home/richmit/bin/ruby20
# -*- Mode:Ruby; Coding:us-ascii-unix; fill-column:158 -*-
################################################################################################################################################################
##
# @file      dirCSUM.rb
# @author    Mitch Richling <https://www.mitchr.me>
# @brief     Compute checksums for a set of directories.@EOL
# @std       Ruby2.0
# @copyright 
#  @parblock
#  Copyright (c) 1996,1998,2005,2016, Mitchell Jay Richling <https://www.mitchr.me> All rights reserved.
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
################################################################################################################################################################

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
require 'optparse'
require 'optparse/time'

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
timeStart      = Time.now
debug          = 0
oldFileFile    = nil
oldFileCtime   = TRUE
oldFileMtime   = TRUE
printFileNames = TRUE
opts = OptionParser.new do |opts|
  opts.banner = "Usage: dirCSUM.rb [options]"
  opts.separator ""
  opts.separator "Options:"
  opts.on("-h",           "--help",             "Show this message")        { puts opts; exit                        }
  opts.on("-n STRING",    "--new STRING",       "File with dirCSUM data")   { |v| oldFileFile=v;                     }
  opts.on("-c Y/N",       "--ctime STRING",     "Check ctime for -n")       { |v| oldFileCtime=v.match(/^[YyTt]/);   }
  opts.on("-p Y/N",       "--pnames STRING",    "Print file names")         { |v| printFileNames=v.match(/^[YyTt]/); }
  opts.on("-m Y/N",       "--mtime STRING",     "Check mtime for -n")       { |v| oldFileMtime=v.match(/^[YyTt]/);   }
  opts.separator ""
end
opts.parse!(ARGV)

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
oldFiles=Hash.new
oldFilesData=Hash.new
if(oldFileFile) then
  STDERR.puts("Starting oldfile read")
  open(oldFileFile, "r:binary") do |file|
    file.each_line do |line|
      timeStamp, atime, ctime, mtime, md5, sha1, prtCharCnt, lineCnt, charCnt, fname = line.chomp.split(/ /, 10)
      oldFiles[fname] = line
      oldFilesData[fname] = {'mtime' => mtime.to_i, 'ctime' => ctime.to_i}
    end
  end
end
      
require 'find'

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Set to the checksum command
csumCmd='/Users/richmit/world/my_prog/checkSum/csum10/mjrCSUM.sh'
csumCmd='/Users/richmit/world/my_prog/checkSum/csum10/mjrCSUM.rb'
csumCmd='/Users/richmit/world/my_prog/checkSum/csum10/mjrCSUM'
#csumCmd='~/bin/csum-pc'
#csumCmd='~/bin/mjrCSUM'

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
STDERR.puts("Starting filesystem scan")
numberOfFiles=0
numberOfFilesSkipped=0
numberOfFilesNew=0
numberOfFilesTim=0
numberOfDirs=0
files=Array.new
filesWhy=Hash.new
ARGV.each do |curDir|
  realCurDir = File.realdirpath(curDir)
  Find.find(realCurDir) do |path|
    if FileTest.directory?(path)
      numberOfDirs += 1
    else
      if(oldFiles.member?(path)) then
        statData = File.lstat(path)
        if( (!(oldFileMtime) || (statData.mtime.tv_sec == oldFilesData[path]['mtime'])) &&
            (!(oldFileCtime) || (statData.ctime.tv_sec == oldFilesData[path]['ctime']))) then
          STDOUT.puts(oldFiles[path])
          numberOfFilesSkipped += 1
        else
          numberOfFilesTim += 1
          numberOfFiles += 1
          files.push(path)
	filesWhy[path] = 'TIM';	
        end
      else
        numberOfFilesNew += 1
        numberOfFiles += 1
        files.push(path)
	filesWhy[path] = 'NEW';	
      end
    end
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
STDERR.puts("Starting checksums")
lastPrt = 0
numberOfFilesS = 0.0
files.each do |path|
  curPct  = 100*(numberOfFilesS/numberOfFiles)
  numberOfFilesS += 1
  if(!printFileNames && (numberOfFiles > 300)) then
    if ((lastPrt+1) <= curPct) then
      lastPrt = curPct
      STDERR.printf("  %5.2f%% %10d files\n", curPct, numberOfFilesS)
    end
  else
    STDERR.printf("  %5.2f%% %10d files %3s :: %s\n", curPct, numberOfFilesS, filesWhy[path], path)
  end
  system(csumCmd, path);
  #STDOUT.puts("#{csumCmd} #{path}")
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
STDERR.puts("Stats")
STDERR.puts("  Files:        #{numberOfFilesSkipped+numberOfFiles}")
STDERR.puts("  Files CSUMed: #{numberOfFiles}")
STDERR.puts("  New Files:    #{numberOfFilesNew}")
STDERR.puts("  Time Changes: #{numberOfFilesTim}")
STDERR.puts("  Run Time:     #{(Time.now-timeStart).to_i} sec")
