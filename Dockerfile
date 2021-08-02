FROM debian:stable
MAINTAINER boredazfcuk

ENV config_dir="/config"

# Container version serves no real purpose. Increment to force a container rebuild.
ARG container_version="1.0.1"
ARG app_dependencies="freeradius samba winbind net-tools"

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED FOR freeradius ${container_version} *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install requirements" && \
   apt-get update && \
   apt-get install -y ${app_dependencies} && \
   mkdir --parents "${config_dir}" && \
   touch "${config_dir}/users.conf" "${config_dir}/custom_clients.conf" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Authorise" && \
   mv "/etc/freeradius/3.0/mods-config/files/authorize" "${config_dir}/authorize" && \
   ln -s "${config_dir}/authorize" "/etc/freeradius/3.0/mods-config/files/authorize" && \
   sed -i "/\$INCLUDE users.other/a \$INCLUDE ${config_dir}/users.conf" "${config_dir}/authorize" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Default" && \
   mv "/etc/freeradius/3.0/sites-available/default" "${config_dir}/default" && \
   ln -s "${config_dir}/default" "/etc/freeradius/3.0/sites-available/default" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Innter-Tunnel" && \
   mv "/etc/freeradius/3.0/sites-available/inner-tunnel" "${config_dir}/inner-tunnel" && \
   ln -s "${config_dir}/inner-tunnel" "/etc/freeradius/3.0/sites-available/inner-tunnel" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | NTLM Auth" && \
   mv "/etc/freeradius/3.0/mods-available/ntlm_auth" "${config_dir}/ntlm_auth" && \
   ln -s "${config_dir}/ntlm_auth" "/etc/freeradius/3.0/mods-available/ntlm_auth" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | MSCHAP" && \
   mv "/etc/freeradius/3.0/mods-available/mschap" "${config_dir}/mschap" && \
   ln -s "${config_dir}/mschap" "/etc/freeradius/3.0/mods-available/mschap" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Clients" && \
   mv "/etc/freeradius/3.0/clients.conf" "${config_dir}/clients.conf" && \
   ln -s "${config_dir}/clients.conf" "/etc/freeradius/3.0/clients.conf" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Filter" && \
   mv "/etc/freeradius/3.0/policy.d/filter" "${config_dir}/filter" && \
   ln -s "${config_dir}/filter" "/etc/freeradius/3.0/policy.d/filter" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Krb5" && \
   ln -s "${config_dir}/krb5.conf" "/etc/krb5.conf" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | NSSwitch" && \
   mv "/etc/nsswitch.conf" "${config_dir}/nsswitch.conf" && \
   ln -s "${config_dir}/nsswitch.conf" "/etc/nsswitch.conf" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | SMB configuration" && \
   mv "/etc/samba/smb.conf" "${config_dir}/smb.conf" && \
   ln -s "${config_dir}/smb.conf" "/etc/samba/smb.conf" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Samba" && \
   mv "/var/lib/samba" "${config_dir}" && \
   ln -s "${config_dir}/samba/" "/var/lib/samba" && \
   apt-get clean

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY bashrc.txt /root/.bashrc
COPY default "${config_dir}/default"
COPY inner-tunnel "${config_dir}/inner-tunnel"
COPY mschap "${config_dir}/mschap"
COPY ntlm_auth "${config_dir}/ntlm_auth"
COPY nsswitch.conf "${config_dir}/nsswitch.conf"
COPY krb5.conf "${config_dir}/krb5.conf"
COPY smb.conf "${config_dir}/smb.conf"

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on startup script and healthcheck" && \
   chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh && \
   chown 107:108 "${config_dir}/custom_clients.conf" "${config_dir}/default" "${config_dir}/inner-tunnel" "${config_dir}/mschap" "${config_dir}/ntlm_auth"

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
  CMD /usr/local/bin/healthcheck.sh
  
VOLUME "${config_dir}"

CMD /usr/local/bin/entrypoint.sh
