DVB Query
=========

``dvb`` is a command-line interface to dvb.de (Dresdner Verkehrsbetriebe).
The webpage is passably usable, sure, but repeated queries for a handful of
routes become tedious very quickly.

Searching for 'dvb'-commands in the Shell history is *much* more friendly.

Supports specification of abbreviations and complex route planning.

User-installation with::

  perl Makefile.PL PREFIX=$HOME/local
  make install

For system-wide installation and tests, see INSTALL.


Technical
----------------------------------------------------------------------

 + Testing: see INSTALL file
 + NEWS: See 'Timeline' below and tag messages (git tag -n)
 + TODO: See source code (grep TODO dvb).


Motivation & Timeline
----------------------------------------------------------------------

2009-12-13, Started.  Motivation: Providing fast access to the DVB
timetable information by scraping the website.

2010-01-22, Downloaded one of the DVB widgets (see reference/
directory).  There's a special server which handles these requests
without my having to parse tons of XML hell.  The .gadget files inside
the officially downloadable zip are in turn just zip archives.

2010-01-27, http://www.perl.com/pub/a/2002/08/20/perlandlwp.html?page=5

2011-03-28, Over one year?  Cleaned up (now with Makefile™) and added
embarrassing abbreviations facility.

2015-09-28, Updated the 'abbreviations facility' sans the embarrassing part:
Fixed UTF-8 (why is this still non-trivial?).

