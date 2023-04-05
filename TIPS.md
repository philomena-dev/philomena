## Files Example

Website route manager:

    /lib/philomena_web/router.ex

    Example:

        router.ex ==> resources "/web3", Web3Controller, only: [:edit, :update], singleton: true

        file path ==> Web3Controller = /lib/philomena_web/controllers/registration/web3_controller.ex
        web3_controller.ex ==> defmodule PhilomenaWeb.Registration.Web3Controller do

        /lib/philomena_web/views/registration/web3_view.ex

        def edit(conn, _params) do ==> /lib/philomena_web/templates/registration/web3/edit.html.slime

## Migrations Build
https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Gen.Migration.html

## Mint Error Fix

If you are seeing this when trying to type "sudo mix ecto.gen.migration"...

    could not compile dependency :mint, "mix compile" failed. You can recompile this dependency with "mix deps.compile mint", update it with "mix deps.update mint" or clean it with "mix deps.clean mint"

You need to type this to fix the script

    sudo apt-get install erlang

## More Errors

Please make sure you have all the dependencies installed:

    Erlang/OTP
    Elixir
    Postgres
    Node.js

    Automake
    For Mac OSX users: brew install automake

    Libtool
    For Mac OSX users: brew install libtool

    Rust - https://www.rust-lang.org/tools/install
    Cargo - https://doc.rust-lang.org/cargo/getting-started/installation.html
    sudo apt-get install rustc
    sudo apt-get install cargo

Also, please make sure all versions are correct as well.

## Add Migration File

    sudo docker exec philomena_app_1 mix ecto.gen.migration <file-name> -r Philomena.Repo
    sudo docker exec philomena_app_1 mix ecto.migrate

## Remove Migration File
    DELETE FROM public.schema_migrations WHERE version = [version]

## Access Postgres

    sudo docker exec -it philomena_app_1 psql -h postgres -U postgres philomena_dev
    \conninfo
