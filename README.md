# vscp.pl - Varnish Stats to cPanel

vscp.pl is used to relay cache hit requests between varnishncsa and cPanel's splitlogs binary for domlog and bytelog writeouts of traffic which otherwise went unseen. This helps cPanel track bandwidth usage, and include previously missed cache hits in statistical log processing. Such as Logaholic, AWStats, Webalizer, etc.

Requirements:
- Varnish already installed
- Custom client IP header (default: X-Real-IP)
- Custom port header (used for splitting downgraded SSL requests into separate domlogs - default: X-Port)

Compatibility:
- Tested with Varnish4 and cPanel 56-60, however it should work fine for all versions.


#Minimal VCL for setting the expected custom headers:

```
# List of trusted IPs offloading HTTPS requests

acl offloaded {
	"localhost";
	"::1";
	"127.0.0.1";
	"10.4.0.1"; # SSL termination proxy IP. Such as Hitch, Nginx, etc.
}

sub vcl_recv {
    if (req.http.X-Forwarded-Proto == "https" ) {
      set req.http.X-Port = "443";
    } else {
      set req.http.X-Port = "80";
    }

    if ((req.http.X-Real-IP) && (client.ip ~ offloaded)) {
        set req.http.X-Forwarded-For = req.http.X-Real-IP;
    } else {
        set req.http.X-Forwarded-For = client.ip;
        set req.http.X-Real-IP = req.http.X-Forwarded-For;
    }
}
```
#Usage:

- Make sure piped logging is enabled in WHM (WHM >> Service Configuration >> Apache Configuration >> Piped Log Configuration) - https://documentation.cpanel.net/display/ALD/Apache+Configuration?piped

- Open vscp.pl, change variables below to enable request debugging, set the IP/Port headers to match your environment, and set the user domains refresh frequency.
```
# Interval in seconds for /etc/userdatadomains checks
my $userdata_poll_frequency = "60";

# Print piped requests to STDOUT
my $debug = '0';

# Custom Port header set in Varnish for the request target (usually 80/443).
# It's is mainly used for differentiating SSL downgraded requests.
my $varnish_port_header = 'X-Port';

# Client IP header set in Varnish. Usually X-Forwarded-For (beware of multiple IP entries if using the default xforwardedfor)
my $varnish_ip_header = 'X-Real-IP';

```
- Once the settings are in place, either open a ```screen``` and run ```perl vscp.pl```, or fork it to the background using ```perl vscp.pl &```
