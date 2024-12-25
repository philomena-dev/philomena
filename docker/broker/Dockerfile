FROM rust:1.83-alpine

ADD https://api.github.com/repos/philomena-dev/FFmpeg/git/refs/heads/release/6.1 /tmp/ffmpeg_version.json
ADD https://api.github.com/repos/philomena-dev/cli_intensities/git/refs/heads/master /tmp/cli_intensities_version.json
ADD https://api.github.com/repos/philomena-dev/mediatools/git/refs/heads/master /tmp/mediatools_version.json

RUN (echo "https://github.com/philomena-dev/prebuilt-ffmpeg/raw/master"; cat /etc/apk/repositories) > /tmp/repositories \
    && cp /tmp/repositories /etc/apk/repositories \
    && apk update --allow-untrusted \
    && apk add build-base git ffmpeg ffmpeg-dev file-dev libjpeg-turbo-dev libpng-dev \
       gifsicle optipng libjpeg-turbo-utils librsvg rsvg-convert imagemagick --allow-untrusted \
    && git clone --depth 1 https://github.com/philomena-dev/cli_intensities /tmp/cli_intensities \
    && cd /tmp/cli_intensities \
    && make -j$(nproc) install \
    && git clone --depth 1 https://github.com/philomena-dev/mediatools /tmp/mediatools \
    && ln -s /usr/lib/librsvg-2.so.2 /usr/lib/librsvg-2.so \
    && cd /tmp/mediatools \
    && make -j$(nproc) install

COPY native/broker /tmp/broker
RUN cd /tmp/broker \
    && cargo build --release \
    && cp target/release/broker_server /usr/local/bin/broker_server

COPY docker/broker/safe-rsvg-convert /usr/local/bin/safe-rsvg-convert
ENV RUST_LOG=trace
CMD ["/usr/local/bin/broker_server", "0.0.0.0:1500"]
