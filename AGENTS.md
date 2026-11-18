# Development shared contributor guide

This repository owns small, reusable development helpers. Keep every public
command explicit about its inputs and leave application paths, versions,
registries, deployment policy, and runtime topology to consuming wrappers.

Libraries must be safe to source: defining a library must not run Git, Docker,
or `dotnet`, mutate source, create output, or contact a remote service. Keep
public examples and fixtures generic; do not add environment-specific paths,
hosts, credentials, or release records.

Test changed shell behavior with focused mocked commands where practical. Do
not make a command publish, tag, or otherwise mutate a remote as part of a
test.
