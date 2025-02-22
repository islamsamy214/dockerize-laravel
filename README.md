# Laravel Lumen in Docker  

**Dockerize PHP Laravel or Lumen projects with the common extensions**  

## Introduction  
This is an edited clone of Sail but with PHP 8.3 version.  

## How to Use  
1. Add the provided files to your project.  
2. Review the `Dockerfile` and remove any unneeded steps to minimize the image.  
3. Run `docker compose up` or `sudo docker compose up`.  

---

## Optimal Configuration  

### 1. Avoid Using `artisan serve`  
The `artisan serve` command is not designed for production environments and is better suited for development. To discourage its use, make the following adjustment:  

**Comment out the default PHP command that uses `artisan serve`:**  
```dockerfile
# ENV SUPERVISOR_PHP_COMMAND="/usr/bin/php -d variables_order=EGPCS /var/www/html/artisan serve --host=0.0.0.0 --port=80"
```
2. Enable Octane with Swoole

For better performance, use Octane with Swoole. Uncomment and configure the Octane-related command in your Dockerfile:

Use Octane with Swoole for improved performance:

```dockerfile
ENV SUPERVISOR_PHP_COMMAND="/usr/bin/php -d variables_order=EGPCS /var/www/html/artisan octane:start --server=swoole --host=0.0.0.0 --port=80"
```

---

Steps to Implement

1. Install Octane in Your Laravel Application

Run the following commands:

```bash
composer require laravel/octane  
php artisan octane:install  
php artisan vendor:publish --tag=octane-config
```

2. Update Your Dockerfile

Configure Octane as the default PHP server:

```dockerfile
# Set Octane as the default PHP command
ENV SUPERVISOR_PHP_COMMAND="/usr/bin/php -d variables_order=EGPCS /var/www/html/artisan octane:start --server=swoole --host=0.0.0.0 --port=80"
```

3. Configure Nginx

Use Nginx to forward traffic to Octane.

4. Deploy the Setup

Build and start your Docker containers:

```bash
docker-compose up --build
```

---

By following this approach, your Laravel Lumen application will leverage the performance benefits of Octane with Swoole, while Nginx acts as the reverse proxy to handle incoming traffic efficiently.


---

Buy Me a Coffee

https://www.buymeacoffee.com/islamsamy

