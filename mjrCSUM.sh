#!/bin/bash# -*- Mode:Shell-script; Coding:us-ascii-unix; fill-column:158 -*-
################################################################################################################################################################
##
# @file      mjrCSUM.sh
# @author    Mitch Richling <https://www.mitchr.me>
# @brief     Compute a file checksum.@EOL
# @std       bash
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
# @todo      @EOL@EOL
# @warning   @EOL@EOL
# @bug       @EOL@EOL
# @filedetails
#
#  Very inefficient way to compute the MD5, SHA1, line count, character count, and binary character count for a file.  It reads the file FOUR times!!!  Still,
#  it's easy to code up... :)
#  
#  Out is: "MD5 SHA1 LINE_COUNT CHAR_COUNT BIN_CHAR_COUNT FILE_NAME"
#
################################################################################################################################################################

################################################################################################################################################################
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
echo `date +%s`                                         \
     `stat -c "%X %Z %Y" "$1"`                          \
     `openssl dgst -hex -md5  "$1" | sed 's/(.*)= /:/'` \
     `openssl dgst -hex -sha1 "$1" | sed 's/(.*)= /:/'` \
     `tr -d "[:print:][:space:]" < "$1" | wc -c`        \
     `wc -l -c "$1"`
