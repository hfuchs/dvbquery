#!/usr/bin/perl -w
# Witz: Wenn die Anfrage nicht länger als 10 Tage her ist, nimm die Daten
# einfach aus dem Cache.  Noch cooler: Liefere immer aus dem Cache, aber
# starte einen thread, der nochmal kontrolliert.

use LWP::Simple;  # Or WWW::Mechanize?
use URI::Escape;
use Text::Iconv;
use Data::Dumper;
use Getopt::Std;
use CGI;
use utf8;
use feature qw/say/;


# --- Globals
# TODO Read from config file
my $server_url = "http://widgets.vvo-online.de/abfahrtsmonitor/";
my $ort        = "Dresden";
#my $from       = "Hauptbahnhof";
#my $to         = "Albertplatz";
my %config     = (  # TODO Put all config here.
    'want_to_chat' => 1,
    'debug'        => 0,
);


# --- Main
#
# Some object inits (TODO put somewhere else)
my $to_utf8  = Text::Iconv->new("latin1", "utf8");
my $to_latin = Text::Iconv->new("utf8", "latin1");

# Command-line parsing
# TODO No args?  Ask.
# TODO Support user-definable abbreviations (eg 'NÖ', 'HB' etc).
if ($from = sanitize_input($ARGV[0])) {
    if ($to = sanitize_input($ARGV[1])) {
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
        #fetch_connection_data($from, $to);
        say "This shit ain't going to work anytime soon...";
    };

    return;
}

sub parse_connection_data {
}

sub fetch_connection_data {
    my ($from, $to) = @_;
    $from = $to_latin->convert($from); # TODO Ugly - perhaps map() might help.
    $to   = $to_latin->convert($to);

    D("-> fetch_connection_data");

    my $departure_or_arrival = 'Ankunft';
    my $date                 = '28.1.2010';
    my $time                 = '13:00';

    chat("So, going from '$from' to '$to', are we?");

    # Original query string from function showSchedule() in 'desk.js' of the
    # 'dvb-fahrplanauskunft-12_vista.zip' widget.
    # More headaches.  encodeURI() in JavaScript does *not* encode these
    # chars: ! # $ & ' ( ) * + , - . / : ; = ? @ _ ~
    # <http://unspecified.wordpress.com/2008/05/24/uri-encoding/>
    my $url = 
        "http://www.dvb.de/de/Fahrplan/Verbindungsauskunft/direkt.do?" .
        "vaform[starttypeswitch_stop]=1&vaform[zieltypeswitch_stop]=1&" .
        "vaform[startort]="   . $ort                  . 
        "&vaform[startname]=" . $from                 . 
        "&vaform[zielort]="   . $ort                  . 
        "&vaform[zielname]="  . $to                   . 
        "&vaform[zeittyp]="   . $departure_or_arrival . 
        "&vaform[datum]="     . $date                 . 
        "&vaform[zeit]="      . $time;
        
    say $url;
    say uri_escape($url, '^!#$()*+,-./:;=?\&\@_~A-Za-z0-9');
#say ($url);# or die "$!";

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
    my $station = $to_latin->convert(shift);

    D("-> fetch_departure_data");
    my $url = "Abfahrten.do?ort=" . CGI::escape($ort) .
              "&hst=" . CGI::escape($station) .
              "&vz=" .  CGI::escape("10:40");
              # TODO Not sure about these.
              # +"&vm="+preferenceForKey('vmPrefChecked')
              # +"&lim="+preferenceForKey('listitemsPrefChecked'));
    return $to_utf8->convert(CGI::unescapeHTML(get($server_url . $url)))
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
    my $station = $to_latin->convert(shift);

    D("-> fetch_station_data");
    my $url = "Haltestelle.do?ort=" . CGI::escape($ort) .  "&hst=" .
              CGI::escape($station);
    D("URL: $url");
    my $list = $to_utf8->convert(CGI::unescapeHTML(get($server_url
                . $url)));
    D("List from server: $list");
    return $list;
}

sub check_station_uniqueness {
    # TODO Caching!  Learning!
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

