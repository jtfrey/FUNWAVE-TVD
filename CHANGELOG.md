# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- CMake build system
- mod_dictionary:  a class implementing a basic keyword-value container

### Changed

- mod_input:  modified to cache all keyword-value pairs from a named input file for reuse each time the same input file is referenced
- Execution header to stdout in main program, displays vital config details, version, etc.
- Minor fixups in variable visibility in PARALLEL versus serial compilation

