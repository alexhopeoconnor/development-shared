# Development shared tooling

This repository contains small, sourceable Bash helpers and an explicit .NET
package-packing command intended for application-owned wrappers. It does not
choose application paths, versions, registries, destinations, or release
policy.

The public API is under `tooling/bash/`. Its libraries are safe to source:
they define functions and constants but do not call Git, Docker, or `dotnet`
until a caller invokes a function. See [the Bash tooling guide](tooling/bash/README.md)
for the supported interfaces.

Released source is available under the [MIT License](LICENSE).
