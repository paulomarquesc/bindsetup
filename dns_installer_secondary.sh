#!/bin/bash

osName=`hostname`
yum -y install bind bind-utils

secondaryIP=`ifconfig eth0 | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1`
domain="pmcglobal.me"

echo master ip is $secondaryIP | tee -a ~/.dns.installer.txt
echo osName  is $osName | tee -a ~/.dns.installer.txt
echo domain  is $domain | tee -a ~/.dns.installer.txt

mkdir -p /var/named/zones
chown named:named /var/named/zones
chmod 770 /var/named/zones

primaryDnsName=$(cat ipaddresses.txt | grep "ns01" | tr -d $'\r' | awk -F, '{print $1}')
primaryDnsIp=$(cat ipaddresses.txt | grep "ns01" | tr -d $'\r' | awk -F, '{print $2}')
secondaryDnsName=$(cat ipaddresses.txt | grep "ns02" | tr -d $'\r' | awk -F, '{print $1}')

# Setting up named.conf

echo "// named.conf
options {
  listen-on port 53 { any; };
  directory \"/var/named\";
  dump-file \"/var/named/data/cache_dump.db\";
  statistics-file \"/var/named/data/named_stats.txt\";
  memstatistics-file \"/var/named/data/named_mem_stats.txt\";
  allow-query { any; };
  allow-transfer { ${primaryDnsIp}; };
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
  type slave;
  file \"slaves/${domain}.db\";
  masters { ${primaryDnsIp}; } ;
};
zone \"0.10.in-addr.arpa\" IN {
	type slave;   
	file  \"slaves/${domain}.rr.db\";
  masters { ${primaryDnsIp}; } ;
};

include \"/etc/named.rfc1912.zones\";
include \"/etc/named.root.key\";" > /etc/named.conf

# Setting up permissions
chown root:named /etc/named.conf
chmod 640 /etc/named.conf

chmod 775 /var/named
chmod 775 /var/named/slaves
chmod 775 /var/named/zones

setsebool -P named_write_master_zones=1

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
