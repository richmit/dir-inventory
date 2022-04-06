#!/bin/bash /home/richmit/bin/ruby20
# -*- Mode:Ruby; Coding:us-ascii-unix; fill-column:158 -*-
################################################################################################################################################################
##
# @file      mjrCSUM.rb
# @author    Mitch Richling <https://www.mitchr.me>
# @brief     Compute a file checksum.@EOL
# @std       Ruby2.0
# @copyright 
#  @parblock
#  Copyright (c) 1997,2005,2016, Mitchell Jay Richling <https://www.mitchr.me> All rights reserved.
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
require 'digest/md5' 
require 'digest/sha1' 

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
outputVersion = 2

fileName = ARGV[0]

open(fileName, "rb") do |file|

  sha1 = Digest::SHA1.new
  md5  = Digest::MD5.new

  statData = File::Stat.new(file)

  numBinChars = numChars = numLines = 0
  buffer = ''
  while (not file.eof) 
    file.read(512, buffer)
    sha1.update(buffer)
    md5.update(buffer)
    buffer.each_byte do |c|
      if ((c<32) || (c>126)) then
        numBinChars += 1
      end
      numChars += 1
      if (c == 10)
        numLines += 1
      end
    end
  end

  # Print out the results
  printf("%u ", Time.now.to_i)
  if(outputVersion >= 2) then
      printf("%u ", statData.atime)
      printf("%u ", statData.ctime)
      printf("%u ", statData.mtime)
  end
  printf("MD5:%s", md5.to_s)
  printf(" SHA1:%s", sha1.to_s)
  printf(" %u %u %u %s\n", numBinChars, numLines, numChars, fileName)
end
