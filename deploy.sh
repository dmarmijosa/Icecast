#!/bin/bash
# Script para automatizar el flujo de despliegue completo.

set -e

# --- Definición de colores ---
COLOR_GREEN='\033[0;32m'
COLOR_BLUE='\033[0;34m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
NC='\033[0m'

# --- Funciones de ayuda ---
print_step() {
    echo -e "\n${COLOR_BLUE}===> $1${NC}";
}
print_success() {
    echo -e "${COLOR_GREEN}✓ $1${NC}";
}
print_warning() {
    echo -e "${COLOR_YELLOW}!! $1${NC}";
}
print_error() {
    echo -e "${COLOR_RED}✗ $1${NC}" >&2;
    exit 1;
}

# --- Verificación de dependencias ---
check_dependencies() {
    print_step "Verificando dependencias (git, docker, argocd)..."
    command -v git >/dev/null 2>&1 || { print_error "Git no está instalado."; }
    docker info >/dev/null 2>&1 || { print_error "Docker no está corriendo. Por favor, inícialo."; }
    command -v argocd >/dev/null 2>&1 || { print_error "Argo CD CLI no está instalado."; }
    print_success "Todas las dependencias están listas."
}

# --- Comienzo del Script ---
check_dependencies
print_step "Iniciando el script de despliegue automatizado"

# --- Preguntas Interactivas ---
read -p "Introduce tu nombre de usuario de Docker Hub: " DOCKER_USER
read -p "Introduce el nombre de la aplicación (ej. teslo-shop, pizzeria-bot): " APP_NAME
read -p "Introduce el nombre del Deployment de Kubernetes (ej. teslo-backend-deployment): " DEPLOYMENT_NAME
read -p "¿Es este un despliegue completamente nuevo? (s/n) [n]: " IS_NEW_DEPLOYMENT
read -p "Escribe un mensaje para el commit de Git: " COMMIT_MESSAGE

# --- Fase 1: Git ---
print_step "Tarea 1: Subiendo cambios a Git..."
git add .
if git diff-index --quiet HEAD --; then
    print_warning "No hay cambios para hacer commit. Continuando..."
else
    git commit -m "$COMMIT_MESSAGE"
fi
git push || print_error "Falló el 'git push'. Verifica tu conexión y permisos."
print_success "Cambios subidos a Git correctamente."

# --- Fase 2: Docker ---
DOCKER_IMAGE="$DOCKER_USER/$APP_NAME:latest"
print_step "Tarea 2: Construyendo y subiendo imagen Docker multi-plataforma: $DOCKER_IMAGE"
if ! docker buildx build --platform linux/amd64,linux/arm64 -t "$DOCKER_IMAGE" --push .; then
    print_error "La construcción o subida de la imagen de Docker falló. Intenta añadir --no-cache si el problema persiste."
fi
print_success "Imagen Docker subida a Docker Hub correctamente."

# --- Fase 3: Argo CD ---
if [[ "$IS_NEW_DEPLOYMENT" =~ ^[sS]([iI])?$ ]]; then
    # Despliegue nuevo
    ARGO_APP_FILE="${APP_NAME}-application.yaml"
    print_step "Tarea 3 (Nuevo Despliegue): Creando aplicación en Argo CD desde '$ARGO_APP_FILE'..."
    if [ ! -f "$ARGO_APP_FILE" ]; then
        print_error "No se encontró el archivo '$ARGO_APP_FILE'. Asegúrate de que exista en la raíz del proyecto."
    fi
    argocd app create -f "$ARGO_APP_FILE" --upsert || print_error "Falló la creación de la aplicación en Argo CD."
    print_warning "Aplicación creada. Forzando una sincronización inicial..."
    argocd app sync "$APP_NAME"
    print_success "Aplicación '$APP_NAME' creada y sincronizada en Argo CD."
else
    # Actualización de una aplicación existente
    print_step "Tarea 3 (Actualización): Reiniciando el Deployment '$DEPLOYMENT_NAME'..."
    if ! argocd app actions run "$APP_NAME" restart --kind Deployment --resource-name "$DEPLOYMENT_NAME"; then
        print_warning "El reinicio con 'actions' falló. Intentando con la interfaz web o revisa tu login de Argo CD (quizás necesites --grpc-web)."
        echo "Como alternativa, puedes reiniciar manualmente desde el dashboard de Argo CD o desde el servidor con:"
        echo "microk8s kubectl rollout restart deployment $DEPLOYMENT_NAME -n <tu-namespace>"
    else
        print_success "Deployment reiniciado. Argo CD se encargará de usar la nueva imagen."
    fi
fi
echo -e "\n${COLOR_GREEN}🚀 ¡Despliegue completado! 🚀${NC}"
echo "Verifica el estado de tu aplicación en el dashboard de Argo CD o con 'argocd app get $APP_NAME'."