# Overview

This repo creates Kasm Workspaces - Docker containers intended for interactive use - using Nix.

Kasm Workspaces serve KasmVNC on a port, used to stream desktops. KasmVNC is a fork of TigerVNC, with modifications to provide additional features. KasmVNC uses noVNC as a web UI. KasmVNC and the Web UI are packaged by a fork of KasmVNC at the github.com/a-h/KasmVNC which adds a Nix flake to build it from source instead of using the complex Dockerfile build process.

Kasm provides example Docker containers at https://github.com/kasmtech/workspaces-core-images - these core images are the base images that other images are based from.

Kasm also provides workspace images at https://github.com/kasmtech/workspaces-images/ which provide the next level of configuration.

The Nix project here reproduces the Dockerfile based processes from scratch using Nix instead, to allow for reproducible image building, and access to the latest packages.

Read the Kasm Workspaces Core and Workspaces Images source code, instead of guessing at the correct configuration and operation, because the Kasm images work well.

Instructions for building Docker images using a Dockerfile based workflow are at https://www.kasmweb.com/docs/develop/how_to/building_images.html

# Registries

Kasm Registries share information about Kasm Workspaces that can be configured.

Kasm Registries are based on this template repo - https://github.com/kasmtech/workspaces_registry_template

Really, they're just a complicated way of serving a JSON file that contains all available workspaces.

Here are two public examples, the first one is small, the second is larger.

- https://kasmregistry.linuxserver.io/1.1/list.json
- https://registry.kasmweb.com/1.0/list.json

The `./workspace.json` file in this repo would show up in a list.json file.

# Building / deploying

Use `nix develop` to get a dev shell with required tools.

To build and deploy locally, use the `xc` commands.

- `xc desktop-build` to build the desktop image.
- `xc desktop-load` to load it into docker `docker load < result`
- `xc desktop-upgrade` to run the latest version you just imported.

So, a typical local build and test look would simply run:

```bash
xc desktop-build && xc desktop-load && xc desktop-upgrade
```

Don't try and use timeout or other scripts. You will be allowed to run `xc` commands automatically, so it makes it much faster.

## Troubleshooting Kasm Provisioning Errors

### "Container is restarting" errors during Kasm provisioning

**Problem:** When attempting to run the image in Kasm, you get an error:
```
Container ... is restarting, wait until the container is running
```

This occurs because Kasm's provisioning system tries to run post-provision commands via `docker exec` while the container is in a restart loop.

**Cause:** The container entrypoint was exiting when child services (KasmVNC or the XFCE desktop) terminated, causing Docker to restart the container repeatedly.

**Solution:** The entrypoint and startup scripts have been modified to:

1. **Keep the main entrypoint process alive** - Uses a monitoring loop instead of waiting for child processes, allowing `docker exec` to work even if services crash
2. **Make the desktop startup resilient** - XFCE components no longer cause the entire session to fail if one component fails to start
3. **Add comprehensive logging** - Health status and warnings are logged to `/tmp/container-health.log` and `/tmp/xstartup.log` for debugging

**Key changes:**
- `startup-script.nix`: Now runs a monitoring loop instead of `wait $XVNC_PID`, and logs service health
- `xstartup.sh`: Now uses `set +e` to continue on component failures, handles D-Bus startup failures gracefully, and uses a loop instead of `sleep infinity`

**Debugging:** After deploying to Kasm, check these logs inside the running container:
- `/tmp/container-health.log` - Service availability monitoring
- `/tmp/xstartup.log` - XFCE desktop session output
- Run `docker logs <container-id>` on the host for entrypoint output
