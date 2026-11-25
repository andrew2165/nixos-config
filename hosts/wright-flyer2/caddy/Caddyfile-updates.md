# Proposed Caddyfile update

Add these lines inside the existing `authentication portal myportal` block:

```caddyfile
trust login redirect uri domain exact test.stewartinternal.com path prefix /
trust login redirect uri domain exact mealie.stewartinternal.com path prefix /
```

These allow post-login navigation back to the exact protected application hosts.
Client credentials, realm-to-role transformations and authorization policies stay
as they are. Apply the additions through the encrypted Caddyfile workflow.

Caddy comes from the shared `nixpkgs-unstable` input. Update that input in
`flake.lock` to upgrade Caddy. Update the plugin tags in `caddy.nix` to upgrade
the plugins and refresh the `withPlugins` hash when the vendored source changes.

The original Caddy 2.11.9 build with caddy-security 1.6.2 and CrowdSec 0.15.0
built successfully using a version override.
The local configuration with these additions passed all 60 runtime assertions,
including OIDC, authorization, TLS, proxying, logging, reload/restart and separate
CrowdSec tests. The supplied configuration without these additions failed its
post-login return check. Production connectivity and credentials were not tested.

Additional verification on 2026-11-06: **35/35 further synthetic integration tests
passed** on the same x86_64 Linux Caddy derivation and output, using the proposed
trust rules. Coverage included WebSockets, HTTP/2, binary POST bodies and encoded
queries, media ranges and conditional responses, forged/duplicate identity and
forwarded headers, invalid OIDC signatures/nonce/issuer/audience/expiry, callback
replay, untrusted redirect destinations, path-based authorization bypass attempts,
and backend outage/recovery. Failed syntax, certificate and listener reloads
preserved the prior configuration and sessions. A successful real configuration
reload preserved both an active SSE stream and an existing authenticated session;
fresh login and final service health also passed. No production credentials or
services were used. The additional harness and generated artifacts were removed.
