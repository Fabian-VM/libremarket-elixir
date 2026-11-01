defmodule Repositorio.Infracciones do
  @moduledoc """
  Operaciones de base de datos directas para la tabla infracciones.
  """

  defp row_to_map([compra_id, infraccion_detectada]) do
    %{
      compra_id: compra_id,
      infraccion_detectada: infraccion_detectada
    }
  end

  def registrar_infraccion(compra_id, infraccion_detectada) do
    query = """
    INSERT INTO infracciones (compra_id, infraccion_detectada)
    VALUES ($1, $2)
    ON CONFLICT (compra_id) DO UPDATE SET
      infraccion_detectada = EXCLUDED.infraccion_detectada
    RETURNING compra_id, infraccion_detectada
    """

    result = Repositorio.query!(query, [compra_id, infraccion_detectada])
    [row] = result.rows
    row_to_map(row)
  end

  def get_infraccion(compra_id) do
    query = "SELECT compra_id, infraccion_detectada FROM infracciones WHERE compra_id = $1 LIMIT 1"
    result = Repositorio.query!(query, [compra_id])

    case result.rows do
      [row] -> row_to_map(row)
      [] -> nil
    end
  end

  def all_infracciones do
    query = "SELECT compra_id, infraccion_detectada FROM infracciones ORDER BY compra_id ASC"
    result = Repositorio.query!(query, [])
    Enum.map(result.rows, &row_to_map/1)
  end
end
