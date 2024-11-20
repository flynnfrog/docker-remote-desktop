# Build xrdp pulseaudio modules in builder container
# See https://github.com/neutrinolabs/pulseaudio-module-xrdp/wiki/README
ARG TAG=bookworm
FROM debian:$TAG as builder

RUN sed 's/Types: deb/Types: deb deb-src/g' -i /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-cache showsrc pulseaudio | grep "^Version: " | awk '{print $2}' | cut -f1 -d- > /tmp/pulseaudio.ver \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        build-essential \
        dpkg-dev \
		doxygen \
        git \
        libpulse-dev \
		meson \
		ninja-build \
        pulseaudio \
    && apt-get build-dep -y pulseaudio \
    && apt-get source pulseaudio \
    && rm -rf /var/lib/apt/lists/*

RUN cd "/pulseaudio-$(cat /tmp/pulseaudio.ver)" \
	&& meson build
	
RUN git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git /pulseaudio-module-xrdp \
    && cd /pulseaudio-module-xrdp \
    && ./bootstrap \
    && ./configure PULSE_DIR="/pulseaudio-$(cat /tmp/pulseaudio.ver)" \
    && make \
    && make install

# Build the final image
FROM debian:$TAG-slim

RUN apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        dbus-x11 \
        locales \
        pavucontrol \
        pulseaudio \
        pulseaudio-utils \
        sudo \
        x11-xserver-utils \
        xfce4 \
        xfce4-terminal \
        xfce4-pulseaudio-plugin \
        xorgxrdp \
        xrdp \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i -E 's/^; autospawn =.*/autospawn = yes/' /etc/pulse/client.conf \
    && [ -f /etc/pulse/client.conf.d/00-disable-autospawn.conf ] && sed -i -E 's/^(autospawn=.*)/# \1/' /etc/pulse/client.conf.d/00-disable-autospawn.conf || : \
    && locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8

COPY --from=builder /usr/lib/pulse-*/modules/module-xrdp-sink.so /usr/lib/pulse-*/modules/module-xrdp-source.so /var/lib/xrdp-pulseaudio-installer/
COPY entrypoint.sh /usr/bin/entrypoint
RUN chmod +x /usr/bin/entrypoint
EXPOSE 3389/tcp
ENTRYPOINT ["/usr/bin/entrypoint"]
