#!/usr/bin/env -S ruby -W0 -E utf-8
# -*- Mode:Ruby; Coding:us-ascii-unix; fill-column:158 -*-
################################################################################################################################################################
##
# @file      dcsumNew.rb
# @author    Mitch Richling <https://www.mitchr.me>
# @brief     Create an inventory for a filesystem directory tree.@EOL
# @keywords  checksum filesystem directory sub-directory tree inventory sqlite database
# @std       Ruby 2.0
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
require 'digest'
require 'sqlite3'
require 'etc'

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Print stuff to STDOUT immediately -- important on windows
$stdout.sync = true

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
dbSetupCode = <<SQL
    -- Raw UNIX groups table
    CREATE TABLE rgroups (groupid INTEGER,
                         gname   TEXT
                        );

    -- Raw UNIX passwd table
    CREATE TABLE rusers (userid   INTEGER,
                        uname    TEXT,
                        primgid  INTEGER,
                        shell    TEXT,
                        gecos    TEXT
                       );

    -- UNIX group memberships (including primary memberships)
    CREATE TABLE groupmembers (groupid INTEGER,
                               userid  INTEGER
                              );

    -- Various bits of meta data about the scan
    --  |-------------------------+--------------------+-------------------------------------------------------------|
    --  | Key                     | Type               | Description                                                 |
    --  |-------------------------+--------------------+-------------------------------------------------------------|
    --  | BLKnFSOBJ               | BOOLEAN            | Are the blocks and blocksz columns in fsobj table?          |
    --  | DEVnFSOBJ               | BOOLEAN            | Is the device column in the in fsobj table?                 |
    --  | EXTnFSOBJ               | BOOLEAN            | Is file extension included as a field in fsobj table?       |
    --  | csum                    | STRING             | The checksum we are using                                   |
    --  |-------------------------+--------------------+-------------------------------------------------------------|
    --  | checksumAvoided         | INTEGER            | Number of checksums avoided in in -u or -U mode             |
    --  | objCnt                  | INTEGER            | Number of objects scanned                                   |
    --  | cntRegFile              | INTEGER            | Number of regular files scanned                             |
    --  | cntDirectories          | INTEGER            | Number of directories scanned                               |
    --  | cntSymLinks             | INTEGER            | Number of symbolic links scanned                            |
    --  | cntFunnyFiles           | INTEGER            | objCnt-(cntRegFile+cntDirectories+cntSymLinks)              |
    --  | cntCsumByte             | INTEGER            | sum(size_of_file) for all checksumed files                  |
    --  | cntCsumByte1KC          | INTEGER            | sum(min(size_of_file, 1024) for all checksumed files        |
    --  | cntCsumFiles            | INTEGER            | Number of files checksumed                                  |
    --  |-------------------------+--------------------+-------------------------------------------------------------|
    --  | engine version          | STRING             | YYYY-MM-DD format date for version of scanner               |
    --  | engine                  | STRING             | Indicates engine platform: ruby, c++                        |
    --  | dircsumMode             | BOOLEAN            | Did the scan run in dircsumMode (-U)                        |
    --  | outDBfile               | STRING             | Name of output DB file (-o)                                 |
    --  | oldFileFile             | STRING             | Name of old DB file (-u)                                    |
    --  | oldFileSize             | BOOLEAN            | File size used for -u and -U mode                           |
    --  | oldFileMtime            | BOOLEAN            | File mtime used for -u and -U mode                          |
    --  | oldFileCtime            | BOOLEAN            | File ctime used for -u and -U mode                          |
    --  | printProgress           | INTEGER            | Amount of progress information printed at scan time         |
    --  | dirToScan               | STRING             | The directory given on command line to scan                 |
    --  | dirToScanPfx            | STRING             | The dirname of dirToScan                                    |
    --  | dirToScanNam            | STRING             | The basename of dirToScan                                   |
    --  |-------------------------+--------------------+-------------------------------------------------------------|
    --  | dumpStart:users         | POSIX Time Integer | Start time for user table dump                              |
    --  | dumpFinish:rusers       | POSIX Time Integer | End time for user table dump                                |
    --  | dumpStart:rgroups       | POSIX Time Integer | Start time for group table dump                             |
    --  | dumpFinish:rgroups      | POSIX Time Integer | End time for group table dump                               |
    --  | scanStart               | POSIX Time Integer | Start time for directory scan                               |
    --  | scanFinish              | POSIX Time Integer | End time for directory scan                                 |
    --  | dumpAndCsumStart:files  | POSIX Time Integer | Start time for file checksums and file data dump            |
    --  | dumpAndCsumFinish:files | POSIX Time Integer | End time for file checksums and file data dump              |
    --  | processStart            | POSIX Time Integer | Start time for process                                      |
    --  | processEnd              | POSIX Time Integer | End time for process                                        |
    --  |-------------------------+--------------------+-------------------------------------------------------------|
    CREATE TABLE meta (mkey   TEXT,
                       mvalue TEXT
                      );

    INSERT INTO meta VALUES ('BLKnFSOBJ',   'TRUE' );  --BLKnFSOBJ--
    INSERT INTO meta VALUES ('BLKnFSOBJ',   'FALSE');  --!BLKnFSOBJ--

    INSERT INTO meta VALUES ('DEVnFSOBJ',   'TRUE' );  --DEVnFSOBJ--
    INSERT INTO meta VALUES ('DEVnFSOBJ',   'FALSE');  --!DEVnFSOBJ--

    INSERT INTO meta VALUES ('EXTnFSOBJ',   'TRUE' );  --EXTnFSOBJ--
    INSERT INTO meta VALUES ('EXTnFSOBJ',   'FALSE');  --!EXTnFSOBJ--

    -- Data for each file system object found in the scan
    CREATE TABLE fsobj (id       INTEGER, -- unique ID in [0, count(*)-1].  Might not be preorder traversal index
                        pid      INTEGER, -- ID of parent or NILL for root object
                        lft      INTEGER, -- left hierarchy bower.                    
                        rgt      INTEGER, -- right hierarchy bower.                   
                        ddeep    INTEGER, -- depth in hierarchy.                      
                        userid   INTEGER, -- non-negative integer.  May be missing from rusers.userid!
                        groupid  INTEGER, -- non-negative integer.  May be missing from rgroups.groupid!
                        deviceid INTEGER, -- integer device number.                   --DEVnFSOBJ--
                        ftype    TEXT,    -- Single char for file type.  See: table ftype2lab
                        fmodes   INTEGER, -- non-negative UNIX mode number. May be platform specific
                        fname    TEXT,    -- file-name.  Hopefully UTF-8, but perhaps now.  No zeros or /.
                        fext     TEXT,    -- Normalized file extension                --EXTnFSOBJ--
                        bytes    INTEGER, -- non-negative integer
                        blocks   INTEGER, -- non-negative integer                     --BLKnFSOBJ--
                        blocksz  INTEGER, -- non-negative integer                     --BLKnFSOBJ--
                        atime    INTEGER, -- UNIX POSIX date integer
                        mtime    INTEGER, -- UNIX POSIX date integer
                        ctime    INTEGER, -- UNIX POSIX date integer
                        csum     TEXT     -- Hex encoded checksum, empty string, symlink target, or dir relpn
                       );

    -- Scan Error Log
    CREATE TABLE serrors (id       INTEGER, -- May be NULL if we don't know the object ID
                          emessage TEXT);   -- Text of the error message.

    -- View of rusers with UNIQUE userid
    CREATE VIEW users AS
      SELECT rusers.userid,
             rusers.uname,
             rusers.primgid,
             rusers.shell,
             rusers.gecos
        FROM rusers
        INNER JOIN (SELECT MAX(rowid) AS mrid,
                           userid
                      FROM rusers
                      GROUP BY userid) tmp1
          ON tmp1.mrid   = rusers.rowid   AND
             tmp1.userid = rusers.userid;

    -- View of rgroups with UNIQUE groupid
    CREATE VIEW groups AS
      SELECT rgroups.groupid,
             rgroups.gname
        FROM rgroups
        INNER JOIN (SELECT MAX(rowid) AS mrid,
                           groupid
                      FROM rgroups
                      GROUP BY groupid) tmp1
          ON tmp1.mrid    = rgroups.rowid    AND
             tmp1.groupid = rgroups.groupid;

    -- Handy view that makes some queries less difficult.  Replace with a real table
    -- if performance is an issue.  Note the path of the root of the scan (the one
    -- with id==pid, in this table will be fqpn)
    CREATE VIEW dirs AS
      SELECT id,
             lft,          
             rgt,          
             pid,
             ddeep,        
             csum AS relpn
        FROM fsobj
        WHERE ftype = 'd';

    -- Just like dirs, but with fqpn instead of relpn.  Note that this
    CREATE VIEW dirsfq AS
      SELECT id,
             lft,                                                              
             rgt,                                                              
             pid,
             ddeep,                                                            
             (SELECT mvalue FROM meta WHERE mkey='dirToScan') || csum AS fqpn
        FROM fsobj
        WHERE ftype = 'd';

    -- Handy "has it all table" that can be quite slow, but makes quick and dirty
    -- queries very easy.  The atime, mtime, & ctime are all timestamp objects.
    -- Joined in are the relpn, uname, and gname.
    CREATE VIEW annofsobj AS
      SELECT fsobj.id                                         AS id,
             fsobj.pid                                        AS pid,
             fsobj.lft                                        AS lft,      
             fsobj.rgt                                        AS rgt,      
             fsobj.ddeep                                      AS ddeep,    
             fsobj.userid                                     AS userid,
             fsobj.groupid                                    AS groupid,
             fsobj.deviceid                                   AS deviceid, --DEVnFSOBJ--
             fsobj.ftype                                      AS ftype,
             fsobj.fmodes                                     AS fmodes,
             fsobj.fname                                      AS fname,
             fsobj.fext                                       AS fext,     --EXTnFSOBJ--
             fsobj.bytes                                      AS bytes,
             fsobj.blocks                                     AS blocks,   --BLKnFSOBJ--
             fsobj.blocksz                                    AS blocksz,  --BLKnFSOBJ--
             fsobj.atime                                      AS atime,
             fsobj.mtime                                      AS mtime,
             fsobj.ctime                                      AS ctime,
             datetime(fsobj.atime, 'unixepoch', 'localtime')  AS atimed,
             datetime(fsobj.mtime, 'unixepoch', 'localtime')  AS mtimed,
             datetime(fsobj.ctime, 'unixepoch', 'localtime')  AS ctimed,
             fsobj.csum                                       AS csum,
             CASE
               WHEN fsobj.pid=fsobj.id THEN "/"
                                       ELSE dirs.relpn||'/'||fsobj.fname
             END                                              AS relpn,
            users.uname                                       AS uname,
            groups.gname                                      AS gname
        FROM fsobj
        JOIN dirs
          ON fsobj.pid=dirs.id
        LEFT JOIN users
          ON fsobj.userid=users.userid
        LEFT JOIN groups
          ON fsobj.groupid=groups.groupid;

    -- Just like annofsobj, but with fqpn instead of relpn (relative path name)
    CREATE VIEW annofsobjfq AS
      SELECT id, pid,
             lft, rgt, ddeep,                                                   
             userid, groupid,
             deviceid,                                                          --DEVnFSOBJ--
             ftype, fmodes, fname,
             fext,                                                              --EXTnFSOBJ--
             bytes,
             blocks, blocksz,                                                   --BLKnFSOBJ--
             atime, mtime, ctime, atimed,
             mtimed, ctimed, csum,
             (SELECT mvalue FROM meta WHERE mkey='dirToScan') ||                
               CASE WHEN relpn='/' THEN ''                                      
                                   ELSE relpn                                   
               END                                                     AS fqpn, 
             uname, gname
        FROM annofsobj;

    -- Add some handy values to the meta table
    CREATE VIEW annometa AS
      SELECT mkey, mvalue FROM meta
      UNION ALL
      SELECT 'dumpAndCsumTime'                                                     AS mkey,
             ((SELECT mvalue FROM meta WHERE mkey = 'dumpAndCsumFinish:files') -
               (SELECT mvalue FROM meta WHERE mkey = 'dumpAndCsumStart:files'))    AS mvalue
      UNION ALL
      SELECT 'scanTime'                                                            AS mkey,
             ((SELECT mvalue FROM meta WHERE mkey = 'scanFinish') -
              (SELECT mvalue FROM meta WHERE mkey = 'scanStart'))                  AS mvalue
      UNION ALL
      SELECT 'totalTime'                                                           AS mkey,
             ((SELECT mvalue FROM meta WHERE mkey = 'processEnd') -
              (SELECT mvalue FROM meta WHERE mkey = 'processStart'))               AS mvalue;

    -- Handy table for transforming single character ftype from fsobj into human readable strings for reports.
    CREATE TABLE ftype2lab (ftype    TEXT,
                            ftypehr  TEXT);
    INSERT INTO ftype2lab VALUES('r', 'Regular File');
    INSERT INTO ftype2lab VALUES('d', 'Directory');
    INSERT INTO ftype2lab VALUES('l', 'Symbolic Link');
    INSERT INTO ftype2lab VALUES('c', 'Bhar Special');
    INSERT INTO ftype2lab VALUES('b', 'Block Special');
    INSERT INTO ftype2lab VALUES('f', 'FIFO');
    INSERT INTO ftype2lab VALUES('s', 'Socket');
    INSERT INTO ftype2lab VALUES('u', 'Unknown Type');
SQL

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Process command line arguments
csumSym = { 'SHA1'  => :csum_sha1,
            'SHA25' => :csum_sha256,
            'MD5'   => :csum_md5,
            'NIL'   => :csum_nil,
            '1K'    => :csum_1k,
            'NAME'  => :csum_name }
doMitchExtXfrm = true
timeStart      = Time.now
outDBfile      = Time.now.strftime('%Y%m%d%H%M%S_dircsum.sqlite')
schemaOpt      = { 'BLKnFSOBJ' => false, 'DEVnFSOBJ' => false, 'EXTnFSOBJ' => true }
putBLKnFSOBJ   = true
putDEVnFSOBJ   = true
dumpSchema     = false
oldFileFile    = nil
dircsumMode    = false
oldFileCtime   = true
oldFileMtime   = true
oldFileSize    = true
$printProgress = 35
csumToUse      = :csum_sha256
opts = OptionParser.new do |opts|
  opts.banner = "Usage: dcsumNew.rb [options] <directory-to-traverse>                                                   "
  opts.separator "                                                                                                      "
  opts.separator "Scan the directory tree rooted at <directory-to-traverse>, and create an SQLite3 database             "
  opts.separator "containing various file meta data.                                                                    "
  opts.separator "                                                                                                      "
  opts.separator "  Help & Information Options:                                                                         "
  opts.on("-h",           "--help",           "Show this message")         { puts opts; exit                            }
  opts.on(                "--schema",         "Print DB schema")           { dumpSchema = true;                         }
  opts.separator "  Output Options:                                                                                     "
  opts.on("-p LEVEL",     "--progress LEVEL", "Verbosity bitmask")         { |v| $printProgress=v.to_i;                 }
  opts.separator "                                       Default: 35                                                    "
  opts.separator "                            +-----+--------------------------------------------+---------------+      "
  opts.separator "                            | bit | Description                                | Incompatible  |      "
  opts.separator "                            +-----+--------------------------------------------+---------------+      "
  opts.separator "                            |   0 | No progress messages                       |               |      "
  opts.separator "                            |   1 | Low resolution progress messages           |               |      "
  opts.separator "                            |     | Basic steps with time stamps               |               |      "
  opts.separator "                            |   2 | DB & CSUM write progress bar               | 8 16          |      "
  opts.separator "                            |   4 | High resolution Scan progress messages     | 32            |      "
  opts.separator "                            |   8 | High resolution CSUM progress              | 2 16          |      "
  opts.separator "                            |     | Print a code for why each csum was done    |               |      "
  opts.separator "                            |  16 | Super resolution CSUM progress             | 2 8           |      "
  opts.separator "                            |     | Print a record for each csum performed:    |               |      "
  opts.separator "                            |     | 1) Code for why csum performed, 2) regular |               |      "
  opts.separator "                            |     | file count, and 3) fq file name            |               |      "
  opts.separator "                            |  32 | Scan progress bar                          | 4             |      "
  opts.separator "                            +-----+--------------------------------------------+---------------+      "
  opts.separator "                                          +------+-------------------------+                          "
  opts.separator "                                          | Code | Checksum Reasons        |                          "
  opts.separator "                                          +------+-------------------------+                          "
  opts.separator "                                          | 0x10 | Size                    |                          "
  opts.separator "                                          | 0x08 | mtime                   |                          "
  opts.separator "                                          | 0x04 | ctime                   |                          "
  opts.separator "                                          | 0x02 | New file                |                          "
  opts.separator "                                          | 0x01 | New scan -- no old data |                          "
  opts.separator "                                          +------+-------------------------+                          "
  opts.on("-o OUT-DB",    "--output OUT-DB",  "output database File name") { |v| outDBfile=v;                           }
  opts.separator "                                       If -o is missing, then a name is constructed using the         "
  opts.separator "                                       date and the strftime template '%Y%m%d%H%M%S_dircsum.sqlite'.  "
  opts.separator "  Update Mode Options:                                                                                "
  opts.on("-u OLD-DB",    "--update OLD-DB",  "File name old database")    { |v| oldFileFile=v;                         }
  opts.separator "                                       Checksums in the input database named OLD-DB are used for      "
  opts.separator "                                       scanned files which appear unchanged.  By default 'unchanged'  "
  opts.separator "                                       means identical relative path names, sizes, and time stamps.   "
  opts.separator "                                       Size, ctime, & mtime may be ignored via -s, -c, & -m options.  "
  opts.on("-c Y/N",       "--ctime Y/N",      "Check ctime for -u option") { |v| oldFileCtime=v.match(/^[YyTt]/);       }
  opts.separator "                                        Default: #{oldFileCtime}                                      "
  opts.on("-m Y/N",       "--mtime Y/N",      "Check mtime for -u option") { |v| oldFileMtime=v.match(/^[YyTt]/);       }
  opts.separator "                                        Default: #{oldFileMtime}                                      "
  opts.on("-s Y/N",       "--size Y/N",       "Check size for -u option")  { |v| oldFileSize=v.match(/^[YyTt]/);        }
  opts.separator "                                        Default: #{oldFileSize}                                       "
  opts.on("-U",           "--dircsum",        "Set dircsum mode")          { dircsumMode = true;                        }
  opts.separator "                                       The idea is that one can keep a '.dircsum' directory           "
  opts.separator "                                       at the root of some directory tree, and keep a historical      "
  opts.separator "                                       sequence of checksum databases for the directory tree.         "
  opts.separator "                                       DB names are as described when the the -o option is missing.   "
  opts.separator "                                         - Sets -u to the latest file in the .dircsum/ sub-directory  "
  opts.separator "                                         - Sets -o to a new file in .dircsum/ sub-directory           "
  opts.separator "                                           May be overridden with an explicitly provided -o option    "
  opts.separator "                                         - Sets the directory to be scanned to the PWD.               "
  opts.separator "                                       If no directory-to-traverse is provided on the command line    "
  opts.separator "                                       and the .dircsum directory exists, then -U is assumed          "
  opts.separator "  Behavioral/Tuning Options:                                                                          "
  opts.on("-k CSUM",      "--csum CSUM",      "Checksum to use")           { |v| if (csumSym.member?(v.upcase)) then
                                                                                   csumToUse = csumSym.member?(v.upcase)
                                                                                 end                                    }
  opts.separator "                                       * sha256 .. SHA256 (default)                                   "
  opts.separator "                                       * sha1 .... SHA1                                               "
  opts.separator "                                       * md5 ..... MD5                                                "                                                              
  opts.separator "                                       * 1k ...... SHA256 of first 1KB of file                        "
  opts.separator "                                       * name .... File Name                                          "
  opts.separator "                                       * nil ..... No Checksum                                        "
  opts.separator "  DB Schema Options:                                                                                  "
  opts.on(                "--BLKnFSOBJ    Y/N",  "Store blocks & blocksz") { |v| schemaOpt['BLKnFSOBJ'] = 
                                                                             v.match(/^[YyTt]/);                        }
  opts.separator "                                        Default: #{schemaOpt['BLKnFSOBJ']}                            "
  opts.on(                "--DEVnFSOBJ    Y/N",  "Store device ID")        { |v| schemaOpt['DEVnFSOBJ'] = 
                                                                             v.match(/^[YyTt]/);                        }
  opts.separator "                                        Default: #{schemaOpt['DEVnFSOBJ']}                            "
  opts.on(                "--EXTnFSOBJ    Y/N",  "Store file extension")   { |v| schemaOpt['EXTnFSOBJ'] = 
                                                                             v.match(/^[YyTt]/);                        }
  opts.separator "                                        Default: #{schemaOpt['EXTnFSOBJ']}                            "
  opts.separator "                                                                                                      "
  opts.separator "                                                                                                      "
end
opts.parse!(ARGV)
dirToScan = nil
if ( !(ARGV[0].nil?)) then
  dirToScan = ARGV[0].dup;
end

if ( !(dircsumMode) && !(dirToScan) ) then
  if (FileTest.exist?('.dircsum')) then
    dircsumMode = true;
    #puts("WARNING: No directory provided, but .dircsum found -- running in -U mode")
  else
    puts("ERROR: No directory provided, and .dircsum missing.  Run with -U to force dircsum mode!")
    exit
  end
end

# Adjust the schema by removing lines based on schemaOpt
schemaOpt.each do |optName, optOn|
  dbSetupCode.gsub!(Regexp.new("^[^\n]+\s--" + ( optOn ? '!' : '') + optName + "--$"), "\n")
end

# If --schema was on the command line, then dump scheme and exit.  Had to wait till now to do this because the schema wasn't known till now.
if(dumpSchema) then
  puts dbSetupCode
  exit
end

# Set lots of stuff based on -U
if(dircsumMode) then
  if(dirToScan) then
    puts("ERROR: Can not provide a directory in dircsum mode!")
    exit
  end
  dirToScan = Dir.pwd
  outDBfile = '.dircsum/' + outDBfile
  if(FileTest.exist?('.dircsum')) then
    oldFileFile = Dir.glob('.dircsum/??????????????_dircsum.sqlite').sort.last
    if(oldFileFile && oldFileFile.length < 20) then
      oldFileFile = nil
    end
  else
    Dir.mkdir('.dircsum')
    if( !(FileTest.exist?('.dircsum'))) then
      puts("ERROR: Could not create '.dircsum'")
      exit
    end
  end
end

# Get real path string
dirToScanPfxLength = nil
dirToScanLength    = nil
dirToScanPfx       = nil
dirToScanNam       = nil
dirToScan.force_encoding(Encoding::BINARY)
if(dirToScan) then
  dirToScan          = File.realdirpath(dirToScan)
  dirToScanLength    = dirToScan.length
  dirToScanPfx       = File.dirname(dirToScan)
  dirToScanNam       = File.basename(dirToScan)
  dirToScanPfxLength = dirToScanPfx.length
else
  puts("ERROR: No directory to be processed was provided, and could not guess default!")
  exit(1)
end

if(ARGV.length > 1) then
  puts("ERROR: Only one directory may be processed at a time")
  exit(1)
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Compute a checksum
def fcs (fileName, csum)
  if(fileName.match(/^\/dev\//)) then
    'SKIP'
  else
    case csum
    when :csum_sha1   then Digest::SHA1.file(fileName).to_s
    when :csum_sha256 then Digest::SHA256.file(fileName).to_s
    when :csum_nil    then ''
    when :csum_md5    then Digest::MD5.file(fileName).to_s
    when :csum_name   then File.basename(fileName)
    when :csum_1k     then open(fileName, 'r:binary') { |file| Digest::SHA256.hexdigest(file.read(1024)) }
    end
  end
end

$scannedObjectCount = 0
#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Object to hold a filesystem object
class FileSystemObject
  @@fsoidx = -1
  def initialize(path, name)
    @id        = (@@fsoidx += 1)
    @name      = name
    @contents  = Array.new
    fqpn       = File.join(path, name)
    begin
      @statData  = File.lstat(fqpn)
    rescue
      STDERR.puts("\nERROR: Could not stat #{name} in directory #{path}")
    end
    # Warn about non-ascii filenames
    # if( !(name.ascii_only?)) then
    #   STDERR.puts("\nWARNING: Filename is non-ascii: #{fqpn}")
    # end
    # Print status
    if (($printProgress & 0x0020) != 0) then
      @id+=1
      if ((@id % 15) == 0) then
        if(@statData.directory?) then
          print("/")
        else
          print("|")
        end
      end
      if ((@id % 1500) == 0) then
        printf(" %015d\n", @id)
      end
    end
    # Add children
    if(@statData.directory?) then
      (($printProgress & 0x0004) != 0) && puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : PATH: #{path} DIR: #{name}")
      begin
        Dir.each_child(fqpn, encoding: Encoding::UTF_8) do |dirEntryName|
          if( !(['.', '..'].member?(dirEntryName))) then
            @contents.push(FileSystemObject.new(fqpn, dirEntryName))
          end
        end
      rescue
        STDERR.puts("\nERROR: Directory Read Failure: #{fqpn}")
        @contents = nil
      end
    end
  end
  attr_reader :path, :name, :statData, :contents, :id
  def fileTypeC
    if(@statData.file?)          then  return('r')
    elsif(@statData.directory?)  then  return('d')
    elsif(@statData.symlink?)    then  return('l')
    elsif(@statData.chardev?)    then  return('c')
    elsif(@statData.blockdev?)   then  return('b')
    elsif(@statData.pipe?)       then  return('f')
    elsif(@statData.socket?)     then  return('s')
    else                               return('?')
    end
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Hold some meta data about a scan, and traverse the tree
class ScanObject
  def initialize(path)
    @fsoid = 0
    @path = path
    @fsd  = FileSystemObject.new(*File.split(File.realdirpath(path)))
  end
  attr_reader :path
  def dump(dbStatement)
    @fsd.dump(dbStatement, File.dirname(@path), 0, 1)
  end
  def each(&aBlock)
    @fsoid = -1
    def gogo(fsobj, dir, pid, depth, &aBlock)
      @fsoid += 1
      leftDirSpan = @fsoid
      id   = fsobj.id
      fqpn = File.join(dir, fsobj.name)
      goodScan = true
      if(fsobj.contents.nil?) then
        goodScan = false
      else
        fsobj.contents.each { |e| gogo(e, fqpn, id, depth+1, &aBlock) }
      end
      @fsoid += 1
      #            fqpn   depth  pid  left         right   fsobj  goodScan
      aBlock.call([ fqpn, depth, pid, leftDirSpan, @fsoid, fsobj, goodScan ])
    end
    gogo(@fsd, File.dirname(@path), 0, 0, &aBlock)
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Read in old data
oldData = Hash.new
if(oldFileFile) then
  SQLite3::Database.new(oldFileFile) do |inDBcon|
    inDBcon.execute("SELECT relpn, bytes, mtime, ctime, csum FROM annofsobj WHERE ftype = 'r';").each do |row|
      oldData[row[0]] = row.values_at(1, 2, 3, 4)
    end
  end
end

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Do the real work
uname2uid  = Hash.new
gid2pmemb  = Hash.new(Array.new)
fileExtRe1 = Regexp.new('^[^.]+\.([^.]+\.(' + ['bdes3', 'gpg', 'GZ', 'BZ', 'BZ2', 'Z', 'ZIP', 'XZ', 'LZMA', '7Z', 'LZO', 'LZ'].join('|') + '))$', Regexp::IGNORECASE)
fileExtRe2 = Regexp.new('^[^.]+\.([^.]+)$')
SQLite3::Database.new(outDBfile) do |dbCon|
  dbCon.execute("PRAGMA synchronous=OFF")
  dbCon.execute("PRAGMA journal_mode=OFF")
  dbCon.execute_batch(dbSetupCode)
  dbCon.prepare( "insert into serrors values (?, ?);" ) do |dbStmtSErrors|
    dbCon.execute( "insert into meta values (?, ?);", 'processStart',            Time.now.to_i)
    dbCon.execute( "insert into meta values (?, ?);", 'csum',                    csumToUse.to_s)
    dbCon.execute( "insert into meta values (?, ?);", 'engine version',          '2020-02-05')
    dbCon.execute( "insert into meta values (?, ?);", 'engine',                  'ruby')
    dbCon.execute( "insert into meta values (?, ?);", 'dirToScan',               dirToScan)
    dbCon.execute( "insert into meta values (?, ?);", 'dirToScanPfx',            dirToScanPfx)
    dbCon.execute( "insert into meta values (?, ?);", 'dirToScanNam',            dirToScanNam)
    dbCon.execute( "insert into meta values (?, ?);", 'dircsumMode',             (dircsumMode ? "TRUE" : "FALSE"))
    dbCon.execute( "insert into meta values (?, ?);", 'printProgress',           $printProgress)
    dbCon.execute( "insert into meta values (?, ?);", 'outDBfile',               outDBfile)
    dbCon.execute( "insert into meta values (?, ?);", 'oldFileFile',             oldFileFile)
    dbCon.execute( "insert into meta values (?, ?);", 'oldFileSize',             (oldFileSize  ? "TRUE" : "FALSE"))
    dbCon.execute( "insert into meta values (?, ?);", 'oldFileMtime',            (oldFileMtime ? "TRUE" : "FALSE"))
    dbCon.execute( "insert into meta values (?, ?);", 'oldFileCtime',            (oldFileCtime ? "TRUE" : "FALSE"))
    (($printProgress & 0x0001) != 0) && puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Starting scan: #{dirToScan}")
    (($printProgress & 0x0001) != 0) && puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Collecting scan meta data")
    dbCon.execute( "insert into meta values (?, ?);", 'dumpStart:users', Time.now.to_i)
    dbCon.prepare( "insert into rusers values (?, ?, ?, ?, ?);" ) do |dbStmtRUsers|
      Etc.passwd do |p|
        dbStmtRUsers.execute(p.uid, p.name, p.gid, p.shell, p.gecos)
        uname2uid[p.name] = p.uid
        if( !(gid2pmemb.member?(p.gid))) then
          gid2pmemb[p.gid] = Array.new
        end
        gid2pmemb[p.gid].push(p.uid)
      end
      dbCon.execute( "insert into meta values (?, ?);", 'dumpFinish:rusers', Time.now.to_i)
      # Populate db rgroups db tables
      dbCon.execute( "insert into meta values (?, ?);", 'dumpStart:rgroups', Time.now.to_i)
      dbCon.prepare( "insert into rgroups values (?, ?);" ) do |dbStmtRGroups|
        dbCon.prepare( "insert into groupmembers values (?, ?);" ) do |dbStmtGroupmembers|
          Etc.group do |g|
            dbStmtRGroups.execute(g.gid, g.name)
            memberUIDs = gid2pmemb[g.gid] +
                         g.mem.map { |u| (uname2uid.member?(u) ? uname2uid[u] : nil) }
            memberUIDs.delete(nil)
            memberUIDs.uniq.each do |u|
              dbStmtGroupmembers.execute(g.gid, u)
            end
          end
        end
      end
    end
    dbCon.execute( "insert into meta values (?, ?);", 'dumpFinish:rgroups', Time.now.to_i)

    (($printProgress & 0x0001) != 0) && puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Scan Starting")
    dbCon.execute( "insert into meta values (?, ?);", 'scanStart', Time.now.to_i)
    scanData = ScanObject.new(dirToScan)
    dbCon.execute( "insert into meta values (?, ?);", 'scanFinish', Time.now.to_i)
    (($printProgress & 0x0020) != 0) && puts("")
    (($printProgress & 0x0001) != 0) && puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : CSUM & DB Write Starting")
    dbCon.execute( "insert into meta values (?, ?);", 'dumpAndCsumStart:files', Time.now.to_i)

    objCnt = cntRegFile = cntDirectories = cntSymLinks = cntFunnyFiles = checksumAvoided = cntCsumByte = cntCsumByte1KC = cntCsumFiles = csumCntLastPrt = 0
    dbCon.transaction
    dbCon.prepare('insert into fsobj values (' +
                  ('?, '*(14 +
                          ( schemaOpt['DEVnFSOBJ'] ? 1 : 0 ) +
                          ( schemaOpt['BLKnFSOBJ'] ? 2 : 0 ) +
                          ( schemaOpt['EXTnFSOBJ'] ? 1 : 0 ))) +
                  '?);' ) do |dbStmtFSObj|
      scanData.each do |fqpn, depth, pid, left, right, fsobj, goodScan|
        if( !(goodScan)) then
          dbStmtSErrors.execute(fsobj.id, "Failed to scan directory")
        end
        relpn = fqpn.slice(dirToScanLength..-1)
        fileTypeC = fsobj.fileTypeC
        csum = nil
        whyNeedCsum = 0
        begin
          if(fileTypeC == 'r') then
            if(oldFileFile) then
              if(oldData.member?(relpn)) then
                bytes, mtime, ctime, csum = oldData[relpn] # Note: csum is from outer scope.
                if (oldFileSize && (bytes != fsobj.statData.size)) then
                  whyNeedCsum += 0x10;
                elsif (oldFileMtime && (mtime != fsobj.statData.mtime.tv_sec)) then
                  whyNeedCsum += 0x08;
                elsif (oldFileCtime && (ctime != fsobj.statData.ctime.tv_sec)) then
                  whyNeedCsum += 0x04;
                end
              else
                whyNeedCsum += 0x02
              end
            else
              whyNeedCsum += 0x01
            end
            cntRegFile += 1;
            (($printProgress & 0x0008) != 0) && printf("%02x.", whyNeedCsum)
            (($printProgress & 0x0008) != 0) && (cntRegFile % 100 == 0) && puts("")
            if(whyNeedCsum == 0) then
              checksumAvoided += 1
            else
              csumCntLastPrt += 1
              cntCsumFiles   += 1
              cntCsumByte    += fsobj.statData.size;
              cntCsumByte1KC += [1024, fsobj.statData.size].min;
              (($printProgress & 0x0010) != 0) && printf("%05b: %15d: %s\n", whyNeedCsum, cntRegFile, fqpn)
              csum = fcs(fqpn, csumToUse)
            end
          elsif (fileTypeC == 'd') then
            cntDirectories+=1
            csum = relpn
          elsif (fileTypeC == 'l') then
            cntSymLinks+=1;
            csum = File.readlink(fqpn)
          else
            cntFunnyFiles+=1;
            csum = ''
          end
        rescue
          csum = 'ERROR'
          dbStmtSErrors.execute(fsobj.id, "Failed to compute checksum")
        end

        fileExt = '';
        if((schemaOpt['EXTnFSOBJ']) && ( (ematch=fsobj.name.match(fileExtRe1)) || (ematch=fsobj.name.match(fileExtRe2)) )) then
          fileExt = ematch[1]
          if(doMitchExtXfrm) then
            fileExt.sub!(/--SS-.*$/, '') # Zap funny extension used by
          end
          fileExt.upcase!
        end
        dbStmtFSObj.execute(*([ fsobj.id, pid, left, right, depth ] +
                              [fsobj.statData.uid, fsobj.statData.gid ] +
                              ( schemaOpt['DEVnFSOBJ'] ? [ fsobj.statData.dev ] : [ ] ) +
                              [ fileTypeC, fsobj.statData.mode, fsobj.name ] +
                              ( schemaOpt['EXTnFSOBJ'] ? [ fileExt ] : [ ] ) +
                              [ fsobj.statData.size ] +
                              ( schemaOpt['BLKnFSOBJ'] ? [ fsobj.statData.blocks, fsobj.statData.blksize ] : [ ] ) +
                              [ fsobj.statData.atime.tv_sec, fsobj.statData.mtime.tv_sec, fsobj.statData.ctime.tv_sec, csum ]))
        objCnt += 1
        if (($printProgress & 0x0002) != 0) then
          if ((objCnt % 15) == 0) then
            if(csumCntLastPrt>0) then
              printf("%1x", csumCntLastPrt)
            else
              print(".")
            end
            csumCntLastPrt=0
          end
          if ((objCnt % 1500) == 0) then
            if(oldFileFile) then
              printf(" %015d %015d\n", objCnt, cntCsumFiles)
            else
              printf(" %015d\n", objCnt)
            end
          end
        end
      end
    end
    dbCon.commit
    dbCon.execute( "insert into meta values (?, ?);", 'dumpAndCsumFinish:files', Time.now.to_i)
    (($printProgress & 0x0002) != 0) && puts("")
    (($printProgress & 0x0008) != 0) && puts("")
    (($printProgress & 0x0001) != 0) && puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Processing Complete")

    dbCon.execute( "insert into meta values (?, ?);", 'cntCsumFiles',    cntCsumFiles)
    dbCon.execute( "insert into meta values (?, ?);", 'cntCsumByte',     cntCsumByte)
    dbCon.execute( "insert into meta values (?, ?);", 'cntCsumByte1KC',  cntCsumByte1KC)
    dbCon.execute( "insert into meta values (?, ?);", 'objCnt',          objCnt)
    dbCon.execute( "insert into meta values (?, ?);", 'cntRegFile',      cntRegFile)
    dbCon.execute( "insert into meta values (?, ?);", 'cntDirectories',  cntDirectories)
    dbCon.execute( "insert into meta values (?, ?);", 'cntSymLinks',     cntSymLinks)
    dbCon.execute( "insert into meta values (?, ?);", 'cntFunnyFiles',   cntFunnyFiles)
    dbCon.execute( "insert into meta values (?, ?);", 'checksumAvoided', checksumAvoided)
    dbCon.execute( "insert into meta values (?, ?);", 'processEnd',      Time.now.to_i)
  end
end
