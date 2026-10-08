

Punteo para release




**Cómo arrancar**

Para usar se recomienda en 2 terminales
- Una terminal para usar el interprete
- Otra para ver los logs de docker compose

En la primer terminal usar esto. En caso de error de permisos, usar `sudo`
```bash
./libremarket.sh start
./libremarket.sh iex compras
```

En la segunda terminal, una vez arrancados lso contenedores, abrir el log
```bash
./libremarket.sh logs
```

**Uso**

El simulador prove comandos de uso rápido.
Para ver todas las opciones disponibles, escribir `Simulador.show_` y presionar TAB
```
iex(compras@a6fc0364f07e)2> Simulador.show_
show_clock/1                 
show_clock_compras/0         
show_clock_envios/0     
show_clock_infracciones/0    
show_clock_pagos/0           
show_clock_ventas/0          
show_clocks/0                
show_count_compras/0         
show_products/0              
show_state/1                 
show_state_compras/0         
show_state_envios/0          
show_state_infracciones/0    
show_state_pagos/0           
show_state_ventas/0
```

El módulo correspondiente imprimirá por la salida estándar el resultado esperado, por lo que se verán en la terminal utilizada para logs

`show_state` muestra el estado actual del servidor
`show_clock` muestra el estado actual del reloj vectorial del servidor
`show_count_compras` muestra un conteo de compras exitosas y fallidas, del servidor de compras
`show_products` muestra el stock de productos, del servidor de ventas


**Logs**
El formato de logs es el siguiente
```
ventas        | ✉ Enviado a compras
ventas        |   {:informar_estado_reservacion, 1, true}
ventas        |   [ C:  1 | I:  0 | V:  1 | E:  0 | P:  0 ]
ventas        | 
infracciones  | ✉ Recibido
infracciones  |   {:detectar_infracciones, 1}
infracciones  |   [ C:  2 | I:  0 | V:  0 | E:  0 | P:  0 ]
infracciones  | 
infracciones  | Compra N° 1: no se ha detectado ninguna infracción
infracciones  | 
compras       | ✉ Recibido
compras       |   {:informar_estado_reservacion, 1, true}
compras       |   [ C:  1 | I:  0 | V:  1 | E:  0 | P:  0 ]
compras       | 
pagos         | ○ [ C:  0 | I:  0 | V:  0 | E:  0 | P:  0 ]
pagos         | 
```

El paso de mensajes (envio o recepción) se denota con un ícono de mensaje `✉`
- Contenido del mensaje 
- Reloj vectorial
	- C: Compras
	- I: Infracciones
	- V: Ventas
	- E: Envios
	- P: Pagos

Cuando se pide a un modulo mostrar su estado del reloj se denota con un ícono circular `○`



**Detalles importantes**
- Existe un modulo `Constantes` que contiene los nombres de las colas de mensajes, y los valores relacionados a la lógica de negocio, como las probabilidades de detectar infracciones. Esto permite modificarlos rápidamente con fines de testeo, para lograr resultados predecibles.

- Un mensaje no siempre tendrá reloj vectorial, los mensajes auxiliares como simular_compra o show_state no llevarán reloj, en esos casos no se incrementa el reloj del receptor porque se asume que no es un mensaje que represente una interacción entre módulos, y por ende es una operación que no necesite ser contado para las posibles relaciones causales de eventos

- Por lo mencionado en el punto anterior, las operaciones `show_*` son idempotentes y no alteran el estado del reloj vectorial del modulo requerido. En la demo en clase se mencionó que ocurrian incrementos por la llegada del mensaje, pero se logró resolver. 
