# Nginx Proxy Manager (NPM) Integration Guide

This guide explains how to map the MASAREN API Gateway and Frontend to a public domain using Nginx Proxy Manager.

## 1. Network Setup
Ensure that the NPM container and the MASAREN containers are on the same Docker network.
In `docker-compose.yml`, add the network:
```yaml
networks:
  masaren-network:
    external: true
```

## 2. Mapping the API Gateway
To expose the backend to the web:
1.  **Add Proxy Host** in NPM.
2.  **Domain Names**: `api.masaren.ai`
3.  **Scheme**: `http`
4.  **Forward Hostname/IP**: `gateway` (or the local IP of the server)
5.  **Forward Port**: `8000`
6.  **Websockets Support**: ENABLE (Crucial for Chat and Real-time notifications).
7.  **SSL**: Select "Request a new SSL Certificate" (Let's Encrypt) and "Force SSL".

## 3. Mapping the Web App
1.  **Add Proxy Host** in NPM.
2.  **Domain Names**: `app.masaren.ai`
3.  **Scheme**: `http`
4.  **Forward Hostname/IP**: `web-app` (or the port where Vite is running, e.g., `localhost:5173`)
5.  **Forward Port**: `5173`
6.  **SSL**: Request a new SSL Certificate.

## 4. Handling Large Uploads (Evidence)
By default, Nginx limits uploads to 1MB. To allow large media files:
1.  Go to the **Advanced** tab of the Proxy Host.
2.  Add the following configuration:
    ```nginx
    client_max_body_size 500M;
    proxy_read_timeout 600s;
    proxy_send_timeout 600s;
    ```
