# How to test locally

## Deploy

### Kubernetes

From the Git clone root of this repository:

```shell
IP=$(ip addr show dev $(route | grep default | awk '{print $(NF)}' | head -1)  | awk '$1 ~ /^inet/ { sub("/.*", "", $2); print $2 }' | head -1)
helm upgrade --install \
  --set postgresql.master.host=${IP} --set postgresql.slave.host=${IP} \
  --set ingress.enabled=true \
  --set ingress.hosts[0]=${IP}.nip.io \
  --set c2c.profiler.enabled=true \
  --values $DEMO_ROOT/values.yaml \
  demo c2cgeoportal
```

Wait for all PODs to become Running and Ready (CTRL-C when done):

```shell
kubectl get pod -l app=c2cgeoportal -l release=demo -w
```

If you want the qgisserver stuff to work:

```shell
kubectl expose --port 80 --name qgisserver service demo-c2cgeoportal-qgisserver
```

To test the deploy:

```shell
helm test --cleanup demo
```

# Install application in OpenShift project

In your project you should have tow branches named e.g. `int-2-6`, `prod-2-6` for the GeoMapFish version 2.6.
Then the tags will also be be `int-2-6` and `prod-2-6`.

Add a `gmf-<project-name>.yaml` file in the `helmfiles` directory (at the root of this repository).
This file is the [helmfile](https://github.com/roboll/helmfile) configuration file and describes the helm releases to deploy.
Look at [helmfiles/gmf-demo.yaml](../helmfiles/gmf-demo.yaml) for an example.

The applications names should be `int-2-6` and `prod-2-6`, and the labels: `project` should have `gmf-<project-name>`,
`version` should have `int`, `prod`, and `type` should have `geoportal`.

Then, create a `helmfiles/gmf-<project-name>/` directory to hold the customization files. We have two kind of files in there:

-   `secret-*.yaml` files: encrypted files that contains "secret" configuration values.
    Can be created or edited with the following command (from the root of this repository):
    ```shell
    sops helmfiles/gmf-<project-name>/<filename>
    ```
    The keys used for encryption are listed in [.sops.yaml](../.sops.yaml) and, if you change them, you can call the
    [re-encrypt-secrets](../re-encrypt-secrets) script.
-   The others have non-sensitive configuration values

Please look at the [helmfiles/gmf-demo/](../helmfiles/gmf-demo) directory for an example. The files it contains are:

-   `secret-secrets.yaml`: Secrets for customizing the [secrets](../secrets/README.md) chart. Will hold the login info for PostgreSQL and S3.
-   `secret-geoportal.yaml`: Secrets for customizing this chart. Typically holds the login info for sentry and SMTP.
-   `values-prod-2-5.yaml`: There will be one such file per release and the file is named after the release.
    Contains all the project and release specific values.
    If you have common values between the releases of a project, you can add a common file and reference it in your helmfile configuration.
    Look at the [gmf-nppr.yaml](../helmfiles/gmf-nppr.yaml) configuration for a more complex example.

See the root [README.md](../README.md) file for help on using helmfile.

## GeoMapFish secrets

If you copy some files from an other project be sure that you don't take some secrets...

First edit all the `helmfiles/gmf-<project-name>/secret-*.yaml`.

On them don't miss to change the `c2c/secret` and the `c2c/authtkt` they should be defferant against all the projects.

Then you should care to modify the non-secret `c2c/sentry/project`.

# Configure the project

Configure the images name in [`ci/config.yaml`](https://github.com/camptocamp/demo_geomapfish/blob/prod-2-6/CONST_create_template/ci/config.yaml#L18-L22)

[The OpenShift project](https://github.com/camptocamp/demo_geomapfish/blob/prod-2-6/.github/workflows/main.yaml#L10)

And you should edit the `CI_GPG_PRIVATE_KEY` and `GOPASS_CI_GITHUB_TOKEN` secrets in the Camptocamp organisation
on GitHib to add your project.

# Publish images to GitHub Container Registry

You should have a version >= `2.6.0.0`, or >= `2.5.0.77`, or >= `2.4.2.14`.

Have in the file `<project-name>/values-commons.yaml` (add the prefix `ghcr.io/`):

```
image:
  repositoryPrefix: ghcr.io/camptocamp/<project-name>
```

In the Camtocamp organisation, add the repository in the `CI_GPG_PRIVATE_KEY` and `GOPASS_CI_GITHUB_TOKEN`
secrets.

Now when you run the CI the images soulf be published.

In the Camtocamp organisation Package open the application images, and associate them to the project.

# Trigger images update to OpenShift

For Travis, you should provide a file named `./helmfiles/<project-name>/travis.env`, that provide `TRAVIS_REPO`
and `TRAVIS_ENDPOINT`.

To be able to trigger OpenShift you should finally run `gopass sync`, `./get-ci-tokens` (your application should already
be in OpenShift, if your project does use travis don't wary about travis related errors), then
`gopass sync`, in Travis the token will be set as a secret, and for GitHub action it will be provide throw
gopass.

Now if you run the CI it should fully work.
