defmodule Libremarket.Compras do
  @moduledoc """
  Módulo de lógica de compras
  """

  def crear_compra(compra_id, producto_id) do
    IO.puts("Compra N° #{compra_id}: creada con producto ##{producto_id} seleccionado")
      %{
        compra_id: compra_id,
        producto_id: producto_id,
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

  def seleccionar_forma_entrega(compra, forma_entrega) do
    IO.puts("Compra N° #{compra.compra_id}: forma de entrega '#{forma_entrega}' seleccionada")
    %{ compra | forma_entrega: forma_entrega }
  end

  def seleccionar_medio_pago(compra, medio_pago) do
    IO.puts("Compra N° #{compra.compra_id}: medio de pago '#{medio_pago}' seleccionado")
    %{ compra | medio_pago: medio_pago }
  end

  def confirmar_compra(compra, confirma_compra) do
    IO.puts("Compra N° #{compra.compra_id}: se registra que el usuario #{if confirma_compra, do: "ha", else: "no ha"} confirmado la compra")
    %{ compra | confirmada_por_usuario: confirma_compra }
  end

  def registrar_estado_infraccion(compra, infraccion_detectada) do
    IO.puts("Compra N° #{compra.compra_id}: se registra que #{if infraccion_detectada, do: "hubo", else: "no hubo"} infraccion")
    %{ compra | infraccion_detectada: infraccion_detectada }
  end

  def registrar_estado_reservacion(compra, producto_esta_reservado) do
    IO.puts("Compra N° #{compra.compra_id}: se registra que #{if producto_esta_reservado, do: "se ha", else: "no se ha"} reservado una unidad del producto")
    %{ compra | producto_esta_reservado: producto_esta_reservado }
  end

  def registrar_costo_envio(compra, costo_envio) do
    IO.puts("Compra N° #{compra.compra_id}: se registra que el costo de envio es de $#{costo_envio}")
    %{ compra | costo_envio: costo_envio }
  end

  def registrar_estado_pago(compra, pago_autorizado) do
    IO.puts("Compra N° #{compra.compra_id}: se registra que el pago #{if pago_autorizado, do: "fue", else: "no fue"} autorizado")
    %{ compra | pago_autorizado: pago_autorizado }
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

end

defmodule Libremarket.Compras.Server do
  @moduledoc """
  Módulo del servidor de compras
  """

  use GenServer
  use AMQP

  @ui_queue_name "ui"
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
      {:seleccionar_producto, compra_id, producto_id} ->
        compra = Libremarket.Compras.crear_compra(compra_id, producto_id)
        new_state = %{
          state |
          compras: [compra | state.compras]
        }
        Producer.send_message(@ui_queue_name, {:seleccionar_forma_entrega, compra_id})
        Producer.send_message(@ventas_queue_name, {:reservar_producto, compra_id, producto_id})
        Producer.send_message(@infracciones_queue_name, {:detectar_infracciones, compra_id})
        {:noreply, new_state}


      {:seleccionar_forma_entrega, compra_id, forma_entrega} ->
        compra = Libremarket.Compras.find_compra_by_id(state.compras, compra_id)
        compra_actualizada = Libremarket.Compras.seleccionar_forma_entrega(compra, forma_entrega)
        new_state = %{ state | compras: Libremarket.Compras.update_in_compras(state.compras, compra_actualizada)}
        if forma_entrega == :retira do
          Producer.send_message(@ui_queue_name, {:seleccionar_medio_pago, compra_id})
        else
          Producer.send_message(@envios_queue_name, {:calcular_costo, compra_id, forma_entrega})
        end
        {:noreply, new_state}


      {:registrar_costo_envio, compra_id, costo_envio} ->
        compra = Libremarket.Compras.find_compra_by_id(state.compras, compra_id)
        compra_actualizada = Libremarket.Compras.registrar_costo_envio(compra, costo_envio)
        new_state = %{ state | compras: Libremarket.Compras.update_in_compras(state.compras, compra_actualizada)}
        Producer.send_message(@ui_queue_name, {:seleccionar_medio_pago, compra_id})
        {:noreply, new_state}


      {:seleccionar_medio_pago, compra_id, medio_pago} ->
        compra = Libremarket.Compras.find_compra_by_id(state.compras, compra_id)
        compra_actualizada = Libremarket.Compras.seleccionar_medio_pago(compra, medio_pago)
        new_state = %{ state | compras: Libremarket.Compras.update_in_compras(state.compras, compra_actualizada)}
        Producer.send_message(@ui_queue_name, {:confirmar_compra, compra_id})
        {:noreply, new_state}


      {:confirmar_compra, compra_id, confirma_compra} ->
        compra = Libremarket.Compras.find_compra_by_id(state.compras, compra_id)
        compra_actualizada = Libremarket.Compras.confirmar_compra(compra, confirma_compra)
        new_state = %{ state | compras: Libremarket.Compras.update_in_compras(state.compras, compra_actualizada)}
        case compra_actualizada.producto_esta_reservado do
          nil -> nil
          false -> Producer.send_message(@ui_queue_name, {:informar_stock_insuficiente, compra_id})
          true ->
            case compra_actualizada.confirmada_por_usuario do
              nil -> nil
              false -> nil
              true ->
                case compra_actualizada.infraccion_detectada do
                  nil -> nil
                  false -> Producer.send_message(@pagos_queue_name, {:autorizar_pago, compra_id})
                  true -> Producer.send_message(@ui_queue_name, {:informar_infraccion, compra_id})
                end
            end
        end
        {:noreply, new_state}


      {:informar_estado_infraccion, compra_id, infraccion_detectada} ->
        compra = Libremarket.Compras.find_compra_by_id(state.compras, compra_id)
        compra_actualizada = Libremarket.Compras.registrar_estado_infraccion(compra, infraccion_detectada)
        new_state = %{ state | compras: Libremarket.Compras.update_in_compras(state.compras, compra_actualizada)}
        case compra_actualizada.producto_esta_reservado do
          nil -> nil
          false -> Producer.send_message(@ui_queue_name, {:informar_stock_insuficiente, compra_id})
          true ->
            case compra_actualizada.confirmada_por_usuario do
              nil -> nil
              false -> nil
              true ->
                case compra_actualizada.infraccion_detectada do
                  nil -> nil
                  false -> Producer.send_message(@pagos_queue_name, {:autorizar_pago, compra_id})
                  true -> Producer.send_message(@ui_queue_name, {:informar_infraccion, compra_id})
                end
            end
        end
        {:noreply, new_state}


      {:informar_estado_reservacion, compra_id, producto_esta_reservado} ->
        compra = Libremarket.Compras.find_compra_by_id(state.compras, compra_id)
        compra_actualizada = Libremarket.Compras.registrar_estado_reservacion(compra, producto_esta_reservado)
        new_state = %{ state | compras: Libremarket.Compras.update_in_compras(state.compras, compra_actualizada)}
        case compra_actualizada.producto_esta_reservado do
          nil -> nil
          false -> Producer.send_message(@ui_queue_name, {:informar_stock_insuficiente, compra_id})
          true ->
            case compra_actualizada.confirmada_por_usuario do
              nil -> nil
              false -> nil
              true ->
                case compra_actualizada.infraccion_detectada do
                  nil -> nil
                  false -> Producer.send_message(@pagos_queue_name, {:autorizar_pago, compra_id})
                  true -> Producer.send_message(@ui_queue_name, {:informar_infraccion, compra_id})
                end
            end
        end
        {:noreply, new_state}


      {:informar_estado_pago, compra_id, pago_autorizado} ->
        compra = Libremarket.Compras.find_compra_by_id(state.compras, compra_id)
        compra_actualizada = (
          if not pago_autorizado do
            Producer.send_message(@ui_queue_name, {:informar_pago_rechazado, compra_id})
            %{
              Libremarket.Compras.registrar_estado_pago(compra, pago_autorizado) |
              finalizado_con_exito: false
            }
          else
            if compra.forma_entrega == :correo do
              Producer.send_message(@envios_queue_name, {:agendar_envio, compra_id})
            end
            Producer.send_message(@ui_queue_name, {:informar_compra_finalizada, compra_id})
            %{
              Libremarket.Compras.registrar_estado_pago(compra, pago_autorizado) |
              finalizado_con_exito: true
            }
          end
        )
        new_state = %{ state | compras: Libremarket.Compras.update_in_compras(state.compras, compra_actualizada)}
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
