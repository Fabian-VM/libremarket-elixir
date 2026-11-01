defmodule Libremarket.Ventas do
  @moduledoc """
  Módulo de lógica de ventas
  """

  alias Libremarket.Ventas


  # OPERACIONES DEL DIAGRAMA
  # -------------------------------------

  def reservar_producto(compra_id, producto) do
    IO.puts("Compra N° #{compra_id}: unidad reservada del producto ##{producto.producto_id} (#{producto.stock} unidades disponibles)\n")
    Repositorio.Ventas.decrementar_stock(producto.producto_id)
    Repositorio.Ventas.reservar_producto(compra_id, producto.producto_id, true)
  end

  def liberar_producto(compra_id, producto_id) do
    producto = Repositorio.Ventas.incrementar_stock(producto_id)
    IO.puts("Compra N° #{compra_id}: unidad liberada del producto ##{producto_id} (#{producto.stock} unidades restantes)\n")
    Repositorio.Ventas.liberar_reservacion(compra_id)
  end

  def enviar_producto(compra_id) do
    IO.puts("Compra N° #{compra_id}: producto enviado\n")
  end



  # UTILIDADES
  # -------------------------------------

  def stock_suficiente(producto) do
    producto.stock - 1 >= 0
  end

  def registrar_fecha_envio(compra_id, fecha_envio) do
    Repositorio.Ventas.registrar_fecha_envio(compra_id, fecha_envio)
  end

  def registrar_estado_infraccion(compra_id, infraccion_detectada) do
    Repositorio.Ventas.registrar_estado_infraccion(compra_id, infraccion_detectada)
  end

  def registrar_estado_pago(compra_id, pago_autorizado) do
    Repositorio.Ventas.registrar_estado_pago(compra_id, pago_autorizado)
  end

  # Encontrar una reservacion de producto por compra_id en la base de datos
  def find_reservacion_by_compra_id(compra_id) do
    Repositorio.Ventas.get_reservacion(compra_id)
  end

  # Encontrar un producto en la base de datos
  def find_producto_by_id(producto_id) do
    Repositorio.Ventas.get_producto(producto_id)
  end


  def continuar_con_envios(reservacion, state) do
    # Punto de sincronizacion
    # Cuando ya reciba todos los mensajes necesarios, seguirá con envios

    # Si algo salió mal y el producto estaba reservado, liberar producto
    if (
      reservacion.reservado == true and
      (reservacion.infraccion_detectada == true or reservacion.pago_autorizado == false)
    ) do
      Ventas.liberar_producto(reservacion.compra_id, reservacion.producto_id)
    end

    # Si todo salió bien, enviar producto
    if (
      reservacion.infraccion_detectada == false and
      reservacion.pago_autorizado == true and
      reservacion.fecha_envio != nil
    ) do
      Ventas.enviar_producto(reservacion.compra_id)
    end

    state
  end

end

defmodule Libremarket.Ventas.Server do
  @moduledoc """
  Módulo del servidor de ventas
  """

  use GenServer
  use AMQP
  alias Libremarket.Ventas

  # FUNCIONES PÚBLICAS
  # -------------------------------------

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
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
    Queue.declare(amqp_channel, Constantes.ventas_queue(), durable: true)
    Basic.consume(amqp_channel, Constantes.ventas_queue(), nil, no_ack: true)

    initial_state = %{
      amqp_channel: amqp_channel,
      vector_component: :ventas
    }

    {:ok, initial_state}
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

      {:reservar_producto, compra_id, producto_id} ->
        producto = Ventas.find_producto_by_id(producto_id)

        state =
          if (producto != nil and Ventas.stock_suficiente(producto)) do
            _reservacion = Ventas.reservar_producto(compra_id, producto)
            Middleware.send_message_server(Constantes.compras_queue(), {:informar_estado_reservacion, compra_id, true}, state)
          else
            _reservacion = Repositorio.Ventas.crear_reservacion_no_reservada(compra_id, producto_id)
            Middleware.send_message_server(Constantes.compras_queue(), {:informar_estado_reservacion, compra_id, false}, state)
          end

        {:noreply, state}


      {:informar_estado_infraccion, compra_id, infraccion_detectada} ->
        reservacion = Ventas.registrar_estado_infraccion(compra_id, infraccion_detectada)
        state = Ventas.continuar_con_envios(reservacion, state)

        {:noreply, state}


      {:informar_estado_pago, compra_id, pago_autorizado} ->
        reservacion = Ventas.registrar_estado_pago(compra_id, pago_autorizado)
        state = Ventas.continuar_con_envios(reservacion, state)

        {:noreply, state}



      {:agendar_envio, compra_id, fecha_envio} ->
        reservacion = Ventas.registrar_fecha_envio(compra_id, fecha_envio)
        state = Ventas.continuar_con_envios(reservacion, state)

        {:noreply, state}



      {:show_state} ->
        IO.inspect(Repositorio.Ventas.all_reservaciones(), label: "Reservaciones en DB")
        {:noreply, state}

      {:show_products} ->
        IO.inspect(Repositorio.Ventas.all_productos(), label: "Productos en DB")
        {:noreply, state}

      {:show_clock} ->
        clock = Repositorio.VectorClocks.get_clock(state.vector_component)
        Middleware.VectorClock.print(clock)
        {:noreply, state}


      bad_payload ->
        IO.puts("ADVERTENCIA: el payload no coincidió con ningun patrón -> #{inspect(bad_payload)}\n")
        {:noreply, state}

    end

  end

end
