#!/bin/bash

# Обновление и установка необходимых пакетов
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y curl git jq lz4 build-essential unzip make gcc ncdu tmux cmake clang pkg-config libssl-dev python3-pip protobuf-compiler bc

# Установка Docker
sudo apt install -y docker.io

# Создание и переход в директорию для Morph
mkdir -p ~/.morph
cd ~/.morph

# Клонирование репозитория Morph
git clone https://github.com/morph-l2/morph.git
cd morph
git checkout v0.2.0-beta

# Установка Go
sudo apt install -y golang-go

# Сборка Geth
make nccc_geth

# Сборка ноды
cd node
make build
cd ..

# Загрузка и распаковка конфигурационных файлов
cd ~/.morph
wget https://raw.githubusercontent.com/morph-l2/config-template/main/holesky/data.zip
unzip data.zip

# Генерация и сохранение приватной фразы
openssl rand -hex 32 > jwt-secret.txt
JWT_SECRET=$(cat jwt-secret.txt)

# Загрузка и распаковка снапшота
wget -q --show-progress https://snapshot.morphl2.io/holesky/snapshot-20240805-1.tar.gz
tar -xzvf snapshot-20240805-1.tar.gz
mv snapshot-20240805-1/geth geth-data
mv snapshot-20240805-1/data node-data

# Запуск Geth в screen-сессии
screen -S geth -dm bash -c "
  cd ~/.morph/morph
  ./go-ethereum/build/bin/geth --morph-holesky \
    --datadir './geth-data' \
    --http \
    --http.api=web3,debug,eth,txpool,net,engine \
    --authrpc.addr localhost \
    --authrpc.vhosts='localhost' \
    --authrpc.port 8551 \
    --authrpc.jwtsecret=./jwt-secret.txt \
    --miner.gasprice='100000000' \
    --log.filename=./geth.log
"

# Ожидание запуска Geth
sleep 10

# Запуск ноды в screen-сессии
screen -S morph -dm bash -c "
  cd ~/.morph
  ./morph/node/build/bin/morphnode --home ./node-data \
    --l2.jwt-secret ./jwt-secret.txt \
    --l2.eth http://localhost:8545 \
    --l2.engine http://localhost:8551 \
    --log.filename ./node.log
"

# Ожидание запуска ноды
sleep 10

# Вывод приватной фразы
echo "Приватная фраза (JWT_SECRET): $JWT_SECRET"

# Инструкции по подключению к screen-сессиям
echo "Для подключения к screen-сессии Geth выполните: screen -r geth"
echo "Для подключения к screen-сессии Morph выполните: screen -r morph"
