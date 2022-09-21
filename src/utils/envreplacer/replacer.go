// Extracted from Caddyfile parser:
// https://github.com/caddyserver/caddy/blob/master/caddyconfig/caddyfile/parse.go

package envreplacer

import (
	"bytes"
	"os"
	"strings"
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
		envString := input[begin+len(spanOpen) : end]
		if len(envString) == 0 {
			offset = end + len(spanClose)
			continue
		}

		// Split the string into a key and an optional default.
		envParts := strings.SplitN(string(envString), envVarDefaultDelimiter, 2)

		// Do a lookup for the env var, replace with the default if not found.
		envVarValue, found := os.LookupEnv(envParts[0])
		if !found && len(envParts) == 2 {
			envVarValue = envParts[1]
		}

		// Get the value of the environment variable.
		// Note that this causes one-level deep chaining.
		envVarBytes := []byte(envVarValue)

		// Splice in the value.
		input = append(input[:begin], append(envVarBytes, input[end+len(spanClose):]...)...)

		// Continue at the end of the replacement.
		offset = begin + len(envVarBytes)
	}
	return input, nil
}

// spanOpen and spanClose are used to bound spans that contain the name of an environment variable.
var (
	spanOpen, spanClose    = []byte{'{', '$'}, []byte{'}'}
	envVarDefaultDelimiter = ":"
)
