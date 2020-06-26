
Create the Cross-build containers with whatever dependencies your Rust requires (can update the Dockerfiles here to add/remove dependencies: `build/containers/intermediate`) by running this command:
```bash
PREFIX=myacr.azurecr.io BUILD_AMD64=1 BUILD_ARM32=0 BUILD_ARM64=1 make cross
```

The Cross-build containers install Rust and Cross as suggested (in part) by the workaround in https://github.com/rust-embedded/cross/issues/260.

Because Github Actions are built into docker containers, `cross` struggles to mount the workspace folder.  To workaround that, the workflow (.github/workflows/build-rust-container.yml) creates a symbolic link (docker-in-docker volume mount sources are in terms of the top-level docker.sock):
```yaml
    - name: Create /github/workspace link for Docker-in-Docker references
      run: |
        sudo mkdir /github
        sudo ln -s $PWD /github/workspace
```