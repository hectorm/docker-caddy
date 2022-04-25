package main

import (
	caddycmd "github.com/caddyserver/caddy/v2/cmd"

	// This is where modules get plugged in:

	_ "github.com/caddyserver/caddy/v2/modules/standard"

	_ "github.com/caddyserver/transform-encoder"
	_ "github.com/mholt/caddy-l4"

	_ "github.com/caddy-dns/cloudflare"

	_ "caddy/modules/cueadapter"
	_ "caddy/modules/tomladapter"
)

func main() {
	caddycmd.Main()
}
