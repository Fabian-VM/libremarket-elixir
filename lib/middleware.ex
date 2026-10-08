defmodule Middleware.Message do
  @moduledoc """
  Módulo para definir estructura de mensajes

  Esta estructura NO debe construirse en módulos externos, solo es de uso interno
  y como valor de retorno
  """

  @enforce_keys [:content]

  defstruct [:content, :vector_clock]

  @type t :: %__MODULE__{
    content: term(),
    vector_clock: Middleware.VectorClock.t() | nil
  }


  # Imprime a detalle un mensaje
  @spec print(
    String.t(),
    Middleware.Message.t()
  ) :: :ok
  def print(details, message) do
    IO.puts(
      "✉ #{details}\n" <>
      "  #{inspect(message.content)}\n" <>
      "  #{inspect(message.vector_clock)}\n"
    )
  end

end

defmodule Middleware.VectorClock do
  @moduledoc """
  Módulo para definir relojes vectoriales
  """
  @enforce_keys [:compras, :infracciones, :ventas, :envios, :pagos]

  defstruct [:compras, :infracciones, :ventas, :envios, :pagos]

  @type t :: %__MODULE__{
    compras: number(),
    infracciones: number(),
    ventas: number(),
    envios: number(),
    pagos: number()
  }
  @type component :: :compras | :infracciones | :ventas | :envios | :pagos

  def new() do
    %Middleware.VectorClock{
      compras: 0,
      infracciones: 0,
      ventas: 0,
      envios: 0,
      pagos: 0
    }
  end

  @spec merge(
    Middleware.VectorClock.t(),
    Middleware.VectorClock.t()
  ) :: Middleware.VectorClock.t()
  def merge(vector_clock, rcv_vector_clock) do
    Enum.reduce(
      [:compras, :infracciones, :ventas, :envios, :pagos],
      vector_clock,
      fn component, acc ->
        Map.update!(
          acc,
          component,
          &max(&1, Map.fetch!(rcv_vector_clock, component))
        )
      end
    )
  end

  # Imprime un reloj vectorial
  @spec print(Middleware.VectorClock.t()) :: :ok
  def print(vector_clock) do
    IO.puts("○ #{inspect(vector_clock)}\n")
  end

end

# Esto implementa las funciones para parseo a string automatico
defimpl String.Chars, for: Middleware.VectorClock do
  def to_string(clock) do
    "[ C: #{String.pad_leading(Kernel.to_string(clock.compras), 2)} | " <>
    "I: #{String.pad_leading(Kernel.to_string(clock.infracciones), 2)} | " <>
    "V: #{String.pad_leading(Kernel.to_string(clock.ventas), 2)} | " <>
    "E: #{String.pad_leading(Kernel.to_string(clock.envios), 2)} | " <>
    "P: #{String.pad_leading(Kernel.to_string(clock.pagos), 2)} ]"
  end
end

defimpl Inspect, for: Middleware.VectorClock do
  import Inspect.Algebra
  def inspect(clock, _opts) do
    clock
    |> Kernel.to_string()
    |> string()
  end
end


defmodule Middleware do

  @moduledoc """
  Módulo para enviar mensajes a RabbitMQ.
  """

  use AMQP
  alias Middleware.VectorClock
  alias Middleware.Message

  # UTILIDADES
  # -------------------------------------

  # Codifica un termino en binario y lo envía a la cola de mensajes indicada
  @spec send_term(String.t(), term()) :: :ok
  defp send_term(queue_name, term) do
    # Obtener el canal AMQP (definido en la configuración)
    {:ok, channel} = AMQP.Application.get_channel(:channel)

    # Declara la cola de mensajes. Si no existe, se crea.
    Queue.declare(channel, queue_name, durable: true)

    # Publicar el mensaje
    Basic.publish(channel, "", queue_name, :erlang.term_to_binary(term))
  end

  # Decodifica un termino en binario y lo interpreta como una estructura de mensaje
  @spec decode_as_message(term()) :: Message.t()
  defp decode_as_message(term) do
    %Message{} = :erlang.binary_to_term(term)
  end



  # FUNCIONES PÚBLICAS
  # -------------------------------------

  # Envio y recepción simple

  @spec send_message(String.t(), term()) :: Message.t()
  def send_message(queue_name, message) do
    message = %Message{ content: message }
    send_term(queue_name, message)
    message
  end

  @spec read_message(term()) :: Message.t()
  def read_message(term) do
    decode_as_message(term)
  end


  # Envió y recepción, pero con estado de servidores

  @spec send_message_server(String.t(), term(), map()) :: map()
  def send_message_server(queue_name, message, state) do
    # VectorClock.print("Reloj antes de enviar el mensaje:", state.vector_clock)
    vector_clock = Map.update!(state.vector_clock, state.vector_component, &(&1 + 1))
    sent_message = %Message{ content: message, vector_clock: vector_clock }
    send_term(queue_name, sent_message)
    Message.print("Enviado a #{queue_name}", sent_message)
    %{ state | vector_clock: sent_message.vector_clock }

  end

  @spec read_message_server(term(), map()) :: { Message.t(), map() }
  def read_message_server(term, state) do

    %Message{ content: rcv_content, vector_clock: rcv_vector_clock} = decode_as_message(term)

    # Ajuste de reloj
    new_vector_clock =
      case rcv_vector_clock do
        # Si el mensaje vino sin reloj, se asume que es un mensaje de simulador
        # y no se debe incrementar, ya que está fuera de la coordinación con relojes
        nil -> state.vector_clock

        # Si el mensaje vino con reloj, es un evento dentro del sistema
        rcv_vector_clock ->
          # VectorClock.print("Reloj antes de recibir mensaje:", state.vector_clock)
          Message.print("Recibido", %Message{ content: rcv_content, vector_clock: rcv_vector_clock})
          new_vector_clock = VectorClock.merge(state.vector_clock, rcv_vector_clock)
          Map.update!(new_vector_clock, state.vector_component, &(&1 + 1))
          # VectorClock.print("Reloj ajustado después de recibir mensaje:", new_vector_clock)
          new_vector_clock

      end

    {
      %Message{ content: rcv_content, vector_clock: new_vector_clock },
      %{ state | vector_clock: new_vector_clock }
    }

  end

end
