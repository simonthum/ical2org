# ical2org.rb

An iCalendar to org-mode converter in pure ruby

Converts iCalendar (rfc2445) to org-mode files using the
tremendous RiCal gem.

2012 by Simon Thum (released under CC BY 3.0)

## Features

* Filtering input based on date or todo state (more is easy to add)
* Proper handling of (most) repeating dates
* Handles vTODOs, not just events
* can be adapted to your setup by you ;)

This is intended for ruby-savy people; until it grows command-line
options that is the conditio sine qua non.

## Install

Requires

* ruby (tested with standard ruby 1.8.7, 1.9.2)
* the rical and tzinfo gems

Just invoke using `ruby` or do `chmod u+x ical2org.rb`.

## Useage

Pack ical2org into a script containing roughly

    ical2org.rb <input.ics | cat my.orgheader - >my_calendar.org

Yes, this prepends a header which is suggested to at least declare the PROPERTIES
and ICALENDAR drawers - or, just remove the latter from the built-in org templates.
In that case, you do not need a header at all.

I recommend setting the resulting files read-only to avoid unwanted changes. This
script is not fit for round-trip org<->ical synchronization.

## Advanced syncing

The headers I prepend to my synced stuff look approximately like: 


    #+TITLE: Department dates
    #+DRAWERS: PROPERTIES ICALENDAR
    #+FILETAGS: :@work:imported:
    #+LINK: edit https://webstuff.company.com/groupCal/%s.ics/edit


The title is pretty straightforward. Next, I declare the two drawers
so I don't see iCalendar text unless I want to - you can also simply
cancel the output by removing the ERb tag.

Next, I declare the tags I use for agenda filtering - including
"imported" in case I want to get rid of anything not natively org.

The `#LINK:` part is the cool stuff. It declares an "edit" link type
which points to my stuff in our groupware and has a `%s` where the
iCal UID is placed. Guess what - my template has a line that (roughly)
says


    [[edit:<%= ev.uid %>][edit this in the webby webs]]


Neat, huh? No syncing issues - just edit the origin source. Of course
this requires a REST-savy web interface, so I've commented out that
part in the templates.

### Notes

This script is intended to be modified to suit your purposes.
If you add something of value to others, please consider
contributing.

It should be easier to adapt than the comparable awk-based solution,
but certainly it is far from perfect.

## License

I declare this work to be useable under the provisions of the CC BY 3.0 license.

http://creativecommons.org/licenses/by/3.0/

## Thanks

Thanks go to the org-mode community for providig such a fine product, and to my
employer, Fraunhofer IGD, for supporting the publication of this script.
