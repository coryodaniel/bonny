# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added `{:error, binary}` as a return value of Controller lifecycle methods
- Implemented `:telemetry` library
- `Bonny.Telemetry.events/0` exposes list of telemetry events
- `mix bonny.gen.manifest --local` for building manifests w/o a Deployment for
  local testing
- `cluster_name: :default` config options. Now uses [k8s](https://github.com/coryodaniel/k8s) cluster registration configuration.

### Changed

- Async watcher event dispatch
- Replaced `HTTPoison` with [k8s](https://github.com/coryodaniel/k8s)

### Removed

- Renamed `group_version` -> `api_version`
- Renamed `Bonny.CRD.plural/0` -> `Bonny.CRD.kind/0`
- `Bypass` from test suite
- `Impl.parse_metadata/1`
- `kubeconf_file` and `kubeconf_opts` config options

## [0.3.0] - 2019-03-04

### Changed

- Replaced `k8s_conf` library with [k8s](https://github.com/coryodaniel/k8s).

## [0.2.3] - 2019-01-13

### Added

- Initial public release.
- Controller lifecycle implementation.
- CRD Watcher.
- mix task: controller generator
- mix task: dockerfile generator
- mix task: k8s manifest generator
