# 📻 Proyecto Icecast en Kubernetes (GitOps con Argo CD) 🚀

Este repositorio contiene la configuración para desplegar un servidor de streaming de audio Icecast en un clúster de Kubernetes, gestionado mediante la filosofía GitOps utilizando Argo CD.

## 🎯 Filosofía GitOps: Git es la Única Fuente de Verdad

En este proyecto, tu repositorio de Git es el centro de todo. Todos los cambios, configuraciones y versiones de tu aplicación viven aquí. Tú describes cómo quieres que sea tu aplicación, y Argo CD se encarga de hacerla realidad en el clúster. No se hacen configuraciones manuales directamente en el servidor.

## 📋 Prerrequisitos

Para que este despliegue funcione, necesitas lo siguiente configurado:

### Servidor Kubernetes (192.168.1.76):
- Un servidor con Ubuntu o similar donde esté instalado MicroK8s
- Argo CD instalado y funcionando en este mismo clúster de MicroK8s
- cert-manager habilitado en MicroK8s (`microk8s enable cert-manager`)
- Un ClusterIssuer llamado `letsencrypt-prod` configurado en cert-manager
- Los puertos 80 y 443 de tu router deben estar redirigidos (Port Forwarding) a la IP local de tu servidor (192.168.1.76)

### Dominio Público:
- Un dominio/subdominio configurado con un registro A apuntando a tu IP pública (ej. icecast.dmarmijosa.com)

### Máquina Local (Tu Mac):
- Git instalado
- Docker Desktop instalado (aunque para Icecast usamos una imagen preexistente, Docker se utiliza para otras aplicaciones con el script deploy.sh)
- Argo CD CLI instalado y autenticado con tu servidor Argo CD (`argocd login argocd.dmarmijosa.com --grpc-web`)
- FFmpeg para enviar streams de prueba

## 📁 Estructura del Repositorio

```
.
├── k8s/
│   ├── 00-namespace.yaml         # Define el Namespace para Icecast
│   ├── 01-secrets.yaml           # Almacena las contraseñas de Icecast de forma segura (Base64)
│   ├── 02-configmap.yaml         # Contiene el archivo icecast.xml para la configuración del servidor
│   ├── 03-deployment.yaml        # Define cómo desplegar el contenedor de Icecast
│   ├── 04-service.yaml           # Expone el pod de Icecast internamente en el clúster
│   ├── 05-ingress.yaml           # Gestiona el acceso público a Icecast a través de HTTPS
│   └── 06-pvc.yaml               # Solicita almacenamiento persistente para los logs de Icecast
├── icecast-application.yaml      # Define la aplicación de Argo CD que monitorea 'k8s/'
└── deploy.sh                     # Script para automatizar el commit, push y sincronización con Argo CD
```

## ⚙️ Archivos de Configuración Clave

### k8s/01-secrets.yaml
Este archivo contiene las contraseñas para Icecast codificadas en Base64.

> ⚠️ **ADVERTENCIA DE SEGURIDAD CRÍTICA** ⚠️
> 
> Las contraseñas de ejemplo utilizadas en este proyecto son para **PROPÓSITOS DE PRUEBA Y APRENDIZAJE ÚNICAMENTE**.
> 
> **¡NUNCA uses contraseñas débiles en un entorno de producción o accesible públicamente!**
> 
> Debes cambiar todas las contraseñas (source-password, relay-password, admin-password) por valores fuertes y únicos antes de hacer público tu servidor.

Para codificar tus contraseñas en Base64:
```bash
echo -n 'tu_nueva_contraseña_secreta' | base64
```

### k8s/02-configmap.yaml
Este ConfigMap almacena el contenido del `icecast.xml` que Icecast utilizará. Incluye rutas para logs y archivos web, y el hostname de tu dominio. Las contraseñas se inyectan como variables de entorno desde `01-secrets.yaml`.

### k8s/05-ingress.yaml
Define cómo el tráfico de `https://icecast.dmarmijosa.com/` es dirigido a tu servicio de Icecast. También se encarga de solicitar automáticamente un certificado SSL a Let's Encrypt a través de cert-manager.

Asegúrate de que el `host:` y los `hosts:` TLS en este archivo coincidan con tu dominio real (`icecast.dmarmijosa.com`).

### icecast-application.yaml
Este archivo le dice a Argo CD dónde está tu repositorio Git (`source.repoURL`), qué rama monitorear (`targetRevision: main`), y qué directorio contiene los manifiestos de Kubernetes (`path: k8s`). También especifica dónde desplegar (el clúster local `https://kubernetes.default.svc`) y el namespace `icecast`.

## 🚀 Proceso de Despliegue (Manualmente)

Una vez que tengas todos los archivos YAML configurados y guardados en tu repositorio Git, el proceso es el siguiente:

1. **Asegúrate de que estás logueado en Argo CD CLI en tu Mac:**
   ```bash
   argocd login argocd.dmarmijosa.com --grpc-web
   ```
   (Introduce tus credenciales de administrador de Argo CD)

2. **Sube tus cambios a Git (si no lo has hecho ya):**
   ```bash
   git add .
   git commit -m "Initial Icecast setup or config updates"
   git push
   ```

3. **Crea la aplicación en Argo CD (si es la primera vez):**
   ```bash
   argocd app create -f icecast-application.yaml --upsert
   ```

4. **Sincroniza la aplicación en Argo CD:**
   ```bash
   argocd app sync icecast-app
   ```
   Este comando forzará a Argo CD a leer los últimos cambios de tu repositorio Git y aplicarlos en tu clúster de Kubernetes.

5. **Monitorea el estado:**
   Puedes monitorear el progreso y la salud de tu aplicación desde tu Mac:
   ```bash
   argocd app get icecast-app --refresh --watch
   ```
   O desde la interfaz web de Argo CD: https://argocd.dmarmijosa.com/applications

   Espera hasta que el **Sync Status** sea **Synced** y el **Health Status** sea **Healthy**.

## ✅ Cómo Probar tu Servidor Icecast

Una vez que la aplicación esté **Synced** y **Healthy** en Argo CD:

### Acceso a la Interfaz Web de Icecast:
- Abre tu navegador y ve a: https://icecast.dmarmijosa.com/status.xsl
- Deberías ver la página de estado de Icecast
- https://icecast.dmarmijosa.com/admin te pedirá las credenciales de administración

### Enviar un Stream de Audio (con FFmpeg desde tu Mac):
Necesitas un archivo de audio (ej. `.mp3`). Abre una terminal en tu Mac:

```bash
ffmpeg -re -i "ruta/a/tu/archivo.mp3" -c:a libmp3lame -b:a 128k -f mp3 icecast://source:[TU_SOURCE_PASSWORD_REAL]@icecast.dmarmijosa.com:8000/mystream
```

> **¡ATENCIÓN!** Recuerda cambiar `[TU_SOURCE_PASSWORD_REAL]` por tu source-password real (la que codificaste en Base64 en `01-secrets.yaml`).

**Pista para la contraseña de ejemplo (si la estás usando para pruebas):** `HazAlgoConKubernetesMuyEspecial`

### Escuchar el Stream:
Mientras FFmpeg esté enviando el stream, abre tu navegador o un reproductor compatible con streams (como VLC) y ve a:
- https://icecast.dmarmijosa.com/mystream

¡Deberías poder escuchar tu stream!

## ⚠️ Posibles Problemas Comunes

### Advertencias HTTPS/Certificados:
Si el certificado no se genera, verifica:
- Logs de los pods de cert-manager en el namespace cert-manager
- `microk8s kubectl describe certificate icecast-tls-secret -n icecast` para ver el estado de la emisión
- Asegúrate de que tu DNS (`icecast.dmarmijosa.com`) esté apuntando correctamente a tu IP pública
- Asegúrate de que los puertos 80/443 están abiertos y redirigidos al servidor 192.168.1.76

### CrashLoopBackOff del pod de Icecast:
- Revisa los logs del pod en Argo CD o con `microk8s kubectl logs <nombre-del-pod> -n icecast`

### Problemas de Conexión de argocd CLI:
- Asegúrate de usar `argocd login argocd.dmarmijosa.com --grpc-web`

## 🎉 ¡Disfruta de tu servidor Icecast en Kubernetes!