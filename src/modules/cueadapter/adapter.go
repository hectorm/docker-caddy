package cueadapter

import (
	"github.com/caddyserver/caddy/v2/caddyconfig"
	"cuelang.org/go/cue"

	"caddy/utils/envreplacer"
)

func init() {
	caddyconfig.RegisterAdapter("cue", Adapter{})
}

// Adapter adapts CUE to Caddy JSON.
type Adapter struct{}

// Adapt converts the CUE config in body to Caddy JSON.
func (a Adapter) Adapt(body []byte, options map[string]interface{}) ([]byte, []caddyconfig.Warning, error) {
	bodyReplaced, err := envreplacer.Replace(body)
	if err != nil {
		return nil, nil, err
	}
	var runtime cue.Runtime
	instance, err := runtime.Compile("Caddyfile.cue", bodyReplaced)
	if err != nil {
		return nil, nil, err
	}
	json, err := instance.Value().MarshalJSON()
	if err != nil {
		return nil, nil, err
	}
	return json, nil, nil
}

// Interface guard.
var _ caddyconfig.Adapter = (*Adapter)(nil)
