defmodule Libremarket.Compras do
  @moduledoc """
  Módulo de lógica de compras
  """

  def seleccionar_producto(compra_id, producto_id) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: producto ##{producto_id} seleccionado")
      %{
        compra_id: compra_id,
        producto_id: producto_id,
        forma_entrega: nil,
        medio_pago: nil,
        costo_envio: nil,
        confirmada_por_usuario: nil,
        infraccion_detectada: nil,
        producto_esta_reservado: nil,
        pago_autorizado: nil
      }
  end

  def seleccionar_forma_entrega(compra, forma_entrega) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra.compra_id}: forma de entrega '#{forma_entrega}' seleccionada")
    %{ compra | forma_entrega: forma_entrega }
  end

  def seleccionar_medio_pago(compra, medio_pago) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra.compra_id}: medio de pago '#{medio_pago}' seleccionado")
    %{ compra | medio_pago: medio_pago }
  end

  def confirmar_compra(compra) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra.compra_id}: confirmada por el usuario")
    %{ compra | confirmada_por_usuario: true }
  end

  def registrar_infraccion_detectada(compra, infraccion_detectada) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra.compra_id}: se registra que #{if infraccion_detectada, do: "hubo", else: "no hubo"} infraccion")
    %{ compra | infraccion_detectada: infraccion_detectada }
  end

  def registrar_producto_reservado(compra, producto_esta_reservado) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra.compra_id}: se registra que #{if producto_esta_reservado, do: "se ha", else: "no se ha"} reservado una unidad del producto")
    %{ compra | producto_esta_reservado: producto_esta_reservado }
  end


  def registrar_costo_envio(compra, costo_envio) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra.compra_id}: se registra que el costo de envio es de $#{costo_envio}")
    %{ compra | costo_envio: costo_envio }
  end

  def registrar_pago_autorizado(compra, pago_autorizado) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra.compra_id}: se registra que el pago #{if pago_autorizado, do: "fue", else: "no fue"} autorizado")
    %{ compra | pago_autorizado: pago_autorizado }
  end

  def informar_stock_insuficiente(compra_id) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: cancelada por stock insuficiente")
  end

  def informar_infraccion(compra_id) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: cancelada por infracción")
  end

  def informar_pago_rechazado(compra_id) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: cancelada por pago rechazado")
  end

  def finalizar_compra(compra_id) do
    IO.puts("[COMPRAS]\t| Compra N° #{compra_id}: realizada con éxito")
  end

end

defmodule Libremarket.Compras.Server do
  @moduledoc """
  Módulo del servidor de compras
  """

  use GenServer
  use AMQP

  @queue_name "compras"

  # FUNCIONES PÚBLICAS
  # -------------------------------------

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def list_compras(pid \\ __MODULE__) do
    GenServer.call(pid, :list_compras)
  end

  def find_compra_by_id(state, compra_id) do
    Enum.find(state.compras, fn item -> item.compra_id == compra_id end)
  end

  def update_compra(state, new_compra) do
    # Recrear la lista de compras pero con la compra actualizada
    new_compras = Enum.map(state.compras, fn item ->
      if item.compra_id == new_compra.compra_id, do: new_compra, else: item
    end)
    # Crear el estado actualizado
    %{ state | compras: new_compras }
  end

  # HANDLERS
  # -------------------------------------

  @impl true
  def init(_state) do
    {:ok, amqp_channel} = AMQP.Application.get_channel(:channel)
    Queue.declare(amqp_channel, @queue_name, durable: true)
    Basic.consume(amqp_channel, @queue_name, nil, no_ack: true)

    # state {
    #   amqp_channel: {...}
    #   secuencia_id: numero
    #   compras: Compra[]
    # }
    initial_state = %{
      amqp_channel: amqp_channel,
      secuencia_id: 0,
      compras: []
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
    IO.puts("Nuevo mensaje")
    case :erlang.binary_to_term(payload) do
      {:seleccionar_producto, producto_id} ->
        IO.puts("Seleccionar producto")
        compra_id = state.secuencia_id + 1
        compra = Libremarket.Compras.seleccionar_producto(compra_id, producto_id)
        new_state = %{
          state |
          secuencia_id: compra_id,
          compras: [compra | state.compras]
        }
        {:noreply, new_state}

      bad_payload ->
        IO.puts("ADVERTENCIA: payload no coincidió con ningun patrón -> #{inspect(bad_payload)}")
        {:noreply, state}
    end

  end

  @impl true
  def handle_call({:seleccionar_medio_pago, compra_id, medio_pago}, _from, state) do
    compra = Libremarket.Compras.Server.find_compra_by_id(state, compra_id)
    compra_actualizada = Libremarket.Compras.seleccionar_medio_pago(compra, medio_pago)
    new_state = Libremarket.Compras.Server.update_compra(state, compra_actualizada)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:confirmar_compra, compra_id}, _from, state) do
    compra = Libremarket.Compras.Server.find_compra_by_id(state, compra_id)
    compra_actualizada = Libremarket.Compras.confirmar_compra(compra)
    new_state = Libremarket.Compras.Server.update_compra(state, compra_actualizada)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:registrar_infraccion_detectada, compra_id, infraccion_detectada}, _from, state) do
    compra = Libremarket.Compras.Server.find_compra_by_id(state, compra_id)
    compra_actualizada = Libremarket.Compras.registrar_infraccion_detectada(compra, infraccion_detectada)
    new_state = Libremarket.Compras.Server.update_compra(state, compra_actualizada)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:registrar_producto_reservado, compra_id, producto_esta_reservado}, _from, state) do
    compra = Libremarket.Compras.Server.find_compra_by_id(state, compra_id)
    compra_actualizada = Libremarket.Compras.registrar_producto_reservado(compra, producto_esta_reservado)
    new_state = Libremarket.Compras.Server.update_compra(state, compra_actualizada)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:registrar_costo_envio, compra_id, costo_envio}, _from, state) do
    compra = Libremarket.Compras.Server.find_compra_by_id(state, compra_id)
    compra_actualizada = Libremarket.Compras.registrar_costo_envio(compra, costo_envio)
    new_state = Libremarket.Compras.Server.update_compra(state, compra_actualizada)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:registar_pago_autorizado, compra_id, pago_autorizado}, _from, state) do
    compra = Libremarket.Compras.Server.find_compra_by_id(state, compra_id)
    compra_actualizada = Libremarket.Compras.registrar_pago_autorizado(compra, pago_autorizado)
    new_state = Libremarket.Compras.Server.update_compra(state, compra_actualizada)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:informar_stock_insuficiente, compra_id}, _from, state) do
    Libremarket.Compras.informar_stock_insuficiente(compra_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:informar_infraccion, compra_id}, _from, state) do
    Libremarket.Compras.informar_infraccion(compra_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:informar_pago_rechazado, compra_id}, _from, state) do
    Libremarket.Compras.informar_pago_rechazado(compra_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:finalizar_compra, compra_id}, _from, state) do
    Libremarket.Compras.finalizar_compra(compra_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:list_compras, _from, state) do
    {:reply, state.compras, state}
  end

end
