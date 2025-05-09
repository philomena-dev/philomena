# Philomena

![Philomena](/assets/static/images/phoenix.svg)

## Getting Started

Make sure you have [Docker](https://docs.docker.com/engine/install/) and [Docker Compose plugin](https://docs.docker.com/compose/install/#scenario-two-install-the-docker-compose-plugin) installed.

You can open this repo via a [devcontainer](https://containers.dev/) in VSCode, JetBrains, GitHub Codespaces or any other [supported IDE](https://containers.dev/supporting). This setup is the recommended way to develop and this way philomena developers share the same dev configs. This makes sure for you that all the required dependencies are installed and configured correctly.

If you can't/don't want to use devcontainers, then go through the _Configure the Host_ section below, otherwise skip it, because this configuration is already done in a devcontainer.

Even if you aren't developing in a devcontainer the scripts in this repo will lazily spin it up and forward their execution into that container via `docker exec` to ensure all their dependencies are available. This way your host stays clean, and all the scripts _just work™_.

## Configure the Host

### Dev CLI `philomena`

Add the directory `scripts/path` to your `PATH` to get the `philomena` dev CLI globally available in your terminal. For example you can add the following to your shell's `.*rc` file, but adjust the path to philomena repo accordingly.

```bash
export PATH="$PATH:$HOME/dev/philomena/scripts/path"
```

### Pre-commit Hook

Run the following command to configure the git pre-commit hook that will auto-format the code and run lightweight checks on each commit.

```bash
philomena init
```

### IDE Setup

If you are using VSCode, you are encouraged to install the recommended extensions specified in [`.devcontainer/devcontainer.json`](./.devcontainer/devcontainer.json).

## Dev Loop

Use the following commands to bring up or shut down a dev stack.

```bash
philomena up
philomena down
```

Once the application has started, navigate to http://localhost:8080 and login with

| Credential | Value               |
| ---------- | ------------------- |
| Email      | `admin@example.com` |
| Password   | `philomena123`      |

> [!TIP]
> See the source code of `scripts/philomena.sh` for details on the additional parameters and other subcommands.

## Troubleshooting

If you are running Docker on Windows and the application crashes immediately upon startup, please ensure that `autocrlf` is set to `false` in your Git config, and then re-clone the repository. Additionally, it is recommended that you allocate at least 4GB of RAM to your Docker VM.

If you run into an OpenSearch bootstrap error, you may need to increase your `max_map_count` on the host as follows:

```
sudo sysctl -w vm.max_map_count=262144
```

If you have SELinux enforcing (Fedora, Arch, others; manifests as a `Could not find a Mix.Project` error), you should run the following in the application directory on the host before proceeding:

```
chcon -Rt svirt_sandbox_file_t .
```

This allows Docker or Podman to bind mount the application directory into the containers.

If you are using a platform which uses cgroups v2 by default (Fedora 31+), use `podman` and `podman-compose`.

## Deployment

You need a key installed on the server you target, and the git remote installed in your ssh configuration.

    git remote add production philomena@<serverip>:philomena/

The general syntax is:

    git push production master

And if everything goes wrong:

    git reset HEAD^ --hard
    git push -f production master

(to be repeated until it works again)
