# vscp.pl - Varnishncsa parse and pipe to cPanel splitlogs

vscp.pl is used to relay requests between varnishncsa and cPanel's splitlogs binary for domlog and bytelog writeouts. This helps cPanel track bandwidth usage, and include previously missed cache hits in statistical log processing. Such as Logaholic, AWStats, Webalizer, etc.

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
    }
}
```
