package main

import (
	caddycmd "github.com/caddyserver/caddy/v2/cmd"

	// This is where modules get plugged in:

	_ "github.com/caddyserver/caddy/v2/modules/standard"

	_ "github.com/caddy-dns/cloudflare"
	_ "github.com/caddy-dns/lego-deprecated"
	_ "github.com/mholt/caddy-l4"

	_ "caddy/modules/cueadapter"
	_ "caddy/modules/tomladapter"
)

func main() {
	caddycmd.Main()
}
