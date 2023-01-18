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

Generate the Linkerd issuer certificate and key:

```sh
step certificate create identity.linkerd.cluster.local issuer.crt issuer.key \
--san identity.linkerd.cluster.local --ca ca.crt --ca-key ca.key \
--profile intermediate-ca --no-password --insecure \
--not-after 8760h
```
