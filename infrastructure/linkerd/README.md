# Generate Linkerd v2 certificates

Install the step CLI on MacOS and Linux using Homebrew run:

```sh
brew install step
```

Generate the Linkerd trust anchor certificate:

```sh
step certificate create identity.linkerd.cluster.local ca.crt ca.key \
--san identity.linkerd.cluster.local \
--profile root-ca --no-password --insecure \
--not-after=87600h
```

