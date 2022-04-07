

# Directory Inventory Tools

Documentation (rendered `org-mode` files) may be found in the
`docs` directory [here](https://richmit.github.io/dir-inventory/index.html). 

These tools provide a way to collect file-system metadata, store that
metadata into an SQL database, and then conveniently query that data
or compare databases.  I use these tools primarily to

 - Track file-system changes over time ::
   Mostly to help me plan for future disk purchases and size my 
   backup needs over time.
 - Drive my "/dynamic/" backup scripts ::
   This system makes snapshots of what's changing in my working trees
    just in case I fat finger something beyond =git='s ability to recover
 - Drive my cloud sync scripts :: 
   I sync encrypted files to the cloud using the content hash as the 
   filename.  This is a nice way to back up stuff to the cloud without 
   depending on the security or privacy of the cloud provider's encryption.
 - Verify the integrity of my "/static/" backups ::
   Just to make sure my weekly & monthly full backups really are 
   good -- without testing them via a full restore.

Probably the most common application people write to me about is file
server usage pattern analysis.  Questions like:

 - How much space is used by =MPG= files?
 - If we enabled =dedup=, how much space would we save?
 - How much space would we save if we switched from =TIFF= to =PNG= 
   as our standard image format?
 - I need to know my data churn rate so I can compute my 
   snapshot storage requirements.
 - How much space can we save if we move stuff not modified 
   in 6 months to cold storage?
 - How much data is owned by people no longer employed at my company?

The main data collection script is =dcsumNew.rb=.  It scans a directory
hierarchy and stores file-system metadata in an SQLite database.  For
many end users this DB and the data it provides is the ultimate end
goal for using this code.  For me the more useful application is found
in the =dcsumCmpDB.rb= and =cmpCSUM.rb= scripts.  These compare two
metadata databases.  When combined with the "=.dircsum=" mode of
=dcsumNew.rb= this provides a powerful way to track file-system changes
over time.

Check out my home page for more stuff: https://www.mitchr.me/

Have fun!

-mitch
