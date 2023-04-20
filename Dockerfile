FROM debian:stable-slim

ARG steamcmd_url="https://raw.githubusercontent.com/eallion/csserver/main/mod/steamcmd_linux.tar.gz"
ARG rehlds_url="https://raw.githubusercontent.com/eallion/csserver/main/mod/rehlds-bin-3.12.0.780.zip"
ARG metamod_url="https://raw.githubusercontent.com/eallion/csserver/main/mod/metamod-bin-1.3.0.131.zip"
ARG amxmod_url="https://raw.githubusercontent.com/eallion/csserver/main/mod/amxmodx-1.9.0-git5294-base-linux.tar.gz"
ARG amxmod_cstrike_url="https://raw.githubusercontent.com/eallion/csserver/main/mod/amxmodx-1.9.0-git5294-cstrike-linux.tar.gz"
ARG revoice_url="https://raw.githubusercontent.com/eallion/csserver/main/mod/revoice_0.1.0.34.zip"
ARG cmps_url="https://raw.githubusercontent.com/eallion/csserver/main/mod/cmps3.7.zip"

# Fix warning:
# WARNING: setlocale('en_US.UTF-8') failed, using locale: 'C'.
# International characters may not work.
RUN apt-get update && apt-get install -y locales \
 && rm -rf /var/lib/apt/lists/* \
 && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8
ENV LC_ALL en_US.UTF-8

# Fix error:
# Unable to determine CPU Frequency. Try defining CPU_MHZ.
# Exiting on SPEW_ABORT
ENV CPU_MHZ=2300

RUN groupadd -r steam && useradd -r -g steam -m -d /opt/steam steam

RUN apt-get -y update && apt-get install -y \
    ca-certificates \
    curl \
    lib32gcc-s1 \
    unzip \
    xz-utils \
    zip \
 && apt-get -y autoremove \
 && rm -rf /var/lib/apt/lists/*

USER steam
WORKDIR /opt/steam
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY ./lib/hlds.install /opt/steam

RUN curl -sL "$steamcmd_url" | tar xzvf - \
    && ./steamcmd.sh +runscript hlds.install

# Fix error that steamclient.so is missing
RUN mkdir -p "$HOME/.steam" \
    && ln -s /opt/steam/linux32 "$HOME/.steam/sdk32"

# Fix warnings:
# couldn't exec listip.cfg
# couldn't exec banned.cfg
RUN touch /opt/steam/hlds/cstrike/listip.cfg
RUN touch /opt/steam/hlds/cstrike/banned.cfg

# Install reverse-engineered HLDS
RUN curl -sLJO "$rehlds_url" \
    && unzip "rehlds-bin-3.12.0.780.zip" -d "/opt/steam/rehlds" \
    && cp -R /opt/steam/rehlds/bin/linux32/* /opt/steam/hlds/ \
    && rm -rf "rehlds-bin-3.12.0.780.zip" "/opt/steam/rehlds"

# Install Metamod-r
RUN curl -sLJO "$metamod_url" \
    && unzip "metamod-bin-1.3.0.131.zip" -d "/opt/steam/metamod" \
    && cp -R /opt/steam/metamod/addons /opt/steam/hlds/cstrike/ \
    && rm -rf "metamod-bin-1.3.0.131.zip" "/opt/steam/metamod" \
    && touch /opt/steam/hlds/cstrike/addons/metamod/plugins.ini \
    && sed -i 's/dlls\/cs\.so/addons\/metamod\/metamod_i386\.so/g' /opt/steam/hlds/cstrike/liblist.gam

# Install AMX mod X
RUN curl -sqL "$amxmod_url" | tar -C /opt/steam/hlds/cstrike/ -zxvf -

# Install AMX mod X CStrike
RUN curl -sqL "$amxmod_cstrike_url" | tar -C /opt/steam/hlds/cstrike/ -zxvf - \
    && cat /opt/steam/hlds/cstrike/mapcycle.txt >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/maps.ini \
    && echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >> /opt/steam/hlds/cstrike/addons/metamod/plugins.ini

# Install reunion
RUN mkdir -p /opt/steam/hlds/cstrike/addons/reunion
COPY lib/reunion/bin/Linux/reunion_mm_i386.so /opt/steam/hlds/cstrike/addons/reunion/reunion_mm_i386.so
COPY lib/reunion/reunion.cfg /opt/steam/hlds/cstrike/reunion.cfg
COPY lib/reunion/amxx/* /opt/steam/hlds/cstrike/addons/amxmodx/scripting/
RUN echo 'linux addons/reunion/reunion_mm_i386.so' >> /opt/steam/hlds/cstrike/addons/metamod/plugins.ini \
    && sed -i 's/Setti_Prefix1 = 5/Setti_Prefix1 = 4/g' /opt/steam/hlds/cstrike/reunion.cfg

# Install revoice
RUN curl -sL "$revoice_url" -o "revoice.zip" \
    && unzip "revoice.zip" -d "/opt/steam/revoice" \
    && mkdir /opt/steam/hlds/cstrike/addons/revoice \
    && cp /opt/steam/revoice/bin/linux32/revoice_mm_i386.so /opt/steam/hlds/cstrike/addons/revoice/revoice_mm_i386.so \
    && cp /opt/steam/revoice/revoice.cfg /opt/steam/hlds/cstrike/addons/revoice/revoice.cfg \
    && echo 'linux addons/revoice/revoice_mm_i386.so' >> /opt/steam/hlds/cstrike/addons/metamod/plugins.ini \
    && rm -rf "revoice.zip" "/opt/steam/revoice"

# Install cmps 比赛插件
RUN curl -sL "$cmps_url" -o "cmps.zip" \
    && unzip "cmps.zip" -d "/opt/steam/cmps" \
    && cp -R /opt/steam/cmps/configs/CmpsCFG /opt/steam/hlds/cstrike/addons/amxmodx/configs/CmpsCFG \
    && cp /opt/steam/cmps/configs/key_bind.ini /opt/steam/hlds/cstrike/addons/amxmodx/configs/key_bind.ini \
    && cp /opt/steam/cmps/plugins/cmps_fix.amxx /opt/steam/hlds/cstrike/addons/amxmodx/plugins/cmps_fix.amxx \
    && cp /opt/steam/cmps/plugins/match_stats.amxx /opt/steam/hlds/cstrike/addons/amxmodx/plugins/match_stats.amxx \
    && echo 'cmps_fix.amxx            ; binds keys for voting' >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/plugins.ini
    && echo 'match_stats.amxx            ; binds keys for voting' >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/plugins.ini
    && rm -rf "cmps.zip" "/opt/steam/cmps"

# Install bind_key
COPY lib/bind_key/amxx/bind_key.amxx /opt/steam/hlds/cstrike/addons/amxmodx/plugins/bind_key.amxx
RUN echo 'bind_key.amxx            ; binds keys for voting' >> /opt/steam/hlds/cstrike/addons/amxmodx/configs/plugins.ini

WORKDIR /opt/steam/hlds

# Copy default config
COPY cstrike cstrike

RUN chmod +x hlds_run hlds_linux

RUN echo 70 > steam_appid.txt

EXPOSE 27015
EXPOSE 27015/udp

# Start server
ENTRYPOINT ["./hlds_run", "-timeout 3", "-pingboost 1"]

# Default start parameters
CMD ["-game cstrike", "+map de_dust2", "+rcon_password 12345678"]
