FROM rust:1.62-bullseye AS librespot

RUN apt-get update \
 && apt-get -y install build-essential portaudio19-dev curl \
 && apt-get clean && rm -fR /var/lib/apt/lists

ARG LIBRESPOT_VERSION=0.4.2

COPY ./install-librespot.sh /tmp/
RUN --mount=type=tmpfs,size=512M,target=/usr/local/cargo/registry/index /tmp/install-librespot.sh

###

FROM alpine:edge AS builder
WORKDIR /snapcast

RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories
RUN apk add --no-cache curl bash librespot git alpine-sdk libvorbis-dev soxr-dev flac-dev avahi-dev expat-dev boost-dev opus-dev alsa-lib-dev npm
RUN git clone --branch develop https://github.com/badaix/snapcast.git /snapcast
RUN npm install --silent --save-dev -g typescript@4.3
RUN curl -L https://github.com/badaix/snapweb/archive/refs/tags/v0.2.0.tar.gz | tar xz --directory / && cd /snapweb-0.2.0 && make
RUN make server

###

FROM debian:bullseye

RUN echo "deb http://deb.debian.org/debian bullseye-backports main" >/etc/apt/sources.list.d/bullseye-backports.list

RUN apt-get update \
 && apt-get -y install snapserver/bullseye-backports \
 && apt-get clean && rm -fR /var/lib/apt/lists

COPY --from=builder /snapcast/server/snapserver /usr/bin/
COPY --from=builder /snapweb-0.2.0/dist /usr/share/snapserver/snapweb
COPY --from=librespot /usr/local/cargo/bin/librespot /usr/local/bin/

COPY run.sh /
CMD ["/run.sh"]

ENV DEVICE_NAME=Snapcast
EXPOSE 1704/tcp 1705/tcp
