FROM debian:stable

# Install build deps.
RUN \
  echo 'APT::Install-Recommends "0";' > /etc/apt/apt.conf.d/99recommends && \
  echo 'deb http://ftp.se.debian.org/debian/ jessie main' > /etc/apt/sources.list && \
  echo 'deb http://security.debian.org/ jessie/updates main' >> /etc/apt/sources.list && \
  apt-get -o Acquire::ForceIPv4=true update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -o Acquire::ForceIPv4=true -yq \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    help2man \
    git \
    gperf \
    libglib2.0-dev \
    libtool

# Build naemon-core.
USER nobody
RUN \
  cd /tmp && \
  git clone --progress https://github.com/naemon/naemon-core.git && \
  cd naemon-core && \
  git reset --hard d77b41b0f4e171a7d62afa9d15b2624d3ae1405d && \
  ./autogen.sh && \
  make clean && \
  ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --libdir=/usr/lib/naemon \
    --with-tempdir=/var/lib/naemon \
    --with-lockfile=/run/naemon/naemon.pid \
    --with-logdir=/var/log/naemon \
    --with-logrotatedir=/etc/logrotate.d \
    --with-pluginsdir=/usr/lib/naemon/plugins \
    --with-checkresultdir=/var/lib/naemon/tmp && \
  make && \
  mkdir /tmp/dst && \
  DESTDIR=/tmp/dst make install

# Install naemon-core.
USER root
RUN \
  groupadd -r naemon && \
  useradd -M -d /home/naemon -g naemon -r -s /bin/false naemon && \
  cd /tmp/dst && \
  chown -Rh root: . && \
  find . -type f -print0 | xargs -0 chmod -c 0644 && \
  find . -type d -print0 | xargs -0 chmod -c 0755 && \
  chmod -c 0755 usr/bin/* && \
  chmod -c 0755 usr/lib/naemon/libnaemon.so* && \
  mkdir -p \
    /etc/naemon \
    /usr/include \
    /usr/lib/naemon \
    /usr/lib/pkgconfig \
    /var/lib/naemon/tmp \
    /var/log/naemon && \
  cp -rv etc/naemon/* /etc/naemon/ && \
  cp -v usr/bin/* /usr/bin/ && \
  cp -v usr/lib/naemon/libnaemon.so* /usr/lib/naemon/ && \
  cp -rv usr/include/naemon /usr/include/naemon && \
  cp -v usr/lib/naemon/pkgconfig/naemon.pc /usr/lib/pkgconfig/ && \
  ln -sv /usr/lib/nagios/plugins /usr/lib/naemon/plugins && \
  chown -Rh naemon: /var/lib/naemon /var/log/naemon && \
  chmod 700 /var/log/naemon /var/log/naemon && \
  chown -h root:naemon /etc/naemon && \
  chmod 750 /etc/naemon && \
  cd /tmp && rm -rf -- *

# Build naemon-livestatus.
USER nobody
RUN \
  cd /tmp && \
  git clone --progress https://github.com/naemon/naemon-livestatus.git && \
  cd naemon-livestatus && \
  git reset --hard 83f9a02b416f8b8d489c1924a3c31c2af60af3f1 && \
  autoreconf -s -i && \
  ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --libdir=/usr/lib/naemon \
    --with-naemon-config-dir=/etc/naemon/modules.d && \
  make && \
  mkdir /tmp/dst && \
  DESTDIR=/tmp/dst make install

# Install naemon-livestatus.
USER root
RUN \
  cd /tmp/dst && \
  chown -Rh root: . && \
  find . -type f -print0 | xargs -0 chmod -c 0644 && \
  find . -type d -print0 | xargs -0 chmod -c 0755 && \
  chmod -c 0755 usr/bin/* && \
  mkdir -p \
    /etc/naemon/modules.d \
    /usr/lib/naemon/naemon-livestatus && \
  cp -v usr/bin/* /usr/bin/ && \
  cp -v usr/lib/naemon/naemon-livestatus/livestatus.* /usr/lib/naemon/naemon-livestatus/ && \
  echo 'broker_module=/usr/lib/naemon/naemon-livestatus/livestatus.so /var/lib/naemon/live' > /etc/naemon/modules.d/livestatus.cfg && \
  echo 'event_broker_options=-1' >> /etc/naemon/modules.d/livestatus.cfg && \
  cd /tmp && rm -rf -- *

# Remove build deps.
USER root
RUN \
  usermod -d /home/naemon naemon && \
  DEBIAN_FRONTEND=noninteractive apt-get --purge remove -yq \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    help2man \
    git \
    gperf \
    libglib2.0-dev \
    libtool && \
  DEBIAN_FRONTEND=noninteractive apt-get --purge autoremove -yq

# Install deps to naemon.
RUN \
  DEBIAN_FRONTEND=noninteractive apt-get install -o Acquire::ForceIPv4=true -yq \
    dnsutils \
    libglib2.0-0 \
    monitoring-plugins-basic \
    monitoring-plugins-standard \
    nagios-nrpe-plugin \
    supervisor && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

RUN rm -rf /etc/naemon/conf.d/*

COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf

COPY ./naemon.cfg /etc/naemon/naemon.cfg
COPY ./main.cfg /etc/naemon/conf.d
COPY ./test.sh /usr/lib/nagios/plugins/test.sh

ENTRYPOINT ["supervisord"]
