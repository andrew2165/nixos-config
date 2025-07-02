FROM caddy:2.10-builder AS builder

RUN xcaddy build \
    --with github.com/greenpau/caddy-security \
    --with github.com/hslatman/caddy-crowdsec-bouncer/crowdsec

FROM caddy:2.10

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
