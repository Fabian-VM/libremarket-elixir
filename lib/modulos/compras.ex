defmodule Libremarket.Compras do
  @moduledoc """
  Módulo de lógica de compras
  """

  alias Libremarket.Compras

  # OPERACIONES DEL DIAGRAMA
  # -------------------------------------

  def seleccionar_producto(compra, producto_id) do
    IO.puts("Compra N° #{compra.compra_id}: producto ##{producto_id} seleccionado\n")
    Repositorio.Compras.seleccionar_producto(compra.compra_id, producto_id)
  end

  def seleccionar_forma_entrega(compra, forma_entrega) do
    IO.puts("Compra N° #{compra.compra_id}: forma de entrega '#{forma_entrega}' seleccionada\n")
    Repositorio.Compras.seleccionar_forma_entrega(compra.compra_id, forma_entrega)
  end

  def seleccionar_medio_pago(compra, medio_pago) do
    IO.puts("Compra N° #{compra.compra_id}: medio de pago '#{medio_pago}' seleccionado\n")
    Repositorio.Compras.seleccionar_medio_pago(compra.compra_id, medio_pago)
  end

  def confirmar_compra(compra, confirma_compra) do
    IO.puts("Compra N° #{compra.compra_id}: la compra #{if confirma_compra, do: "ha sido", else: "no ha sido"} confirmada por el usuario\n")
    Repositorio.Compras.confirmar_compra(compra.compra_id, confirma_compra)
  end

  def informar_compra_no_confirmada_por_usuario(compra) do
    IO.puts("Compra N° #{compra.compra_id}: se informa que no fue confirmada por el usuario\n")
  end

  def informar_infraccion(compra) do
    IO.puts("Compra N° #{compra.compra_id}: se informa que se detectó una infracción\n")
  end

  def informar_pago_rechazado(compra) do
    IO.puts("Compra N° #{compra.compra_id}: se informa que el pago fue rechazado\n")
  end

  def informar_stock_insuficiente(compra) do
    IO.puts("Compra N° #{compra.compra_id}: se informa que no hubo stock suficiente del producto\n")
  end

  def finalizar_compra(compra, finalizado_con_exito) do
    if finalizado_con_exito do
      IO.puts("Compra N° #{compra.compra_id}: se ha finalizado su compra con éxito. Hasta nunca!\n")
    else
      IO.puts("Compra N° #{compra.compra_id}: se ha cancelado su compra\n")
    end
    Repositorio.Compras.finalizar_compra(compra.compra_id, finalizado_con_exito)
  end




  # UTILIDADES
  # -------------------------------------

  def crear_compra do
    compra = Repositorio.Compras.crear_compra()
    IO.puts("Compra N° #{compra.compra_id}: nueva compra iniciada\n")
    compra
  end

  def registrar_estado_infraccion(compra, infraccion_detectada) do
    Repositorio.Compras.registrar_estado_infraccion(compra.compra_id, infraccion_detectada)
  end

  def registrar_estado_pago(compra, pago_autorizado) do
    Repositorio.Compras.registrar_estado_pago(compra.compra_id, pago_autorizado)
  end

  def registrar_estado_reservacion(compra, producto_esta_reservado) do
    Repositorio.Compras.registrar_estado_reservacion(compra.compra_id, producto_esta_reservado)
  end

  def registrar_costo_envio(compra, costo_envio) do
    Repositorio.Compras.registrar_costo_envio(compra.compra_id, costo_envio)
  end

  # Encontrar una compra por su id en la base de datos
  def find_compra_by_id(compra_id) do
    Repositorio.Compras.get_compra(compra_id)
  end

  def continuar_con_pagos(compra, state) do
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
          Compras.informar_infraccion(compra)
          Compras.finalizar_compra(compra, false)
          state

        # Este caso no aparece en el diagrama
        not compra.confirmada_por_usuario ->
          Compras.informar_compra_no_confirmada_por_usuario(compra)
          Compras.finalizar_compra(compra, false)
          state

        # Este caso tampoco aparece en el diagrama
        not compra.producto_esta_reservado ->
          Compras.informar_stock_insuficiente(compra)
          Compras.finalizar_compra(compra, false)
          state

        # Si todo se cumplió por fin
        true ->
          Middleware.send_message_server(Constantes.pagos_queue(), {:autorizar_pago, compra.compra_id}, state)

      end

    else
      state
    end

  end

end

defmodule Libremarket.Compras.Server do
  @moduledoc """
  Módulo del servidor de compras
  """

  use GenServer
  use AMQP
  alias Libremarket.Compras

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
  #   vector_component: VectorClock.component
  # }
  @impl true
  def init(_state) do
    {:ok, amqp_channel} = AMQP.Application.get_channel(:channel)
    Queue.declare(amqp_channel, Constantes.compras_queue(), durable: true)
    Basic.consume(amqp_channel, Constantes.compras_queue(), nil, no_ack: true)

    initial_state = %{
      amqp_channel: amqp_channel,
      vector_component: :compras
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
  def handle_info({:basic_deliver, raw_message, _meta}, state) do

    {message, state} = Middleware.read_message_server(raw_message, state)

    case message.content do
      {:simular_compra, producto_id, forma_entrega, medio_pago, confirmada_por_usuario} ->
        compra = Compras.crear_compra()

        compra = Compras.seleccionar_producto(compra, producto_id)
        compra = Compras.seleccionar_forma_entrega(compra, forma_entrega)
        state = Middleware.send_message_server(Constantes.ventas_queue(), {:reservar_producto, compra.compra_id, producto_id}, state)
        state = Middleware.send_message_server(Constantes.infracciones_queue(), {:detectar_infracciones, compra.compra_id}, state)

        state =
          if forma_entrega in [:correo, "correo"] do
            Middleware.send_message_server(Constantes.envios_queue(), {:calcular_costo, compra.compra_id, forma_entrega}, state)
          else
            state
          end

        compra =
          if forma_entrega in [:correo, "correo"] do
            compra
          else
            Compras.registrar_costo_envio(compra, 0)
          end

        compra = Compras.seleccionar_medio_pago(compra, medio_pago)
        _compra = Compras.confirmar_compra(compra, confirmada_por_usuario)

        {:noreply, state}


      {:informar_costo_envio, compra_id, costo_envio} ->
        compra = Compras.find_compra_by_id(compra_id)
        compra = Compras.registrar_costo_envio(compra, costo_envio)

        state = Compras.continuar_con_pagos(compra, state)

        {:noreply, state}


      {:informar_estado_infraccion, compra_id, infraccion_detectada} ->
        compra = Compras.find_compra_by_id(compra_id)
        compra = Compras.registrar_estado_infraccion(compra, infraccion_detectada)

        state = Compras.continuar_con_pagos(compra, state)

        {:noreply, state}


      {:informar_estado_reservacion, compra_id, producto_esta_reservado} ->
        compra = Compras.find_compra_by_id(compra_id)
        compra = Compras.registrar_estado_reservacion(compra, producto_esta_reservado)

        state = Compras.continuar_con_pagos(compra, state)

        {:noreply, state}


      {:informar_estado_pago, compra_id, pago_autorizado} ->
        compra = Compras.find_compra_by_id(compra_id)
        compra = Compras.registrar_estado_pago(compra, pago_autorizado)

        state =
          if pago_autorizado and compra.forma_entrega == :correo do
            Middleware.send_message_server(Constantes.envios_queue(), {:agendar_envio, compra_id}, state)
          else
            state
          end

        _compra =
          if not pago_autorizado do
            Compras.informar_pago_rechazado(compra)
            Compras.finalizar_compra(compra, false)
          else
            Compras.finalizar_compra(compra, true)
          end

        {:noreply, state}


      {:show_state} ->
        IO.inspect(Repositorio.Compras.all_compras(), label: "Compras en DB")
        {:noreply, state}


      {:show_clock} ->
        clock = Repositorio.VectorClocks.get_clock(state.vector_component)
        Middleware.VectorClock.print(clock)
        {:noreply, state}

      {:show_count_compras} ->
        %{totales: totales, exitosos: exitosos, fallidos: fallidos, errores: errores} =
          Repositorio.Compras.count_compras()

        IO.puts(
          "====================================================\n" <>
          "|        CONTEO DE COMPRAS                         |\n" <>
          "====================================================\n" <>
          "#{String.pad_leading(Integer.to_string(totales), 6)}  Totales\n" <>
          "#{String.pad_leading(Integer.to_string(exitosos), 6)}  Finalizados con éxito\n" <>
          "#{String.pad_leading(Integer.to_string(fallidos), 6)}  Finalizados sin éxito\n" <>
          "#{String.pad_leading(Integer.to_string(errores), 6)}  Sin finalizar (posibles errores)\n"
        )
        {:noreply, state}


      bad_payload ->
        IO.puts("ADVERTENCIA: el payload no coincidió con ningun patrón -> #{inspect(bad_payload)}\n")
        {:noreply, state}

    end

  end

end
