# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic
Versioning](https://semver.org/spec/v2.0.0.html).

## 0.5.5 - 2026-11-06

### Added

* Add `doc` option support to `field/3` in both `typedstruct` and `typedrecord`
    so field-level documentation can be included in generated module docs under
    a `Fields` section.
* Add validated constructor generation with `constructors: true`.
    * `typedstruct`: `new/1`, `new!/1`, `from_map/1`, `from_keyword/1`.
    * `typedrecord`: `<record>_new/1`, `<record>_new!/1`,
        `<record>_from_map/1`, `<record>_from_keyword/1`.
* Add `default_fn: &Mod.fun/0` field option for dynamic defaults used by
        generated constructors.
* Add introspection helpers with `introspection: true`.
* Add docs merge controls with `docs: :full | :module_only | :fields_only | false`.
* Add strict mode with `strict: true` for both `typedstruct` and `typedrecord`.
* Add `derive: [...]` support for `typedstruct`.
* Add `plugins: [...]` option to `use TypedStruct` to automatically inject default
    plugins into all `typedstruct` and `typedrecord` definitions. This enables
    wrapper modules to provide preset plugins without manual configuration per
    struct definition (#5).

### Changed

* Add validation for unknown top-level options in `typedstruct` and `typedrecord`.
* Improve duplicate field errors with source line information.

## [0.3.0] - 2022-02-15

### Added

* [Plugin] Add the `field/4` callback with an additional `env` argument. This is
    the same as `field/3` but gives access to the environment of the field
    definition.

### Deprecated

* [Plugin] Deprecate the `field/3` callback in favour of `field/4`. You should
    migrate to `field/4`, simply by adding `_env` as the last argument in your
    implementation. Currently, if a plugin implements `field/3`, `field/4` is
    derived from it and a compilation warning is emitted. `field/3` will be
    removed in TypedStruct 1.0.0.

### Removed

* Drop support for unsupported Elixir versions in the tests and CI. The
    library may still be compatible, but this is not tested.

### Fixed

* Fix the lexical scope of the `typestruct` block, so it covers it completely.
    Previously, anything defined inside the `typedstruct` block, such as
    aliases, would not be available for the field definitions. See #22 and #21
    for details.
* Fix a typo in the documentation.

## [0.2.1] - 2020-07-19

### Added

* Add the `module: ModuleName` top-level option to create the typed struct in a
    submodule.

### Changed

* Update the `@typedoc` example in the documentation to put it inside the
    `typedstruct` block and not above. While putting it above works in the
    general case, it is mandatory to put it inside the block when defining a
    submodule.

## [0.2.0] - 2020-05-31

### Added

* Add a plugin API.

### Removed

* Remove reflection support through the `__keys__/0`, `__defaults__/0` and
    `__types__/0` function which where defined by TypedStruct in the user
    modules. If you rely on these functions, please use the
    [TypedStructLegacyReflection](https://github.com/ejpcmac/typed_struct_legacy_reflection)
    plugin to enable them again, and consider creating a plugin for your needs.

### Fixed

* Do not enforce fields with a default value set to nil (fixes #14).
* Prefix all internal module attributes and clean them after use (fixes #15).
* Create a scope in the `typedstruct` block to avoid import leaks.

## [0.1.4] - 2018-11-13

### Added

* Add the ability to generate an opaque type (#10).

## [0.1.3] - 2018-09-06

### Fixed

* Fix a bug where boolean fields with `default: false` where still enforced when
    setting `enforce: true` at top-level.

## [0.1.2] - 2018-09-06

### Added

* Add the ability to enforce keys by default (#6).

### Fixed

* Clarify the documentation about `runtime: false`.

## [0.1.1] - 2018-06-20

### Fixed

* Do not make the type nullable when there is a default value.

## [0.1.0] - 2018-06-19

### Added

* Struct definition
* Type definition
* Default values
* Enforced keys

[Unreleased]: https://github.com/saleyn/typedstruct/compare/main...develop
[0.5.0]: https://github.com/saleyn/typedstruct/compare/v0.3.0...v0.5.0
[0.3.0]: https://github.com/ejpcmac/typed_struct/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/ejpcmac/typed_struct/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/ejpcmac/typed_struct/compare/v0.1.4...v0.2.0
[0.1.4]: https://github.com/ejpcmac/typed_struct/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/ejpcmac/typed_struct/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/ejpcmac/typed_struct/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/ejpcmac/typed_struct/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/ejpcmac/typed_struct/releases/tag/v0.1.0
