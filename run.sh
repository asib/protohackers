set -x

export PORT=5000
RUNNING_PID=$(lsof -t -i :$PORT)

if [ $? -eq 0 ]; then
    echo "killing $RUNNING_PID"
    kill -s TERM $RUNNING_PID
fi

cd /home/ubuntu/protohackers/apps/$1
mix local.hex --force
mix deps.get
mix release --overwrite
../../_build/dev/rel/$1/bin/$1 start