FROM killua99/node-ruby AS assets-compiled

ARG MASTODON_VERSION=2.9.3

COPY mastodon-upstream /tmp/mastodon-build

RUN set -eux; \
    \
    mkdir -p /opt/mastodon && \
    cp /tmp/mastodon-build/Gemfile* /opt/mastodon/ && \
    cp /tmp/mastodon-build/package.json /opt/mastodon/ && \
    cp /tmp/mastodon-build/yarn.lock /opt/mastodon/ && \
    cd /opt/mastodon && \
    bundle config set deployment 'true' && \
    bundle config set without 'development test' && \
    bundle install -j$(nproc) && \
    yarn install --pure-lockfile && \
    yarn cache clean

FROM assets-compiled AS final

# Copy mastodon
COPY --chown=991:991 mastodon-upstream /opt/mastodon
COPY --from=assets-compiled --chown=991:991 /opt/mastodon /opt/mastodon
ADD --chown=991:991 https://raw.githubusercontent.com/eficode/wait-for/master/wait-for /wait-for

ARG UID=991
ARG GID=991

# Compiling assets.
RUN set -eux; \
    \
    chmod a+x /wait-for && \
    addgroup --gid ${GID} mastodon && \
    adduser -D -u ${UID} -G mastodon -h /opt/mastodon mastodon && \
    cd /opt/mastodon && \
    ln -s /opt/mastodon /mastodon

# Run mastodon services in prod mode
ENV RAILS_ENV="production"
ENV NODE_ENV="production"

# Tell rails to serve static files
ENV RAILS_SERVE_STATIC_FILES="true"
ENV BIND="0.0.0.0"
ENV PATH="${PATH}:/opt/mastodon/bin"

# Set the run user
USER mastodon

# Precompile assets
RUN set -eux; \
    \
    cd ~ \
    OTP_SECRET=precompile_placeholder SECRET_KEY_BASE=precompile_placeholder rails assets:precompile

# Set the work dir and the container entry point
WORKDIR /opt/mastodon

ENTRYPOINT [ "/sbin/tini", "--" ]

EXPOSE 3000 4000
