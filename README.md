# ical2org.rb

An iCalendar to org-mode converter

Converts iCalendar (rfc2445) to org-mode files using the
tremendous RiCal gem.

2012 by Simon Thum (released under CC BY 3.0)

## Install

Requires

* ruby (tested with 1.8.7)
* the rical and tzinfo gems

## Useage

Pack ical2org into a script containing roughly

    `ical2org.rb <input.ics | cat my.orgheader - >my_calendar.org`

Yes, this prepends a header which is suggested to at least declare the PROPERTIES
and ICALENDAR drawers - or, just remove the latter from the built-in org templates.

I recommend setting the resulting files read-only to avoid unwanted changes. This
script is not fit for round-trip org<->ical synchronization.

## Notes

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
