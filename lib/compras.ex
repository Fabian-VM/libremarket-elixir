defmodule Libremarket.Compras do
  @moduledoc """
  Módulo de lógica de compras
  """

  # OPERACIONES DEL DIAGRAMA
  # -------------------------------------

  def seleccionar_producto(compra, producto_id) do
    IO.puts("Compra N° #{compra.compra_id}: producto ##{producto_id} seleccionado")
    %{ compra | producto_id: producto_id }
  end

  def seleccionar_forma_entrega(compra, forma_entrega) do
    IO.puts("Compra N° #{compra.compra_id}: forma de entrega '#{forma_entrega}' seleccionada")
    %{ compra | forma_entrega: forma_entrega }
  end

  def seleccionar_medio_pago(compra, medio_pago) do
    IO.puts("Compra N° #{compra.compra_id}: medio de pago '#{medio_pago}' seleccionado")
    %{ compra | medio_pago: medio_pago }
  end

  def confirmar_compra(compra, confirma_compra) do
    IO.puts("Compra N° #{compra.compra_id}: la compra #{if confirma_compra, do: "ha sido", else: "no ha sido"} confirmada por el usuario")
    %{ compra | confirmada_por_usuario: confirma_compra }
  end

  def informar_compra_no_confirmada_por_usuario(compra) do
    IO.puts("Compra N° #{compra.compra_id}: se informa que no fue confirmada por el usuario")
  end

  def informar_infraccion(compra) do
    IO.puts("Compra N° #{compra.compra_id}: se informa que se detectó una infracción")
  end

  def informar_pago_rechazado(compra) do
    IO.puts("Compra N° #{compra.compra_id}: se informa que el pago fue rechazado")
  end

  def informar_stock_insuficiente(compra) do
    IO.puts("Compra N° #{compra.compra_id}: se informa que no hubo stock suficiente del producto")
  end

  def finalizar_compra(compra, finalizado_con_exito) do
    if finalizado_con_exito do
      IO.puts("Compra N° #{compra.compra_id}: se ha finalizado su compra con éxito. Hasta nunca!")
    else
      IO.puts("Compra N° #{compra.compra_id}: se ha cancelado su compra")
    end
    %{ compra | finalizado_con_exito: finalizado_con_exito }
  end




  # UTILIDADES
  # -------------------------------------

  def crear_compra(compra_id) do
    IO.puts("Compra N° #{compra_id}: nueva compra iniciada")
      %{
        compra_id: compra_id,
        producto_id: nil,
        forma_entrega: nil,
        medio_pago: nil,
        costo_envio: nil,
        confirmada_por_usuario: nil,
        infraccion_detectada: nil,
        producto_esta_reservado: nil,
        pago_autorizado: nil,
        finalizado_con_exito: nil
      }
  end

  def registrar_estado_infraccion(compra, infraccion_detectada) do
    %{ compra | infraccion_detectada: infraccion_detectada }
  end

  def registrar_estado_pago(compra, pago_autorizado) do
    %{ compra | pago_autorizado: pago_autorizado }
  end

  def registrar_estado_reservacion(compra, producto_esta_reservado) do
    %{ compra | producto_esta_reservado: producto_esta_reservado }
  end

  def registrar_costo_envio(compra, costo_envio) do
    %{ compra | costo_envio: costo_envio }
  end

  # Encontrar una compra en una lista de compras
  def find_compra_by_id(compras, compra_id) do
    Enum.find(compras, fn item -> item.compra_id == compra_id end)
  end

  # Recrear la lista de compras pero con la compra actualizada
  def update_in_compras(compras, new_compra) do
    Enum.map(compras, fn item ->
      if item.compra_id == new_compra.compra_id, do: new_compra, else: item
    end)
  end

  def evaluar_si_continuar_con_pagos(compra, cola_mensajes) do
    # Punto de sincronización
    # Algunos resultados pueden haber llegado previamente
    # Ante la llegada de cualquier mensaje, verifico todo
    # En algun momento llegará un mensaje que hará que todo se cumpla
    if (
      compra.confirmada_por_usuario != nil      # de compras
      and compra.infraccion_detectada != nil    # de infracciones
      and compra.producto_esta_reservado != nil # de ventas
      and compra.costo_envio != nil             # de envios
      and compra.finalizado_con_exito == nil    # si la compra ya fue finalizada, salir
    ) do
      cond do
        # Este caso aparece en el diagrama
        compra.infraccion_detectada ->
          Libremarket.Compras.informar_infraccion(compra)
          Libremarket.Compras.finalizar_compra(compra, false)

        # Este caso no aparece en el diagrama
        not compra.confirmada_por_usuario ->
          Libremarket.Compras.informar_compra_no_confirmada_por_usuario(compra)
          Libremarket.Compras.finalizar_compra(compra, false)

        # Este caso tampoco aparece en el diagrama
        not compra.producto_esta_reservado ->
          Libremarket.Compras.informar_stock_insuficiente(compra)
          Libremarket.Compras.finalizar_compra(compra, false)

        # Si todo se cumplió por fin
        true ->
          Producer.send_message(cola_mensajes, {:autorizar_pago, compra.compra_id})
          compra

      end

    else
      compra

    end

  end

end

defmodule Libremarket.Compras.Server do
  @moduledoc """
  Módulo del servidor de compras
  """

  use GenServer
  use AMQP

  @compras_queue_name "compras"
  @infracciones_queue_name "infracciones"
  @ventas_queue_name "ventas"
  @envios_queue_name "envios"
  @pagos_queue_name "pagos"


  # FUNCIONES PÚBLICAS
  # -------------------------------------

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_state(pid \\ __MODULE__) do
    GenServer.call(pid, :get_state)
  end


  # HANDLERS
  # -------------------------------------

  # state {
  #   amqp_channel: {...}
  #   compras: Compra[]
  # }
  @impl true
  def init(_state) do
    {:ok, amqp_channel} = AMQP.Application.get_channel(:channel)
    Queue.declare(amqp_channel, @compras_queue_name, durable: true)
    Basic.consume(amqp_channel, @compras_queue_name, nil, no_ack: true)

    initial_state = %{
      amqp_channel: amqp_channel,
      secuencia_id: 0,
      compras: []
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Necesario para recibir una confirmación del broker al registrarse como consumidor
  # (Si no está este handler, va a suceder un error de invocación a una función que no existe)
  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    {:noreply, state}
  end

  # Recepción de mensajes
  @impl true
  def handle_info({:basic_deliver, payload, _meta}, state) do

    case :erlang.binary_to_term(payload) do

      {:simular_compra, producto_id, forma_entrega, medio_pago, confirmada_por_usuario} ->
        compra = Libremarket.Compras.crear_compra(state.secuencia_id + 1)

        compra = Libremarket.Compras.seleccionar_producto(compra, producto_id)
        compra = Libremarket.Compras.seleccionar_forma_entrega(compra, forma_entrega)
        Producer.send_message(@ventas_queue_name, {:reservar_producto, compra.compra_id, producto_id})
        Producer.send_message(@infracciones_queue_name, {:detectar_infracciones, compra.compra_id})

        compra =
          if forma_entrega == :correo do
            Producer.send_message(@envios_queue_name, {:calcular_costo, compra.compra_id, forma_entrega})
            compra
          else
            Libremarket.Compras.registrar_costo_envio(compra, 0)
          end

        compra = Libremarket.Compras.seleccionar_medio_pago(compra, medio_pago)
        compra = Libremarket.Compras.confirmar_compra(compra, confirmada_por_usuario)

        new_state = %{ state | secuencia_id: compra.compra_id, compras: [ compra | state.compras ]}
        {:noreply, new_state}


      {:informar_costo_envio, compra_id, costo_envio} ->
        compra = Libremarket.Compras.find_compra_by_id(state.compras, compra_id)
        compra = Libremarket.Compras.registrar_costo_envio(compra, costo_envio)

        compra = Libremarket.Compras.evaluar_si_continuar_con_pagos(compra, @pagos_queue_name)

        new_state = %{ state | compras: Libremarket.Compras.update_in_compras(state.compras, compra)}
        {:noreply, new_state}


      {:informar_estado_infraccion, compra_id, infraccion_detectada} ->
        compra = Libremarket.Compras.find_compra_by_id(state.compras, compra_id)
        compra = Libremarket.Compras.registrar_estado_infraccion(compra, infraccion_detectada)

        compra = Libremarket.Compras.evaluar_si_continuar_con_pagos(compra, @pagos_queue_name)

        new_state = %{ state | compras: Libremarket.Compras.update_in_compras(state.compras, compra)}
        {:noreply, new_state}


      {:informar_estado_reservacion, compra_id, producto_esta_reservado} ->
        compra = Libremarket.Compras.find_compra_by_id(state.compras, compra_id)
        compra = Libremarket.Compras.registrar_estado_reservacion(compra, producto_esta_reservado)

        compra = Libremarket.Compras.evaluar_si_continuar_con_pagos(compra, @pagos_queue_name)

        new_state = %{ state | compras: Libremarket.Compras.update_in_compras(state.compras, compra)}
        {:noreply, new_state}


      {:informar_estado_pago, compra_id, pago_autorizado} ->
        compra = Libremarket.Compras.find_compra_by_id(state.compras, compra_id)
        compra = Libremarket.Compras.registrar_estado_pago(compra, pago_autorizado)
        compra =
          if not pago_autorizado do
            Libremarket.Compras.informar_pago_rechazado(compra)
            Libremarket.Compras.finalizar_compra(compra, false)
          else
            if compra.forma_entrega == :correo do
              Producer.send_message(@envios_queue_name, {:agendar_envio, compra_id})
            end
            Libremarket.Compras.finalizar_compra(compra, true)
          end

        new_state = %{ state | compras: Libremarket.Compras.update_in_compras(state.compras, compra)}
        {:noreply, new_state}


      {:show_state} ->
        IO.inspect(state)
        {:noreply, state}


      bad_payload ->
        IO.puts("ADVERTENCIA: el payload no coincidió con ningun patrón -> #{inspect(bad_payload)}")
        {:noreply, state}

    end

  end

end
