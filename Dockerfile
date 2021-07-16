FROM debian:stable
MAINTAINER boredazfcuk

ENV config_dir="/config"

# Container version serves no real purpose. Increment to force a container rebuild.
ARG container_version="1.0.0"
ARG app_dependencies="freeradius samba winbind net-tools"

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED FOR freeradius ${container_version} *****" && \
echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install requirements" && \
   apt-get update && \
   apt-get install -y ${app_dependencies} && \
   mkdir --parents "${config_dir}" && \
   touch "${config_dir}/users.vpn" && \
   ln -s "${config_dir}/users.vpn" "/etc/freeradius/3.0/users.vpn" && \
   sed -i "/\$INCLUDE users.other/a \$INCLUDE ${config_dir}/users.vpn" "/etc/freeradius/3.0/mods-config/files/authorize" && \
   apt-get clean

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY bashrc.txt /root/.bashrc
COPY default /etc/freeradius/3.0/sites-available/default
COPY inner-tunnel /etc/freeradius/3.0/sites-available/inner-tunnel
COPY mschap /etc/freeradius/3.0/mods-available/mschap
COPY ntlm_auth /etc/freeradius/3.0/mods-available/ntlm_auth
COPY nsswitch.conf /etc/nsswitch.conf
COPY krb5.conf /etc/krb5.conf
COPY smb.conf /etc/samba/smb.conf

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | Set permissions on startup script and healthcheck" && \
   chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh && \
   chown 106:107 /etc/freeradius/3.0/mods-available/mschap /etc/freeradius/3.0/mods-available/ntlm_auth

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s \
  CMD /usr/local/bin/healthcheck.sh
  
VOLUME "${config_dir}"

CMD /usr/local/bin/entrypoint.sh
