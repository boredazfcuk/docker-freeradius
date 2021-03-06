#!/bin/bash

##### Functions #####
Initialise(){
   echo
   dns_name="${domain_name}.${tld_name}"
   lan_ip="$(hostname -i)"
   samba_name="$(hostname)"
   join_status="$(net ads testjoin --kerberos 2>&1 | tail -1 | cut -d':' -f 1)"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** boredazfcuk/freeradius container for freeradius started *****"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** $(realpath "${0}") date: $(date --reference=$(realpath "${0}") +%Y/%m/%d_%H:%M) *****"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** $(realpath "${0}") hash: $(md5sum $(realpath "${0}") | awk '{print $1}') *****"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    $(cat /etc/*-release | grep "^NAME" | sed 's/NAME=//g' | sed 's/"//g') $(cat /etc/*-release | grep "VERSION_ID" | sed 's/VERSION_ID=//g' | sed 's/"//g')"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Configuration directory: ${config_dir}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Samba name: ${samba_name}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    LAN IP Address: ${lan_ip}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Time zone: ${TZ:=UTC}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Domain name: ${domain_name}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    TLD name: ${tld_name}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    DNS name: ${dns_name}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Primary KDC: ${primarykdc_name}.${dns_name}"
   if [ "${secondarykdc_name}" ]; then echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Secondary KDC: ${secondarykdc_name}.${dns_name}"; fi
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Domain Computers SID: ${domain_computers_sid}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    VPN Users SID: ${vpn_users_sid}"
}

AddFilterStripUsername(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Add strip_username function to filters"
   local filter_file
   filter_file="${config_dir}/filter"
   if [ "$(grep -c filter_strip_username "${filter_file}")" = 0 ]; then
      {
         echo
         echo 'filter_strip_username {' 
         echo -e "\t"'if ("%{request:User-Name}" =~ /^(.*)@(.*)/) {'
         echo -e "\t\t" '      update request {'
         echo -e "\t\t\t" '         Stripped-User-Name := "%{1}"'
         echo -e "\t\t\t" '         Realm := "%{2}"'
         echo -e "\t\t" '   }'
         echo -e "\t" '}'
         echo
         echo -e "\t" '   if ("%{request:User-Name}" =~ /^(.*?)\\\\(.+)$/) {'
         echo -e "\t\t" '      update request {'
         echo -e "\t\t\t" '         Stripped-User-Name := "%{2}"'
         echo -e "\t\t\t" '         Realm := "%{1}"'
         echo -e "\t\t" '      }'
         echo -e "\t" '   }'
         echo '}'
      } >> "${filter_file}"
   fi
}

AmendConfig(){
   local default_file
   default_file="${config_dir}/default"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Amend default file: ${default_file}"
   if [ "$(grep -c DOMAINNAME "${default_file}")" -gt 0 ]; then
      sed -i "s/DOMAINNAME/${domain_name}/" "${default_file}"
   fi
   if [ "$(grep -c TLDNAME "${default_file}")" -gt 0 ]; then
      sed -i "s/TLDNAME/${tld_name}/" "${default_file}"
   fi
   local inner_tunnel_file
   inner_tunnel_file="${config_dir}/inner-tunnel"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Amend inner-tunnel file: ${inner_tunnel_file}"
   if [ "$(grep -c DOMAINNAME "${inner_tunnel_file}")" -gt 0 ]; then
      sed -i "s/DOMAINNAME/${domain_name}/" "${inner_tunnel_file}"
   fi
   if [ "$(grep -c TLDNAME "${inner_tunnel_file}")" -gt 0 ]; then
      sed -i "s/TLDNAME/${tld_name}/" "${inner_tunnel_file}"
   fi
   local mschap_file
   mschap_file="${config_dir}/mschap"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Amend mschap file: ${mschap_file}"
   if [ "$(grep -c DOMAINNAME "${mschap_file}")" -gt 0 ]; then
      sed -i "s/DOMAINNAME/${domain_name^^}/g" "${mschap_file}"
   fi
   if [ "$(grep -c DOMAINCOMPUTERSSID "${mschap_file}")" -gt 0 ]; then
      sed -i "s/DOMAINCOMPUTERSSID/${domain_computers_sid}/" "${mschap_file}"
   fi
   if [ "$(grep -c VPNUSERSSID "${mschap_file}")" -gt 0 ]; then
      sed -i "s/VPNUSERSSID/${vpn_users_sid}/" "${mschap_file}"
   fi
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Amend ntlm_auth file"
   local ntlm_auth_file
   ntlm_auth_file="${config_dir}/ntlm_auth"
   if [ "$(grep -c DOMAINNAME "${ntlm_auth_file}")" -gt 0 ]; then
      sed -i "s/DOMAINNAME/${domain_name^^}/" "${ntlm_auth_file}"
   fi
   local krb5_file
   krb5_file="${config_dir}/krb5.conf"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Amend krb5 file: ${krb5_file}"
   if [ "$(grep -c LCDOMAINNAME "${krb5_file}")" -gt 0 ]; then
      sed -i "s/LCDOMAINNAME/${domain_name,,}/" "${krb5_file}"
   fi
   if [ "$(grep -c DOMAINNAME "${krb5_file}")" -gt 0 ]; then
      sed -i "s/DOMAINNAME/${domain_name^^}/" "${krb5_file}"
   fi
   if [ "$(grep -c LCTLDNAME "${krb5_file}")" -gt 0 ]; then
      sed -i "s/LCTLDNAME/${tld_name,,}/" "${krb5_file}"
   fi
   if [ "$(grep -c TLDNAME "${krb5_file}")" -gt 0 ]; then
      sed -i "s/TLDNAME/${tld_name^^}/" "${krb5_file}"
   fi
   if [ "$(grep -c PRIMARYKDC "${krb5_file}")" -gt 0 ]; then
      sed -i "s/PRIMARYKDC/${primarykdc_name^^}/" "${krb5_file}"
   fi
   if [ "${secondarykdc_name}" ]; then
      if [ "$(grep -c SECONDARYKDC "${krb5_file}")" -gt 0 ]; then
         sed -i "s/SECONDARYKDC/${secondarykdc_name^^}/" "${krb5_file}"
      fi
   else
      sed -i "/SECONDARYKDC/d" "${krb5_file}"
   fi
   local smb_file
   smb_file="${config_dir}/smb.conf"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Amend smb file: ${smb_file}"
   if [ "$(grep -c LCDOMAINNAME "${smb_file}")" -gt 0 ]; then
      sed -i "s/LCDOMAINNAME/${domain_name,,}/" "${smb_file}"
   fi
   if [ "$(grep -c DOMAINNAME "${smb_file}")" -gt 0 ]; then
      sed -i "s/DOMAINNAME/${domain_name^^}/g" "${smb_file}"
   fi
   if [ "$(grep -c LCTLDNAME "${smb_file}")" -gt 0 ]; then
      sed -i "s/LCTLDNAME/${tld_name,,}/" "${smb_file}"
   fi
   if [ "$(grep -c PRIMARYKDC "${smb_file}")" -gt 0 ]; then
      sed -i "s/PRIMARYKDC/${primarykdc_name^^}/" "${smb_file}"
   fi
   if [ "$(grep -c KRB5CONFIGDIR "${smb_file}")" -gt 0 ]; then
      sed -i 's/KRB5CONFIGDIR/${config_dir}/' "${smb_file}"
   fi
   local clients_file
   clients_file="${config_dir}/clients.conf"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Amend clients file: ${clients_file}"
   if [ "$(tail -1 "${clients_file}")" != "\$INCLUDE ${config_dir}/custom_clients.conf" ]; then
      echo "\$INCLUDE ${config_dir}/custom_clients.conf" >> "${clients_file}"
   fi
}

TestDomainJoin(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Domain member status: ${join_status}"
   if [ "${join_status}" != "Join is OK" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR:   ***** Container ${samba_name} is not joined to the domain *****"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    To join the domain, connect to the container with: docker exec -it <container_name> /bin/bash"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    E.g. docker exec -it freeradius /bin/bash"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Then from the terminal prompt, issue the command: net ads join --user Administrator@${dns_name} --no-dns-updates"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ...and enter the password when prompted. This container will restart in 5 minutes"
      sleep 300
      exit 1
   fi
}

LaunchFreeRadius(){
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Starting Winbind: $(/etc/init.d/winbind start)"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    ***** Configuration of FreeRadius container launch environment complete *****"
   if [ -z "${1}" ]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') INFO:    Starting FreeRadius"
      exec "$(which freeradius)" -X
   else
      exec "$@"
   fi
}

##### Script #####
Initialise
AddFilterStripUsername
AmendConfig
TestDomainJoin
LaunchFreeRadius
