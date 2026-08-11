# syntax = docker/dockerfile:1
ARG RUBY_VERSION=3.4.1
FROM ruby:${RUBY_VERSION}-slim

WORKDIR /app

ENV BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
      build-essential git curl ca-certificates python3 unzip \
      ffmpeg libsodium-dev libopus-dev \
    && curl -fsSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp \
    && chmod a+rx /usr/local/bin/yt-dlp \
    && curl -fsSL https://deno.land/install.sh | sh -s -- -y --no-modify-path \
    && mv /root/.deno/bin/deno /usr/local/bin/deno \
    && rm -rf /root/.deno \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
      cmake libssl-dev nlohmann-json3-dev \
    && git clone https://github.com/cisco/mlspp.git /tmp/mlspp \
    && git -C /tmp/mlspp checkout 1cc50a124a3bc4e143a787ec934280dc70c1034d \
    && cmake -S /tmp/mlspp -B /tmp/mlspp/build -DBUILD_SHARED_LIBS=ON -DTESTING=OFF -DDISABLE_GREASE=ON -DMLS_CXX_NAMESPACE=mlspp -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /tmp/mlspp/build -j"$(nproc)" \
    && cmake --install /tmp/mlspp/build \
    && git clone --branch v1.1.1/cpp https://github.com/discord/libdave.git /tmp/libdave \
    && cmake -S /tmp/libdave/cpp -B /tmp/libdave/build -DBUILD_SHARED_LIBS=ON -DTESTING=OFF -DPERSISTENT_KEYS=OFF -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /tmp/libdave/build -j"$(nproc)" \
    && cmake --install /tmp/libdave/build \
    && rm -rf /tmp/mlspp /tmp/libdave \
    && ldconfig \
    && apt-get purge -y cmake \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN useradd bot --create-home --shell /bin/bash && chown -R bot:bot /app
USER bot:bot

CMD ["bin/bot"]
