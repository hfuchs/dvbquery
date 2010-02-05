#!/usr/bin/perl -w
# 2010-02-03, Created by H Fuchs <hagen.fuchs@physik.tu-dresden.de>
# The GNU Public Licence applies, but if this script breaks your legs, don't
# come running to me!
#
# Witz: Wenn die Anfrage nicht länger als 10 Tage her ist, nimm die Daten
# einfach aus dem Cache.  Noch cooler: Liefere immer aus dem Cache, aber
# starte einen thread, der nochmal kontrolliert.

#use strict; # TODO :)
use LWP::Simple;   # TODO Either LWP *or* Mech!
use WWW::Mechanize 1.5;
use HTML::TreeBuilder;
use URI::Escape;
#use Text::Iconv;
use Encode;
#use Data::Dumper;
use Getopt::Std;
use CGI qw/unescape_HTML/;
use utf8;
use feature qw/say/;
use URI;  # TODO URI::Escape *and* URI?  Don't think so.


# --- Globals
# TODO Read from config file
my $server_url = "http://widgets.vvo-online.de/abfahrtsmonitor/";
my $ort        = "Dresden";
my %config     = (  # TODO Put all config here.
    'want_to_chat' => 1,
    'debug'        => 0,
);


# --- Main
#
# Some object inits (TODO put somewhere else)
#my $to_utf8  = Text::Iconv->new("latin1", "utf8");
#my $to_latin = Text::Iconv->new("utf8", "latin1");

# Command-line parsing
my %args;
getopts("f:t:a:", \%args);
my $time = $args{'a'};  # "at"

# TODO No args?  Ask.
# TODO Support user-definable abbreviations (eg 'NÖ', 'HB' etc).
if ($from = sanitize_input($args{'f'})) {
    if ($to = sanitize_input($args{'t'})) {
        display_connections($from, $to);
    } else {
        display_departure($from);
    }
} else {
    chat("Mind telling me WTF you want?  Much appreciated...");
    display_help();
}


# --- Subroutines
sub display_connections {
    D("TODO: display_connections");
    my ($from, $to) = @_;

    chat("Travelling from '" . $from . "' to '" . $to . "', I see.");
    if (check_station_uniqueness(($from, $to))) {

        # Now on to the real connection data.
        #$result = parse_connection_data(fetch_connection_data($from, $to));
        # TODO Fix this shit.
        fetch_connection_data($from, $to);
        #say "This shit ain't going to work anytime soon...";
    };

    return;
}

sub parse_connection_data {
}

sub fetch_connection_data {
    D("-> fetch_connection_data");

    # TODO $time still global
    my ($from, $to) = @_;
    #$from = $to_latin->convert($from); # TODO Ugly - perhaps map() might help.
    #$to   = $to_latin->convert($to);

    #say ($url);# or die "$!";
    # See HTML::Element for operations on the tree, HTML::TreeBuilder for
    # parsing information and WWW::Mechanize for general documentation.
    my $mech = new WWW::Mechanize;

    # TODO Zum Kotzen.
    my ($sec,$min,$hour,$day,$month,$year,,,) = localtime(time);
    $year = $year+1900;
    $time = "$hour:$min" unless ($time);

    $mech->get('http://dvb.de'); # TODO variable?
    # TODO decode_utf8(), really?
    my $page = $mech->submit_form(
        'with_fields' => {
            'vaform[datum]'     =>  "$day." . ++$month . ".$year",
            'vaform[startname]' =>  decode_utf8($from),
            'vaform[startort]'  =>  'Dresden',
            'vaform[zeit]'      =>  $time,
            'vaform[zeittyp]'   =>  'dep',
            'vaform[zielname]'  =>  decode_utf8($to),
            'vaform[zielort]'   =>  'Dresden',
        }
    );

    # TODO Factor out into parse_connection_data()!
    if ($mech->success) {
        # TODO Why does the TreeBuilder still need UTF-8 decoding?
        my $tree = HTML::TreeBuilder->new_from_content(decode_utf8 $page->content);

        # Find all "full trip" tables and parse each one.
        say "-"x70;
        my @rides = $tree->look_down( '_tag' , 'table', 'class', 'full trip' );
        foreach my $ride (@rides) {
            my @stops = $ride->look_down( '_tag', 'tr' );
            foreach my $stop (@stops) {
                # Remove elements that add no information.
                my @bastards = $stop->look_down('_tag', 'ul', 'class', 'linkliste');
                push @bastards, $stop->look_down('_tag', 'img');
                $_->delete foreach (@bastards);

                # Find the individual description elements.  Entries:
                #  - time
                #  - "ab"/"an"
                #  - station
                #  - additional information
                my @desc = $stop->look_down( '_tag', 'td' );
                my $tmp = $desc[0]->as_text.' '.$desc[1]->as_text.' '.$desc[2]->as_text;
                print encode_utf8 $tmp;

                # Parsing the badly-formatted info-string
                # TODO Linienänderungen!  ul class=changelist
                # TODO Überfahrhilfe!  </br>Überfahrhilfe
                foreach my $info ($desc[4]->look_down('_tag','td')) {
                    if (my $bold =  $info->look_down('_tag','b')) {
                        my $line = $bold->as_text;
                        $line =~ s/^[^0-9]*([0-9]*)[^0-9]*$/$1/;
                        print " ($line)";
                        $bold->delete;
                    }
                    if (my $note = $info->as_text) {
                        print "\n\t" . encode_utf8 $note;
                    }
                }
                print "\n";
            }
            say "-"x70;
        }
        $tree->delete;
    } else {
        say STDERR "Error: ", $mech->response->status_line;
    }

    #my $departure_or_arrival = 'Ankunft';
    #
    ## Original query string from function showSchedule() in 'desk.js' of the
    ## 'dvb-fahrplanauskunft-12_vista.zip' widget.
    ## More headaches.  encodeURI() in JavaScript does *not* encode these
    ## chars: ! # $ & ' ( ) * + , - . / : ; = ? @ _ ~
    ## <http://unspecified.wordpress.com/2008/05/24/uri-encoding/>
    #my $url = 
    #    "http://www.dvb.de/de/Fahrplan/Verbindungsauskunft/direkt.do?" .
    #    "vaform[starttypeswitch_stop]=1&vaform[zieltypeswitch_stop]=1&" .
    #    "vaform[startort]="   . $ort                  . 
    #    "&vaform[startname]=" . $from                 . 
    #    "&vaform[zielort]="   . $ort                  . 
    #    "&vaform[zielname]="  . $to                   . 
    #    "&vaform[zeittyp]="   . $departure_or_arrival . 
    #    "&vaform[datum]="     . $date                 . 
    #    "&vaform[zeit]="      . $time;
    #    
    #say $url;
    #say uri_escape($url, '^!#$()*+,-./:;=?\&\@_~A-Za-z0-9');
    #
    #return $to_utf8->convert(CGI::unescapeHTML(get($url)))
    #    or die "TODO - I died.  Completely unexpected, too!";
}

sub display_departure {
    my $station = shift;

    chat("So, you want to know everything about station '$station'?");

    if (check_station_uniqueness($station)) {

        # Now on to the real departure data.
        $result = parse_departure_data(fetch_departure_data($station));

        if (scalar(@$result) > 0) {
            chat("Holmes!  Coaches leave in:");
            foreach my $entry (@$result) {
                print "  ". $entry->{'minutes'} . "\tminutes to " .
                $entry->{'destination'} . " (" .
                $entry->{'number'} . ")." . "\n";
            }
        } else {
            chat("My!  Nothing leaves from _there_.");
        }
    } # No else required here, right?

    return 1;
}

sub parse_departure_data {
    my $string = shift;
    my $result;

    if ($string =~ s/^\[(.*)\]$/$1/) {
        my $i = 0;
        while ($string =~ s/^,?\["(.*?)","(.*?)","(.*?)"\]//) {
            $result->[$i]->{'number'}      = $1;
            $result->[$i]->{'destination'} = $2;
            $result->[$i++]->{'minutes'}   = $3;
        }
        return $result
    } else {
        die "Unparseable."; # TODO: exception handling
    }
}

sub fetch_departure_data {
    my $station = shift;

    my $url = URI->new($server_url .
        "Abfahrten.do?ort=$ort&hst=$station&vz=20:00");
        # TODO Not sure about these.
        # +"&vm="+preferenceForKey('vmPrefChecked')
        # +"&lim="+preferenceForKey('listitemsPrefChecked'));
    return encode_utf8(unescapeHTML(get($url)))
        or die "TODO - I died!";
}

sub parse_station_data {
    my $string = shift;
    my $result;

    if ($string =~ s/^\[(.*)\]$/$1/) { # Removing outmost brackets.
        my $i = 0;
        while ($string =~ s/^,?\[\["(.*?)"\]\],\[\[(.*?)\]\]//) {
            $result->[$i]->{'ort'}        = $1;
            my @stations                  = split(/\],\[/, $2);
            map { s/^"(.*?)".*$/$1/ } @stations;
            $result->[$i++]->{'stations'} = \@stations;
        }
        return $result
    } else {
        die "Unparseable.";
    }
}

sub fetch_station_data {
    my $station = shift;
    # URL(decode_utf8)=plauen%20n%C3%B6thnitzer%20stra%C3%9Fe
    # URL(nothing)    =plauen%20n%C3%B6thnitzer%20stra%C3%9Fe
    # URL(to_latin)   =plauen%20n%F6thnitzer%20stra%DFe

    my $url  = URI->new($server_url . "Haltestelle.do?ort=$ort&hst=$station");
    return encode_utf8(CGI::unescapeHTML(get($url)))
        or die "TODO - I died!";
}

sub check_station_uniqueness {
    # TODO Caching!  Learning!
    # TODO Inconsistent user interface, chat()s all over the place.
    my @stations = @_;

    foreach $station (@stations) {
        my $result = parse_station_data(fetch_station_data($station));

        if (scalar(@{$result->[0]->{'stations'}}) > 1) {
            chat("But multiple stations match your request (silly bugger!):");
            say  "  $_" foreach (@{$result->[0]->{'stations'}});
            chat("Do try to be more specific next time, will you?");
            return '';
        }
    }

    return 1;
}

sub sanitize_input {
    my ($input) = @_;
    D("TODO: sanitize_input");
    return $input;
}

sub display_help {
    D("TODO: display_help");
    exit -1;
}

sub D {
    say STDERR "Debug (@_)" if ($config{'debug'});
    return;
}

# TODO More variety!
sub chat {
    say @_ if ($config{'want_to_chat'});
    return;
}

