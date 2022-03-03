# [Kubernetes](https://kubernetes.io/) [HELM chart](https://helm.sh/) for [GeoMapFish](https://github.com/camptocamp/c2cgeoportal)

Assemble the charts:

- [Apache](https://github.com/camptocamp/helm-apache), For MapServer and QGIS server
- [geoportal](https://github.com/camptocamp/helm-geoportal)

[Example of minimal config](./tests/recommend.yaml)

[Mutualize project](https://github.com/camptocamp/helm-mutualized/)

## Contributing

Make your changes.

Update expected manifests:

```bash
make gen-expected
```

Note that this require helm v3, so you may need to specify which helm executable to use:

```bash
HELM=helm3 make gen-expected
```

Now you can review and commit changes in generated manifests and open a pull request.
