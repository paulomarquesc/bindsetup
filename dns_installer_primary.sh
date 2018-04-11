#!/bin/bash

osName=`hostname`
yum -y install bind bind-utils

service named start
service named stop 

masterIP=`ifconfig eth0 | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1`
domain="pmcglobal.me"

echo master ip is $masterIP | tee -a ~/.dns.installer.txt
echo osName  is $osName | tee -a ~/.dns.installer.txt
echo domain  is $domain | tee -a ~/.dns.installer.txt

mkdir -p /var/named/zones

primaryDnsName=$(cat ipaddresses.txt | grep "ns01" | tr -d $'\r' | awk -F, '{print $1}' )
secondaryDnsName=$(cat ipaddresses.txt | grep "ns02" | tr -d $'\r' | awk -F, '{print $1}' )
secondaryDnsIp=$(cat ipaddresses.txt | grep "ns02" | tr -d $'\r' | awk -F, '{print $2}' )

# Setting up named.conf

echo "// named.conf
options {
  listen-on port 53 { any; };
  directory \"/var/named\";
  dump-file \"/var/named/data/cache_dump.db\";
  statistics-file \"/var/named/data/named_stats.txt\";
  memstatistics-file \"/var/named/data/named_mem_stats.txt\";
  allow-query { any; };
  recursion yes;
  
  dnssec-enable yes;
  dnssec-validation yes;

  /* Path to ISC DLV key */
  bindkeys-file \"/etc/named.iscdlv.key\";

  managed-keys-directory \"/var/named/dynamic\";

};
logging {
  channel default_debug {
    file \"data/named.run\";
    severity dynamic;
  };
};
zone \".\" IN {
  type hint;
  file \"named.ca\";
};
zone \"${domain}\" IN {
  type master;
  file \"zones/${domain}.db\";
  allow-update { none; }; 
  allow-transfer { localhost; ${secondaryDnsIp}; };
  notify yes;
  also-notify { ${secondaryDnsIp}; };
};
zone \"0.10.in-addr.arpa\" IN {
	type master;   
	file  \"zones/${domain}.rr.db\";  
	allow-update { none; }; 
  allow-transfer { localhost; ${secondaryDnsIp}; };
  notify yes;
  also-notify { ${secondaryDnsIp}; };
};

include \"/etc/named.rfc1912.zones\";
include \"/etc/named.root.key\";
" > /etc/named.conf

chown root:named /etc/named.conf
chmod 640 /etc/named.conf

echo "
\$TTL 86400
@ IN SOA ${osName}.  root.${domain}.  (
  2011112904  ;  serial
  60  ;  refresh (1 minute)
  15  ;  retry (15 seconds)
  1800  ;  expire (30 minutes)
  10  ; minimum (10 seconds)
)
@ IN NS ${primaryDnsName}.${domain}.
@ IN NS ${secondaryDnsName}.${domain}.
"  >  /var/named/zones/pmcglobal.me.db.1

echo "
\$TTL 86400
@ IN SOA ${osName}.  root.${domain}.  (
  2011112904  ;  serial
  60  ;  refresh (1 minute)
  15  ;  retry (15 seconds)
  1800  ;  expire (30 minutes)
  10  ; minimum (10 seconds)
)
@ IN NS ${primaryDnsName}.${domain}.
@ IN NS ${secondaryDnsName}.${domain}.
"  >  /var/named/zones/pmcglobal.me.rr.db.1

# Adding PTR records from ipaddresses.txt file
awk -F"[.,]" '{print $1,$2,$3,$4,$5}' ./ipaddresses.txt | tr -d $'\r' | while read ptrhost a1 a2 a3 a4 
do 
echo "$a4.$a3      PTR     ${ptrhost}.pmcglobal.me." >> /var/named/zones/pmcglobal.me.rr.db.1
done
awk '{ gsub(/\xef\xbb\xbf/,""); print }' /var/named/zones/pmcglobal.me.rr.db.1 > /var/named/zones/pmcglobal.me.rr.db

# Adding A records from ipaddresses.txt file
awk -F,  '{print $1, $2}' ./ipaddresses.txt | tr -d $'\r' | while read ip hostname
do
echo "${ip} 3600 IN  A ${hostname}"
done >> /var/named/zones/pmcglobal.me.db.1

echo "
puppet 3600 IN CNAME puppet.pmcglobal.me. 
puppetdb 3600 IN CNAME puppetdb.pmcglobal.me.
" >> /var/named/zones/pmcglobal.me.db.1

awk '{ gsub(/\xef\xbb\xbf/,""); print }' /var/named/zones/pmcglobal.me.db.1 > /var/named/zones/pmcglobal.me.db

rm -rf /var/named/zones/pmcglobal.me.db.1
rm -rf /var/named/zones/pmcglobal.me.rr.db.1 

# Setting up permissions
chown root:named /var/named/zones/pmcglobal.me.db
chmod 660 /var/named/zones/pmcglobal.me.db

chown root:named /var/named/zones/pmcglobal.me.rr.db
chmod 660 /var/named/zones/pmcglobal.me.rr.db

chmod 775 /var/named

# Starting DNS Service
service named start

dig @127.0.0.1 $osName

if [ $? = 0 ]
then
  echo "DNS Setup was successful!"
else
  echo "DNS Setup failed"
fi

chkconfig --add named
chkconfig named on

echo Fully Finished the $0 script  | tee -a ~/.dns.installer.txt
