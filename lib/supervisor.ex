defmodule Libremarket.Supervisor do
  use Supervisor

  @doc """
  Inicia el supervisor
  """
  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  defp children() do
    case System.get_env("SERVER_TO_RUN") do
      nil -> [{Libremarket.Compras.Server, %{}}, {Libremarket.Infracciones.Server, %{}}]
      server_to_run -> [ {String.to_existing_atom("Elixir." <> server_to_run), %{}} ]
    end
  end

  @impl true
  def init(_opts) do
    Supervisor.init(children(), strategy: :one_for_one)
  end
end
