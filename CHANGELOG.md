# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.4] - 2021-08-09

### Added
- @impl to macros for clean compilation
- error handling for mid-stream errors
## [0.4.3] - 2020-06-09

### Added
- Configure watched namespace via config.exs or BONNY_POD_NAMESPACE 
- BONNY_POD_NAMESPACE supports "magic" value "__ALL__"

## [0.4.1] - 2019-11-26

### Added
- Support for reconciling/watching `core` resources

## [0.4.0] - 2019-10-23

### Added

- Basic integration w/ [Notion](https://github.com/coryodaniel/notion) for telemetry
- Bonny.Server.Reconciler continually process a list operation
- Bonny.Server.Scheduler write custom kubernetes schedulers
- Added Bonny.PeriodicTask for scheduling periodically executed functions

### Changed

- Dockerfile gen uses OTP releases

### Removed

- Removed `reconcile_batch_size`

## [0.3.3] - 2019-06-25

### Added

- Add additional printer columns
- Bonny.Naming module
- .credo.exs

## [0.3.2] - 2019-04-15

### Added

- Bonny.Watcher and Bonny.Reconciler telemetry events

## [0.3.1] - 2019-04-11

### Added

- Support for a reconcile/1 callback
- `reconcile_every` config option to schedule how often to run
  reconciliation
- `reconcile_batch_size` to set the size of the HTTP GET limit
  when fetching batches of items to reconcile
- Added `{:error, binary}` as a return value of Controller lifecycle methods
- Implemented `:telemetry` library
- `Bonny.Sys.Event.events/0` exposes list of telemetry events
- `mix bonny.gen.manifest --local` for building manifests w/o a Deployment for
  local testing
- `cluster_name: :default` config options. Now uses [k8s](https://github.com/coryodaniel/k8s) cluster registration configuration.

### Changed

- Async watcher event dispatch
- Replaced `HTTPoison` with [k8s](https://github.com/coryodaniel/k8s)

### Fixed

- Receiving :DOWN messages no longer crashes Watcher [#20](https://github.com/coryodaniel/bonny/issues/20)
- Issue with partially received events [#43](https://github.com/coryodaniel/bonny/issues/43)
- Fix invalid singular name generation from module names "MyMod" -> my_mod; "MyMod" -> mymod

### Removed

- Renamed `group_version` -> `api_version`
- Renamed Bonny.CRD.plural/1 -> `Bonny.CRD.kind/1`
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
