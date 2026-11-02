


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
 




---

Laboratorio 4

# 11. Combinar el laboratorio 2

**Nodo 1**
Instalar docker:
sudo apt install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo systemctl status docker
docker compose version

Para no usar sudo a cada rato (eso si, guarda con los permisos)
sudo usermod -aG docker $USER

Luego cerrar la sesión ssh y volver a entrar para notar los cambios
exit

Agregar esto en el HAProxy
sudo nano /etc/haproxy/haproxy.cfg
```
Lab4
frontend postgres_front
    bind *:5432
    mode tcp
    option tcplog
    default_backend postgres_back

backend postgres_back
    mode tcp
    server node2 192.168.56.11:5432 check
```

Verificar que la configuracion se mantiene valida
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy
sudo ss -tlnp | grep 5432



**Nodo 2**

Acceder al postgresql.conf (lo más probable es que tire la ruta /etc/postgresql/16/main/postgresql.conf)
sudo -u postgres psql -c "SHOW config_file;"
sudo nano /etc/postgresql/16/main/postgresql.conf

Buscar la linea con listen addresses y modificarlo de esta forma
```
#listen_addresses = 'localhost'
listen_addresses = '*'
```

Acceder al pg_hba.conf (lo mas probable es que tire la ruta /etc/postgresql/16/main/pg_hba.conf)
sudo -u postgres psql -c "SHOW hba_file;"
sudo nano /etc/postgresql/16/main/pg_hba.conf

Ir a la ultima linea y agregar
```
host    all    all    192.168.56.10/32    scram-sha-256
```

Reiniciar postgres y verificar
sudo systemctl restart postgresql
sudo ss -tlnp | grep 5432


**Nodo 1**
Asegurarse de que el firewall no bloquee
sudo ufw allow 5432/tcp

Probar la conexión al postgres del nodo 2
sudo apt install postgresql-client -y
psql -h 192.168.56.11 -p 5432 -U appuser -d appdb
\q

Probar la conexión a través del proxy
psql -h 192.168.56.10 -p 5432 -U appuser -d appdb
\q




**Aplicación**
Clonar el repositorio:
git clone https://github.com/Fabian-VM/libremarket-elixir.git

No olvidar agregar en un .env todo lo necesario
```
CLOUDAMQP_URL=...
DB_HOST=192.168.56.10
DB_PORT=5432
DB_NAME=appdb
DB_USER=appuser
DB_PASSWORD=soporte
```



Compilar el proyecto, iniciar y ejecutar una simulación para verificar que funciona adentro del nodo
./mix-deps-gets.sh
./compile.sh
./libremarket.sh start
./libremarket.sh iex compras
Simulador.simular_compra


# 12. Actualizar servicio web en nodos 2 y 3

Cambiar el contenido del deploy.sh en ambos nodos por este
```
#!/bin/bash

# ==============================================================================
# Despliegue: Panel de monitoreo PostgreSQL
# Ejecutar en Nodo 2 y Nodo 3
# ==============================================================================

set -e

echo "[1/2] Desplegando panel web..."

cat << 'EOF' | sudo tee /var/www/html/index.php > /dev/null
<?php

$host = gethostname();

// Configuración de conexión local
$db = @pg_connect(
    "host=127.0.0.1 port=5432 dbname=appdb user=appuser password=soporte"
);

$estado_db = "DESCONECTADO";
$rol_db = "DESCONOCIDO";
$tablas = [];
$error = null;

if (!$db) {
    $error = "No se pudo establecer conexión con PostgreSQL.";
} else {

    // Consultar el rol del servidor
    $rol_result = pg_query($db, "SELECT pg_is_in_recovery()");

    if ($rol_result) {
        $rol_row = pg_fetch_assoc($rol_result);

        $rol_db = ($rol_row["pg_is_in_recovery"] === "t")
            ? "STANDBY"
            : "PRIMARY";
    }

    $estado_db = "CONECTADO";

    // Descubrir automáticamente las tablas del esquema public
    $tablas_result = pg_query(
        $db,
        "SELECT table_name
         FROM information_schema.tables
         WHERE table_schema = 'public'
           AND table_type = 'BASE TABLE'
         ORDER BY table_name"
    );

    if ($tablas_result) {

        while ($fila = pg_fetch_assoc($tablas_result)) {

            $nombre = $fila["table_name"];
            $tabla_sql = pg_escape_identifier($db, $nombre);

            // Obtener cantidad de registros
            $count_result = pg_query(
                $db,
                "SELECT COUNT(*) AS total FROM $tabla_sql"
            );

            $total = $count_result
                ? pg_fetch_result($count_result, 0, "total")
                : "Error";

            // Obtener hasta 50 registros
            $datos_result = pg_query(
                $db,
                "SELECT * FROM $tabla_sql LIMIT 50"
            );

            $columnas = [];
            $registros = [];

            if ($datos_result) {

                $cantidad_columnas = pg_num_fields($datos_result);

                for ($i = 0; $i < $cantidad_columnas; $i++) {
                    $columnas[] = pg_field_name($datos_result, $i);
                }

                while ($registro = pg_fetch_assoc($datos_result)) {
                    $registros[] = $registro;
                }
            }

            $tablas[] = [
                "nombre" => $nombre,
                "total" => $total,
                "columnas" => $columnas,
                "registros" => $registros
            ];
        }
    }
}

function escapar($valor) {
    return htmlspecialchars(
        (string)$valor,
        ENT_QUOTES | ENT_SUBSTITUTE,
        "UTF-8"
    );
}

?>

<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <title>Estado de PostgreSQL</title>

    <style>
        body {
            font-family: system-ui, sans-serif;
            background: #f4f4f9;
            margin: 0;
            padding: 25px;
            color: #222;
        }

        .container {
            max-width: 1200px;
            margin: auto;
        }

        .header, .card {
            background: white;
            padding: 22px;
            border-radius: 8px;
            margin-bottom: 20px;
            box-shadow: 0 2px 5px rgba(0,0,0,.08);
        }

        .header {
            text-align: center;
        }

        .status {
            display: inline-block;
            padding: 7px 14px;
            border-radius: 5px;
            font-weight: bold;
            margin: 5px;
        }

        .ok {
            background: #d4edda;
            color: #155724;
        }

        .error {
            background: #f8d7da;
            color: #721c24;
        }

        .standby {
            background: #fff3cd;
            color: #856404;
        }

        .table-wrapper {
            overflow-x: auto;
        }

        table {
            border-collapse: collapse;
            width: 100%;
            font-size: 14px;
            margin-top: 12px;
        }

        th, td {
            border: 1px solid #ddd;
            padding: 9px;
            text-align: left;
            white-space: nowrap;
        }

        th {
            background: #e9ecef;
        }

        tr:nth-child(even) {
            background: #f8f9fa;
        }

        .empty {
            color: #777;
            font-style: italic;
        }

        h2 {
            margin-top: 0;
        }

        .info {
            color: #666;
            font-size: 13px;
        }
    </style>
</head>

<body>
<div class="container">

    <div class="header">

        <h1>Estado del nodo: <?= escapar($host) ?></h1>

        <h3>Base de datos PostgreSQL</h3>

        <span class="status <?= $db ? 'ok' : 'error' ?>">
            <?= escapar($estado_db) ?>
        </span>

        <span class="status <?= $rol_db === 'PRIMARY' ? 'ok' : 'standby' ?>">
            <?= escapar($rol_db) ?>
        </span>

    </div>

    <?php if ($error): ?>

        <div class="card">
            <h2>Error de conexión</h2>
            <p class="error"><?= escapar($error) ?></p>
        </div>

    <?php else: ?>

        <h2>Tablas de la base de datos</h2>

        <?php if (empty($tablas)): ?>

            <div class="card">
                No se encontraron tablas en el esquema public.
            </div>

        <?php endif; ?>

        <?php foreach ($tablas as $tabla): ?>

            <div class="card">

                <h2><?= escapar($tabla["nombre"]) ?></h2>

                <p>
                    Registros:
                    <strong><?= escapar($tabla["total"]) ?></strong>
                </p>

                <?php if (empty($tabla["registros"])): ?>

                    <p class="empty">La tabla no contiene registros.</p>

                <?php else: ?>

                    <div class="table-wrapper">

                        <table>
                            <thead>
                                <tr>
                                    <?php foreach ($tabla["columnas"] as $columna): ?>
                                        <th><?= escapar($columna) ?></th>
                                    <?php endforeach; ?>
                                </tr>
                            </thead>

                            <tbody>
                                <?php foreach ($tabla["registros"] as $registro): ?>
                                    <tr>
                                        <?php foreach ($tabla["columnas"] as $columna): ?>
                                            <td>
                                                <?= $registro[$columna] === null
                                                    ? '<span class="empty">NULL</span>'
                                                    : escapar($registro[$columna]) ?>
                                            </td>
                                        <?php endforeach; ?>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>

                    </div>

                    <?php if ((int)$tabla["total"] > 50): ?>
                        <p class="info">
                            Mostrando los primeros 50 registros.
                        </p>
                    <?php endif; ?>

                <?php endif; ?>

            </div>

        <?php endforeach; ?>

    <?php endif; ?>

</div>
</body>
</html>

EOF

echo "[2/2] Reiniciando Apache..."
sudo systemctl restart apache2

echo "¡Panel desplegado correctamente!"
```



# 13. Promoción automática

**Nodo 1**
Instalar etcd
sudo apt install etcd-server etcd-client

Verificar instalación
sudo systemctl status etcd

Agregar configuraciones
El puerto 2379 será para que lo use patroni
sudo nano /etc/default/etcd
```
ETCD_LISTEN_CLIENT_URLS="http://127.0.0.1:2379,http://192.168.56.10:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.56.10:2379"
```

Reiniciar para aplicar config
sudo systemctl restart etcd

Verificar que todo esta funcionando
sudo ss -lntp | grep 2379
ETCDCTL_API=3 etcdctl --endpoints=http://127.0.0.1:2379 endpoint health

Agregar unas configuraciones de firewall para aceptar conexiones por ese nuevo puerto desde los otros 2 nodos
sudo ufw allow from 192.168.56.11 to any port 2379 proto tcp
sudo ufw allow from 192.168.56.12 to any port 2379 proto tcp


**Nodo 2 y 3**
Verificar con netcat que se puede conectar al nodo 1
nc -vz -w 3 192.168.56.10 2379

Instalar patroni
sudo apt clean
sudo apt update
sudo apt install patroni python3-etcd3

Verificar instalacion
patroni --version
patronictl version
python3 -c "import etcd3; print('Cliente etcd3 disponible')"

Configurar patroni (solo en el nodo 2, ya que se replicaran automaticamente al nodo 3)
sudo -u postgres psql

CREATE USER patroni_admin WITH SUPERUSER ENCRYPTED PASSWORD 'PatroniAdmin_2026';
CREATE USER rewind_user WITH ENCRYPTED PASSWORD 'RewindUser_2026';

GRANT EXECUTE ON FUNCTION pg_catalog.pg_ls_dir(text, boolean, boolean) TO rewind_user;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_stat_file(text, boolean) TO rewind_user;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_read_binary_file(text) TO rewind_user;
GRANT EXECUTE ON FUNCTION pg_catalog.pg_read_binary_file(text, bigint, bigint, boolean) TO rewind_user;

\q

Configurar en nodos 2 y 3
sudo -u postgres psql -c "ALTER SYSTEM SET wal_log_hints = 'on';"

Crear en nodos 2 y 3
sudo mkdir -p /etc/patroni
sudo chown postgres:postgres /etc/patroni
sudo chmod 750 /etc/patroni

En nodo 2 agregar al archivo (deberia estar vacio)
sudo nano /etc/patroni/config.yml
```
scope: postgres-cluster
namespace: /service/
name: nodo2

restapi:
  listen: 192.168.56.11:8008
  connect_address: 192.168.56.11:8008

etcd3:
  hosts: 192.168.56.10:2379

postgresql:
  listen: 127.0.0.1,192.168.56.11:5432
  connect_address: 192.168.56.11:5432
  data_dir: /var/lib/postgresql/16/main
  config_dir: /etc/postgresql/16/main
  bin_dir: /usr/lib/postgresql/16/bin

  authentication:
    superuser:
      username: patroni_admin
      password: "PatroniAdmin_2026"
    replication:
      username: replicador
      password: "replicador"
    rewind:
      username: rewind_user
      password: "RewindUser_2026"

  use_pg_rewind: true

  parameters:
    wal_level: replica
    hot_standby: "on"
    wal_log_hints: "on"
    max_wal_senders: 10
    max_replication_slots: 10
    max_connections: 100
```

Agregar permisos sobre el archivo configurado
sudo chown postgres:postgres /etc/patroni/config.yml
sudo chmod 600 /etc/patroni/config.yml


Repetir lo del nodo 2 en el nodo 3, pero con algunas cosas cambiadas
sudo nano /etc/patroni/config.yml
```
scope: postgres-cluster
namespace: /service/
name: nodo3

restapi:
  listen: 192.168.56.12:8008
  connect_address: 192.168.56.12:8008

etcd3:
  hosts: 192.168.56.10:2379

postgresql:
  listen: 127.0.0.1,192.168.56.12:5432
  connect_address: 192.168.56.12:5432
  data_dir: /var/lib/postgresql/16/main
  config_dir: /etc/postgresql/16/main
  bin_dir: /usr/lib/postgresql/16/bin

  authentication:
    superuser:
      username: patroni_admin
      password: "PatroniAdmin_2026"
    replication:
      username: replicador
      password: "replicador"
    rewind:
      username: rewind_user
      password: "RewindUser_2026"

  use_pg_rewind: true

  parameters:
    wal_level: replica
    hot_standby: "on"
    wal_log_hints: "on"
    max_wal_senders: 10
    max_replication_slots: 10
    max_connections: 100
```

Igual que con el nodo 2, agregar permisos sobre el archivo configurado en el nodo 3
sudo chown postgres:postgres /etc/patroni/config.yml
sudo chmod 600 /etc/patroni/config.yml

Evitar que postgres se inicie solo (en ambos nodos)
sudo systemctl disable postgresql.service postgresql@16-main.service
sudo systemctl disable --runtime postgresql@16-main.service

Y verificar que el primero diga "disabled" y el segundo "active" (en ambos nodos)
systemctl is-enabled postgresql.service
systemctl is-active postgresql@16-main.service


Iniciar patroni primero en el nodo 2 y comprobar que esta corriendo
sudo systemctl start patroni
sudo systemctl status patroni

Repetir lo mismo en el nodo 3

Luego reiniciar la db en el nodo 3 
sudo -u postgres patronictl -c /etc/patroni/config.yml restart postgres-cluster nodo3

Habilitar conexiones con el rewind user (es algo que permite reincorporar instancias como replicas en vez de tener que reestablecerlo antes de incorporarlo o algo asi)
Y tambien con el patroni_admin, que sera el que se use desde el nodo 1.
En el nodo 2 asegurarse que tenga esto:
sudo nano /etc/postgresql/16/main/pg_hba.conf
```
# Laboratorio
host    replication     replicador      192.168.56.12/32        scram-sha-256
host    all     all     192.168.56.10/32        scram-sha-256    
host    postgres    rewind_user    192.168.56.12/32    scram-sha-256
host    all    patroni_admin    192.168.56.10/32    scram-sha-256

```

En el nodo 3 tambien:
sudo nano /etc/postgresql/16/main/pg_hba.conf
```
host    replication     replicador      192.168.56.11/32        scram-sha-256
host    all    all    192.168.56.10/32    scram-sha-256
host    postgres    rewind_user    192.168.56.11/32    scram-sha-256
host    all    patroni_admin    192.168.56.10/32    scram-sha-256
```

Verificar desde ambos nodos que se aplique (esto deberia devolver "t")
sudo -u postgres psql -c "SELECT pg_reload_conf();"

**Prueba de switchover (manual)**
Ahora viene lo peligroso, hay que transferirle a proposito el liderazgo al nodo 3
El comando deberia funcionar en cualquiera de ambos nodos
sudo -u postgres patronictl -c /etc/patroni/config.yml switchover postgres-cluster --leader nodo2 --candidate nodo3

Esperar 30 segundos, y correr este comando en ambos nodos. Deberia indicar como es esperado quién es replica y quien es lider. Ambos deberian estar en estado "running"
sudo patronictl -c /etc/patroni/config.yml list

Ahora otro paso peligroso, hacer el switchover en el sentido contrario. Ejecutarlo en cualquiera de ambos nodos
sudo -u postgres patronictl -c /etc/patroni/config.yml switchover postgres-cluster --leader nodo3 --candidate nodo2

**Solución de problemas (conflicto de administracion de procesos)**
Si al hacer alguno de ambos switchovers alguno queda en estado "start failed", hay que verificar que solo patroni sea el que está encargandose de arrancar postgres, o sea, que ningun otro proceso meta sus narices en lo que no debe. El primer sospechoso es systemd

Si al hacer cat de esto sale "auto" al final, entonces estará chocando con patroni
cat /etc/postgresql/16/main/start.conf

Si es asi, modificarlo para cambiar "auto" por manual". Luego reiniciar, y deshabilitar el reinicio automatico de postgres
sudo nano /etc/postgresql/16/main/start.conf
sudo systemctl daemon-reload
sudo systemctl disable --runtime postgresql@16-main

Verificar que dice "disabled"
systemctl is-enabled postgresql@16-main

**Prueba de failover (switchover automático)**
Verificar quien es el nodo primario y quien es la replica. 
sudo -u postgres patronictl -c /etc/patroni/config.yml list

Asumiendo que nodo 2 es primario, apagar la maquina virtual abruptamente (desde el administrador de maquinas virtuales, no desde el comando) y pasados unos segundos verificcar desde el nodo 3 que ahora él es el lider
sudo -u postgres patronictl -c /etc/patroni/config.yml list

Habiendo verificado que el nodo 3 es el lider, encender el nodo 2 nuevamente, y pasados unos segundos otra vez verificar que se incorporó pero como réplica
sudo -u postgres patronictl -c /etc/patroni/config.yml list

**Solución de problemas (conflicto de timelines)**
Si hubo un error debido a que hubo una confuncion en los pg_hba.conf, corregir y luego correr este comando, pasando por argumento el nombre del nodo que hay que restaurar con datos sanos
sudo patronictl -c /etc/patroni/config.yml reinit postgres-cluster nodo2










