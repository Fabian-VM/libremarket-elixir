


# Infraestructura

Nodos en general:
- Hostname: sd-nodo-*
- Usuario: vboxuser
- Contraseña: vboxuser

Nodo 2 (postgres)
- Usuario: "appuser" 
- Contraseña: "soporte"
- Bases de datos: "appdb"

Red: 
- Host-only
- Nombre "vboxnet0"
- 192.168.56.0/24
    - Nodo 1: .10
    - Nodo 2: .11
    - Nodo 3: .12





# Cómo guardar configs de vms y demás

Listar
VBoxManage list vms

Guardar configs
VBoxManage showvminfo "sd-nodo-1" --machinereadable > sd-nodo-1.txt

Guardar el ova (o sea los discos y todo, pesadito)
VBoxManage export "sd-nodo-1" --output sd-nodo-1.ova

Guardar cosasa de redes
VBoxManage list hostonlyifs > hostonlyifs.txt
VBoxManage list dhcpservers > dhcpservers.txt








# 1: Instanciar nodo 1

ISO (elegir el que dice server install): https://ubuntu.zero.com.ar/releases/noble/

Verificar checksum que coincida con alguno de aca: https://ubuntu.zero.com.ar/releases/noble/SHA256SUMS
sha256sum ubuntu-24.04.5-live-server-amd64.iso

nombrarlos como sd-nodo-*



# 2: Crear la red

**Red host only**
Configurar una red host-only desde tools > host-only networks
El tab "adapter" es la configuracion del adaptador para la máquina host, dejarle la primer IP disponible (192.168.56.1/24)
La red debe quedar como dice el enunciado del lab3 (la ip de red) y mascara usar la /24 nomas
Probablemente le dejara el nombre "vboxnet0"

Luego, ir a la config de la vm del nodo 1 y agregar el adapter 2, ponerle "host-only" y usar el nombre de la red (que sera la unica opcion para elegir probablemente)

arrancar la vm



# 3: Configuración de red para el nodo 1

**Listar ips configuradas**
ip -br addr

**Configurar ip estatica**
Modificar ip en el archivo config
sudo nano /etc/netplan/50-cloud-init.yaml

Algo asi
```
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      dhcp4: false
      addresses:
        - 192.168.56.10/24
```

Y luego aplicar
sudo netplan try

**Probar**
en la terminal del nodo 1 probar a hacer ping a la ip del host (la que se indico en tools > host-only networks > la pestaña "adapter")
y tambien probar a hacer ping al nodo 1 desde una terminal en el host



# 3: SSH

Ya que la red ya esta configurada, para mas comodidad

sudo apt install openssh-server
sudo systemctl enable --now ssh

y listo, pa conectarse (obviamente usar el username e ip del nodo):
ssh vboxuser@192.168.56.11 

si sale algo de pregunta de si es o no confiable, decirle "yes"



# 4: Instanciar nodo 2

Clonar el nodo 1

**Cambiar hostname**
sudo hostnamectl set-hostname sd-nodo-2

**Configurar red**
Dejar el adaptador de la red host-only en la instancia
Entrar al archivo de configuración de netplan de la máquina para darle otra ip estática diferente (sino hay conflicto)
(y es mas o menos lo mismo que la configuracion de red para el nodo 1)

**Probar**
Reiniciar para aplicar los cambios
sudo reboot

Una vez reiniciado, hacer ping entre el nodo clonado y los demás, para verificar conexión




# 5: Servidor nodo 2


**Instalar cosas**
Instalar apache, php, postgres y otras cositas para conectarlos
sudo apt install apache2 php postgresql libapache2-mod-php php-pgsql

Verificar que estan andando
sudo systemctl status apache2
sudo systemctl status postgresql


**Crear db**
Entrar al postgres y crear la db
sudo -u postgres psql
CREATE USER appuser WITH PASSWORD 'soporte';
CREATE DATABASE appdb OWNER appuser;
\q

Entrar a la db para crear las tablas
sudo -u postgres psql -d appdb
CREATE TABLE IF NOT EXISTS contadores (
    id SERIAL PRIMARY KEY,
    nodo_origen VARCHAR(50),
    marca_tiempo TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
GRANT ALL PRIVILEGES ON TABLE contadores TO appuser;
GRANT ALL PRIVILEGES ON SEQUENCE contadores_id_seq TO appuser;
\q

**Crear app php**
Crear un archivo deploy.sh que genere el archivo con el contenido en el lugar correcto
nano deploy.sh

Y copiarle esto
```bash
#!/bin/bash

# ==============================================================================
# Script de Despliegue: Interfaz Web para Pruebas de Tolerancia a Fallos
# Ejecutar en: Nodo 2 (Primary) y Nodo 3 (Standby)
# ==============================================================================

set -e

echo "[1/2] Desplegando aplicación web en /var/www/html/index.php..."

cat << "EOF" | sudo tee /var/www/html/index.php > /dev/null

<?php
$host = gethostname();
// Supresión de advertencias y captura limpia del estado de conexión
$db = @pg_connect("host=127.0.0.1 dbname=appdb user=appuser password=soporte");

if (!$db) {

    // Si el motor local de PostgreSQL está caído o inaccesible
    $estado_db = "DESCONECTADO";
    $mensaje = "<p style=\"color:red; font-weight:bold;\">✗ Error Crítico: La capa de aplicación no puede alcanzar a la base de datos local.</p>";
    $total_registros = "Desconocido (Offline)";

} else {
    // Inicializar la tabla (solo se ejecutará si es el Primary)
    @pg_query($db, "CREATE TABLE IF NOT EXISTS contadores (id serial PRIMARY KEY, nodo_origen varchar(50), marca_tiempo timestamp DEFAULT current_timestamp)");

    $mensaje = "";

    // Lógica de inserción
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $insert = @pg_query($db, "INSERT INTO contadores (nodo_origen) VALUES ('$host')");
        if ($insert) {
            $mensaje = "<p style=\"color:green; font-weight:bold;\">✓ Registro guardado exitosamente por los WAL.</p>";
        } else {
            $error = pg_last_error($db);
            $mensaje = "<p style=\"color:red; font-weight:bold;\">✗ Transacción rechazada (Modo Standby). Detalle: $error</p>";
        }
    }



    // Consultar el total de registros
    $result = @pg_query($db, "SELECT count(*) as total FROM contadores");
    $row = $result ? @pg_fetch_assoc($result) : false;
    $total_registros = $row ? $row['total'] : 0;

    // Consultar el rol del motor (Primary/Standby)
    $rol_res = @pg_query($db, "SELECT pg_is_in_recovery();");
    $rol_row = $rol_res ? @pg_fetch_assoc($rol_res) : false;
    $estado_db = ($rol_row && $rol_row["pg_is_in_recovery"] == "t") ? "STANDBY (Solo Lectura)" : "PRIMARY (Lectura y Escritura)";

}

?>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Laboratorio: Sistemas Distribuidos</title>
    <style>
        body { font-family: system-ui, sans-serif; background: #f4f4f9; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); text-align: center; }
        .btn { background: #007bff; color: white; border: none; padding: 10px 20px; font-size: 16px; border-radius: 4px; cursor: pointer; margin-top: 20px; }
        .btn:hover { background: #0056b3; }
        .stats { margin-top: 20px; padding: 15px; background: #e9ecef; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <h2>Atendido por: <strong><?php echo $host; ?></strong></h2>
        <p>Estado del motor local: <strong><?php echo $estado_db; ?></strong></p>
        <?php echo $mensaje; ?>

        <form method="POST">
            <button type="submit" class="btn" <?php if(!$db) echo "disabled"; ?>>Generar Transacción (INSERT)</button>
        </form>
        <div class="stats">
            <h3>Total de registros en la red: <strong><?php echo $total_registros; ?></strong></h3>
        </div>
    </div>
</body>
</html>

EOF

echo "[2/2] Reiniciando servicio web..."
sudo systemctl restart apache2
echo "¡Aplicación desplegada exitosamente! Recarga tu navegador." 
```

Darle permisso de ejecucion y ejecutar para que genere el php que va a servir apache
chmod +x deploy.sh
./deploy.sh

Y finalmente borrar la pagina por defecto de apache (porque sino va a servir esa y no nuestro index.php)
sudo rm /var/www/html/index.html


**Probar**
Desde el propio nodo 2
curl http://localhost/

Desde el host (usando la ip del nodo 2)
curl http://192.168.56.11/



# 6: Proxy nodo 1, incluir nodo 2

**Instalar cosas**
Instalar HAProxy (para lo del proxy) y UFW (lo del firewall para setear el puerto 80 en escucha) (ufw suele venir ya instalado)
sudo apt install haproxy ufw

Para que no se rompa lo del ssh por el firewall, en el nodo 1 poner antes de continuar:
sudo ufw allow OpenSSH

**Habilitar UFW**
sudo ufw allow 80/tcp
sudo ufw enable
sudo ufw status

**Configurar HAProxy**
Archivo de configs
sudo nano /etc/haproxy/haproxy.cfg

Y alli no eliminar nada, solo agregar las siguientes configs. De esta config lo unico que hay que ajustar son las IPs de los nodos entre los que va a balancear la carga.
```
# Lab3
frontend http_front
    bind *:80
    mode http
    default_backend web_servers

backend web_servers
    mode http
    balance roundrobin
    option httpchk
    server web1 192.168.56.11:80 check
    # Este añadirlo cuando el nodo 3 ya esté operativo
    # server web2 192.168.56.12:80 check
```

Validar la configuracion
sudo haproxy -c -f /etc/haproxy/haproxy.cfg

Habilitar el servicio
sudo systemctl enable --now haproxy

O si ya estaba corriendo, refrescar
sudo systemctl restart haproxy

Verificar que esta andando con
sudo systemctl status haproxy

**Probar**
Probar desde la máquina host (al balanceador de carga)
http://192.168.56.10

Probar desde la máquina host (directamente al nodo 2)
http://192.168.56.11

Si no funca, puede que haga falta reiniciar nomas
sudo systemctl restart haproxy


# 7: Instanciar nodo 3

Repetir lo mismo hecho al instanciar el nodo 2 + configuración de red


# 8: Nodo 3 con db pasivo


En el nodo 2, para que acepte conexiones externas (las replicas pasivas como el nodo 3 van a querer conectarse) hay que modificar la configuración
```bash

# Crear un usuario habilitador "replicador" para que pueda replicar
sudo -u postgres psql
CREATE ROLE replicador WITH LOGIN REPLICATION PASSWORD 'replicador';
\q


# Hallar la versión
PG_VERSION=$(ls /var/lib/postgresql/ | sort -n | tail -1)

# Encontrar el archivo de config
sudo nano /etc/postgresql/$PG_VERSION/main/postgresql.conf

# En la primer sección de las configs, modificar la linea esta y agregarle la ip del propio nodo 2 (de esa forma escucha conexiones entrantes), debe estar descomentado
# listen_addresses = 'localhost,192.168.56.11'
# En la sección de write-ahead logs también debe estar esto descomentado
# wal_level = replica
# En la sección de replicación también
# max_wal_senders = 10

# Encontrar el archivo de config de replicación
sudo nano /etc/postgresql/$PG_VERSION/main/pg_hba.conf
# Y agregar al final de todo (asi habilita a un usuario llamado "replicador" que va a ser el del nodo 3)
# host    replication    replicador    192.168.56.12/32    scram-sha-256

# Reiniciar postgres
sudo systemctl restart postgresql
```


Este script se debe ejecutar en el nodo 3, para que quede como solo lectura y solo copie lo del nodo 2 (que es la fuente de verdad)
La contraseña que va a pedir va a ser la contraseña del usuario "replicador"
pasivo.sh
```bash
#!/bin/bash

# Detener servicio de postgres
sudo systemctl stop postgresql

# Vaciar todos los datos preexistentes (sobretodo si el nodo 3 es un clonado del nodo 2)
PG_VERSION=$(ls /var/lib/postgresql/ | sort -n | tail -1)
DATA_DIR="/var/lib/postgresql/$PG_VERSION/main/"
sudo find /var/lib/postgresql/16/main/ -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

# Clonar la db (notese que es la IP del nodo 2, copia sus datos)
sudo -u postgres pg_basebackup -h 192.168.56.11 -D $DATA_DIR -U replicador -v -P -R

# Iniciar el motor en standby (gracias al clonado anterior)
sudo systemctl start postgresql
```




# 9: Proxy nodo 1, incluir nodo 3

En la sección donde se dejo comentado la linea para el nodo 3, descomentarlo
En esa misma seccion tambien dice como reiniciar para que tome la nueva configuración

Si el HAProxy redirige todo a una sola maquina, entrar a esa maquina y probar a detener el apache a ver si redirige al otro
sudo systemctl stop apache2
sudo systemctl start apache2




# 10. Actividades finales de prueba

Práctica 1: Distribución Asimétrica de Carga (Capa de Red) Demuestra cómo adaptar el clúster cuando los servidores tienen capacidades de hardware distintas, forzando al balanceador a enviar más tráfico al nodo primario.
1.	En la terminal del Nodo 1 (HAProxy), edita la configuración: sudo nano /etc/haproxy/haproxy.cfg.
2.	En la sección backend, añade el parámetro weight para darle el triple de prioridad al Nodo 2:
o	server nodo2 192.168.56.11:80 check weight 3
o	server nodo3 192.168.56.12:80 check weight 1
3.	Reinicia el proxy: sudo systemctl restart haproxy.
4.	Validación: Abre la aplicación web y presiona F5 diez veces rápidas. La interfaz revelará que el Nodo 2 atiende aproximadamente el 75% de tus peticiones, rompiendo la distribución 50/50 tradicional del Round Robin.



Práctica 2: Auditoría Interna del Clúster (Capa de Datos) Permite verificar la salud del streaming replication consultando directamente el motor, una habilidad esencial para el diagnóstico en producción sin depender del frontend.
1.	Ingresa a la terminal del Nodo 2 (Primary).
2.	Ejecuta esta consulta a las vistas del sistema de PostgreSQL: sudo -u postgres psql -c "SELECT application_name, client_addr, state, sync_state FROM pg_stat_replication;"
3.	Validación: La terminal devolverá una tabla donde el motor primario confirma que el Nodo 3 (client_addr: 192.168.56.12) está conectado (state: streaming) y recibiendo los registros WAL en tiempo real (sync_state: async). Si esta tabla aparece vacía, la replicación está rota.
 



