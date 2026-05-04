FROM alpine:3.23.4

USER root

RUN apk add parted e2fsprogs wget rsync qemu-img

COPY ./defaults/apks /apks
RUN cd apks && \
    xargs -n 1 apk fetch --recursive < packages

COPY defaults/usr /usr
COPY defaults/overlay /overlay