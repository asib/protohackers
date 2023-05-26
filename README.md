# Protohackers

Solutions to the [protohackers](protohackers.com) challenges.
These are probably not at all idiomatic - I used these challenges
and the [`h^`](hackattic.com) challenges to learn Elixir.

## Deploy and run

- Create an Ubuntu instance on AWS.
- Expose all TCP ports to all traffic.
- Attach an elastic IP just in case.
- [Install Elixir](#install-elixir)
- [Copy over files](#copy-over-files)
- SSH into the Ubuntu instance
- [Build a release](#build-a-release)
- [Run the server](#run-the-server)

### Install Elixir

From: https://askubuntu.com/questions/1418015/elixir-installation-on-ubuntu

Links to: https://www.erlang-solutions.com/downloads/

```
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt-get update
sudo apt-get install erlang
sudo apt-get install elixir
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