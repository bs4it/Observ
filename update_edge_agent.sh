#!/bin/bash
#teste
source config.env
# Variáveis
EDGE_CONTAINER="portainer_edge_agent"
PORTAINER_AGENT_IMAGE="portainer/agent"
EDGE_ID="${EDGE_ID:-}"
EDGE_KEY="${EDGE_KEY:-}"
EDGE_INSECURE_POLL="${EDGE_INSECURE_POLL:-1}"
PORTAINER_AGENT_DATA_DIR="${PORTAINER_AGENT_DATA_DIR:-/opt/portainer/portainer_agent_data}"
export ENABLE_CLEANUP="true"
#ENABLE_CLEANUP="true" - Caso queira a Limpeza de volumes e imagens não utilizadas, descomente esse comando. Anteção isso afeta todos os clientes, analise fria e calmamente antes de utilizar.
#               "false" - Caso nao queira limpeza    

# Obtem a versão a ser instalada no GitHub
LATEST_VERSION_RAW=$(curl -s https://api.github.com/repos/bs4it/Observ/contents/portainer_edge_version?ref=main)

if [ $? -ne 0 ]; then
  echo "Erro ao obter a versão do GitHub."
  exit 1
fi
LATEST_VERSION=$(echo "$LATEST_VERSION_RAW" | jq -r '.content' | base64 --decode)
if [ -z "$LATEST_VERSION" ]; then
  echo "Erro ao decodificar a versão mais recente."
  exit 1
fi
echo "Versão mais recente disponível: $LATEST_VERSION"

# Obter a versão atual do container (se existir)
CURRENT_VERSION=""
if docker inspect "$EDGE_CONTAINER" >/dev/null 2>&1; then
  CURRENT_VERSION=$(docker inspect "$EDGE_CONTAINER" | jq -r '.[0].Config.Image' | cut -d ':' -f 2)
  if [ $? -ne 0 ]; then
    echo "Aviso: Erro ao obter a versão atual do container."
  fi
  echo "Versão atual do Edge Agent: $CURRENT_VERSION"
else
  echo "O container '$EDGE_CONTAINER' não existe."
fi

# Verificação e atualização
if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
  echo "Atualizando o Edge Agent de $CURRENT_VERSION para $LATEST_VERSION..."

  # Pull da nova imagem
  echo "Baixando a imagem $PORTAINER_AGENT_IMAGE:$LATEST_VERSION..."
  docker pull "$PORTAINER_AGENT_IMAGE":"$LATEST_VERSION"
  if [ $? -ne 0 ]; then
    echo "Erro ao baixar a imagem $PORTAINER_AGENT_IMAGE:$LATEST_VERSION."
    exit 1
  fi

  # Parar e remover o container antigo
  if [ ! -z "$CURRENT_VERSION" ]; then
    echo "Parando o container '$EDGE_CONTAINER'..."
    docker stop "$EDGE_CONTAINER"
    if [ $? -ne 0 ]; then
      echo "Erro ao parar o container '$EDGE_CONTAINER'."
    fi

    echo "Removendo o container '$EDGE_CONTAINER'..."
    docker rm "$EDGE_CONTAINER"
    if [ $? -ne 0 ]; then
      echo "Erro ao remover o container '$EDGE_CONTAINER'."
    fi
  fi

  # Executar o novo container
  echo "Executando o novo container '$EDGE_CONTAINER' na versão $LATEST_VERSION..."
  docker run -d \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /var/lib/docker/volumes:/var/lib/docker/volumes \
    -v /:/host \
    -v "$PORTAINER_AGENT_DATA_DIR":/data \
    --restart always \
    --name "$EDGE_CONTAINER" \
    -e EDGE=1 \
    -e EDGE_ID="$EDGE_ID" \
    -e EDGE_KEY="$EDGE_KEY" \
    -e EDGE_INSECURE_POLL="$EDGE_INSECURE_POLL" \
    "$PORTAINER_AGENT_IMAGE":"$LATEST_VERSION"
  if [ $? -ne 0 ]; then
    echo "Erro ao executar o novo container '$EDGE_CONTAINER'."
    exit 1
  fi

  echo "Edge Agent atualizado com sucesso para a versão $LATEST_VERSION!"
else
  echo "Edge Agent já está na versão mais recente ($CURRENT_VERSION)."
fi


# Limpeza de volumes e imagens não utilizadas (controlada por variável de ambiente)
if [ "${ENABLE_CLEANUP}" == "true" ] || [ "${ENABLE_CLEANUP}" == "1" ]; then
 echo "Iniciando limpeza de volumes e imagens não utilizadas..."
 docker system prune -af --volumes
 if [ $? -ne 0 ]; then
   echo "Erro ao limpar volumes não utilizados."
 fi
  docker image prune -a -f
 if [ $? -ne 0 ]; then
   echo "Erro ao limpar imagens não utilizadas."
 fi
   echo "Limpeza de volumes e imagens não utilizadas concluída."
else
   echo "Limpeza automática de volumes e imagens não utilizada (variável ENABLE_CLEANUP não definida como 'true' ou '1')."
fi


echo "Script de atualização do Edge Agent finalizado."
