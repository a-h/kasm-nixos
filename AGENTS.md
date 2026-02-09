# Building / deploying

Use `nix develop` to get a dev shell with required tools.

To build and deploy locally, use the `xc` commands.

- `xc desktop-build` to build the desktop image.
- `xc desktop-load` to load it into docker `docker load < result`
- `xc desktop-upgrade` to run the latest version you just imported.
