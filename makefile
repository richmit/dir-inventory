# -*- Mode:Makefile; Coding:us-ascii-unix; fill-column:158 -*-
################################################################################################################################################################
##
# @file      makefile
# @author    Mitch Richling <https://www.mitchr.me>
# @brief     Build my checksum program@EOL
# @std       GNUmake
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

ifeq "$(PLATFORM)" ''
PLATFORM = LINUXx32
endif

################################################################################################################################################################
## BEGIN: This is the part of the file you may need to edit for your system.
################################################################################################################################################################

### Cygwin
ifeq "$(PLATFORM)" 'CYGWINx86'
CFLAGS    = -O5 -Wall $(BOPTIONS)
CC        = gcc
OPENSSLIP = -I/usr/include
OPENSSLLP = -L/usr/lib
OPENSSLLL = -lcrypto
endif

### Solaris (64-bit, x86, SunPro Compiler 12)
ifeq "$(PLATFORM)" 'SOLsp12x86_64'
CFLAGS     = -D_POSIX_PTHREAD_SEMANTICS -fast -m64 -lrt -lpthread -lsocket -lnsl $(BOPTIONS)
CC         = cc
#OPENSSLIP = -I/home/richmit/local/openssl/0.9.8b/install/include
#OPENSSLLP = -L/home/richmit/local/openssl/0.9.8b/install/lib
#OPENSSLLL = -lcrypto
endif

### Solaris (64-bit, x86, SunPro Compiler 11)
ifeq "$(PLATFORM)" 'SOLsp11x86_64'
CFLAGS     = -D_POSIX_PTHREAD_SEMANTICS -fast -xarch=generic64 -lrt -lpthread -lsocket -lnsl $(BOPTIONS)
CC         = cc
#OPENSSLIP = -I/home/richmit/local/openssl/0.9.8b/install/include
#OPENSSLLP = -L/home/richmit/local/openssl/0.9.8b/install/lib
#OPENSSLLL = -lcrypto
endif

### Solaris (64-bit, x86)
ifeq "$(PLATFORM)" 'SOLx86_64'
CFLAGS     = -O5 -m64 -lrt -lpthread -lsocket -lnsl -lumem $(BOPTIONS)
CC         = gcc
#OPENSSLIP = -I/home/richmit/local/openssl/0.9.8b/install/include
#OPENSSLLP = -L/home/richmit/local/openssl/0.9.8b/install/lib
#OPENSSLLL = -lcrypto
endif

### Solaris (64-bit)
ifeq "$(PLATFORM)" 'SOLxUSv9'
CFLAGS     = -D_POSIX_PTHREAD_SEMANTICS -xO5 -xarch=v9 -lrt -lpthread -lsocket -lnsl $(BOPTIONS)
CC         = cc
OPENSSLIP = -I/home/richmit/local/openssl/0.9.8b/install/include
OPENSSLLP = -L/home/richmit/local/openssl/0.9.8b/install/lib
OPENSSLLL = -lcrypto
endif

### Solaris (32-bit) -- non-portable, but easy, Solaris-ism: _FILE_OFFSET_BITS=64
ifeq "$(PLATFORM)" 'SOLxUSv8'
CFLAGS    = -D_FILE_OFFSET_BITS=64 -lrt -xO5 -xarch=v8 -lpthread -lsocket -lnsl $(BOPTIONS)
CC        = cc
OPENSSLIP = -I/apps/free/openssl/0.9.8/include
OPENSSLLP = -I/apps/free/openssl/0.9.8/lib
# HACK: Force static link of just libcrypto...
OPENSSLLL = /apps/free/openssl/0.9.8/lib/libcrypto.a
endif

### MacOS X
ifeq "$(PLATFORM)" 'DARWINxPPC'
#CFLAGS    = -O5 -Wall -DUSELCHOWN=chown $(BOPTIONS)
CFLAGS    = -O5 -Wall $(BOPTIONS)
CC        = gcc
OPENSSLIP = -I/usr/include
OPENSSLLP = -L/usr/lib
OPENSSLLL = -lcrypto
endif

### MacOS X
ifeq "$(PLATFORM)" 'DARWINx86'
CFLAGS    = -O4 -Wall -m64 $(BOPTIONS)
CC        = gcc
OPENSSLIP = -I/usr/include
OPENSSLLP = -L/usr/lib
OPENSSLLL = -lcrypto

OPENSSLIP = -I/opt/local/include
OPENSSLLP = -L/opt/local/lib
OPENSSLLL = -lcrypto
endif

### Linux
ifeq "$(PLATFORM)" 'LINUXx64'
CFLAGS    = -m64 -lpthread -Wall $(BOPTIONS)
CC        = gcc
OPENSSLIP = -I/usr/include
OPENSSLLP = -L/usr/lib
OPENSSLLL = -lcrypto
endif

### Linux
ifeq "$(PLATFORM)" 'LINUXx32'
CFLAGS    = -m32 -lpthread -Wall $(BOPTIONS)
CC        = gcc
OPENSSLIP = -I/usr/include
OPENSSLLP = -L/usr/lib
OPENSSLLL = -lcrypto
endif

################################################################################################################################################################
## No need to edit anything below this point.  Everything from this point on simply consists of the compile rules.
################################################################################################################################################################

#FAKEMAKETRGT = makefile

all : mjrCSUM_$(PLATFORM)
	@echo Make Complete

mjrCSUM_$(PLATFORM) : mjrCSUM.c $(FAKEMAKETRGT)
	$(CC) $(CFLAGS) $(OPENSSLIP) $(OPENSSLLP) $(OPENSSLLL) mjrCSUM.c -o mjrCSUM_$(PLATFORM)

install :
	mv -f mjrCSUM_DARWINx* mjrCSUM_SOLx* mjrCSUM_LINUXx* /home/richmit/world/my_prog/products/UNIV/

clean : 
	@echo Make Complete
	rm -f *_CYGWINx86.exe
	rm -f *_CYGWINx86.stackdump
	rm -f *_SOLsp12x86_64
	rm -f *_SOLsp11x86_64
	rm -f *_SOLx86_64
	rm -f *_SOLxUSv9
	rm -f *_SOLxUSv8
	rm -f *_DARWINxPPC
	rm -f *_DARWINx86
	rm -f *_LINUXx64
	rm -f *~
	rm -f *.bak
	rm -f *.exe
