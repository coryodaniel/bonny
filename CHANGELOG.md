# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

<!-- Add your changelog entry to the relevant subsection -->

<!-- ### Added | Changed | Deprecated | Removed | Fixed | Security -->

### Fixes

- Fix for an issue reported in [#180](https://github.com/coryodaniel/bonny/pull/180) already: Add operator name as env variable to deployment.

<!-- No new entries below this line! -->

## [1.1.1] - 2023-02-24

### Fixed

- `Bonny.Pluggable.Finalizer` - Remove finalizers from resource if they need to be removed.
- `Bonny.Axn` - Regression where descendants were not applied - [#192](https://github.com/coryodaniel/bonny/pull/192), [#191](https://github.com/coryodaniel/bonny/issues/191)

## [1.1.0] - 2023-02-22

This release updates its dependency on `k8s` to a new major version (`2.x`). If
you're using `k8s` directly in your code, you should have added it explicitely
to your dependencies in `mix.exs` and this update will fail until you update
that dependency manually. If you're using `k8s` directly in your code but you
haven't added it explicetly to your list of dependencies, you might get
surprises as `2.x` comes with (yet few) breaking changes.

### Fixed

- Prevent duplicate descendants

### Changed

- Upgraded k8s dependency to 2.x. [#173](https://github.com/coryodaniel/bonny/pull/173)

### Added

- `Bonny.Pluggable.AddMissingGVK` - A pluggable step for adding missing GVK information to resources - [#184](https://github.com/coryodaniel/bonny/pull/184), [#183](https://github.com/coryodaniel/bonny/issues/183)
- Helpers to define conditions on custom resources. [#188](https://github.com/coryodaniel/bonny/pull/188)
  - `Bonny.API.Version.add_conditions/1` - Helper to define a schema for conditions on the CRD
  - `Bonny.Axn.set_condition/4` - Helper to set a condition on a resource
- `Bonny.Pluggable.Finalizer` - A pluggable step to define and implement finalizers, [#6](https://github.com/coryodaniel/bonny/issues/6), [#189](https://github.com/coryodaniel/bonny/pull/189)
- `Bonny.Axn.register_after_processed/2` - Registers a callback to be invoked at the very end of an action event's processing by the operator

## [1.0.1] - 2023-02-04

### Fixed

- Initialized application calls the wrong function to initialize conn - [#181](https://github.com/coryodaniel/bonny/pull/181)
- Don't add operator to supervision tree in `:test` env per default - [#182](https://github.com/coryodaniel/bonny/issues/182)

## [1.0.0] - 2022-11-28

With Version 1.0.0, Bonny got a thorough refactoring. Besides this changelog,
you might consider the several guides (e.g. the [migration guide](./guides/migration.mid))

- `Bonny.Operator` was introduced as an entry point to the watching and handling
  of processes. Your controllers are not more added to the supervision tree by
  bonny. Instead you must create an operator and add that to your application's
  supervision tree.
- The [`Pluggable`](https://hex.pm/packages/pluggable) (think [`Plug`](https://hex.pm/packages/plug))
  library is used with `Bonny.Axn` as token to process `ADDED`, `MODIFIED`,
  `DELETED` and reconciliation events by `Pluggable` pipelines.
- `Bonny.ControllerV2` was introduced as a successor to `Bonny.Controller`. It leverages
  `Pluggable.StepBuilder` (think `Plug.Builder`) to build a pluggable pipeline.
- `Bonny.Event` and `Bonny.EventRecorder` were introducd for Kubernetes
  event creation ([#156](https://github.com/coryodaniel/bonny/pull/156), [#5](https://github.com/coryodaniel/bonny/issues/5))

### Why this refactoring?

- Allows for better CRD and API version definitions
- With a `Pluggable` architecture, controllers are much easier to test (Think of `Plug.Conn` tests)
- The `Pluggable` architecture makes your processing pipelines composable and simpler to customize/extend
- Decoupling of manifest generation and action event processing
- Internally, the amount of macros was reduced which makes Bonny easier to understand and maintain

## [1.0.0-rc.3] - 2022-11-19

### Fixed

- `Bonny.Mix.Operator` - fix manifest generation: remove version from apiGroup in ClusterRole.

## [1.0.0-rc.2] - 2022-11-15

### Added

- `Bonny.Pluggable.AddManagedByLabelToDescendants` - Adds the `app.kubernetes.io/managed-by` label to all descendants registered within the pipeline.
- Allow `nil` and `{controller :: module(), init_opts :: keyword()}` in the operator's `controllers/2` callback.

### Fixed

- `K8sConn` - Implement spec correctly.

### Changed

- `Bonny.Axn.apply_descendants/N`, `Bonny.Axn.apply_status/N` - Raise upon error.

## [1.0.0-rc.1] - 2022-10-31

# Added

- Better logs in case of errors while applying status, descendants or events
- Integration tests for these logs

## [1.0.0-rc.0] - 2022-10-29

### Changed

With Version 1.0.0, Bonny got a thorough refactoring. Besides this changelog,
you might consider the several guides (e.g. the [migration guide](./guides/migration.mid))

- `Bonny.Operator` was introduced as an entry point to the watching and handling
  of processes. Your controllers are not more added to the supervision tree by
  bonny. Instead you must create an operator and add that to your application's
  supervision tree.
- The [`Pluggable`](https://hex.pm/packages/pluggable) (think [`Plug`](https://hex.pm/packages/plug))
  library is used with `Bonny.Axn` as token to process `ADDED`, `MODIFIED`,
  `DELETED` and reconciliation events by `Pluggable` pipelines.
- `Bonny.ControllerV2` was introduced as a successor to `Bonny.Controller`. It leverages
  `Pluggable.StepBuilder` (think `Plug.Builder`) to build a pluggable pipeline.
- `Bonny.Event` and `Bonny.EventRecorder` were introducd for Kubernetes
  event creation ([#156](https://github.com/coryodaniel/bonny/pull/156), [#5](https://github.com/coryodaniel/bonny/issues/5))

Why this refactoring?

- Allows for better CRD and API version definitions
- With a `Pluggable` architecture, controllers are much easier to test (Think of `Plug.Conn` tests)
- The `Pluggable` architecture makes your processing pipelines composable and simpler to customize/extend
- Manifest generation and event processing were decoupled
- Internally, the amount of macros was reduced which makes Bonny easier to maintain

### Added

- `Bonny.Pluggable.SkipObservedGenerations` - halts the pipelines for a defined list of actions if the observed generation equals the resource's generation.
- `Bonny.Pluggable.ApplyDescendants` - applies all the descendants added to the `%Bonny.Axn{}` struct.
- `Bonny.Pluggable.ApplyStatus` - applies the status of the given `%Bonny.Axn{}` struct to the status subresource.
- `Bonny.Pluggable.Logger`- logs an action event and when status, descendants and events are applied to the cluster. If desired, it makes sense to be placed as first step in your operator pipeline but can also be added to a controller pipeline.
- `Bonny.Resource.add_owner_reference/3` used to add the owner reference to resources created by the controller. ([#147](https://github.com/coryodaniel/bonny/pull/147))
- An integration test suite was added that runs tests against a "real" kubernetes cluster on the CI pipeline ([#146](https://github.com/coryodaniel/bonny/pull/146), [#84](https://github.com/coryodaniel/bonny/issues/84))
- Mix task for initializing a new operator `mix bonny.init` ([#160](https://github.com/coryodaniel/bonny/pull/160), [#67](https://github.com/coryodaniel/bonny/issues/67))

### Deprecated

- `Bonny.Controller` was deprecated in favor of the new design with
  `Bonny.Operator` and `Bonny.ControllerV2`

## [0.5.2] - 2022-08-31

### Updated

- Use name of application in Deployments instead of service account name. ([#142](https://github.com/coryodaniel/bonny/pull/142))

### Fixed

- CRD manifest generation for `apiextensions.k8s.io/v1` ([#143](https://github.com/coryodaniel/bonny/pull/143), [#117](https://github.com/coryodaniel/bonny/issues/117), [#101](https://github.com/coryodaniel/bonny/pull/101))

## [0.5.1] - 2022-05-25

### Fixed

- Add missing `priv` folder to package

## [0.5.0] - 2022-04-23

Version 0.5.0 comes with some major changes. Please read through the [migration guide](./guides/migrations.md) before upgrading.

## Added

- `Bonny.Server.AsyncStreamRunner` to run streams in a separate process
- `Bonny.Sys.Telemetry` defines `telemetry` spans and events

## Updated

- `Bonny.Server.Watcher` and `Bonny.Server.Reconciler` were rewritten completely. They now prepare streams which are to be run with `Bonny.Server.AsyncStreamRunner`
- Dependency `k8s` was updated to version `~> 1.1` and code was refactored accordingly

## Deprecated

- `Bonny.Sys.Event` was deprecated in favor of `Bonny.Sys.Telemetry`

## [0.4.4] - 2021-08-09

### Added

- @impl to macros for clean compilation
- error handling for mid-stream errors

## [0.4.3] - 2020-06-09

### Added

- Configure watched namespace via config.exs or BONNY_POD_NAMESPACE
- BONNY_POD_NAMESPACE supports "magic" value "**ALL**"

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
