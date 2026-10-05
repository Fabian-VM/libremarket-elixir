defmodule Producer.Message do
  @moduledoc """
  Módulo para definir estructura de mensajes

  Esta estructura NO debe construirse en módulos externos, solo es de uso interno de Producer
  y como valor de retorno
  """

  @enforce_keys [:content]

  defstruct [:content, :vector_clock]

  @type t :: %__MODULE__{
    content: term(),
    vector_clock: Producer.VectorClock.t() | nil
  }
end

defmodule Producer.VectorClock do
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
    %Producer.VectorClock{
      compras: 0,
      infracciones: 0,
      ventas: 0,
      envios: 0,
      pagos: 0
    }
  end
end

defmodule Producer do
  @moduledoc """
  Módulo para enviar mensajes a RabbitMQ.
  """
  use AMQP

  defp send_raw_message(queue_name, message) do
    # Obtener el canal AMQP (definido en la configuración)
    {:ok, channel} = AMQP.Application.get_channel(:channel)

    # Declara la cola de mensajes. Si no existe, se crea.
    Queue.declare(channel, queue_name, durable: true)

    # Publicar el mensaje
    Basic.publish(channel, "", queue_name, :erlang.term_to_binary(message))

    IO.puts(
      "\t✉ Envíado a @#{queue_name}\n" <>
      "\t  #{inspect(message.content)}\n" <>
      "\t  #{inspect(message.vector_clock)}\n"
    )
  end

  defp read_raw_message(raw_message) do
    message = %Producer.Message{} = :erlang.binary_to_term(raw_message)
    IO.puts(
      "\t✉ Recibido\n" <>
      "\t  #{inspect(message.content)}\n" <>
      "\t  #{inspect(message.vector_clock)}\n"
    )
    message
  end

  defp merge_vector_clocks(vector_clock, rcv_vector_clock) do
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



  @doc """
  Simula el comportamiento de un middleware.
  Retorna el mensaje enviado, completo.
  """
  @spec send_message(String.t(), term()) :: Producer.Message.t()
  def send_message(queue_name, message) do
    message = %Producer.Message{ content: message }
    send_raw_message(queue_name, message)
    message
  end


  @doc """
  Simula el comportamiento de un middleware.
  Retorna el mensaje recibido, completo y decodificado.
  """
  @spec read_message(term()) :: Producer.Message.t()
  def read_message(raw_message) do
    read_raw_message(raw_message)
  end



  @doc """
  Simula el comportamiento de un middleware que gestione los relojes vectoriales al
  enviar mensajes.

  Retorna el mensaje enviado, completo.

  """
  @spec send_message_with_clock(
    String.t(),
    term(),
    Producer.VectorClock.t(),
    Producer.VectorClock.component()
  ) :: Producer.Message.t()
  def send_message_with_clock(queue_name, message, vector_clock, vector_component) do
    IO.puts(
      "\t○ Reloj antes de enviar el mensaje:\n" <>
      "\t  #{inspect(vector_clock)}\n"
    )
    vector_clock = Map.update!(vector_clock, vector_component, &(&1 + 1))
    message = %Producer.Message{ content: message, vector_clock: vector_clock }
    send_raw_message(queue_name, message)

    message
  end


  @doc """
  Simula el comportamiento de un middleware que gestione los relojes vectoriales al
  recibir mensajes.

  Retorna el mensaje recibido, completo y decodificado.

  """
  @spec read_message_with_clock(
    term(),
    Producer.VectorClock.t(),
    Producer.VectorClock.component()
  ) :: Producer.Message.t()
  def read_message_with_clock(raw_message, vector_clock, vector_component) do
    IO.puts(
      "\t○ Reloj antes de recibir mensaje:\n" <>
      "\t  #{inspect(vector_clock)}\n"
    )

    %Producer.Message{ content: content, vector_clock: rcv_vector_clock} = read_raw_message(raw_message)

    # Si hay reloj vectorial en el mensaje recibido, fusionarlos con el local
    new_vector_clock =
      case rcv_vector_clock do
        nil -> vector_clock
        rcv_vector_clock -> merge_vector_clocks(vector_clock, rcv_vector_clock)
      end

    # reloj + 1
    new_vector_clock =
      Map.update!(new_vector_clock, vector_component, &(&1 + 1))

    IO.puts(
      "\t○ Reloj ajustado después de recibir mensaje:\n" <>
      "\t  #{inspect(new_vector_clock)}\n"
    )
    %Producer.Message{ content: content, vector_clock: new_vector_clock }
  end


end
