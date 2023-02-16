# Real-World GitOps: Flux, Flagger, and Linkerd

This is the documentation - and executable code! - for the Service Mesh
Academy workshop on Flux, Flagger, and Linkerd. The easiest way to use this
file is to execute it with [demosh].

Things in Markdown comments are safe to ignore when reading this later. When
executing this with [demosh], things after the horizontal rule below (which
is just before a commented `@SHOW` directive) will get displayed.

[demosh]: https://github.com/BuoyantIO/demosh

This workshop requires some fairly specific setup.

- First, you need a running Kubernetes cluster that can support `LoadBalancer`
  services.

- Second, you need to fork https://github.com/kflynn/gitops-linkerd and
  https://github.com/BuoyantIO/faces-demo under your own account. You also
  need to set GITHUB_USER to your GitHub username, and GITHUB_TOKEN to a
  personal access token under your account with `repo` scope.

- Third, you need to clone your two forked repos side-by-side in the directory
  tree, so that "gitops-linkerd" and "faces-demo" are siblings. Both of these
  clones need to be in their `main` branch.

- Finally, you need to edit `apps/faces/faces-sync.yaml` in your clone of
  `gitops-linkerd` to point to your fork of faces-demo -- change the `url`
  field on line 8 as appropriate.

When you use `demosh` to run this file (from your `gitops-linkerd` clone), all
of the above will be checked for you.

<!-- set -e >
<!-- @import demosh/demo-tools.sh -->
<!-- @import demosh/check-requirements.sh -->
<!-- @import demosh/check-github.sh -->

<!-- @start_livecast -->

```bash
BAT_STYLE="grid,numbers"
```

---
<!-- @SHOW -->

# Real-World GitOps: Flux, Flagger, and Linkerd

Welcome to the Service Mesh Academy workshop on Flux, Flagger, Weave GitOps,
and Linkerd. We're starting with an empty cluster, so the first task is to
bootstrap Flux itself. Flux will be bootstrapping everything else.

Note the `--owner` and `--repository` switches here: we are explicitly looking
for the `${GITHUB_USER}/gitops-linkerd` repo here.

```bash
flux bootstrap github \
  --owner=${GITHUB_USER} \
  --repository=gitops-linkerd \
  --branch=main \
  --path=./clusters/my-cluster \
  --personal
```

At this point Flux will install its own in-cluster services, then continue
with all the other components we've defined (Weave GitOps, Linkerd, Flagger,
etc.). We can see what it's doing by looking at its Kustomization resources:

```bash
flux get kustomizations
```

Bootstrapping everything can take a little while, of course, so there's a
`--watch` switch that can be nice. We'll use that to keep an eye on what's
going on, and make sure that everything is proceeding correctly:

```bash
flux get kustomizations --watch
```

One thing to be aware of here: note that that last line says "Applied", not
"applied and everything is ready". Let's also wait until our application is
completely running:

```bash
kubectl rollout status -n faces deployments
watch kubectl get pods -n faces
```

<!-- @clear -->

# Dashboards

At this point, our application is happily running. It's called Faces, and it's
a single-page web app that... shows faces in a web browser, as we can see at
http://127-0-0-1.faces.sslip.io/.

<!-- @browser_then_terminal -->

We also have two dashboards that we can see in the browser:

- The Linkerd Viz dashboard is at http://127-0-0-1.linkerd.sslip.io/
- The Weave GitOps dashboard is at http://127-0-0-1.wego.sslip.io/

Let's go check those out. These are not specific to our application; they
provide insight into what's happening under the hood.

<!-- @browser_then_terminal -->

# What's Under The Hood

Now that we have things running, let's back up and look at _exactly_ how Flux
pulls everything together. A good first step here is to look back at the `flux
bootstrap` command we used to kick everything off:

```
flux bootstrap github \
  --owner=${GITHUB_USER} \
  --repository=gitops-linkerd \
  --branch=main \
  --path=./clusters/my-cluster \
  --personal
```

The `path` argument there defines where Flux will look to get the definitions
for how to set up the cluster. If we look there, we'll see two files:
`apps.yaml` and `infrastructure.yaml`. (We also see `flux-system`, which is
for configuration of the core Flux components themselves -- we're not going to
look into this during this workshop.)

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
ls -l clusters/my-cluster
```

<!-- @clear -->

`infrastructure.yaml` is a good place to look first. Let's look at the first
two documents in this file with `yq`.

The first document defines a `Kustomization` resource called `cert-manager`.
This Kustomization lives in the `flux-system` namespace, doesn't depend on
anything, and has `kustomize` files at `infrastructure/cert-manager`:

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
yq 'select(document_index == 0)' clusters/my-cluster/infrastructure.yaml \
    | bat -l yaml
```

<!-- @clear -->

The second document defines a Kustomization called `linkerd`, also in the
`flux-system` namespace. It depends on `cert-manager`, and has `kustomize`
files at `infrastructure/linkerd`.

(That `dependsOn` element is worth an extra callout: it's an extremely
powerful aspect of Flux that makes setting up complex applications really
easy.)

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
yq 'select(document_index == 1)' clusters/my-cluster/infrastructure.yaml \
    | bat -l yaml
```

<!-- @clear -->

Let's look quickly at `cert-manager`'s `kustomize` files:

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
ls -l ./infrastructure/cert-manager
```

The `kustomization.yaml` file tells `kustomize` what other files to use:

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
bat ./infrastructure/cert-manager/kustomization.yaml
```

<!-- @clear -->

If we look at those three files, the interesting thing to note with them is
that they're just ordinary YAML. We're not using `kustomize`'s ability to
patch things here; we're just using it to sequence applying some YAML -- and
some of the YAML is for Flux resources rather than Kubernetes resources.

`namespace.yaml` creates the `cert-manager` namespace:

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
bat ./infrastructure/cert-manager/namespace.yaml
```

`repository.yaml` tells Flux where to find the Helm chart for `cert-manager`:

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
bat ./infrastructure/cert-manager/repository.yaml
```

Finally, `release.yaml` tells Flux how to use the Helm chart to install
`cert-manager`:

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
bat ./infrastructure/cert-manager/release.yaml
```

Again, we're not actually using `kustomize` to patch anything here: all we're
doing is telling it to create some resources for us.

<!-- @wait_clear -->

We won't look at all the other components in `infrastructure`, but there's one
important thing buried in `infrastructure/flagger`. Here's what that looks like:

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
ls -l ./infrastructure/flagger
```

This is basically the same pattern as we saw for `cert-manager`, and most of
it is basically just setting up a standard Helm install of Flagger, following
the docs at https://docs.flagger.app.

However, Flagger requires us to define the set of _selector labels_ that it
will pay attention to when it watches for rollouts, and by default, that set
does not include `service`. We want to be able to use `service` when managing
rollouts, so we've added it in `infrastructure/flagger/release.yaml`:

```bash
bat ./infrastructure/flagger/release.yaml
```

<!-- @wait_clear -->

So that's a quick look at some of the definitions for the infrastructure of
this cluster -- basically, all the things our application needs to work. Now
let's continue with a look at `apps.yaml`, which is the definition of the
Faces application itself. There's just a single YAML document in this file: it
defines a Kustomization named `apps`, still in `flux-system` namespace, that
depends on both `flagger` and `ingress-nginx`, and has `kustomize` files in
the `apps` directory:

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
bat ./clusters/my-cluster/apps.yaml
```

<!-- @clear -->

Looking at that `apps` directory, there's a single directory for `faces`,
which in turn has various files:

```bash
#@echo
#@notypeout
#@nowaitbefore
ls -l apps
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
ls -l apps/faces
```

<!-- @clear -->

Again, let's start with `kustomization.yaml`.

```bash
#@echo
#@notypeout
#@nowaitbefore
bat ./apps/faces/kustomization.yaml
```

`kustomizations.yaml` tells `kustomize` to pull in several other files -- and,
importantly, sets the namespace for all the other things it's pulling from
those files to be `faces`. (In fact, if it pulls in a file that sets a
different namespace, the namespace in `kustomizations.yaml` will override what
the file says.)

The choice of namespace is mostly a matter of convention: typically,
infrastructure things live in `flux-system` and application things don't.
However, the namespace will also come up again when we talk about
reconciliation.

<!-- @wait_clear -->

Let's take a look at those files one at a time.

First, we have `namespace.yaml`. This one is straightforward: it defines the
`faces` namespace that we'll use for everything here, and it tells Linkerd to
inject any Pods appearing in this namespace.

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
bat ./apps/faces/namespace.yaml
```

<!-- @clear -->

Next up is `faces-sync.yaml`. This is... _less_ straightforward. It has
several documents in it, so let's look at those one by one.

The first document defines the Git repository that's the source of truth for
the Faces resources. We're using the `${GITHUB_USER}/faces-demo` repo, looking
at the `main` branch, and we're ignoring everything except for a few files in
`k8s/01-base` -- and, remember, per `kustomization.yaml` this GitRepository
resource will be created in the `faces` namespace.

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
yq 'select(document_index == 0)' apps/faces/faces-sync.yaml | bat -l yaml
```

Let's take a quick look at that GitHub repo (and branch) in the
browser:

<!-- @browser_then_terminal -->

So, basically, we're pulling in the minimal set of files to actually deploy
the Faces app. Let's continue with the _second_ document in `faces-sync.yaml`,
which defines yet another Kustomization resource -- this one is named `faces`,
and lives in the `faces` namespace rather than the `flux-system` namespace.

The `faces` Kustomization includes patches to the minimal deployment files for
the Faces app -- specifically, we're going to force the `ERROR_FRACTION`
environment variable to "0" in all our Deployments. (We have to use two
separate patches for this because the Deployments for the backend workloads
already include some environment variables, and the `faces-gui` Deployment
does not.)

```bash
#@echo
#@notypeout
yq 'select(document_index == 1)' apps/faces/faces-sync.yaml | bat -l yaml
```

The reason we care about the `ERROR_FRACTION` is that it's the environment
variable that controls how often errors get injected into the Faces services
-- for the moment, we want these services _not_ to fail artificially, so that
we get to see how everything is supposed to look before we start breaking
things!

<!-- @wait_clear -->

Next up is `faces-ingress.yaml`. Unsurprisingly, this file defines an Ingress
resource that we'll use to route to the Faces services. It's fairly
straightforward, if a little long:

```bash
#@echo
#@notypeout
bat apps/faces/faces-ingress.yaml
```

<!-- @clear -->

After the Ingress definition, `faces-canary.yaml` tells Flagger how to do
canary rollouts of the `face`, `smiley`, and `color` services in the Faces
app. All three are basically the same, so we'll just look at the one for the
`face` service. The important things here are that, when a new deployment
happens:

1. We're going to have Flagger ramp traffic in 5% increments every 10 seconds
   until it reaches 50%, then the next step will be to fully cut over; and
2. We're going to demand a 70% success rate to keep going.

```bash
#@echo
#@notypeout
yq 'select(document_index == 0)' apps/faces/faces-canary.yaml | bat -l yaml
```

Remember that this applies to the services _behind_ the Faces GUI only! For
the GUI itself, we'll do A/B testing.

<!-- @wait_clear -->

The A/B test is defined by our last file, `faces-abtest.yaml`. The important
things to notice in here are:

1. We're only working with the `faces-gui` service here.
2. We also have to know which Ingress to mess with, because Flagger needs to
   modify the Ingress to route only specific traffic to the deployment we're
   testing!
3. The `analysis.match` clause says that the new deployment will _only_ get
   traffic where the `X-Faces-Header` has the value `testuser`.
4. Finally, we're again going to demand a 70% success rate to keep going.

```bash
#@echo
#@notypeout
bat apps/faces/faces-abtest.yaml
```

<!-- @clear -->

## Putting it All Together

Taking all those files together, there's a lot going on under the hood, but
rather little that the app developers need to worry about:

- We've defined how all the infrastructure fits together.
- We've defined how our application gets deployed.
- We've defined how to roll out new versions of the Faces GUI using A/B
  testing.
- We've defined how to roll out new versions of the underlying Faces services
  using canaries.

Most importantly: now that this is set up, application developers generally
won't have to think much about it.

Finally, one last reminder: don't forget that that `faces` Kustomization lives
in the `faces` namespace.

<!-- @wait_clear -->

## A Failed Rollout

OK! Let's actually roll out a new version and watch what happens. We're going
to start by trying to roll out to a _failing_ version. This is bit more
instructive than starting with a successful rollout, because you'll get to see
how Flagger responds when things go wrong.

To get the ball rolling, edit `faces-sync.yaml` to set the `ERROR_FRACTION` to
75% for all the backend Faces services. (This is on line 35 -- don't mess with
the `ERROR_FRACTION` for the `faces-gui`.)

```bash
${EDITOR} apps/faces/faces-sync.yaml
```

Let's double-check the changes...

```bash
git diff --color | more -r
```

Once convinced that they're OK, commit and push the change.

```bash
git add apps/faces/faces-sync.yaml
git commit -m "Force ERROR_FRACTION for backend Faces services to 75%"
git push
```

<!-- @wait_clear -->

At this point, we could just wait for Flux to notice our change. This is how
we'd do things in production: commit, and let the system work.

However, right now Flux is set up to check for changes every 10 minutes, and
that's just too long to wait for this demo. Instead, we'll manually tell Flux
to reconcile any changes to the `apps` Kustomization immediately

**Many things will happen at this point:**

- Flagger will start updating Canary resources in the `faces` namespace. We'll
  be able to watch these using the command line in this window.

- Flagger will tell Linkerd to start routing traffic to the new Deployments.
  We'll be able to watch this in the Linkerd dashboard.

- The Faces GUI will start seeing responses from the new (bad) Deployments.
  We'll be able to see this in the Faces GUI: not all the faces will be
  smileys, and not all the cell backgrounds will be green.

<!-- @wait_clear -->

So. Off we go. Let's trigger the rollout by explicitly telling Flux to
reconcile the `apps` Kustomization.

**Note**: When we trigger the rollout, we'll get an error message about
Flagger not being ready. This isn't a problem, it's just an artifact of the
manual trigger.

```bash
flux reconcile ks apps --with-source
```

Then, we'll start watching the Canary resources here that Flagger should be
updating, using the command line. We'll also watch the faces GUI itself, and
the Linkerd Viz dashboard, so we really have three separate views of the world
here.

```bash
kubectl get -n faces canaries -w
```

<!-- @show_terminal -->
<!-- @clear -->

At this point, we've seen a rollout fail. Let's repeat that, but this time set
things up for success. Once again, we'll start with editing `faces-sync.yaml`:
this time, we'll set `ERROR_FRACTION` to "20" so that we should see some
errors but still succeed with the rollout (since we need at least 70% success
to continue: an error fraction of 20% should give us an 80% success rate).

```bash
${EDITOR} apps/faces/faces-sync.yaml
```

Again, we'll doublecheck the changes...

```bash
git diff --color | more -r
```

...then commit, push, and trigger reconciliation.

```bash
git add apps/faces/faces-sync.yaml
git commit -m "Force ERROR_FRACTION for backend Faces services to 20%"
git push
```

This time, we'll trigger the reconciliation from the Weave GitOps GUI.

<!-- @browser_then_terminal -->

Once again, we can watch the rollout progress with the CLI.

```bash
kubectl get -n faces canaries -w
```

<!-- @show_terminal -->

So, this time around the rollout actually succeeded, since we passed the
minimum success threshold.

<!-- @wait_clear -->

## The Source Repo

When we walked through the Flux setup in the first place, you might remember
this bit of setup from the first document in `faces-sync.yaml`:

```bash
#@echo
#@notypeout
#@nowaitbefore
#@waitafter
yq 'select(document_index == 0)' apps/faces/faces-sync.yaml | bat -l yaml
```

As we discussed earlier, we're pulling our initial deployments from the
`${GITHUB_USER}/faces-demo` repo, then applying patches from the
`${GITHUB_USER}/gitops-linkerd` repo to those resources. This means that we
can also use Flux and Flagger to handle changes _to the initial deployment
resources_ in `${GITHUB_USER}/faces-demo` -- the tools aren't limited to
managing changes to the patches.

<!-- @wait_clear -->

Let's demo this by editing the base `smiley` service definition to show a
different smiley. We could do this with a `kustomize` patch, but it's much
easier this way.

Since the `${GITHUB_USER}/face-demo` repo is cloned into a sibling directory
of `${GITHUB_USER}/gitops-linkerd`, we can easily edit the base definition and
push it up to GitHub. Let's change the kind of smiley that the `smiley`
service will send back: to do this, add a environment variable to the `smiley`
Deployment's Pod template, for example `SMILEY=HeartEyes` (case matters on
both sides of the `=`!).

```bash
${EDITOR} ../faces-demo/k8s/01-base/faces.yaml
```

We'll doublecheck the changes as before -- the only change here is the `-C`
argument to `git`, to point it to the correct clone.

```bash
git -C ../faces-demo diff --color | more -r
```

Then, we'll use the same `git -C` trick to commit and push our change.

```bash
git -C ../faces-demo add k8s/01-base/faces.yaml
git -C ../faces-demo commit -m "Switch to HeartEyes smileys"
git -C ../faces-demo push
```

<!-- @wait_clear -->

After that, again, we could just wait for the reconciliation to happen on its
own, but that would take longer than we'd like, so we'll kick it off by hand
by telling Flux to reconcile the `faces` Kustomization.

You might recall that last time we told Flux to reconcile the `apps`
Kustomization. That won't work this time: when manually triggering
reconciliation, Flux just looks at the one Kustomization you tell it to,
rather than recursing into Kustomizations it creates. So, this time, we tell
it to look in the `faces` namespace for the `faces` Kustomization:

```bash
flux reconcile ks faces -n faces --with-source
```

Once that happens, watching the rollout progress with the CLI is the same as
before:

```bash
kubectl get -n faces canaries -w
```

<!-- @show_terminal -->

So now we have all `HeartEyes` smileys, since our rollout succeeded.

<!-- @wait_clear -->

## A/B Deployments

Now let's take a look at the GUI. We want to roll out a simple change to have
the background be light cyan -- however! We don't want random users to get
this (as a canary would cause), we want our to test users to see it first.
This is a perfect use case for A/B testing.

As we reviewed earlier, this is set up with the `faces-abtest.yaml`. The
critical point we want to review here is the `match` specification which
determines how we route traffic:

```bash
#@echo
#@notypeout
bat apps/faces/faces-abtest.yaml
```

As this is defined, we key the A/B routing on the `X-Faces-User` header: if
this header has a value of "testuser", we'll route the request to the incoming
workload.

<!-- @wait_clear -->

So, let's go ahead and modify `faces-sync.yaml` to set the new background
color, by adding the `COLOR` environment variable to the `faces-gui`. Note
that we set it unconditionally: we're going to trust the canary to do the
right thing here.

```bash
${EDITOR} apps/faces/faces-sync.yaml
```

Again, we'll doublecheck the changes...

```bash
git diff --color | more -r
```

...then commit, push, and trigger reconciliation.

```bash
git add apps/faces/faces-sync.yaml
git commit -m "Force the GUI background to light cyan"
git push
```

This time we're back to reconciling the `apps` Kustomization:

```bash
flux reconcile ks apps --with-source
```

<!-- @wait_clear -->

Even though this is an A/B rollout, we still watch it by watching Canaries
resources – nice for consistency even if it's somewhat odd. While this is
going on, too, we can flip between a browser sending no `X-Faces-User` header,
and a browser sending `X-Faces-User: testuser`, and we'll see the difference.

```bash
kubectl get -n faces canaries -w
```

Now that the rollout is finished, we'll see the new background color from both
browsers.

<!-- @wait_clear -->

## Error Handling

It wouldn't be a talk about real-world usage if we didn't talk at least a bit
about things going wrong, right? Specifically, when things go wrong, what can
you do?

### Get Events

When Flux and Flagger are working, they post Kubernetes events describing
important things that are happening. This is a great go-to to figure out
what's going on when things are misbehaving.

Note that you may need to look at events in various namespaces.

<!-- @wait -->

### Describe Pods

If you have a Pod that doesn't seem to be starting, `kubectl describe pod` can
help you see what's going on. (Partly this is because describing the Pod will
show you events for that Pod -- it can be a quicker way to get a
narrowly-focused view of events, though.)

<!-- @wait -->

### Get Controller Logs

As a bit of a last resort, there are firehoses of logs from the Flux and
Flagger controllers:

- The `flagger` Deployment in the `flagger-system` namespace is the place to
  start if you want a really detailed look at what Flagger is doing.

- There are several controllers in the `flux-system` namespace too -- for
  example, the `kustomize-controller` is doing most of the work in this demo.

In all cases, the logs have an _enormous_ amount of information, which can
make them hard to sift through -- but sometimes they have the critical bit
that you need to see what's going on.

<!-- @wait_clear -->

## Real-World GitOps: Flux, Flagger, and Linkerd

And there you have it! You can find the source for this workshop at

https://github.com/BuoyantIO/gitops-linkerd

and, as always, we welcome feedback. Join us at https://slack.linkerd.io/ for
more.

<!-- @wait -->
<!-- @show_slides -->
