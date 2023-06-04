set -x
source env.sh

rsync -i protohackers.cer -r apps config mix.exs .formatter.exs run.sh $HOST:/home/ubuntu/protohackers/
