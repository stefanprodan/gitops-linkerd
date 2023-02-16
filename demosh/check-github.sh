set -e

# This demo _requires_ a few things:
#
# 1. You need to set GITHUB_USER to your GitHub username.
#
# 2. You need to set GITHUB_TOKEN to a GitHub personal access token with repo
#    access to your fork of gitops-linkerd.
#
# 3. You need to fork https://github.com/kflynn/gitops-linkerd and
#    https://github.com/BuoyantIO/faces-demo under the $GITHUB_USER account.
#
# 4. You need to clone the two repos side-by-side in the directory tree, so
#    that "gitops-linkerd" and "faces-demo" are siblings.
#
# 5. You need both clones to be in their "main" branch.
#
# 6. You need to be running this script from the "gitops-linkerd" repo.
#
# 7. Finally, you need to edit apps/faces/faces-sync.yaml to point to your
#    fork of faces-demo -- change the `url` field on line 8.
#
# This script verifies that all these things are done.
#
# NOTE WELL: We use Makefile-style escaping in several places, because
# demosh needs it.

# First up, is GITHUB_USER set?
if [ -z "$GITHUB_USER" ]; then \
    echo "GITHUB_USER is not set" >&2 ;\
    exit 1 ;\
fi

# Next up, is GITHUB_TOKEN set to something with repo scope?

s1=$(curl -s -I -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/$GITHUB_USER/gitops-linkerd)
s2=$(echo "$s1" | tr -d '\015' | grep 'x-oauth-scopes:')
scopes=$(echo "$s2" | cut -d: -f2- | tr -d ' ",\012')

if [ "$scopes" != "repo" ]; then \
    echo "GITHUB_TOKEN does not have repo scope" >&2 ;\
    exit 1 ;\
fi

# OK. Next up: we should be in the gitops-linkerd repo, and our "origin"
# remote should point to a fork of the repo under the $GITHUB_USER account.

origin=$(git remote get-url --all origin)

if [ $(echo "$origin" | grep -c "$GITHUB_USER/gitops-linkerd\.git$") -ne 1 ]; then \
    echo "Not in the $GITHUB_USER fork of gitops-linkerd" >&2 ;\
    exit 1 ;\
fi

# Next up: we should be in the "main" branch.
if [ $(git branch --show-current) != "main" ]; then \
    echo "Not in the main branch of gitops-linkerd" >&2 ;\
    exit 1 ;\
fi

# Next up: we should have a sibling directory called "faces-demo" that has an
# origin remote pointing to a fork of the repo under the $GITHUB_USER account.

if [ ! -d ../faces-demo ]; then \
    echo "Missing sibling directory ../faces-demo" >&2 ;\
    exit 1 ;\
else \
    origin=$(git -C ../faces-demo remote get-url --all origin) ;\
    \
    if [ $(echo "$origin" | grep -c "$GITHUB_USER/faces-demo\.git$") -ne 1 ]; then \
        echo "../faces-demo is not the $GITHUB_USER fork of faces-demo" >&2 ;\
        exit 1 ;\
    fi ;\
    \
    if [ $(git -C ../faces-demo branch --show-current) != "main" ]; then \
        echo "Not in the main branch of faces-demo" >&2 ;\
        exit 1 ;\
    fi ;\
fi

# Finally, let's make sure that the `url` in `app/faces/faces-sync.yaml` is
# set correctly.

faces_demo_url=$(yq 'select(document_index==0) .spec.url' apps/faces/faces-sync.yaml)

if [ "$faces_demo_url" != "https://github.com/${GITHUB_USER}/faces-demo" ]; then \
    echo "apps/faces/faces-sync.yaml is not pointing to the $GITHUB_USER fork of faces-demo" >&2 ;\
    exit 1 ;\
fi

set +e
