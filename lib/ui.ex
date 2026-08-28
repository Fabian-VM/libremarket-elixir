defmodule Libremarket.Ui do

  # Acá condenso todo lo que iria haciendo el usuario en la UI
  def comprar(producto_id, forma_entrega, medio_pago) do
    compra_id = Libremarket.Compras.Server.seleccionar_producto(producto_id)
    hay_infraccion = Libremarket.Infracciones.Server.detectar_infraccion(compra_id)
    _producto_esta_reservado = Libremarket.Ventas.Server.reservar_producto(compra_id, producto_id)

    Libremarket.Compras.Server.seleccionar_forma_entrega(compra_id, forma_entrega)

    # ESTO EN EL MODULO ENVIOS
    costo_envio = if forma_entrega == :retira, do: 0, else: 10 # calcular costo
    IO.puts("[ENVIOS]\t| Compra N° #{compra_id}: costo de envío de $#{costo_envio}")

    Libremarket.Compras.Server.seleccionar_medio_pago(compra_id, medio_pago)
    Libremarket.Compras.Server.confirmar_compra(compra_id)

    # Agregar caso de stock insuficiente
    if (hay_infraccion) do
      # Compras.informar_infraccion
      IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: cancelada por infracción")
      # Ventas.liberar_producto
      IO.puts("[VENTAS]\t| Compra N° #{compra_id}: producto #{producto_id} liberado")
      "okn't"
    else
      # Autorizar pago
      pago_autorizado = Enum.random([true, false])
      if (not pago_autorizado) do
        # Compras.informar_pago_rechazado
        IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: cancelada por pago rechazado")
        # Ventas.liberar_producto
        IO.puts("[VENTAS]\t| Compra N° #{compra_id}: producto #{producto_id} liberado")
        "okn't"
      else
        if (forma_entrega == :correo) do
          # Envios.agendar_envio
          IO.puts("[ENVIOS]\t| Compra N° #{compra_id}: envio agendado")
          # Ventas.enviar_producto
          IO.puts("[VENTAS]\t| Compra N° #{compra_id}: producto en envio")
        end
        IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: compra realizada con éxito")
        "ok"
      end
    end
  end

end
