set -x
source env.sh

./sync.sh
ssh -i protohackers.cer $HOST "/home/ubuntu/protohackers/run.sh $1"