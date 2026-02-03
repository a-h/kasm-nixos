# Kasm 

## Tasks

### desktop-build

```bash
nix build .#desktop
```

### desktop-push

```bash
crane push ./result ghcr.io/a-h/kasm-nixos/desktop:latest
```
