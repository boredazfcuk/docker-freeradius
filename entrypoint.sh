#!/bin/bash

##### Functions #####
Initialise(){
   echo
   lan_ip="$(hostname -i)"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO     ***** boredazfcuk/freeradius container for freeradius started *****"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO     ***** $(realpath "${0}") date: $(date --reference=$(realpath "${0}") +%Y/%m/%d_%H:%M) *****"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO     ***** $(realpath "${0}") hash: $(md5sum $(realpath "${0}") | awk '{print $1}') *****"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO     $(cat /etc/*-release | grep "^NAME" | sed 's/NAME=//g' | sed 's/"//g') $(cat /etc/*-release | grep "VERSION_ID" | sed 's/VERSION_ID=//g' | sed 's/"//g')"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO     LAN IP Address: ${lan_ip}"
   echo "$(date '+%Y-%m-%d %H:%M:%S') INFO     Time zone: ${TZ:=UTC}"
}

AddFilterStripUsername(){
   local filter_file
   filter_file="/etc/freeradius/3.0/policy.d/filter"
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
   default_file="/etc/freeradius/3.0/sites-available/default"
   if [ "$(grep -c DOMAINNAME "${default_file}")" > 0 ]; then
      sed -i "s/DOMAINNAME/${domain_name}/" "${default_file}"
   fi
   if [ "$(grep -c TLDNAME "${default_file}")" > 0 ]; then
      sed -i "s/TLDNAME/${tld_name}/" "${default_file}"
   fi

   local inner_tunnel_file
   inner_tunnel_file="/etc/freeradius/3.0/sites-available/inner-tunnel"
   if [ "$(grep -c DOMAINNAME "${inner_tunnel_file}")" > 0 ]; then
      sed -i "s/DOMAINNAME/${domain_name}/" "${inner_tunnel_file}"
   fi
   if [ "$(grep -c TLDNAME "${inner_tunnel_file}")" > 0 ]; then
      sed -i "s/TLDNAME/${tld_name}/" "${inner_tunnel_file}"
   fi

   local mschap_file
   mschap_file="/etc/freeradius/3.0/mods-available/mschap"
   if [ "$(grep -c DOMAINNAME "${mschap_file}")" > 0 ]; then
      sed -i "s/DOMAINNAME/${domain_name^^}/g" "${mschap_file}"
   fi
   if [ "$(grep -c DOMAINCOMPUTERSSID "${mschap_file}")" > 0 ]; then
      sed -i "s/DOMAINCOMPUTERSSID/${domain_computers_sid}/" "${mschap_file}"
   fi
   if [ "$(grep -c VPNUSERSSID "${mschap_file}")" > 0 ]; then
      sed -i "s/VPNUSERSSID/${vpn_users_sid}/" "${mschap_file}"
   fi

   local ntlm_auth_file
   ntlm_auth_file="/etc/freeradius/3.0/mods-available/ntlm_auth"
   if [ "$(grep -c DOMAINNAME "${ntlm_auth_file}")" > 0 ]; then
      sed -i "s/DOMAINNAME/${domain_name^^}/" "${ntlm_auth_file}"
   fi

   local krb5_file
   krb5_file="/etc/krb5.conf"
   if [ "$(grep -c LCDOMAINNAME "${krb5_file}")" > 0 ]; then
      sed -i "s/LCDOMAINNAME/${domain_name,,}/" "${krb5_file}"
   fi
   if [ "$(grep -c DOMAINNAME "${krb5_file}")" > 0 ]; then
      sed -i "s/DOMAINNAME/${domain_name^^}/" "${krb5_file}"
   fi
   if [ "$(grep -c LCTLDNAME "${krb5_file}")" > 0 ]; then
      sed -i "s/LCTLDNAME/${tld_name,,}/" "${krb5_file}"
   fi
   if [ "$(grep -c TLDNAME "${krb5_file}")" > 0 ]; then
      sed -i "s/TLDNAME/${tld_name^^}/" "${krb5_file}"
   fi
   if [ "$(grep -c PRIMARYKDC "${krb5_file}")" > 0 ]; then
      sed -i "s/PRIMARYKDC/${primarykdc_name^^}/" "${krb5_file}"
   fi
   if [ "${secondarykdc_name}" ]; then
      if [ "$(grep -c SECONDARYKDC "${krb5_file}")" > 0 ]; then
         sed -i "s/SECONDARYKDC/${secondarykdc_name^^}/" "${krb5_file}"
      fi
   else
      sed -i "/SECONDARYKDC/d" "${krb5_file}"
   fi

   local smb_file
   smb_file="/etc/samba/smb.conf"
   if [ "$(grep -c LCDOMAINNAME "${smb_file}")" > 0 ]; then
      sed -i "s/LCDOMAINNAME/${domain_name,,}/" "${smb_file}"
   fi
   if [ "$(grep -c DOMAINNAME "${smb_file}")" > 0 ]; then
      sed -i "s/DOMAINNAME/${domain_name^^}/g" "${smb_file}"
   fi
   if [ "$(grep -c LCTLDNAME "${smb_file}")" > 0 ]; then
      sed -i "s/LCTLDNAME/${tld_name,,}/" "${smb_file}"
   fi
   if [ "$(grep -c PRIMARYKDC "${smb_file}")" > 0 ]; then
      sed -i "s/PRIMARYKDC/${primarykdc_name^^}/" "${smb_file}"
   fi

}

LaunchFreeRadius (){
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
LaunchFreeRadius
