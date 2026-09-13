# Respuesta al punto 3 del laboratorio n°1

Existen diversos problemas de concurrencia:

### 1. Condición de carrera en la reserva y liberación de stock (Servidor de Ventas)
* **Retención de stock y falsos rechazos:** Como el producto se reserva al inicio del proceso, si varias compras concurrentes intentan adquirir las mismas unidades disponibles, el stock se agota tempranamente. Si algunas de esas compras son posteriormente canceladas (por detección de infracción, pago rechazado o no confirmación del cliente), los productos reservados se liberan tarde, habiendo provocado que otros compradores concurrentes reciban un falso rechazo por "falta de stock".
* **Fuga de stock por fallos inesperados:** Si un proceso de compra o la interfaz falla a mitad de camino o sufre un timeout antes de invocar a `liberar_producto/2`, el stock queda reservado indefinidamente en el estado del servidor de ventas.

### 2. Falta de sincronización entre Infracciones y Pagos
Dado que el análisis de infracciones se inicia de manera paralela a la selección del medio de pago y entrega por parte del cliente, si no existe una barrera de sincronización adecuada antes de invocar al Servidor de Pagos, se puede producir una condición de carrera donde se autorice y se realice el pago de una compra que después es marcada como infracción.

### 3. Cuellos de botella y timeouts en servidores sincrónicos (GenServers)
Al ser una comunicación sincrónica mediante `GenServer.call/2`, cada servidor procesa un único mensaje a la vez de su *mailbox*.
Bajo alta concurrencia, las solicitudes simultáneas enviadas desde múltiples procesos de simulación se encolan linealmente. Esto genera un efecto cascada de latencia donde las peticiones del final de la cola pueden superar el tiempo límite de espera por defecto (5 segundos), lanzando un error de `:timeout` y abortando abruptamente la transacción.

### 4. Acceso e inconsistencia de estado en estructuras de datos
Al mantener el estado de las compras en colecciones no atómicas o listas lineales, las consultas e inserciones concurrentes sobre una misma entidad pueden derivar en lecturas inconsistentes o fallos por intentar actualizar registros que aún no se terminaron de crear en el servidor de compras.

---
> **Conclusión:** Todos estos incisos deberían tenerse en cuenta para la posterior implementación de comunicación mediante mensajes y la desacoplación de los servicios.
