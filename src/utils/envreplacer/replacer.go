// Extracted from Caddyfile parser:
// https://github.com/caddyserver/caddy/blob/master/caddyconfig/caddyfile/parse.go

package envreplacer

import (
	"bytes"
	"os"
)

// Replace replaces all occurrences of environment variables.
func Replace(input []byte) ([]byte, error) {
	var offset int
	for {
		begin := bytes.Index(input[offset:], spanOpen)
		if begin < 0 {
			break
		}
		begin += offset // Make beginning relative to input, not offset.
		end := bytes.Index(input[begin+len(spanOpen):], spanClose)
		if end < 0 {
			break
		}
		end += begin + len(spanOpen) // Make end relative to input, not begin.

		// Get the name; if there is no name, skip it.
		envVarName := input[begin+len(spanOpen) : end]
		if len(envVarName) == 0 {
			offset = end + len(spanClose)
			continue
		}

		// Get the value of the environment variable.
		envVarValue := []byte(os.ExpandEnv(os.Getenv(string(envVarName))))

		// Splice in the value.
		input = append(input[:begin],
			append(envVarValue, input[end+len(spanClose):]...)...)

		// Continue at the end of the replacement.
		offset = begin + len(envVarValue)
	}
	return input, nil
}

// spanOpen and spanClose are used to bound spans that contain the name of an environment variable.
var spanOpen, spanClose = []byte{'{', '$'}, []byte{'}'}
