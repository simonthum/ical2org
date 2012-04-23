#!/usr/bin/env ruby
#
# Converts iCalendar (rfc2445) to org-mode files using the
# tremendous RiCal gem.
#
# 2012 by Simon Thum
# Thanks to Fraunhofer IGD for supporting the publication of this script.
#
# Note: This script is intended to be modified to suit your purposes.
#       If you add something of value to others, please consider
#       contributing.
#
# TODO: update sequence handling, configurable templates, general
#       commandline option parsing, check for emacs/unix date limits,
#       nicer (non-Erb) templates, ...
#
#
# Requires rical and tzinfo gems

require 'rubygems'
gem 'ri_cal'
gem 'tzinfo'
require 'erb'
require 'ri_cal'

# e.g. output will be suppressed if default is specified
DEFAULT_TZ = 'Europe/Berlin'

# see the RiCal docs if Timezones don't work out for you
::RiCal::PropertyValue::DateTime::default_tzid = DEFAULT_TZ # :floating

# timespan for filtering (which should really be done by your server/app) and recurrences limitation
FILTER_SPAN = [Date.today - 90, Date.today + 400]

# org-mode ignores weekdays, but it should match for convenience
# WEEKDAYS = %w{So Mo Di Mi Do Fr Sa} # german weekdays
WEEKDAYS = %w{Su Mo Tu We Th Fr Sa} # english weekdays

# org date (ISO 8601)
def orgDate(t)
  "%04d-%02d-%02d %s" % [t.year, t.month, t.day, (WEEKDAYS[t.wday]) ]
end

# org time (ISO 8601)
def orgTime(ti)
  "%02d:%02d" % [ti.hour, ti.min]
end

def hasHour?(dt)
  dt.respond_to?(:hour)
end

# org date and time string
def orgDateTime(dt, repeaterClause = nil)
  res = "<" + orgDate(dt)
  res += " " + orgTime(dt) if (hasHour?(dt))
  res += " " + repeaterClause if (!repeaterClause.nil?)
  res + ">"
end

# date and time span (on the same date)
def orgTimeSpanShort(st, et, repeaterClause = nil)
  res = "<" + orgDate(st)
  res += " " + orgTime(st) if (hasHour?(st))
  res += "-" + orgTime(et) if (hasHour?(et))
  res += " " + repeaterClause if (!repeaterClause.nil?)
  res + ">"
end

# subtract one day if end is a new day's beginning
def fixupEndTime(tend)
  if (!hasHour?(tend) || (tend.hour == 0 && tend.minute==0)) then
    tend - 1
  else
    tend
  end
end

# single-day ical time span?
def simpleTimeSpan?(tstart, tend)
  return true if tend.nil?
  tend = fixupEndTime(tend)  
  # test date equality
  if (tstart.day == tend.day &&
      tstart.month == tend.month &&
      tstart.year == tend.year) then
    return true
  end
  false
end

# time span, possibly several days
def orgTimeSpan(tstart, tend, repeaterClause = nil)
  # start and end on same date -> use short notation
  if (simpleTimeSpan?(tstart, tend)) then
    orgTimeSpanShort(tstart, tend, repeaterClause)
  else
    # long notation
    res = orgDateTime(tstart, repeaterClause)
    
    tend = fixupEndTime(tend)
    # use of repeater in spanning date seems impossible in org-mode
    # alterntively, this case could be unfolded
    if (repeaterClause.nil?) then
      res += "--" + orgDateTime(tend) if !tend.nil?
    else
      warn "omission of end time to allow repeater: " + orgDateTime(tstart, repeaterClause) + "--" + orgDateTime(tend)
    end
    res
  end
end

# time span and a human-readable hint to the origin TZ
def orgTimeSpanTZ(tstart, tend, repeaterClause = nil)
  res = orgTimeSpan(tstart, tend, repeaterClause)
  res += " [" + tstart.tzid + "]" if(tstart.respond_to?(:tzid) && tstart.tzid != DEFAULT_TZ)
  res
end

def dateInRange(date)
  return date >= FILTER_SPAN[0] && date <= FILTER_SPAN[1]
end

# can the rule be expressed as a org-mode repeater?
def isOrgCompatRepeater?(ical)
  # no exrule
  return false if !ical.exrule_property.empty?
  # one rrule
  return false if ical.rrule_property.size != 1
  # no count, no bound, daily+
  rr = ical.rrule_property[0]
  return false if rr.bounded?
  return false if !( %w[DAILY WEEKLY MONTHLY YEARLY].include?(rr.freq))
  true
end

# org repeater clause for an ical entry which is believed to be org-mode compatible
def orgRepeaterClause(ical)
  rr = ical.rrule_property[0]
  "+%d%s" % [ rr.interval, rr.freq[0..0].downcase ]
end

# put errors to stderr
def putError(err, ical)
  warn err
  warn err.backtrace
  warn "------ (ical) --------"
  warn ical
  warn "----------------------"
end

OrgEventTemplate = ERB.new <<-'EOT', nil, "%<>"
<%#-*- coding: UTF-8 -*-%>
* <%= ev.summary %><%= !ev.status.nil? ? ( " (" + ev.status + ")" ) : "" %>
  :PROPERTIES:
  :ID: <%= ev.uid %>
  :icalCategories: <%= ev.categories.join(" ") %>
  :END:
% if (!ev.recurs?)
  <%= orgTimeSpanTZ(ev.dtstart, ev.dtend) %>
% end
% if (!ev.location.nil?)
  Location: <%= ev.location %>
% end
  <%= result[:description] %>
% if (!ev.organizer.nil?)
  Organizer: <%= ev.organizer %>
% end
% if (!ev.url.nil?)
  <%= ev.url %>
% end
% if (ev.recurs?) then
%   if (isOrgCompatRepeater?(ev))
  Recurs: <%= orgTimeSpan(ev.dtstart, ev.dtend, orgRepeaterClause(ev)) %>
%   else
  Occurrences: <% ev.occurrences(:overlapping => FILTER_SPAN).each { |occ| %><%= orgTimeSpan(occ.dtstart, occ.dtend) %> <% } %>
%   end
% end
  <%# uncomment if you have an edit link: = "[[edit:%s][edit %s]]" % [ev.uid, ev.summary]  %>
  :ICALENDAR:
<%= ev %>
  :END:
EOT

# this can be used to fix up stuff before the template processing starts
def evaluateEvent(ev)
  {
    # this is what requiring fields in standards gets you
    :description => ev.description.nil? ? "" : ev.description.chomp
  }
end

def orgEventSection(ev)
  result = evaluateEvent(ev)
  OrgEventTemplate.result(binding)
rescue StandardError => e
  putError(e, ev)
end

# filter events (e.g. by date)
def includeEvent?(ev)
  begin
    return true if (ev.recurs? && ev.occurrences(:overlapping => FILTER_SPAN).count > 0)
  rescue
    warn "Omitting event with incomprehensible recurrence:"
    warn ev
    return false
  end
  return true if (!ev.dtend.nil? && dateInRange(ev.dtend))
  return true if (dateInRange(ev.dtstart))
  false
end

OrgTodoTemplate = ERB.new <<-'EOT', nil, "%<>"
<%#-*- coding: UTF-8 -*-%>
* <%= results[:orgKeyword] %><%= results[:orgPrio] %><%= todo.summary %>
  <% if (!todo.due.nil?) then %>DEADLINE: <%= orgDateTime(todo.finish_time) %><% end %><% if (!todo.dtstart.nil?) then %> SCHEDULED: <%= orgDateTime(todo.dtstart) %><% end %>
  :PROPERTIES:
  :ID: <%= todo.uid %>
  :icalCategories: <%= todo.categories.join(" ") %>
  :icalPriority:  <%= todo.priority %>
  :END:
% if (!todo.location.nil?)
  Location: <%= todo.location %>
% end
% if (!todo.organizer.nil?)
  Organizer: <%= todo.organizer %>
% end
% if (!todo.url.nil?)
  <%= todo.url %>
% end
  <%= todo.description %>
  <%# uncomment this if you have an edit link: = "[[edit:%s][edit]]" % [todo.uid]  %>
  :ICALENDAR:
<%= todo %>
  :END:
EOT

# org keywords for ical completion states (see the RFC)
OrgKeywordForCompleted = {
  "COMPLETED" => "DONE",  
  "CANCELLED" => "CANCELLED",
  "IN-PROCESS" => "TODO",  # in case you have a STARTED state, this is a nice place for it
  "NEEDS-ACTION" => "TODO",
  nil => "TODO"
}

# evaluate various things available to the template
def evaluateTodo(todo)
  { 
    :orgKeyword => OrgKeywordForCompleted[todo.completed],
    :orgPrio => (!todo.priority.nil? && todo.priority > 1) ? "#C " : " " 
  }
end

# return org TODO section
def orgTodoSection(todo)
  results = evaluateTodo(todo)
  OrgTodoTemplate.result(binding)
rescue StandardError => e
  putError(e, todo)
end

# decide wheter to include/evaluate the VTODO
def includeTodo?(todo)
  return true if (todo.status != "COMPLETED" && todo.status != "CANCELLED")
  # if open, see if we care
  return dateInRange(todo.completed)
end

comps = RiCal.parse(STDIN)

# handle events
comps.each do |cal|
  cal.events.each do |event|
    puts orgEventSection(event) if includeEvent?(event)
  end
end

# handle TODOs
comps.each do |cal|
  cal.todos.each do |todo|
    puts orgTodoSection(todo) if includeTodo?(todo)
  end
end
