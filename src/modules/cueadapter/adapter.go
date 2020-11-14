package cueadapter

import (
	"github.com/caddyserver/caddy/v2/caddyconfig"
	"cuelang.org/go/cue"
)

func init() {
	caddyconfig.RegisterAdapter("cue", Adapter{})
}

// Adapter adapts CUE to Caddy JSON.
type Adapter struct{}

// Adapt converts the CUE config in body to Caddy JSON.
func (a Adapter) Adapt(body []byte, options map[string]interface{}) ([]byte, []caddyconfig.Warning, error) {
	var runtime cue.Runtime
	instance, err := runtime.Compile("Caddyfile.cue", body)
	if err != nil {
		return nil, nil, err
	}
	result, err := instance.Value().MarshalJSON()
	if err != nil {
		return nil, nil, err
	}
	return result, nil, nil
}

// Interface guard.
var _ caddyconfig.Adapter = (*Adapter)(nil)
