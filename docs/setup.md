# Guía de Instalación y Configuración

## Requisitos Previos

- Node.js 18+ (para el frontend)
- Docker y Docker Compose (para el backend)
- Una cuenta en Oracle Cloud (Siempre Gratis)
- Una API Key de Google Gemini
- Cliente de Oracle Database (opcional, para conexión local)

## Entorno Local

### 1. Clonar el repositorio

```bash
git clone https://github.com/Ml1302/APP01-Gesti-n-financiera-personal.git
cd APP01-Gesti-n-financiera-personal
```

### 2. Configurar variables de entorno

```bash
cp .env.example .env
# Editar .env con tus credenciales
```

### 3. Backend

```bash
# Construir y levantar contenedores
docker-compose up -d

# Las migraciones de base de datos se ejecutan automáticamente
```

### 4. Frontend

```bash
cd frontend  # o el directorio correspondiente
npm install
npm run dev
```

La aplicación estará disponible en `http://localhost:3000`.

## Despliegue

### Frontend (Vercel)

1. Conecta tu repositorio a [Vercel](https://vercel.com).
2. Configura las variables de entorno desde el panel de Vercel.
3. Cada push a `main` despliega automáticamente.

### Backend (Oracle Cloud)

1. Aprovisiona una instancia Always Free con Oracle Linux.
2. Instala Docker y Docker Compose.
3. Copia los archivos del backend a la instancia.
4. Configura las variables de entorno en la instancia.
5. Ejecuta `docker-compose up -d`.

## Variables de Entorno

Ver `.env.example` en la raíz del proyecto para la lista completa de variables requeridas.
