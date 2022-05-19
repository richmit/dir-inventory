#!/usr/bin/env -S ruby -W0 -E utf-8
# -*- Mode:Ruby; Coding:us-ascii-unix; fill-column:158 -*-
################################################################################################################################################################
##
# @file      dcsumCmpDB.rb
# @author    Mitch Richling <https://www.mitchr.me>
# @brief     Compare two filesystem directory tree inventory databases.@EOL
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
################################################################################################################################################################

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
Encoding.default_external="utf-8";

#---------------------------------------------------------------------------------------------------------------------------------------------------------------

require 'optparse'
require 'optparse/time'
require 'sqlite3'

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
doTextReport  = true
dbd           = nil
difDBhasFS    = false
verbose       = false
difDBhasXidx  = false
opts = OptionParser.new do |opts|
  opts.banner = "Usage: dcsumCmpDB.rb [options] scanDB1 scanDB2                                        "
  opts.separator "                                                                                     "
  opts.separator "Options:                                                                             "
  opts.on("-h",        "--help",          "Show this message")                  { puts opts; exit      }
  opts.on("-v",        "--verbose",       "Print verbose data to STDERR")       { verbose = true       }
  opts.on("-q",        "--noTextDiff",    "Suppress report on STDOUT")          { doTextReport = false }
  opts.on("-o OUT-DB", "--output OUT-DB", "Output a difference report as a DB") { |v| dbd=v            }
  opts.on(             "--fsobjInDiffDB", "Include object data in report DB")   { difDBhasFS = true    }
  opts.on(             "--indexInDiffDB", "Include more indexes in report DB")  { difDBhasXidx = true  }
  opts.separator "                                                                                     "
  opts.separator "Read two scan databases, and produce a file difference report.                       "
  opts.separator "                                                                                     "
end
opts.parse!(ARGV)
db1 = ARGV[0]
db2 = ARGV[1]

if(db1.nil? && db2.nil? && FileTest.directory?('.dircsum')) then
  dbFiles = Dir.glob('.dircsum/??????????????_dircsum.sqlite')
  if(dbFiles.length >= 2) then
    db1 = dbFiles[-2]
    db2 = dbFiles[-1]
  end
end

if(!(doTextReport) && dbd.nil?) then
  STDERR.puts("ERROR: The --noTextDiff (-q) option combined with no --output (-o) option results in no action.")
  exit
end
if(db1.nil? || db2.nil?) then
  STDERR.puts("ERROR: Two databases are required as final arguments")
  exit
end
if((difDBhasFS || difDBhasXidx) && dbd.nil?) then
  STDERR.puts("ERROR: The --output option is required with the --fsobjInDiffDB and/or --indexInDiffDB option")
  exit
end
if(!(dbd.nil?) && FileTest.exist?(dbd)) then
  File.delete(dbd)
end

# Should only compare relative path names
# select substr(fqpn, (select length(mvalue)+1 from meta where mkey='dirToScan')) from annofsobj

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
sqlDiffRep = <<SQL
CREATE TABLE diffrep AS
SELECT '='                                                        AS side,
       CASE WHEN d1_annofsobj.ftype = d2_annofsobj.ftype THEN '='
            ELSE                                              '!'
       END                                                        AS dftype,
       CASE WHEN d1_annofsobj.ftype = 'd' AND
                 d2_annofsobj.ftype = 'd'                THEN '='
            WHEN d1_annofsobj.csum = d2_annofsobj.csum   THEN '='
            ELSE                                              '!'
       END                                                        AS dcsum,
       CASE WHEN d1_annofsobj.bytes < d2_annofsobj.bytes THEN '<'
            WHEN d1_annofsobj.bytes > d2_annofsobj.bytes THEN '>'
            ELSE                                              '='
       END                                                        AS dbytes,
       CASE WHEN abs(d1_annofsobj.bytes - d2_annofsobj.bytes) >= 1099511627777 THEN '+'
            WHEN abs(d1_annofsobj.bytes - d2_annofsobj.bytes) >= 1099511627776 THEN 'T'
            WHEN abs(d1_annofsobj.bytes - d2_annofsobj.bytes) >= 1073741824    THEN 'G'
            WHEN abs(d1_annofsobj.bytes - d2_annofsobj.bytes) >= 1048576       THEN 'M'
            WHEN abs(d1_annofsobj.bytes - d2_annofsobj.bytes) >= 1024          THEN 'K'
            WHEN abs(d1_annofsobj.bytes - d2_annofsobj.bytes) >  0             THEN 'B'
            ELSE                                                                    '='
       END                                                        AS sbytes,
       CASE WHEN d1_annofsobj.ctime < d2_annofsobj.ctime THEN '<'
            WHEN d1_annofsobj.ctime > d2_annofsobj.ctime THEN '>'
            ELSE                                              '='
       END                                                        AS dctime,
       CASE WHEN d1_annofsobj.mtime < d2_annofsobj.mtime THEN '<'
            WHEN d1_annofsobj.mtime > d2_annofsobj.mtime THEN '>'
            ELSE                                              '='
       END                                                        AS dmtime,
       d1_annofsobj.id                                            AS id1,
       d2_annofsobj.id                                            AS id2,
       d1_annofsobj.relpn
  FROM d1_annofsobj
  INNER JOIN d2_annofsobj
      ON d1_annofsobj.fname =  d2_annofsobj.fname AND
         d1_annofsobj.relpn =  d2_annofsobj.relpn
  WHERE dftype =  '!' OR
        dcsum  =  '!' OR
        dctime != '=' OR
        dmtime != '=' OR
        dbytes != '='
UNION ALL
SELECT '>'                 AS side,
       '.'                 AS dftype,
       '.'                 AS dcsum,
       '.'                 AS dbytes,
       '.'                 AS sbytes,
       '.'                 AS dctime,
       '.'                 AS dmtime,
       NULL                AS id1,
       d2_annofsobj.id     AS id2,
       d2_annofsobj.relpn  AS relpn
  FROM d2_annofsobj
  WHERE NOT d2_annofsobj.relpn IN (SELECT d1_annofsobj.relpn
                                     FROM d1_annofsobj)
UNION ALL
SELECT '<'                AS side,
       '.'                AS dftype,
       '.'                AS dcsum,
       '.'                AS dbytes,
       '.'                AS sbytes,
       '.'                AS dctime,
       '.'                AS dmtime,
       d1_annofsobj.id    AS id1,
       NULL               AS id2,
       d1_annofsobj.relpn AS relpn
  FROM d1_annofsobj
  WHERE NOT d1_annofsobj.relpn IN (SELECT d2_annofsobj.relpn
                                    FROM d2_annofsobj)
  ORDER BY side, dftype, dbytes, dcsum, dctime, dmtime, sbytes
;
SQL

SQLite3::Database.new(':memory:') do |dbCon|
  verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Start")
  dbCon.execute('PRAGMA synchronous=OFF')
  dbCon.execute('PRAGMA journal_mode=OFF')
  dbCon.execute('attach database "' + db1 + '" as d1;')
  dbCon.execute('attach database "' + db2 + '" as d2;')
  verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Materializing Left annofsobj")
  dbCon.execute('CREATE TABLE d1_annofsobj AS SELECT * FROM d1.annofsobj;')
  verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Indexing Left relpn annofsobj")
  dbCon.execute('CREATE UNIQUE INDEX d1_annofsobj_relpn ON d1_annofsobj (relpn);')
  if(difDBhasXidx) then
    verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Indexing Left id annofsobj")
    dbCon.execute('CREATE UNIQUE INDEX d1_annofsobj_id ON d1_annofsobj (id);')
    verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Indexing Left lft annofsobj")
    dbCon.execute('CREATE UNIQUE INDEX d1_annofsobj_lft ON d1_annofsobj (lft);')
    verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Indexing Left rgt annofsobj")
    dbCon.execute('CREATE UNIQUE INDEX d1_annofsobj_rgt ON d1_annofsobj (rgt);')
    verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Indexing Left csum annofsobj")
    dbCon.execute('CREATE  INDEX d1_annofsobj_csum ON d1_annofsobj (csum);')
  end
  verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Materializing Right annofsobj")
  dbCon.execute('CREATE TABLE d2_annofsobj AS SELECT * FROM d2.annofsobj;')
  verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Indexing Right relpn annofsobj")
  dbCon.execute('CREATE UNIQUE INDEX d2_annofsobj_relpn ON d2_annofsobj (relpn);')
  if(difDBhasXidx) then
    verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Indexing Right id annofsobj")
    dbCon.execute('CREATE UNIQUE INDEX d2_annofsobj_id ON d2_annofsobj (id);')
    verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Indexing Right lft annofsobj")
    dbCon.execute('CREATE UNIQUE INDEX d2_annofsobj_lft ON d2_annofsobj (lft);')
    verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Indexing Right rgt annofsobj")
    dbCon.execute('CREATE UNIQUE INDEX d2_annofsobj_rgt ON d2_annofsobj (rgt);')
    verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Indexing Right csum annofsobj")
    dbCon.execute('CREATE  INDEX d2_annofsobj_csum ON d2_annofsobj (csum);')
  end
  verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Diff Report")
  dbCon.execute(sqlDiffRep)
  if(doTextReport) then
    verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Report Print")
    dbCon.prepare("SELECT side, dftype, dcsum, dbytes, sbytes, dctime, dmtime, relpn from diffrep;") do |dbStmtRep|
      #STDOUT.puts(dbStmtRep.columns.join(' '))
      STDOUT.puts("#")
      STDOUT.puts("# Difference report")
      STDOUT.puts("#  Left  DB: #{db1}")
      STDOUT.puts("#  Right DB: #{db2}")
      STDOUT.puts("#")
      STDOUT.puts("# E Object Exists on Left (<), Right (>), or Both (=)")
      STDOUT.puts("# T Object types are the same (=) or different (!)")
      STDOUT.puts("# S Object checksums are the same (=) or Different (!)")
      STDOUT.puts("# B File size (B=bytes).  Bigger on left (>), Bigger on right (<), or equal (=)")
      STDOUT.puts("# B Scale of file size difference")
      STDOUT.puts("# C The c-time is older on left (<), newer on left (>), or equal (=)")
      STDOUT.puts("# M The m-time is older on left (<), newer on left (>), or equal (=)")
      STDOUT.puts("# N File name")
      STDOUT.puts("#")
      STDOUT.puts("E T S B B C M N")
      dbStmtRep.execute.each do |row|
        STDOUT.puts(row.join(' '))
      end
    end
  end
  if(dbd) then
    if(difDBhasFS) then
      verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Write Report DB with fsobj data")
      SQLite3::Database.new(dbd) do |dbConOut|
        dbBack = SQLite3::Backup.new(dbConOut, 'main', dbCon, 'main')
        dbBack.step(-1)
        dbBack.finish
      end
    else
      verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Write Report DB")
      dbCon.execute('attach database "' + dbd + '" as dd;')
      dbCon.execute('CREATE TABLE dd.diffrep AS SELECT * FROM diffrep;')
    end
  end
  verbose && STDERR.puts("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} : Done")
end
