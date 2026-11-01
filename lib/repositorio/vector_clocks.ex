defmodule Repositorio.VectorClocks do
  @moduledoc """
  Acceso y actualización de relojes vectoriales en PostgreSQL.
  Cada módulo tiene su propia tabla de reloj vectorial de una sola fila.
  """

  alias Middleware.VectorClock

  @valid_components [:compras, :infracciones, :ventas, :envios, :pagos]

  @spec table_name(atom()) :: String.t()
  def table_name(component) when component in @valid_components do
    "vector_clock_#{component}"
  end

  @spec get_clock(atom()) :: VectorClock.t()
  def get_clock(component) when component in @valid_components do
    table = table_name(component)
    query = "SELECT vc_compras, vc_infracciones, vc_ventas, vc_envios, vc_pagos FROM #{table} WHERE unica_fila = true LIMIT 1"
    result = Repositorio.query!(query, [])

    case result.rows do
      [[c, i, v, e, p]] ->
        %VectorClock{
          compras: c,
          infracciones: i,
          ventas: v,
          envios: e,
          pagos: p
        }

      [] ->
        clock = VectorClock.new()
        update_clock(component, clock)
        clock
    end
  end

  @spec update_clock(atom(), VectorClock.t()) :: VectorClock.t()
  def update_clock(component, %VectorClock{} = clock) when component in @valid_components do
    table = table_name(component)

    query = """
    INSERT INTO #{table} (unica_fila, vc_compras, vc_infracciones, vc_ventas, vc_envios, vc_pagos)
    VALUES (true, $1, $2, $3, $4, $5)
    ON CONFLICT (unica_fila) DO UPDATE SET
      vc_compras = EXCLUDED.vc_compras,
      vc_infracciones = EXCLUDED.vc_infracciones,
      vc_ventas = EXCLUDED.vc_ventas,
      vc_envios = EXCLUDED.vc_envios,
      vc_pagos = EXCLUDED.vc_pagos
    """

    Repositorio.query!(query, [
      clock.compras,
      clock.infracciones,
      clock.ventas,
      clock.envios,
      clock.pagos
    ])

    clock
  end
end
