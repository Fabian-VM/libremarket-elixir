defmodule Libremarket.Ui do

  # Notas (fabian):
  # 1. Esta seria la implementación del flujo principal indicado en el diagrama de actividades
  # 2. Está implementado en Ui y no en Compras porque si se implementa allí, habrán llamadas que serán locales,
  #    pero las demás a los GenServer de los demas, y eso dispersaría la implementación y sería más dificil
  #    verificarlo respecto al diagrama. En cambio de esta forma, con solo mirar esta función podemos tenerlo claro
  # 3. En el siguiente incremento se separarán los módulos cada vez mas para asemejarse a un sistema distribuido,
  #    pero ahora mismo lo que se busca es primero implementar la logica de negocio de forma secuencial
  # 4. El modulo de Compras es el que va pidiendo que los demás procesen cosas
  # 5. Cada resultado de Compras pide a otro modulo ajeno lo guardaen su estado.
  #    No solo se guardo en una variable, porque cuando este flujo sea por paso de mensajes,
  #    cada modulo deberá guardar cada resultado que obtenga. Por eso se implementa ahora.

  def comprar(producto_id, forma_entrega, medio_pago, confirma_compra) do
    compra_id = Libremarket.Compras.Server.seleccionar_producto(producto_id)

    Libremarket.Compras.Server.seleccionar_forma_entrega(compra_id, forma_entrega)

    infraccion_detectada = Libremarket.Infracciones.Server.detectar_infraccion(compra_id)
    Libremarket.Compras.Server.registrar_infraccion_detectada(compra_id, infraccion_detectada)

    producto_esta_reservado = Libremarket.Ventas.Server.reservar_producto(compra_id, producto_id)
    Libremarket.Compras.Server.registrar_producto_reservado(compra_id, producto_esta_reservado)

    if forma_entrega != :retira do
      costo_envio = Libremarket.Envios.Server.calcular_costo(compra_id, forma_entrega)
      Libremarket.Compras.Server.registrar_costo_envio(compra_id, costo_envio)
    end

    Libremarket.Compras.Server.seleccionar_medio_pago(compra_id, medio_pago)

    if confirma_compra do
      Libremarket.Compras.Server.confirmar_compra(compra_id)
    end


    # Agregar caso de stock insuficiente
    if (not producto_esta_reservado) do
      Libremarket.Compras.Server.informar_stock_insuficiente(compra_id)
      :not_ok
    else
      if (infraccion_detectada) do
        Libremarket.Compras.Server.informar_infraccion(compra_id)
        Libremarket.Ventas.Server.liberar_producto(compra_id, producto_id)
        :not_ok
      else
        # Autorizar pago
        pago_autorizado = Libremarket.Pagos.Server.autorizar_pago(compra_id)
        Libremarket.Compras.Server.registrar_pago_autorizado(compra_id, pago_autorizado)
        if (not pago_autorizado) do
          Libremarket.Compras.Server.informar_pago_rechazado(compra_id)
          Libremarket.Ventas.Server.liberar_producto(compra_id, producto_id)
          :not_ok
        else
          if (forma_entrega == :correo) do
            Libremarket.Envios.Server.agendar_envio(compra_id)
            Libremarket.Ventas.Server.enviar_producto(compra_id, producto_id)
          end
          Libremarket.Compras.Server.finalizar_compra(compra_id)
          :ok
        end
      end
    end
  end

end
