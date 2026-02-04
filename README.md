# Kasm 

## Tasks

### desktop-build

Interactive: true

```bash
nix build .#desktop
```

### desktop-push

Interactive: true

```bash
gunzip -c result | skopeo copy docker-archive:/dev/stdin docker://ghcr.io/a-h/kasm-nixos/desktop:latest
```

### desktop-pull

Interactive: true

```bash
skopeo copy docker://ghcr.io/a-h/kasm-nixos/desktop:latest docker-archive:desktop.tar
```