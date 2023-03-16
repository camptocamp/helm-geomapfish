# [Kubernetes](https://kubernetes.io/) [HELM chart](https://helm.sh/) for [GeoMapFish](https://github.com/camptocamp/c2cgeoportal)

Assemble the charts:

- [Apache](https://github.com/camptocamp/helm-apache), For MapServer and QGIS server
- [geoportal](https://github.com/camptocamp/helm-geoportal)

[Example of minimal config](./tests/recommend.yaml)

[Mutualize project](https://github.com/camptocamp/helm-mutualized/)

## Mutualize

The tiles and print services, respectively "TileCloud Chain" and "MapFish Print" are shared between
projects and deployed in the `gs-mutualize` namespace.

They need to load configurations stored in repositories of projects on GitHub.

### Configuration workflow

Diagram of the configuration workflow:

![Diagram of the configuration workflow](./mutualize.png 'Diagram of the configuration workflow')

#### GitHubWebhook

One `GitHubWebhook` will be created for each entry in `geomapfish.mutualize.configs` in project Chart values.
Those objects will be used by the
[GitHub WebHook operator](https://github.com/camptocamp/operator-github-webhook/)
to create the corresponding GitHub WebHooks in project repository.
Those WebHooks will trigger the mutualize shared config manager on push on GitHub.

#### Mutualize Shared Config Manager

One `SharedConfigSource` will be create for each `geomapfish.mutualize.configs`.
Those objects are used by the
[Shared Config Manager Operator](https://github.com/camptocamp/operator-shared-config-manager)
to build a `ConfigMap` (from the `SharedConfigConfig` object) that contains the master config of the mutualize
Shared Config Manager.
With this config, the Shared Config Manager will checkout the configured repository,
Do the variable replacement, and distribute the configurations to the mutualize services.

#### Mutualize TileCloud Chain hosts

One other `SharedConfigSource` will be create for each entry in key `hosts` of each entry in
`geomapfish.mutualize.configs` if `tilecloudchain` is `true`.
Those object are used by the
[Shared Config Manager Operator](https://github.com/camptocamp/operator-shared-config-manager)
to create a `ConfigMap` (from the `SharedConfigConfig` object) that contains the TileCloud Chain hosts config.

## Contributing

Install the pre-commit hooks:

```bash
pip install pre-commit
pre-commit install --allow-missing-config
```
