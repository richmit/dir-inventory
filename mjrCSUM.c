// -*- Mode:C; Coding:us-ascii-unix; fill-column:158 -*-
/**************************************************************************************************************************************************************/
/**
 @file      mjrCSUM.c
 @author    Mitch Richling <https://www.mitchr.me>
 @brief     Compute custom "checksum" for files.@EOL
 @std       C99
 @copyright 
  @parblock
  Copyright (c) 1997,2005,2016, Mitchell Jay Richling <https://www.mitchr.me> All rights reserved.

  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice, this list of conditions, and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions, and the following disclaimer in the documentation
     and/or other materials provided with the distribution.

  3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software
     without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
  DAMAGE.
  @endparblock
 @filedetails

  This little C program is intended to read a single file given on the command line and produce single line of output that can be used to later check the
  file's content via check-sums.  The intended application is incremental backup, backup integrity, and backup cataloging.

  The output (v1) is: 
     TIME MD5 SHA1 NUM_BIN_CHARS NUM_LINES NUM_CHARS FILE_NAME

  The output (v2) is:
     TIME ATIME CTIME MTIME MD5 SHA1 NUM_BIN_CHARS NUM_LINES NUM_CHARS FILE_NAME

  Parse note:  
     v1 may be diffienterated from v2 by noteing that the MD5 value is prefixed with "MD5:".  Thus, v1 has one integer before the MD5, and v2 has four.

  Compile on linux with something like this:
     gcc -Wall -O5 mjrCSUM.c -lcrypto -o mjrCSUM              

***************************************************************************************************************************************************************/

/*------------------------------------------------------------------------------------------------------------------------------------------------------------*/
#include <openssl/ssl.h>

#include <ctype.h>
#include <errno.h>              /* error stf       POSIX */
#include <fcntl.h>              /* UNIX file ctrl  UNIX  */

#include <stdio.h>              /* I/O lib         ISOC  */
#include <stdlib.h>             /* Standard Lib    ISOC  */
#include <sys/stat.h>           /* UNIX stat       POSIX */
#include <time.h>
#include <unistd.h>             /* UNIX std stf    POSIX */

/*------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int main(int argc, char *argv[]);

#define READ_SIZE 1024*128

/* Version of the output to deliver. */
#define OUTPUT_VERSION 2

/*------------------------------------------------------------------------------------------------------------------------------------------------------------*/
int main(int argc, char *argv[]) {
  int FD;
  char fileBuf[READ_SIZE+10];
  int returnValue;
  unsigned long numLines    = 0;
  unsigned long numChars    = 0;
  unsigned long numBinChars = 0;
  EVP_MD_CTX md5ctx, sha1ctx;
  unsigned char md5val[EVP_MAX_MD_SIZE], sha1val[EVP_MAX_MD_SIZE];
  unsigned int md5len, i, sha1len;
  struct stat s;

  /* Make sure we got an argument */
  if(argc < 2) {
    fprintf(stderr, "ERROR: One argument required (a file name)\n");
    exit(1);
  }

  /* Stat the file. */
  if(lstat(argv[1], &s) < 0) {
    printf("ERROR: Could not stat file: '%s'\n", argv[1]);
    exit(2);
  } /* end if */

  if(s.st_mode & S_IFREG) {

    /* Open our file... */
    if((FD = open(argv[1], O_RDONLY)) < 0) {
      perror("ERROR: File open");
      exit(10);
    } /* end if */

    /* Intialize the hash objects. */
    EVP_DigestInit(&md5ctx, EVP_md5());
    EVP_DigestInit(&sha1ctx, EVP_sha1());

    /* Read the file and feed data to the counters and hash functions. */
    while((returnValue = read(FD, fileBuf, READ_SIZE)) > 0) {
      for(i=0; i<returnValue; i++) {
        // Check for Binary chars
        if( !(isprint(fileBuf[i]) || isspace(fileBuf[i])) )
          numBinChars++;
        // Add up chars
        numChars++;
        // Check for NL
        if(fileBuf[i] == 10)
          numLines++;
      }
      EVP_DigestUpdate(&md5ctx, fileBuf, returnValue);
      EVP_DigestUpdate(&sha1ctx, fileBuf, returnValue);
    } /* end while */

    /* Make sure we exited well. */
    if(returnValue < 0) {
      perror("ERROR: File read");
      exit(11);
    } /* end if */

    /* We are done with the file, so we close it now. */
    if(close(FD) < 0) {
      perror("ERROR: File close");
      exit(13);
    } /* end if */

    /* Finish up the hash function computation. */
    EVP_DigestFinal(&md5ctx, md5val, &md5len);
    EVP_DigestFinal(&sha1ctx, sha1val, &sha1len);

    /* Print out the results */
    printf("%lu ", (unsigned long)time(NULL));
    if(OUTPUT_VERSION >= 2) {
      printf("%lu ", (unsigned long)s.st_atime);
      printf("%lu ", (unsigned long)s.st_ctime);
      printf("%lu ", (unsigned long)s.st_mtime);
    }
    printf("MD5:");
    for(i=0; i<md5len; i++)
      printf("%02x", md5val[i]);
    printf(" SHA1:");
    for(i=0; i<sha1len; i++)
      printf("%02x", sha1val[i]);
    printf(" %lu %lu %lu %s\n", numBinChars, numLines, numChars, argv[1]);
  }

  return 0;  
}
