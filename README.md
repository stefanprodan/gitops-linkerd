# gitops-linkerd

Progressive Delivery with Linkerd, Flagger and Flux v2

## Prerequisites

In order to install the workshop prerequisites you'll need a Kubernetes cluster 1.18
or newer with Load Balancer support and RBAC enabled.

### Install Flux v2

Install the CLI on MacOS and Linux using Homebrew run:

```sh
brew install fluxcd/tap/flux
```

Install the controllers on your cluster:

```console
$ flux install

✚ generating manifests
✔ manifests build completed
► installing components in flux-system namespace
✔ install completed
◎ verifying installation
✔ source-controller ready
✔ kustomize-controller ready
✔ helm-controller ready
✔ notification-controller ready
✔ install finished
```

## Infrastructure setup

Create a source that points to this repository:

```sh
flux create source git flux-system \
--interval=1m \
--url=https://github.com/stefanprodan/gitops-linkerd \
--branch=v2
```

Create a Kustomization to reconcile Linkerd on your cluster:

```sh
flux create kustomization linkerd \
--source=gitops-linkerd \
--path="./infrastructure/linkerd" \
--prune=true \
--interval=30m \
--wait=true
```

Configure Flagger reconciliation specifying Linkerd as a dependency:

```sh
flux create kustomization flagger \
--depends-on=linkerd \
--source=gitops-linkerd \
--path="./infrastructure/flagger" \
--prune=true \
--interval=30m \
--wait=true
```

Configure Contour reconciliation specifying Linkerd as a dependency:

```sh
flux create kustomization ingress-nginx \
--depends-on=linkerd \
--source=gitops-linkerd \
--path="./infrastructure/ingress-nginx" \
--prune=true \
--validation=client \
--interval=30m \
--wait-true
```

## Workloads setup

Configure the frontend workload with A/B testing deployment strategy and
the backend workload with progressive traffic shifting:

```sh
flux create kustomization apps \
--depends-on=linkerd \
--source=gitops-linkerd \
--path="./apps" \
--prune=true \
--interval=30m \
--wait-true
```
