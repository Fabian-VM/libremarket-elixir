defmodule Repositorio.Compras do
  @moduledoc """
  Operaciones de base de datos directas para la tabla compras.
  """

  @columns [
    "compra_id",
    "producto_id",
    "forma_entrega",
    "medio_pago",
    "costo_envio",
    "confirmada_por_usuario",
    "infraccion_detectada",
    "producto_esta_reservado",
    "pago_autorizado",
    "finalizado_con_exito"
  ]

  @select_columns Enum.join(@columns, ", ")

  defp row_to_map([
         compra_id,
         producto_id,
         forma_entrega,
         medio_pago,
         costo_envio,
         confirmada_por_usuario,
         infraccion_detectada,
         producto_esta_reservado,
         pago_autorizado,
         finalizado_con_exito
       ]) do
    %{
      compra_id: compra_id,
      producto_id: producto_id,
      forma_entrega: to_atom(forma_entrega),
      medio_pago: to_atom(medio_pago),
      costo_envio: to_number(costo_envio),
      confirmada_por_usuario: confirmada_por_usuario,
      infraccion_detectada: infraccion_detectada,
      producto_esta_reservado: producto_esta_reservado,
      pago_autorizado: pago_autorizado,
      finalizado_con_exito: finalizado_con_exito
    }
  end

  defp to_atom(nil), do: nil
  defp to_atom(val) when is_binary(val), do: String.to_atom(val)
  defp to_atom(val) when is_atom(val), do: val

  defp to_string_val(nil), do: nil
  defp to_string_val(val) when is_atom(val), do: Atom.to_string(val)
  defp to_string_val(val) when is_binary(val), do: val

  defp to_number(nil), do: nil
  defp to_number(%Decimal{} = d), do: Decimal.to_integer(d)
  defp to_number(val) when is_number(val), do: val

  def crear_compra do
    query = """
    INSERT INTO compras DEFAULT VALUES
    RETURNING #{@select_columns}
    """

    result = Repositorio.query!(query, [])
    [row] = result.rows
    row_to_map(row)
  end

  def get_compra(compra_id) do
    query = "SELECT #{@select_columns} FROM compras WHERE compra_id = $1 LIMIT 1"
    result = Repositorio.query!(query, [compra_id])

    case result.rows do
      [row] -> row_to_map(row)
      [] -> nil
    end
  end

  def seleccionar_producto(compra_id, producto_id) do
    query = "UPDATE compras SET producto_id = $1 WHERE compra_id = $2 RETURNING #{@select_columns}"
    result = Repositorio.query!(query, [producto_id, compra_id])
    [row] = result.rows
    row_to_map(row)
  end

  def seleccionar_forma_entrega(compra_id, forma_entrega) do
    query = "UPDATE compras SET forma_entrega = $1 WHERE compra_id = $2 RETURNING #{@select_columns}"
    result = Repositorio.query!(query, [to_string_val(forma_entrega), compra_id])
    [row] = result.rows
    row_to_map(row)
  end

  def seleccionar_medio_pago(compra_id, medio_pago) do
    query = "UPDATE compras SET medio_pago = $1 WHERE compra_id = $2 RETURNING #{@select_columns}"
    result = Repositorio.query!(query, [to_string_val(medio_pago), compra_id])
    [row] = result.rows
    row_to_map(row)
  end

  def confirmar_compra(compra_id, confirma_compra) do
    query = "UPDATE compras SET confirmada_por_usuario = $1 WHERE compra_id = $2 RETURNING #{@select_columns}"
    result = Repositorio.query!(query, [confirma_compra, compra_id])
    [row] = result.rows
    row_to_map(row)
  end

  def registrar_costo_envio(compra_id, costo_envio) do
    costo_decimal = if costo_envio != nil, do: Decimal.new(costo_envio), else: nil
    query = "UPDATE compras SET costo_envio = $1 WHERE compra_id = $2 RETURNING #{@select_columns}"
    result = Repositorio.query!(query, [costo_decimal, compra_id])
    [row] = result.rows
    row_to_map(row)
  end

  def registrar_estado_infraccion(compra_id, infraccion_detectada) do
    query = "UPDATE compras SET infraccion_detectada = $1 WHERE compra_id = $2 RETURNING #{@select_columns}"
    result = Repositorio.query!(query, [infraccion_detectada, compra_id])
    [row] = result.rows
    row_to_map(row)
  end

  def registrar_estado_reservacion(compra_id, producto_esta_reservado) do
    query = "UPDATE compras SET producto_esta_reservado = $1 WHERE compra_id = $2 RETURNING #{@select_columns}"
    result = Repositorio.query!(query, [producto_esta_reservado, compra_id])
    [row] = result.rows
    row_to_map(row)
  end

  def registrar_estado_pago(compra_id, pago_autorizado) do
    query = "UPDATE compras SET pago_autorizado = $1 WHERE compra_id = $2 RETURNING #{@select_columns}"
    result = Repositorio.query!(query, [pago_autorizado, compra_id])
    [row] = result.rows
    row_to_map(row)
  end

  def finalizar_compra(compra_id, finalizado_con_exito) do
    query = "UPDATE compras SET finalizado_con_exito = $1 WHERE compra_id = $2 RETURNING #{@select_columns}"
    result = Repositorio.query!(query, [finalizado_con_exito, compra_id])
    [row] = result.rows
    row_to_map(row)
  end

  def count_compras do
    query = """
    SELECT
      count(*)::integer AS totales,
      count(*) FILTER (WHERE finalizado_con_exito = true)::integer AS exitosos,
      count(*) FILTER (WHERE finalizado_con_exito = false)::integer AS fallidos,
      count(*) FILTER (WHERE finalizado_con_exito IS NULL)::integer AS errores
    FROM compras
    """

    result = Repositorio.query!(query, [])
    [[totales, exitosos, fallidos, errores]] = result.rows

    %{
      totales: totales,
      exitosos: exitosos,
      fallidos: fallidos,
      errores: errores
    }
  end

  def all_compras do
    query = "SELECT #{@select_columns} FROM compras ORDER BY compra_id ASC"
    result = Repositorio.query!(query, [])
    Enum.map(result.rows, &row_to_map/1)
  end
end
