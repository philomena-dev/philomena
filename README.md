# Philomena
![Philomena](/assets/static/images/phoenix.svg)

## Getting started
On systems with `docker` and `docker-compose` installed, the process should be as simple as:

```
docker-compose build
docker-compose up
```

If you use `podman` and `podman-compose` instead, the process for constructing a rootless container is nearly identical:

```
podman-compose build
podman-compose up
```

Once the application has started, navigate to http://localhost:8080 and login with admin@example.com / philomena123

## Troubleshooting

If you are running Docker on Windows and the application crashes immediately upon startup, please ensure that `autocrlf` is set to `false` in your Git config, and then re-clone the repository. Additionally, it is recommended that you allocate at least 4GB of RAM to your Docker VM.

If you run into an Elasticsearch bootstrap error, you may need to increase your `max_map_count` on the host as follows:
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

## Files Example

Website route manager:

    /lib/philomena_web/router.ex

    Example:

        router.ex ==> resources "/web3", Web3Controller, only: [:edit, :update], singleton: true
        
        file path ==> Web3Controller = /lib/philomena_web/controllers/registration/web3_controller.ex
        web3_controller.ex ==> defmodule PhilomenaWeb.Registration.Web3Controller do

        /lib/philomena_web/views/registration/web3_view.ex

        def edit(conn, _params) do ==> /lib/philomena_web/templates/registration/web3/edit.html.slime


## Admin Login
This is the credentials to access the admin panel of this project repository.

    user: admin@example.com
    password: philomena123