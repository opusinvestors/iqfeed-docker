FROM ubuntu:kinetic

# env substitution not working properly so hard coded stuff below :(
ENV UBUNTU_NAME kinetic
ENV UBUNTU_VER 22.10

ENV LC_ALL C.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV DEBIAN_FRONTEND noninteractive
ENV DISPLAY :1

ENV IQFEED_PRODUCT_ID IQLINK
ENV IQFEED_PRODUCT_VERSION 6.2.0.25
ENV IQFEED_INSTALLER_BIN="iqfeed_client_6_2_0_25.exe"
ENV IQFEED_LOG_LEVEL 0xF222
ENV IQFEED_SHUTDOWN_DELAY 60

ENV WINEPREFIX /root/.wine
ENV WINEDEBUG -all

WORKDIR /root

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get upgrade -yq && \
    apt-get install -yq --no-install-recommends \
        software-properties-common apt-utils supervisor xvfb wget tar gpg-agent bbe netcat-openbsd net-tools && \
# Install python for pyiqfeed
    apt-get install -yq --no-install-recommends \
        git python3 python3-setuptools python3-numpy python3-pip python3-tz \
        python3-psycopg2 python3-dateutil python3-sqlalchemy python3-pandas && \
# Cleaning up.
    apt-get autoremove -y --purge && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install winehq-stable    
RUN wget -O - https://dl.winehq.org/wine-builds/winehq.key | apt-key add - && \
    add-apt-repository 'deb https://dl.winehq.org/wine-builds/ubuntu/ kinetic main' && \
    apt-get update && apt-get install -yq --no-install-recommends winehq-stable && \
    apt-get install -yq --no-install-recommends winbind winetricks cabextract && \
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
	chmod +x winetricks && mv winetricks /usr/local/bin && \
# Cleaning up.
    apt-get autoremove -y --purge && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Init wine instance
RUN winecfg && wineserver --wait
# Download iqfeed client
RUN wget -nv http://www.iqfeed.net/$IQFEED_INSTALLER_BIN -O /root/$IQFEED_INSTALLER_BIN
# Install iqfeed client
RUN xvfb-run -s -noreset -a wine64 /root/$IQFEED_INSTALLER_BIN /S && wineserver --wait
RUN wine64 reg add HKEY_CURRENT_USER\\\Software\\\DTN\\\IQFeed\\\Startup /t REG_DWORD /v LogLevel /d $IQFEED_LOG_LEVEL /f && wineserver --wait && \
    wine64 reg add HKEY_CURRENT_USER\\\Software\\\DTN\\\IQFeed\\\Startup /T REG_SZ /v SubmitAnonymousStats /d 0 /f && wineserver --wait && \
    wine64 reg add HKEY_CURRENT_USER\\\Software\\\DTN\\\IQFeed\\\Startup /t REG_SZ /v ShutdownDelayLastClient /d $IQFEED_SHUTDOWN_DELAY /f && wineserver --wait && \
    wine64 reg add HKEY_CURRENT_USER\\\Software\\\DTN\\\IQFeed\\\Startup /t REG_SZ /v ShutdownDelayStartup /d $IQFEED_SHUTDOWN_DELAY /f && wineserver --wait

# 'hack' to allow the client to listen on other interfaces
RUN bbe -e "s/127.0.0.1/000.0.0.0/g" "/root/.wine/drive_c/Program Files/DTN/IQFeed/iqconnect.exe" > "/root/.wine/drive_c/Program Files/DTN/IQFeed/iqconnect_patched.exe"

# cleanup
RUN apt-get autoremove -y --purge && \
    apt-get clean -y && \
    rm -rf /home/wine/.cache /var/lib/apt/lists/* /root/.wine/drive_c/iqfeed_install.exe

ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

EXPOSE 5009
EXPOSE 9100
EXPOSE 9200
EXPOSE 9300
EXPOSE 9400
