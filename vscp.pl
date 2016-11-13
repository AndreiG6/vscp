#!/usr/bin/perl -w
#
# vscp.pl pipes cache hits between varnishncsa and cPanel's splitlogs
# binary for domlog and bytelog writeouts. This helps cPanel track
# bandwidth usage, and include previously missed cache hits in
# statistical log processing. Such as Logaholic, AWStats, Webalizer
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
# Interval in seconds for /etc/userdatadomains checks
my $userdata_poll_frequency = "60";

# Custom Port header set in Varnish for the request target (usually 80/443).
#  It's is mainly used for diferentiating SSL downgraded requests.
my $varnish_port_header     = 'X-Port';

# Client IP header set in Varnish. Usually X-Forwarded-For (beware of multiple IP entries if using the default xforwardedfor)
my $varnish_ip_header       = 'X-Real-IP';

chomp(my $piped_logging = `grep ^enable_piped_logs\=1 /var/cpanel/cpanel.config`);
if (!$piped_logging) {
    print qq{
    Piped logging is currently disabled. To enable follow the steps below to enable.
    
    Log into WHM, and follow this sequence to the right place:
    
    - Service Configuration >> Apache Configuration >> Piped Log Configuration
    - Enable piped Apache logging, save it and let it rebuild the configuration.
    
    For more information on piped logging in WHM:
    
    https://documentation.cpanel.net/display/ALD/Apache+Configuration
    https://www.liquidweb.com/kb/how-and-why-enabling-apaches-piped-logging/

};
    exit;
}

use Sys::Hostname;
my $host        = hostname;
my $vncsa_pid   = open( VNCSA,'varnishncsa -F "%{Varnish:hitmiss}x:::%b:::%{HOST}i:::%{X-Port}i %{X-Real-IP}i %l %u %t \"%m %U%q %H\" %s %b \"%{Referer}i\" \"%{User-agent}i\"" |') or die "Couldn't fork: $!\n";
my $split_logs  = open( SPLITLOGS,"| /usr/local/cpanel/bin/splitlogs --main=${host} --mainout=/usr/local/apache/logs/access_log") or die "Couldn't fork: $!\n";
my $split_bytes =  open( SPLITBYTES,    "| /usr/local/cpanel/bin/splitlogs --main=${host} --suffix=-bytes_log" )  or die "Couldn't fork: $!\n";
my %domlogs;
my $loaded_md5 = "";
my $debug = '0';
my $check_time = time();

while (<VNCSA>) {
    chomp $_;
    &get_userdata;
    my ( $hit, $bytes, $domain, $rlog ) = split /:::/, $_;
    my $domlog = &get_log($domain);
    if ( ($domlog) && ( $hit =~ /hit/ ) ) {
        print "TOLOGPIPE: $domlog:$rlog\n" if ($debug);
        print SPLITLOGS "$domlog:$rlog\n";
        print "TOBYTEPIPE: $domlog $bytes .\n" if ($debug);
        print SPLITBYTES "$domlog $bytes .\n";
    }
}
close(VNCSA);

# Subroutines
sub get_userdata() {
    return if ( time() < $check_time );
    chomp( my $check_md5 = `md5sum /etc/userdatadomains|awk '{print\$1}'` );
    if ( $check_md5 =~ /^$loaded_md5$/m ) {
        $check_time = time() + $userdata_poll_frequency;
        return;
    }
    %domlogs = ();
    open( my $udfh, '-|', "sed -e 's/://g' /etc/userdatadomains" ) or die $!;
    while ( my $userdata = <$udfh> ) {
        chomp $userdata;
        my $user;
        my ( $udom, $owner, $type, $dom, $rest ) = split /==/, $userdata;
        ( $udom, $user ) = split / /, $udom;
        my $d = $udom;
        $d =~ s/^\*\./_wildcard_./;
        if ( $type =~ /addon/ ) {
            if ( $udom =~ /^\*\./m ) {
                $domlogs{$udom} = $d;
            }
            else {
                $domlogs{$udom} = $dom;
                $domlogs{$dom}  = $dom;
            }
        }
        elsif ( $type =~ /main/ ) {
            if ( $udom =~ /^\*\./m ) {
                $domlogs{$udom} = $d;
            }
            else {
                $domlogs{$udom} = $dom;
            }
        }
        elsif ( $type =~ /sub/ ) {
            if ( $udom =~ /^\*\./m ) {
                $domlogs{$udom} = $d;
            }
            else {
                $domlogs{$udom} = $udom;
            }
        }
    }
    $loaded_md5 = $check_md5;
    $check_time = time() + $userdata_poll_frequency;
}

sub get_log() {
    my $check = shift;
    $check =~ s/^www\.//g;
    if ( $domlogs{$check} ) {
        return $domlogs{$check};
    }
    else {
        $check =~ s/^[\w-]+\./\*\./;    # strip subdomain for wildcard check
                                        #$check = '*.'.$check;
        if ( $domlogs{$check} ) {
            return $domlogs{$check};
        }
    }
}

