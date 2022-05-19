#!/usr/bin/env -S ruby -W0 -E utf-8
# -*- Mode:Ruby; Coding:us-ascii-unix; fill-column:158 -*-
################################################################################################################################################################
##
# @file      applyOrgBlockSQL.rb
# @author    Mitch Richling <https://www.mitchr.me>
# @brief     Extract a code block from an org-mode document, and run it.@EOL
# @keywords  checksum filesystem directory sub-directory tree inventory sqlite database
# @std       Ruby 2.0
# @copyright
#  @parblock
#  Copyright (c) 2016, Mitchell Jay Richling <https://www.mitchr.me> All rights reserved.
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
Encoding.default_external="utf-8";

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
nameOfDB    = ARGV[0]
nameOfBlock = ARGV[1]
nameOfFile  = ARGV[2] || 'readme.org'

if(nameOfDB.match(/^-+h/)) then
  puts('                                                                       ')
  puts('Use: applyOrgBlockSQL.rb name_of_db name_of_block [name_of_org_file]   ')
  puts('                                                                       ')
  puts('  Extract a named code block from an org file (readme.org by default), ')
  puts('  and apply to the named DB.                                           ')
  puts('                                                                       ')
  exit
end

if( !(FileTest.exist?(nameOfDB)))
  puts("ERROR: DB file could not be found: #{nameOfDB}")
end
if( !(FileTest.exist?(nameOfFile))) then
  puts("ERROR: ORG file could not be found: #{nameOfFile}")
end

blockStartRe = Regexp.new("^#\\+NAME:\s*#{nameOfBlock}\s*$")

foundBlock = false
codeInOurBlock = 'sqlite3 -header ' + nameOfDB + ' "'
open(nameOfFile, 'r') do |inOrgFile|
  inOrgFile.each_line do |line|
    if(foundBlock) then
      if(line.match(/^#\+end_src\s*$/)) then
        break
      else
        if( !(line.match(/^#\+begin_src\s+sql/))) then
          codeInOurBlock += (' ' + line.chomp.lstrip)
        end
      end
    else
      if(blockStartRe.match(line)) then
        foundBlock = true
      end
    end
  end
end
codeInOurBlock += '"'

if(foundBlock) then
  system(codeInOurBlock);
else
  puts("ERROR: Could not find block: #{nameOfBlock}")
end
