Sets up HandBrakeCLI with dynamic library support for Amazon Linux environments.
No GUI support.

## Overview

Github Action should build the executable however, at this stage it is utilizing many dynamic import and the packages are required on the target machine too. The setup_dynamic_libs.sh should mostly set things up correctly. (sudo and Amazon SPAL repository required)
Before running the dynamic lib install script make sure Amazon SPAL repository is enabled with this command:

```bash
dnf install -y spal-release
```

It is also possible to run inside after the build in the container. The script installs x264 to /usr/ , it seems /usr/local/ doesn't seem to work if LD_LIBRARY_PATH=/usr/local/lib64:/usr/local/lib:$LD_LIBRARY_PATH is not specified.

## Requirements

- Docker (for containerized builds)
- Amazon Linux environment or Docker with Amazon Linux base image
- Standard build tools (gcc, make, etc. - included in Dockerfile)
