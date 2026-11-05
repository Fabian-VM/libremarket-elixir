




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

Agregar esto en el HAProxy, basicamente se esta hardcodeando que al querer operar con la base de datos, se redirija siempre al nodo 2, solo por ahora para asegurarse de que todo esta funcionando
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

**Nodo 1 - ETCD**
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


**Nodo 2 y 3 - Patroni**
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

**Nodo 1 - HAProxy**

Modificar la configuración de proxy para eliminar la redirección de consultas sql al nodo 2, y hacerlo dinámico. El proxy consultaría el endpoint de patroni que indica si el nodo es el primario, asi puede mandar las consultas por ahí
sudo nano /etc/haproxy/haproxy.cfg
```
# Lab4
frontend postgres_front
    bind *:5432
    mode tcp
    option tcplog
    default_backend postgres_back

backend postgres_back
   mode tcp
   option httpchk GET /primary
   http-check expect status 200

   server node2 192.168.56.11:5432 check port 8008 inter 2s fall 3 rise 2
   server node3 192.168.56.12:5432 check port 8008 inter 2s fall 3 rise 2

```

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










