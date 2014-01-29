use strict;

package DDG::Goodie::WorkdaysBetween;
# ABSTRACT: Give the number of work days between two given dates. Does not
# consider holidays.

use DDG::Goodie;
use Time::Piece;
use List::Util qw( min max );

triggers start => "workdays between", "business days between", "work days between", "working days";

zci answer_type => "workdays_between";

primary_example_queries 'workdays between 01/31/2000 01/31/2001';
secondary_example_queries 'workdays between 01/31/2000 01/31/2001 inclusive';
description 'Calculate the number of workdays between two dates. Does not consider holidays.';
name 'WorkDaysBetween';
code_url 'https://github.com/duckduckgo/zeroclickinfo-goodies/blob/master/lib/DDG/Goodie/WorkdaysBetween.pm';
category 'calculations';
topics 'everyday';
attribution github => ['http://github.com/mgarriott', 'mgarriott'];

handle remainder => sub {
    my ($start, $end) = get_dates($_);

    # If get_dates failed, return nothing.
    unless ($start && $end) {
        return;
    }

    my $inclusive = '';

    my $total_days = int( $end->mjd ) - int( $start->mjd );
    my $num_weeks = int($total_days / 7);

    # For every 7 days there will always be 1 Saturday and 1 Sunday, therefore
    # we subtract 2 days for every full week in the range.
    my $workdays = $total_days - ($num_weeks * 2);

    # Find the remaining number of days that didn't fall into the full weeks
    # we already counted.
    my $remainder = $total_days % 7;

    # Adding the starting weekday to the number of remainder days allows us to
    # determine whether or not the remainder days contain a Saturday and/or a
    # Sunday.
    
    my $weekday_start = $start->_wday;
    if($start->_wday == 0) {
	$weekday_start = 7;
    }

    my $start_plus_remainder = $weekday_start + $remainder;
    
    # We only regard something as 'inclusive' if the day
    # ends on a weekday.
    if(/inclusive/ && ($start_plus_remainder % 7) < 6) {
	$inclusive = ', inclusive';
	$workdays++;
    }

    # Problems only arise when we deal with remainders.
    if($remainder > 0) {
	# What happens if we land on a weekend?
	if($start_plus_remainder % 7 == 0) {
	    $workdays -= 2;
	}

	if($start_plus_remainder % 7 == 6) {
	    $workdays -= 1;
	}

	# What happens if we start on a weekend?
	if($weekday_start == 6) {
	    $workdays -= 2;
	}

	if($weekday_start == 7) {
	    $workdays -= 1;
	}

	# What happens if the weekend is in the middle?
	if($weekday_start < 6 && $start_plus_remainder > 7) {
	    $workdays -= 2;
	}

	if($workdays < 0) {
	    $workdays = 0;
	}
    }

    my $date_format = "%b %d, %Y";
    my $start_str = $start->strftime($date_format);
    my $end_str = $end->strftime($date_format);

    my $verb = $workdays == 1 ? 'is' : 'are';
    my $number = $workdays == 1 ? 'workday' : 'workdays';

    return "There $verb $workdays $number between $start_str and $end_str$inclusive.";
};

# Given a string containing two dates, parse out the dates, and return them in
# chronological order.
#
# On success this subroutine returns a two element array of
# Time::Piece in the following format ( $start_date, $end_date )
#
# On failure this function returns nothing.
sub get_dates {
    my @date_strings = $_ =~ m#(\d{1,2}/\d{1,2}/\d{2,4}|\w{0,9} \d{1,2},? \d{2,4}|\d{1,2}-\d{1,2}-\d{2,4}|\d{1,2}\.\d{1,2}\.\d{2,4})#gi;

    # If we don't have two dates matching the correct format, return nothing.
    if (scalar(@date_strings) != 2) {
        return;
    }

    # A list of date formats to try sequentially.
    my $day_format_slash = "%d/%m/";
    my $day_format_dash = "%d-%m-";
    my $day_format_period = "%d.%m.";
    my @date_formats = ( "%m/%d/", "%m-%d-", "%m.%d.", $day_format_slash, $day_format_dash, $day_format_period, "%b %d ", "%b %d, ", "%B %d ", "%B %d, ");

    # Flag that determines if we are using the DD/MM/YYYY format
    my $day_is_first = 0;

    # Populate the @dates array. With Time::Piece
    my @dates;
    for (my $i = 0; $i < scalar(@date_strings); $i++) {
        my $date_string = $date_strings[$i];
        foreach (@date_formats) {
            local $@;

	    # Check to see if we're using the shortened year format or not.
	    my $year_format = '%y';
	    if($date_string =~ /\d{4}$/) {
		$year_format = '%Y';
	    }

            my $time;
            eval {
                # Attempt to parse the date here.
                $time = Time::Piece->strptime($date_string, "$_$year_format");
            };

            # If we didn't get an error parsing the time...
            unless ($@) {

                # If a date matches the DD/MM/YYYY format we want to ensure
                # that all the XX/XX/XXXX dates match that specific format.
                # Therefore, we remove the MM/DD/YYYY format from the
                # dates_format array, clear the dates array, and restart the
                # loop. This way all XX/XX/XXXX dates will match only the
                # DD/MM/YYYY format.
                if ( ($_ eq $day_format_slash || $_ eq $day_format_dash || $_ eq $day_format_period) && !$day_is_first ) {
                    # Set the flag indicating that we are using DD/MM/YYYY
                    $day_is_first = 1;

                    # Remove the formats in the array that begin with the month.
                    shift(@date_formats) for(1 .. 3);

                    # Empty the @dates array
                    undef @dates;
                    # Reset the loop index
                    $i = -1;
                    # Restart the loop iteration
                    next;
                }

                # If the format was acceptable, add the date to the @dates array
                push(@dates, $time);
                last;
            }
        }
    }

    # Bail out if we don't have exactly two dates.
    if (scalar(@dates) != 2) {
        return;
    }

    # Find the start and end dates.
    my $start = min(@dates);
    my $end = max(@dates);

    return ($start, $end);
}

1;
