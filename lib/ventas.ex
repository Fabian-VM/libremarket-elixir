defmodule Libremarket.Ventas do
  @moduledoc """
  Módulo de lógica de ventas
  """

  # OPERACIONES DEL DIAGRAMA
  # -------------------------------------

  def reservar_producto(compra_id, producto) do
    IO.puts("Compra N° #{compra_id}: unidad reservada del producto ##{producto.producto_id} (#{producto.stock} unidades disponibles)\n")
    %{
      compra_id: compra_id,
      producto_id: producto.producto_id,
      infraccion_detectada: nil,
      pago_autorizado: nil,
      fecha_envio: nil
    }
  end

  def liberar_producto(productos, compra_id, producto_id) do
    producto = find_producto_by_id(productos, producto_id)
    producto = %{ producto | stock: producto.stock + 1 }
    IO.puts("Compra N° #{compra_id}: unidad liberada del producto ##{producto_id} (#{producto.stock} unidades restantes)\n")
    update_in_productos(productos, producto)
  end

  def enviar_producto(compra_id) do
    IO.puts("Compra N° #{compra_id}: producto enviado\n")
  end



  # UTILIDADES
  # -------------------------------------

  def stock_suficiente(productos, producto_id) do
    producto = find_producto_by_id(productos, producto_id)
    producto.stock - 1 >= 0
  end

  def registrar_fecha_envio(reservacion, fecha_envio) do
    %{ reservacion | fecha_envio: fecha_envio }
  end

  def registrar_estado_infraccion(reservacion, infraccion_detectada) do
    %{ reservacion | infraccion_detectada: infraccion_detectada }
  end

  def registrar_estado_pago(reservacion, pago_autorizado) do
    %{ reservacion | pago_autorizado: pago_autorizado }
  end

  # Encontrar una reservacion de producto en una lista de reservaciones
  def find_reservacion_by_compra_id(reservaciones, compra_id) do
    Enum.find(reservaciones, fn item -> item.compra_id == compra_id end)
  end

  # Recrear la lista de productos pero con el producto actualizado
  def update_in_reservaciones(reservaciones, reservacion) do
    Enum.map(reservaciones, fn item ->
      if item.compra_id == reservacion.compra_id, do: reservacion, else: item
    end)
  end

  # Encontrar un producto en una lista de productos
  def find_producto_by_id(productos, producto_id) do
    Enum.find(productos, fn item -> item.producto_id == producto_id end)
  end

  # Recrear la lista de productos pero con el producto actualizado
  def update_in_productos(productos, producto_actualizado) do
    Enum.map(productos, fn producto ->
      if producto.producto_id == producto_actualizado.producto_id, do: producto_actualizado, else: producto
    end)
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
  #   productos: Producto[]
  #   reservaciones: Reservacion[]
  #   vector_component: VectorClock.component
  #   vector_clock: VectorClock
  # }
  @impl true
  def init(_state) do
    {:ok, amqp_channel} = AMQP.Application.get_channel(:channel)
    Queue.declare(amqp_channel, Constantes.ventas_queue(), durable: true)
    Basic.consume(amqp_channel, Constantes.ventas_queue(), nil, no_ack: true)
    min_stock = 1
    max_stock = 10
    initial_state = %{
      amqp_channel: amqp_channel,
      reservaciones: [],
      productos: [
        %{ producto_id: 1, stock: Enum.random(min_stock .. max_stock) },
        %{ producto_id: 2, stock: Enum.random(min_stock .. max_stock) },
        %{ producto_id: 3, stock: Enum.random(min_stock .. max_stock) },
        %{ producto_id: 4, stock: Enum.random(min_stock .. max_stock) },
        %{ producto_id: 5, stock: Enum.random(min_stock .. max_stock) },
        %{ producto_id: 6, stock: Enum.random(min_stock .. max_stock) },
        %{ producto_id: 7, stock: Enum.random(min_stock .. max_stock) },
        %{ producto_id: 8, stock: Enum.random(min_stock .. max_stock) },
        %{ producto_id: 9, stock: Enum.random(min_stock .. max_stock) },
        %{ producto_id: 10, stock: Enum.random(min_stock .. max_stock) }
      ],
      vector_component: :ventas,
      vector_clock: Middleware.VectorClock.new()
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
        if (Ventas.stock_suficiente(state.productos, producto_id)) do
          producto = Ventas.find_producto_by_id(state.productos, producto_id)
          producto = %{ producto | stock: producto.stock - 1 }
          reservacion = Ventas.reservar_producto(compra_id, producto)
          state = %{
            state |
            reservaciones: [ reservacion | state.reservaciones ],
            productos: Ventas.update_in_productos(state.productos, producto)
          }
          state = Middleware.send_message_server(Constantes.compras_queue(), {:informar_estado_reservacion, compra_id, true}, state)
          {:noreply, state}
        else
          state = Middleware.send_message_server(Constantes.compras_queue(), {:informar_estado_reservacion, compra_id, false}, state)
          {:noreply, state}
        end



      {:informar_estado_infraccion, compra_id, infraccion_detectada} ->
        reservacion = Ventas.find_reservacion_by_compra_id(state.reservaciones, compra_id)
        reservacion = Ventas.registrar_estado_infraccion(reservacion, infraccion_detectada)

        # Si algo salió mal, liberar producto
        productos_actualizados =
          if (
            reservacion.infraccion_detectada == true or
            reservacion.pago_autorizado == false
          ) do
            Ventas.liberar_producto(state.productos, compra_id, reservacion.producto_id)
          else
            state.productos
          end

        # Si todo salió bien, enviar producto
        if (
          reservacion.infraccion_detectada == false and
          reservacion.pago_autorizado == true and
          reservacion.fecha_envio != nil
        ) do
          Ventas.enviar_producto(compra_id)
        end

        state = %{
          state |
          productos: productos_actualizados,
          reservaciones: Ventas.update_in_reservaciones(state.reservaciones, reservacion)
        }
        {:noreply, state}


      {:informar_estado_pago, compra_id, pago_autorizado} ->
        reservacion = Ventas.find_reservacion_by_compra_id(state.reservaciones, compra_id)
        reservacion = Ventas.registrar_estado_pago(reservacion, pago_autorizado)

        # Si algo salió mal, liberar producto
        productos_actualizados =
          if (
            reservacion.infraccion_detectada == true or
            reservacion.pago_autorizado == false
          ) do
            Ventas.liberar_producto(state.productos, compra_id, reservacion.producto_id)
          else
            state.productos
          end

        # Si todo salió bien, enviar producto
        if (
          reservacion.infraccion_detectada == false and
          reservacion.pago_autorizado == true and
          reservacion.fecha_envio != nil
        ) do
          Ventas.enviar_producto(compra_id)
        end

        state = %{
          state |
          productos: productos_actualizados,
          reservaciones: Ventas.update_in_reservaciones(state.reservaciones, reservacion)
        }
        {:noreply, state}



      {:agendar_envio, compra_id, fecha_envio} ->
        reservacion = Ventas.find_reservacion_by_compra_id(state.reservaciones, compra_id)
        reservacion = Ventas.registrar_fecha_envio(reservacion, fecha_envio)

        # Si todo salió bien, enviar producto
        if (
          reservacion.infraccion_detectada == false and
          reservacion.pago_autorizado == true and
          reservacion.fecha_envio != nil
        ) do
          Ventas.enviar_producto(compra_id)
        end

        state = %{
          state |
          reservaciones: Ventas.update_in_reservaciones(state.reservaciones, reservacion)
        }
        {:noreply, state}



      {:show_state} ->
        IO.inspect(state)
        {:noreply, state}

      {:show_products} ->
        IO.inspect(state.productos)
        {:noreply, state}

      {:show_clock} ->
        Middleware.VectorClock.print(state.vector_clock)
        {:noreply, state}


      bad_payload ->
        IO.puts("ADVERTENCIA: el payload no coincidió con ningun patrón -> #{inspect(bad_payload)}\n")
        {:noreply, state}

    end

  end

end
