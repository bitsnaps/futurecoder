# Stage 1: Python base
FROM python:3.12.1-slim as python-base

# Install git and poetry
RUN apt-get update && apt-get install -y git && \
    pip install poetry

# Set up poetry
ENV POETRY_NO_INTERACTION=1 \
    POETRY_VIRTUALENVS_IN_PROJECT=1 \
    POETRY_VIRTUALENVS_CREATE=1 \
    POETRY_CACHE_DIR=/tmp/poetry_cache

WORKDIR /app

# Copy poetry files
COPY pyproject.toml poetry.lock ./

# Install python dependencies
RUN poetry install --no-root


# Stage 2: Static file generation
FROM python-base as static-generator

WORKDIR /app

# Copy application code
COPY . .

# Generate static files
RUN . .venv/bin/activate && ./scripts/generate.sh


# Stage 3: Frontend build
FROM node:22-alpine as frontend-builder

WORKDIR /app

# Copy frontend code
COPY frontend/package.json frontend/package-lock.json ./frontend/
COPY frontend/public ./frontend/public/
COPY frontend/src ./frontend/src/
COPY frontend/craco.config.js ./frontend/

# Copy generated files from the previous stage
COPY --from=static-generator /app/frontend/src/python_book.js ./frontend/src/
COPY --from=static-generator /app/frontend/src/generated_steps.js ./frontend/src/
COPY --from=static-generator /app/frontend/public/service-worker.js ./frontend/public/

# Install npm dependencies
WORKDIR /app/frontend
RUN npm ci

# Build the frontend
RUN npm run build


# Stage 4: Final runtime image
FROM nginx:stable-alpine

# Copy built frontend from the builder stage
COPY --from=frontend-builder /app/frontend/build /usr/share/nginx/html

# Copy nginx config if needed (optional, for custom routing)
# COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]