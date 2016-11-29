#!/bin/bash
# Quick script to get things rolling on cPanel servers
# Usage: ./install_cpanel.sh

checks=(vscp.pl
vscpd.initd
vscpd.chkservd)
vscpl=/opt/vscp/vscp.pl

if [ ! -d "/var/cpanel" ];then
  echo "This installer is only intended for cPanel servers."
  exit 1
else
  echo "Installing vscpd .. (${vscpl})"
fi

for i in "${checks[@]}";do
  [[ ! -f "$i" ]] && { echo "Missing: $i";fail=1; }
done
[[ $fail ]] && exit 1

[[ ! -d "/opt/vscp" ]] && mkdir /opt/vscp
if [ "`pwd`/vscp.pl" != "${vscpl}" ];then
  [[ -f "${vscpl}" ]] && mv -v ${vscpl}{,.backup.$(date +%s)}
  cp vscp.pl /opt/vscp/
fi

[[ -x "${vscpl}" ]] && chmod +x ${vscpl}

if [ -f "/etc/init.d/vscpd" ];then
  chmod 0 /etc/init.d/vscpd
  \mv -f /etc/init.d/vscpd{,.old}
fi
cp vscpd.initd /etc/init.d/vscpd
chmod +x /etc/init.d/vscpd
chkconfig vscpd on

if ! grep -q ^vscpd: /etc/chkserv.d/chkservd.conf;then
  sed -i "1i vscpd:1" /etc/chkserv.d/chkservd.conf
fi
echo 'service[vscpd]=,,,/etc/init.d/vscpd restart,root' > /etc/chkserv.d/vscpd

service vscpd restart
/scripts/restartsrv_chkservd
