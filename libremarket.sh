#!/bin/bash

start() {
    # Levantar los contenedores en segundo plano
    export DOCKER_UID=$(id -u)
    export DOCKER_GID=$(id -g)
    docker compose up -d "$@"
}

stop() {
    export DOCKER_UID=$(id -u)
    export DOCKER_GID=$(id -g)
    docker compose down
}

# Comprobar el argumento proporcionado
if [[ $1 == "start" ]]; then
    shift
    start "$@"
elif [[ $1 == "stop" ]]; then
    stop
elif [[ $1 == "iex" ]]; then
    docker attach $2
elif [[ $1 == "logs" ]]; then
    docker compose logs -f
else
    echo "Uso: $0 {start|stop|iex nombre_de_contenedor}"
    echo "     $0 logs"
    exit 1
fi
