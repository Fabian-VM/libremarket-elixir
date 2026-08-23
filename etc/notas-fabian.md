

**Posibles errores**
Las infracciones no se deberian procesar antes de si quiera pasar al medio de pago? sino hace que Envios calcule costos al dope, o que Ventas reserve productos



**UI**
```php
Ui.comprar(producto, medio_pago, forma_entrega):
    const id_compra = Random.id()
    const costo_envio = 0
    return Compras.seleccionar_producto({id_compra, producto, costo_envio, medio_pago, forma_entrega})
```

**Compras**
```php
function Compras.seleccionar_producto({...}):
    Ventas.reservar_producto({...}) 
    const [{...}, hay_infraccion] = Task.await_many([
        Task.async(Compras.seleccionar_forma_entrega({...})),
        Task.async(Compras.detectar_infracciones({...}))
    ])

    if (hay_infraccion):
        Pagos.autorizar_pago({...})
    else:
        return Compras.informar_infraccion()

function Compras.seleccionar_forma_entrega({...}):
    if forma_entrega == correo:
        costo_envio = Envios.calcular_costo({...})
    return Compras.seleccionar_medio_pago({...})

function Compras.seleccionar_medio_pago({...}):
    return Compras.confirmar_compra({...})    

function Compras.confirmar_compra({...}):
    return {...}

function Compras.informar_infraccion({...}):
    return "Infracción encontrada para " + {...}


costo_total = precio(producto)
```

**Envios**
```php

function Envios.calcular_costo({...}):
    return Random.entero()
    

```

**Pagos**
```php
function Pagos.autorizar_pago({...}):
    const [ ] = Task.await_many([
        Task.async(Compras.seleccionar_forma_entrega({...})),
        Task.async(Compras.detectar_infracciones({...}))
    ])


```

