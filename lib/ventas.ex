defmodule Libremarket.Ventas do
  @moduledoc """
  Módulo de lógica de ventas
  """

  def stock_suficiente(productos, compra_id, producto_id) do
    producto = find_producto_by_id(productos, producto_id)
    stock_suficiente = producto.stock - 1 >= 0
    if (stock_suficiente) do
      IO.puts("Compra N° #{compra_id}: es posible reservar una unidad del producto ##{producto_id} (#{producto.stock} unidades disponibles)")
    else
      IO.puts("Compra N° #{compra_id}: insuficiente stock del producto ##{producto_id}")
    end
    stock_suficiente
  end

  def reservar_producto(compra_id, producto_id) do
    IO.puts("Compra N° #{compra_id}: unidad reservada del producto ##{producto_id}")
    %{
      compra_id: compra_id,
      producto_id: producto_id,
      infraccion_detectada: nil,
      pago_autorizado: nil,
      fecha_envio: nil
    }
  end

  def registrar_fecha_envio(reservacion, fecha_envio) do
    IO.puts("Compra N° #{reservacion.compra_id}: se registra la fecha de envio agendada (#{fecha_envio})")
    %{ reservacion | fecha_envio: fecha_envio }
  end

  def registrar_estado_infraccion(reservacion, infraccion_detectada) do
    IO.puts("Compra N° #{reservacion.compra_id}: se registra que #{if infraccion_detectada, do: "hubo", else: "no hubo"} infraccion")
    %{ reservacion | infraccion_detectada: infraccion_detectada }
  end

  def registrar_estado_pago(reservacion, pago_autorizado) do
    IO.puts("Compra N° #{reservacion.compra_id}: se registra que el pago #{if pago_autorizado, do: "fue", else: "no fue"} autorizado")
    %{ reservacion | pago_autorizado: pago_autorizado }
  end

  def liberar_producto(productos, compra_id, producto_id) do
    producto = find_producto_by_id(productos, producto_id)
    producto_actualizado = %{ producto | stock: producto.stock + 1 }
    IO.puts("Compra N° #{compra_id}: unidad liberada del producto ##{producto_id} (#{producto_actualizado.stock} unidades restantes)")
    update_in_productos(productos, producto_actualizado)
  end

  def enviar_producto(compra_id) do
    IO.puts("Compra N° #{compra_id}: producto enviado")
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
    Enum.map(productos, fn item ->
      if item.producto_id == producto_actualizado.producto_id, do: producto_actualizado, else: item
    end)
  end

end

defmodule Libremarket.Ventas.Server do
  @moduledoc """
  Módulo del servidor de ventas
  """

  use GenServer
  use AMQP

  @ventas_queue_name "ventas"
  @compras_queue_name "compras"


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
  # }
  @impl true
  def init(_state) do
    {:ok, amqp_channel} = AMQP.Application.get_channel(:channel)
    Queue.declare(amqp_channel, @ventas_queue_name, durable: true)
    Basic.consume(amqp_channel, @ventas_queue_name, nil, no_ack: true)
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
      ]
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
  def handle_info({:basic_deliver, payload, _meta}, state) do
    case :erlang.binary_to_term(payload) do
      {:reservar_producto, compra_id, producto_id} ->
        if (Libremarket.Ventas.stock_suficiente(state.productos, compra_id, producto_id)) do
          reservacion = Libremarket.Ventas.reservar_producto(compra_id, producto_id)
          producto = Libremarket.Ventas.find_producto_by_id(state.productos, producto_id)
          producto_actualizado = %{ producto | stock: producto.stock - 1 }
          new_state = %{
            state |
            reservaciones: [ reservacion | state.reservaciones ],
            productos: Libremarket.Ventas.update_in_productos(state.productos, producto_actualizado)
          }
          Producer.send_message(@compras_queue_name, {:informar_estado_reservacion, compra_id, true})
          {:noreply, new_state}
        else
          Producer.send_message(@compras_queue_name, {:informar_estado_reservacion, compra_id, false})
          {:noreply, state}
        end


      {:agendar_envio, compra_id, fecha_envio} ->
        reservacion = Libremarket.Ventas.find_reservacion_by_compra_id(state.reservaciones, compra_id)
        reservacion_actualizada = Libremarket.Ventas.registrar_fecha_envio(reservacion, fecha_envio)
        new_state = %{
          state |
          reservaciones: Libremarket.Ventas.update_in_reservaciones(state.reservaciones, reservacion_actualizada)
        }
        {:noreply, new_state}


      {:informar_estado_infraccion, compra_id, infraccion_detectada} ->
        reservacion = Libremarket.Ventas.find_reservacion_by_compra_id(state.reservaciones, compra_id)
        reservacion_actualizada = Libremarket.Ventas.registrar_estado_infraccion(reservacion, infraccion_detectada)

        # Si algo salió mal, liberar producto
        productos_actualizados = if (
          reservacion_actualizada.infraccion_detectada == true or
          reservacion_actualizada.pago_autorizado == false
        ) do
          Libremarket.Ventas.liberar_producto(state.productos, compra_id, reservacion_actualizada.producto_id)
        else
          state.productos
        end

        # Si todo salió bien, enviar producto
        if (
          reservacion_actualizada.infraccion_detectada == false and
          reservacion_actualizada.pago_autorizado == true and
          reservacion_actualizada.fecha_envio != nil
        ) do
          Libremarket.Ventas.enviar_producto(compra_id)
        end

        new_state = %{
          state |
          productos: productos_actualizados,
          reservaciones: Libremarket.Ventas.update_in_reservaciones(state.reservaciones, reservacion_actualizada)
        }
        {:noreply, new_state}


      {:informar_estado_pago, compra_id, pago_autorizado} ->
        reservacion = Libremarket.Ventas.find_reservacion_by_compra_id(state.reservaciones, compra_id)
        reservacion_actualizada = Libremarket.Ventas.registrar_estado_pago(reservacion, pago_autorizado)

        # Si algo salió mal, liberar producto
        productos_actualizados = if (
          reservacion_actualizada.infraccion_detectada == true or
          reservacion_actualizada.pago_autorizado == false
        ) do
          Libremarket.Ventas.liberar_producto(state.productos, compra_id, reservacion_actualizada.producto_id)
        else
          state.productos
        end

        # Si todo salió bien, enviar producto
        if (
          reservacion_actualizada.infraccion_detectada == false and
          reservacion_actualizada.pago_autorizado == true and
          reservacion_actualizada.fecha_envio != nil
        ) do
          Libremarket.Ventas.enviar_producto(compra_id)
        end

        new_state = %{
          state |
          productos: productos_actualizados,
          reservaciones: Libremarket.Ventas.update_in_reservaciones(state.reservaciones, reservacion_actualizada)
        }
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
