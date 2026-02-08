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

### desktop-load

Interactive: true

```bash
docker load < result
```

### desktop-pull

Interactive: true

```bash
skopeo copy docker://ghcr.io/a-h/kasm-nixos/desktop:latest docker-archive:desktop.tar
```

### desktop-run

Interactive: true

```bash
docker rm -f kasm-desktop 2>/dev/null || true
docker run -d --name kasm-desktop \
	--tmpfs /home/user --tmpfs /tmp \
	-p 6901:6901 \
	ghcr.io/a-h/kasm-nixos/desktop:latest
```

### desktop-upgrade

Interactive: true

```bash
docker rm -f kasm-desktop 2>/dev/null || true
docker run -d --name kasm-desktop \
	--tmpfs /home/user --tmpfs /tmp \
	-p 6901:6901 \
	ghcr.io/a-h/kasm-nixos/desktop:latest
```

### browser-open

Open in browser:

```bash
open https://localhost:6901/
```