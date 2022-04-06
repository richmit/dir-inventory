#!/bin/bash /home/richmit/bin/ruby20
# -*- Mode:Ruby; Coding:us-ascii-unix; fill-column:158 -*-
################################################################################################################################################################
##
# @file      dupCSUM.rb
# @author    Mitch Richling <https://www.mitchr.me>
# @brief     Read given checksum files, and report on files with the same contents.@EOL
# @std       Ruby2.0
# @copyright 
#  @parblock
#  Copyright (c) 1998,2004,2005,2016, Mitchell Jay Richling <https://www.mitchr.me> All rights reserved.
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
onlyExisting = false
onlyFiles    = false
includeRE    = false
debug        = 0
opts = OptionParser.new do |opts|
  opts.banner = "Usage: argParse2.rb [options]"
  opts.separator ""
  opts.separator "Options:"
  opts.on("-h",        "--help",            "Show this message")                { puts opts; exit                                                     }
  opts.on("-e Y/N",    "--existing Y/N",    "Existing files only")              { |v| onlyExisting=v.match(/^[YTyt]/);                                }
  opts.on("-f Y/N",    "--files Y/N",       "Regular files only (implies -e)")  { |v| onlyFiles=v.match(/^[YTyt]/); onlyFiles && (onlyExisting=true); }
  opts.on("-i STRING", "--include STRING",  "Regular expression to match")      { |v| includeRE=Regexp.new(v);                                        }
  opts.on("-d INT",    "--debug INT",       "Set debug level")                  { |v| debug=v.to_i;                                                   }
  opts.separator ""
  opts.separator ""
  opts.separator ""
end
opts.parse!(ARGV)

#---------------------------------------------------------------------------------------------------------------------------------------------------------------

ignoreList = { 'MD5:d41d8cd98f00b204e9800998ecf8427e' => 'empty file'
             }

#---------------------------------------------------------------------------------------------------------------------------------------------------------------

files = Hash.new
filen = 0
ARGV.each do |fileName|
  filen += 1
  STDERR.puts("Reading checksum file: #{fileName}")
  open(fileName, 'r') do |file|
    file.each_line do |line|
      timeStamp, atime, ctime, mtime, md5, sha1, prtCharCnt, lineCnt, charCnt, fname = line.chomp.split(/ /, 10)
      if(files.member?(md5)) then
        files[md5].push([ filen, fname ])
      else
        files[md5] = [ [ filen, fname ] ]
      end
    end
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------

files.each do |md5, cfiles|
  if((!ignoreList.member?(md5)) && (cfiles.length > 1)) then
    
    dupList = nil
    if(onlyFiles || onlyExisting) then
      dupList = Array.new
      cfiles.each do |filen, fname|
        if !(onlyFiles) || !(FileTest.symlink?(fname)) then
          if !(onlyExisting) || FileTest.exist?(fname) then
             if (!(includeRE) || fname.match(includeRE)) then
               dupList.push([filen, fname])
             end
          end
        end
      end
    else
      dupList = cfiles
    end

    if(dupList.length > 1) then
      puts('='*80)
      puts(md5)
      dupList.each do |filen, fname|
        printf("  %3d: %s\n", filen, fname)
      end
    end
  end
end
