# Protohackers

Solutions to the [protohackers](protohackers.com) challenges.
These are probably not at all idiomatic - I used these challenges
and the [`h^`](hackattic.com) challenges to learn Elixir.

## Deploy and run on Fly.io

The Dockerfile accepts an `APPLICATION` argument, which will run
the specified application:

```
fly deploy --build-arg APPLICATION=means_to_an_end
```

### Memory

_Means to an End_ required additional memory. Fly enables updating
memory using the `fly scale` command:

```
$ fly scale show      
VM Resources for app: protohackers-asib

Groups
NAME    COUNT   KIND    CPUS    MEMORY  REGIONS 
app     1       shared  1       256 MB  lhr    

$ fly scale memory 512
```

## Deploy and run on AWS

1. Create an Ubuntu instance on AWS.
1. Expose all TCP ports to all traffic.
1. Attach an elastic IP just in case.
1. [Install Elixir](#install-elixir)
1. [Copy over files](#copy-over-files)
1. SSH into the Ubuntu instance
1. [Build a release](#build-a-release)
1. [Run the server](#run-the-server)

Alternatively, after installing Elixir, use
[`redeploy.sh`](./redeploy.sh) to sync, build and run an app.
You'll need to modify [`env.sh`](./env.sh) first to update the
username and host IP.

For example, the following will resync, build and run the `echo_server`
app:

```
$ ./redeploy.sh echo_server
```

### Install Elixir

From: https://askubuntu.com/questions/1418015/elixir-installation-on-ubuntu

Links to: https://www.erlang-solutions.com/downloads/

```
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt-get update
sudo apt-get install erlang elixir
```

### Copy over files

```
rsync -i protohackers.cer -r apps config mix.exs .formatter.exs ubuntu@UBUNTU_IP:/home/ubuntu/protohackers/
```

### Build a release

```
cd apps/APP_NAME
mix release
```

### Run the server

```
# from within the app directory
PORT=$PORT ../../_build/dev/rel/APP_NAME/bin/APP_NAME start
```