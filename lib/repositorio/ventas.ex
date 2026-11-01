defmodule Repositorio.Ventas do
  @moduledoc """
  Operaciones de base de datos directas para las tablas productos y reservaciones.
  """

  @reservacion_columns [
    "compra_id",
    "producto_id",
    "reservado",
    "infraccion_detectada",
    "pago_autorizado",
    "fecha_envio"
  ]

  @select_reservaciones Enum.join(@reservacion_columns, ", ")

  defp row_to_reservacion([
         compra_id,
         producto_id,
         reservado,
         infraccion_detectada,
         pago_autorizado,
         fecha_envio
       ]) do
    %{
      compra_id: compra_id,
      producto_id: producto_id,
      reservado: reservado,
      infraccion_detectada: infraccion_detectada,
      pago_autorizado: pago_autorizado,
      fecha_envio: fecha_envio
    }
  end

  defp to_timestamp(nil), do: nil
  defp to_timestamp(%NaiveDateTime{} = ndt), do: ndt
  defp to_timestamp(%DateTime{} = dt), do: DateTime.to_naive(dt)
  defp to_timestamp(%Date{} = d), do: NaiveDateTime.new!(d, ~T[00:00:00])

  # PRODUCTOS

  def get_producto(producto_id) do
    query = "SELECT producto_id, stock FROM productos WHERE producto_id = $1 LIMIT 1"
    result = Repositorio.query!(query, [producto_id])

    case result.rows do
      [[id, stock]] -> %{producto_id: id, stock: stock}
      [] -> nil
    end
  end

  def decrementar_stock(producto_id) do
    query = "UPDATE productos SET stock = stock - 1 WHERE producto_id = $1 RETURNING producto_id, stock"
    result = Repositorio.query!(query, [producto_id])
    [[id, stock]] = result.rows
    %{producto_id: id, stock: stock}
  end

  def incrementar_stock(producto_id) do
    query = "UPDATE productos SET stock = stock + 1 WHERE producto_id = $1 RETURNING producto_id, stock"
    result = Repositorio.query!(query, [producto_id])
    [[id, stock]] = result.rows
    %{producto_id: id, stock: stock}
  end

  def all_productos do
    query = "SELECT producto_id, stock FROM productos ORDER BY producto_id ASC"
    result = Repositorio.query!(query, [])
    Enum.map(result.rows, fn [id, stock] -> %{producto_id: id, stock: stock} end)
  end

  # RESERVACIONES

  def get_reservacion(compra_id) do
    query = "SELECT #{@select_reservaciones} FROM reservaciones WHERE compra_id = $1 LIMIT 1"
    result = Repositorio.query!(query, [compra_id])

    case result.rows do
      [row] -> row_to_reservacion(row)
      [] -> nil
    end
  end

  def reservar_producto(compra_id, producto_id, reservado) do
    query = """
    INSERT INTO reservaciones (compra_id, producto_id, reservado)
    VALUES ($1, $2, $3)
    ON CONFLICT (compra_id) DO UPDATE SET
      producto_id = EXCLUDED.producto_id,
      reservado = EXCLUDED.reservado
    RETURNING #{@select_reservaciones}
    """

    result = Repositorio.query!(query, [compra_id, producto_id, reservado])
    [row] = result.rows
    row_to_reservacion(row)
  end

  def crear_reservacion_no_reservada(compra_id, producto_id) do
    reservar_producto(compra_id, producto_id, false)
  end

  def liberar_reservacion(compra_id) do
    query = """
    UPDATE reservaciones
    SET reservado = false
    WHERE compra_id = $1
    RETURNING #{@select_reservaciones}
    """

    result = Repositorio.query!(query, [compra_id])

    case result.rows do
      [row] -> row_to_reservacion(row)
      [] -> nil
    end
  end

  def registrar_estado_infraccion(compra_id, infraccion_detectada) do
    query = """
    INSERT INTO reservaciones (compra_id, infraccion_detectada)
    VALUES ($1, $2)
    ON CONFLICT (compra_id) DO UPDATE SET
      infraccion_detectada = EXCLUDED.infraccion_detectada
    RETURNING #{@select_reservaciones}
    """

    result = Repositorio.query!(query, [compra_id, infraccion_detectada])
    [row] = result.rows
    row_to_reservacion(row)
  end

  def registrar_estado_pago(compra_id, pago_autorizado) do
    query = """
    INSERT INTO reservaciones (compra_id, pago_autorizado)
    VALUES ($1, $2)
    ON CONFLICT (compra_id) DO UPDATE SET
      pago_autorizado = EXCLUDED.pago_autorizado
    RETURNING #{@select_reservaciones}
    """

    result = Repositorio.query!(query, [compra_id, pago_autorizado])
    [row] = result.rows
    row_to_reservacion(row)
  end

  def registrar_fecha_envio(compra_id, fecha_envio) do
    query = """
    INSERT INTO reservaciones (compra_id, fecha_envio)
    VALUES ($1, $2)
    ON CONFLICT (compra_id) DO UPDATE SET
      fecha_envio = EXCLUDED.fecha_envio
    RETURNING #{@select_reservaciones}
    """

    result = Repositorio.query!(query, [compra_id, to_timestamp(fecha_envio)])
    [row] = result.rows
    row_to_reservacion(row)
  end

  def all_reservaciones do
    query = "SELECT #{@select_reservaciones} FROM reservaciones ORDER BY compra_id ASC"
    result = Repositorio.query!(query, [])
    Enum.map(result.rows, &row_to_reservacion/1)
  end
end
