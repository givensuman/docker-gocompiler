# givensuman/docker-gocompiler

a compiler-as-a-service for Go

Cross-compiling Go projects that use CGO is notoriously difficult due to linker dependencies. This image provides a pre-configured environment using the Zig toolchain as a C/C++ compiler, allowing you to build statically linked binaries for Linux, macOS, and Windows from any host machine with a single command.

## Usage

Cross-compile a Go project with this one-liner:

```bash
docker run --rm -v $(pwd):/app givensuman/docker-gocompiler
```

## License

[MIT](./LICENSE)
