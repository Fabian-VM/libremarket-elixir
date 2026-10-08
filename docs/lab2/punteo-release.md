

# Laboratorio N.° 2

## Cómo empezar

Para realizar pruebas cómodamente, se recomienda abrir dos terminales:
- Una terminal para usar el intérprete de elixir
- Otra terminal para ver los logs de todos los contenedores

En la primer terminal iniciar los contenedores e ingresar a algún contenedor. Realmente no importa a qué contenedor se accede, ya que para iniciar la simulación se envía un mensaje a la cola de mensajes de compras.

```bash
./libremarket.sh start
./libremarket.sh iex compras
```

En la segunda terminal, una vez arrancados los contenedores, mostrar los logs.
```bash
./libremarket.sh logs
```

En caso de error de permisos, usar `sudo`

## Cómo simular compras y consultar estados

El simulador posee funciones de simulación de compra, incluidas desde el laboratorio anterior. La función `simular_compra/1` espera un ID de producto, el resto espera una cantidad de compras a simular.

```
iex(compras@a6fc0364f07e)1> Simulador.simular_compra
simular_compra/0                
simular_compra/1                
simular_compras_async/0         
simular_compras_async/1         
simular_compras_secuencial/0    
simular_compras_secuencial/1
```

Se incluyeron además funciones auxiliares para agilizar las consultas. Se pueden listar todas escribiendo `Simulador.show_` y presionando TAB para mostrar las opciones disponibles por autocompletado.
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

Ante la consulta del estado de un módulo, el mismo lo imprimirá por la salida estándar. Es decir, se mostrará en la terminal usada para ver los logs.

- `show_state/1` muestra el estado actual del servidor que posea la cola de mensajes indicada (`"compras"`, `"infracciones"`, etc.)
- `show_clock/1` muestra el estado actual del reloj vectorial del servidor que posea la cola de mensajes indicada
- `show_clocks/0` muestra el estado actual de todos los relojes vectoriales
- `show_products/0` muestra el stock de productos, del servidor de ventas
- `show_count_compras/0` muestra un conteo de compras exitosas y fallidas del servidor de compras, como el siguiente:
```
====================================================
|        CONTEO DE COMPRAS                         |
====================================================
    17  Totales
    16  Finalizados con éxito
     1  Finalizados sin éxito
     0  Sin finalizar (posibles errores)
```
Las compras "sin finalizar" indican un posible error debido a que indica que existen compras cuyo estado de éxito es nulo (ni `true` ni `false`). Dado que el proceso de compras está especificado con terminaciones exitosas y no exitosas, quiere decir que algún mensaje no fue recibido por compras, y por ende no pudo determinar un estado final de la compra.


## Cómo leer la salida estándar de contenedores

El formato de logs es el siguiente
```
ventas        | ✉ Enviado a compras
ventas        |   {:informar_estado_reservacion, 1, true}
ventas        |   [ C:  1 | I:  0 | V:  1 | E:  0 | P:  0 ]
ventas        | 
infracciones  | Compra N° 1: no se ha detectado ninguna infracción
infracciones  | 
pagos         | ○ [ C:  0 | I:  0 | V:  0 | E:  0 | P:  0 ]
pagos         | 
```

El paso de mensajes (envio o recepción) se denota con un ícono de mensaje `✉`. 
- La primer linea indica el contenido del mensaje 
- La segunda linea indica el reloj vectorial incluido en el mensaje.

El estado del reloj vectorial de un servidor se denota con un ícono circular `○`. Este se muestra ante una consulta `Simulador.show_clock/1` o `Simulador.show_clocks/0`

Los componentes del reloj vectorial fueron abreviados tomando la primer letra de cada módulo:
```
C: Compras
I: Infracciones
V: Ventas
E: Envios
P: Pagos
```


## Ejemplo 

El siguiente log corresponde al proceso de una compra con `Simulador.simular_compra/0`:
```
compras       | Compra N° 1: nueva compra iniciada
compras       | 
compras       | Compra N° 1: producto #4 seleccionado
compras       | 
compras       | Compra N° 1: forma de entrega 'correo' seleccionada
compras       | 
compras       | ✉ Enviado a ventas
compras       |   {:reservar_producto, 1, 4}
compras       |   [ C:  1 . I:  0 . V:  0 . E:  0 . P:  0 ]
compras       | 
ventas        | Compra N° 1: unidad reservada del producto #4 (1 unidades disponibles)
ventas        | 
compras       | ✉ Enviado a infracciones
compras       |   {:detectar_infracciones, 1}
compras       |   [ C:  2 . I:  0 . V:  0 . E:  0 . P:  0 ]
compras       | 
compras       | ✉ Enviado a envios
compras       |   {:calcular_costo, 1, :correo}
compras       |   [ C:  3 . I:  0 . V:  0 . E:  0 . P:  0 ]
compras       | 
compras       | Compra N° 1: medio de pago 'tc' seleccionado
compras       | 
compras       | Compra N° 1: la compra ha sido confirmada por el usuario
compras       | 
ventas        | ✉ Enviado a compras
ventas        |   {:informar_estado_reservacion, 1, true}
ventas        |   [ C:  1 . I:  0 . V:  2 . E:  0 . P:  0 ]
ventas        | 
infracciones  | Compra N° 1: no se ha detectado ninguna infracción
infracciones  | 
envios        | Compra N° 1: costo de envío de $50 rupias
envios        | 
infracciones  | ✉ Enviado a compras
infracciones  |   {:informar_estado_infraccion, 1, false}
infracciones  |   [ C:  2 . I:  2 . V:  0 . E:  0 . P:  0 ]
infracciones  | 
envios        | ✉ Enviado a compras
envios        |   {:informar_costo_envio, 1, 50}
envios        |   [ C:  3 . I:  0 . V:  0 . E:  2 . P:  0 ]
envios        | 
infracciones  | ✉ Enviado a ventas
infracciones  |   {:informar_estado_infraccion, 1, false}
infracciones  |   [ C:  2 . I:  3 . V:  0 . E:  0 . P:  0 ]
infracciones  | 
compras       | ✉ Enviado a pagos
compras       |   {:autorizar_pago, 1}
compras       |   [ C:  7 . I:  2 . V:  2 . E:  2 . P:  0 ]
compras       | 
pagos         | Compra N° 1: pago autorizado
pagos         | 
pagos         | ✉ Enviado a compras
pagos         |   {:informar_estado_pago, 1, true}
pagos         |   [ C:  7 . I:  2 . V:  2 . E:  2 . P:  2 ]
pagos         | 
pagos         | ✉ Enviado a ventas
pagos         |   {:informar_estado_pago, 1, true}
pagos         |   [ C:  7 . I:  2 . V:  2 . E:  2 . P:  3 ]
pagos         | 
compras       | ✉ Enviado a envios
compras       |   {:agendar_envio, 1}
compras       |   [ C:  9 . I:  2 . V:  2 . E:  2 . P:  2 ]
compras       | 
compras       | Compra N° 1: se ha finalizado su compra con éxito. Hasta nunca!
compras       | 
envios        | Compra N° 1: envio agendado para el dia 2026-10-08
envios        | 
envios        | ✉ Enviado a ventas
envios        |   {:agendar_envio, 1, ~D[2026-10-08]}
envios        |   [ C:  9 . I:  2 . V:  2 . E:  4 . P:  2 ]
envios        | 
ventas        | Compra N° 1: producto enviado
ventas        | 
```

Luego, al consultar los relojes vectoriales con `Simulador.show_clocks/0`:
```
compras       | ○ [ C:  9 . I:  2 . V:  2 . E:  2 . P:  2 ]
compras       | 
infracciones  | ○ [ C:  2 . I:  3 . V:  0 . E:  0 . P:  0 ]
infracciones  | 
ventas        | ○ [ C:  9 . I:  3 . V:  5 . E:  4 . P:  3 ]
ventas        | 
compras       | :ok
envios        | ○ [ C:  9 . I:  2 . V:  2 . E:  4 . P:  2 ]
envios        | 
pagos         | ○ [ C:  7 . I:  2 . V:  2 . E:  2 . P:  3 ]
pagos         | 
```

Que al unificarlos se obtiene `[ C:  9 . I:  3 . V:  5 . E:  4 . P:  3 ]`





## Otros detalles importantes

### Módulo de constantes
Existe un modulo `Constantes` que contiene los nombres de las colas de mensajes, y los valores relacionados a la lógica de negocio, como las probabilidades de detectar infracciones. Esto permite modificarlos rápidamente con fines de testeo, para lograr resultados predecibles.

Por ejemplo se podría modificar de esta forma:
```elixir
defmodule Constantes do

  def compras_queue, do: "compras"
  def infracciones_queue, do: "infracciones"
  def ventas_queue, do: "ventas"
  def envios_queue, do: "envios"
  def pagos_queue, do: "pagos"

  def prob_pago_autorizado, do: 100 # 70
  def prob_forma_entrega_correo, do: 100 # 70
  def prob_usuario_confirma, do: 100 # 80
  def prob_infraccion, do: 0 # 30

end
```

### Testing de resultados predecibles
Gracias al modulo de constantes, se pueden establecer valores de forma que se pueda predecir cómo resultará una compra. Así, se obtiene un patrón determinístico que permite verificar el funcionamiento correcto del paso de mensajes.

Sea `r` el reloj vectorial que se obtiene de unificar los relojes vectoriales de cada módulo (según el algoritmo de relojes vectoriales).
Sea `n` el número de compras exitosas con forma de entrega "correo", consecutivas desde el inicio de ejecución de los servidores.
Los valores de los relojes vectoriales reales seguirán este patrón:
```
n	| r
-------------------------------------------------
0	| ○ [ C:  0 . I:  0 . V:  0 . E:  0 . P:  0 ]
1	| ○ [ C:  9 . I:  3 . V:  5 . E:  4 . P:  3 ]
2	| ○ [ C: 18 . I:  6 . V: 10 . E:  8 . P:  6 ]
3	| ○ [ C: 27 . I:  9 . V: 15 . E: 12 . P:  9 ]
...
n	| ○ [ C: 9n . I: 3n . V: 5n . E: 4n . P: 3n ]
```
Este comportamiento dejará de repetirse luego de la primer compra fallida, la cual será provocada por la falta de stock (generalmente con n > 10)


### No todos los mensajes poseen reloj vectorial
Un mensaje no siempre tendrá reloj vectorial, los mensajes auxiliares como simular_compra o show_state no llevarán reloj, en esos casos no se incrementa el reloj del receptor porque se asume que no es un mensaje que represente una interacción entre módulos, y por ende es una operación que no necesite ser contado para las posibles relaciones causales de eventos.

Las operaciones `show_*` son idempotentes y no alteran el estado del reloj vectorial del modulo requerido. En la demo en clase se mencionó que ocurrian incrementos por la llegada del mensaje, pero se logró resolver. 
```elixir
iex(compras@35444c5582ed)3> Simulador.show_clock_compras
:ok
○ [ C:  9 . I:  2 . V:  2 . E:  2 . P:  2 ]

iex(compras@35444c5582ed)4> Simulador.show_clock_compras
:ok
○ [ C:  9 . I:  2 . V:  2 . E:  2 . P:  2 ]

iex(compras@35444c5582ed)5> 
```

### Errores por mensajes antiguos

Si sucedió algun tipo de error durante simulaciones de compras, y se decide reiniciar los contenedores, puede que se esté volviendo a iniciar alguno o todos los modulos teniendo mensajes en la cola de mensajes almacenados en CloudAMQP, por lo que luego de arrancar los recibirán e intentar realizar operaciones con compras que no existen (`nil`). 

Por ello podría suceder que los modulos terminan de consumir los mensajes pendientes de la sesión anterior.

En caso de suceder, debería ser suficiente con reiniciar una vez más los contenedores.


