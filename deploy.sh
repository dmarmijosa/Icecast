#!/bin/bash
# Script para automatizar el flujo de despliegue completo. [cite: 101]

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
    print_step "Verificando dependencias (git, docker, argocd)..." [cite: 105]
    command -v git >/dev/null 2>&1 || { print_error "Git no está instalado."; } [cite: 105, 106]
    docker info >/dev/null 2>&1 || { print_error "Docker no está corriendo. Por favor, inícialo."; } [cite: 106]
    command -v argocd >/dev/null 2>&1 || { print_error "Argo CD CLI no está instalado."; } [cite: 107]
    print_success "Todas las dependencias están listas." [cite: 108]
}

# --- Comienzo del Script ---
check_dependencies
print_step "Iniciando el script de despliegue automatizado" [cite: 109]

# --- Preguntas Interactivas ---
read -p "Introduce tu nombre de usuario de Docker Hub: " DOCKER_USER [cite: 109]
read -p "Introduce el nombre de la aplicación (ej. teslo-shop, pizzeria-bot): " APP_NAME [cite: 109]
read -p "Introduce el nombre del Deployment de Kubernetes (ej. teslo-backend-deployment): " DEPLOYMENT_NAME [cite: 109]
read -p "¿Es este un despliegue completamente nuevo? (s/n) [n]: " IS_NEW_DEPLOYMENT [cite: 109]
read -p "Escribe un mensaje para el commit de Git: " COMMIT_MESSAGE [cite: 109]

# --- Fase 1: Git ---
print_step "Tarea 1: Subiendo cambios a Git..." [cite: 109]
git add . [cite: 110]
if git diff-index --quiet HEAD --; then
    print_warning "No hay cambios para hacer commit. Continuando..."
else
    git commit -m "$COMMIT_MESSAGE" [cite: 110]
fi
git push || print_error "Falló el 'git push'. Verifica tu conexión y permisos." [cite: 110]
print_success "Cambios subidos a Git correctamente." [cite: 111]

# --- Fase 2: Docker ---
DOCKER_IMAGE="$DOCKER_USER/$APP_NAME:latest" [cite: 112]
print_step "Tarea 2: Construyendo y subiendo imagen Docker multi-plataforma: $DOCKER_IMAGE" [cite: 112]
if ! docker buildx build --platform linux/amd64,linux/arm64 -t "$DOCKER_IMAGE" --push .; then [cite: 113]
    print_error "La construcción o subida de la imagen de Docker falló. Intenta añadir --no-cache si el problema persiste." [cite: 113]
fi
print_success "Imagen Docker subida a Docker Hub correctamente." [cite: 114]

# --- Fase 3: Argo CD ---
if [[ "$IS_NEW_DEPLOYMENT" =~ ^[sS]([iI])?$ ]]; then [cite: 114]
    # Despliegue nuevo
    ARGO_APP_FILE="${APP_NAME}-application.yaml" [cite: 115]
    print_step "Tarea 3 (Nuevo Despliegue): Creando aplicación en Argo CD desde '$ARGO_APP_FILE'..." [cite: 115]
    if [ ! -f "$ARGO_APP_FILE" ]; then [cite: 116]
        print_error "No se encontró el archivo '$ARGO_APP_FILE'. Asegúrate de que exista en la raíz del proyecto." [cite: 116]
    fi
    argocd app create -f "$ARGO_APP_FILE" --upsert || print_error "Falló la creación de la aplicación en Argo CD." [cite: 117, 118]
    print_warning "Aplicación creada. Forzando una sincronización inicial..." [cite: 119]
    argocd app sync "$APP_NAME" [cite: 119]
    print_success "Aplicación '$APP_NAME' creada y sincronizada en Argo CD." [cite: 119]
else
    # Actualización de una aplicación existente
    print_step "Tarea 3 (Actualización): Reiniciando el Deployment '$DEPLOYMENT_NAME'..." [cite: 120]
    if ! argocd app actions run "$APP_NAME" restart --kind Deployment --resource-name "$DEPLOYMENT_NAME"; then [cite: 121]
        print_warning "El reinicio con 'actions' falló. Intentando con la interfaz web o revisa tu login de Argo CD (quizás necesites --grpc-web)." [cite: 122]
        echo "Como alternativa, puedes reiniciar manualmente desde el dashboard de Argo CD o desde el servidor con:" [cite: 123]
        echo "microk8s kubectl rollout restart deployment $DEPLOYMENT_NAME -n <tu-namespace>" [cite: 123]
    else
        print_success "Deployment reiniciado. Argo CD se encargará de usar la nueva imagen." [cite: 123]
    fi
fi
echo -e "\n${COLOR_GREEN}🚀 ¡Despliegue completado! 🚀${NC}" [cite: 124]
echo "Verifica el estado de tu aplicación en el dashboard de Argo CD o con 'argocd app get $APP_NAME'." [cite: 124]