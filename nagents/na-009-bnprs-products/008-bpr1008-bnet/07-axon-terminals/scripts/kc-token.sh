#!/bin/bash
# Mints a Keycloak client_credentials token for the smartpresence API. Prints ONLY the token.
set -u
V1_CONFIG="$HOME/BPR/GitRepos2/BPR1008_bNet/bpr1008.bnet.main/_BprFws/App.config"
cfg(){ grep -oE "key=\"$1\" value=\"[^\"]*\"" "$V1_CONFIG" | head -1 | sed 's/.*value="//;s/"$//'; }
curl -s -X POST "$(cfg Keycloak.TokenEndpoint)" \
  -d grant_type=client_credentials \
  -d client_id="$(cfg Keycloak.ClientId)" \
  --data-urlencode client_secret="$(cfg Keycloak.ClientSecret)" \
  | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])'
