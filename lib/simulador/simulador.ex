defmodule Simulador do


  # SIMULACIÓN
  # -------------------------------------

  def simular_compra(producto_id) do
    forma_entrega = if Enum.random(1..100) <= Constantes.prob_forma_entrega_correo(), do: :correo, else: :retira
    medio_pago = Enum.random([:efectivo, :transferencia, :td, :tc])
    confirma_compra = Enum.random(1..100) <= Constantes.prob_usuario_confirma()
    Libremarket.Ui.comprar(producto_id, forma_entrega, medio_pago, confirma_compra)
  end

  def simular_compra() do
    simular_compra(:rand.uniform(10))
  end

  def simular_compras_secuencial(cantidad \\ 1) do
    for _n <- 1 .. cantidad do
      simular_compra()
    end
  end

  def simular_compras_async(cantidad \\ 1) do
    tasks = for _n <- 1 .. cantidad do
      Task.async(fn -> simular_compra() end)
    end
    Task.await_many(tasks)
  end



  # UTILIDADES
  # -------------------------------------

  @doc """
  Envía un mensaje :show_state a la cola de mensajes especificada.
  Se espera que el proceso servidor que consuma ese mensaje, imprima su estado
  por la salida estándar.

  De esa forma no hace falta ingresar a dicho servidor para ejecutar el comando,
  sino únicamente leer su salida estándar.
  """
  def show_state(queue) do
    Middleware.send_message(queue, {:show_state})
    :ok
  end

  def show_state_compras, do: show_state(Constantes.compras_queue())
  def show_state_infracciones, do: show_state(Constantes.infracciones_queue())
  def show_state_ventas, do: show_state(Constantes.ventas_queue())
  def show_state_envios, do: show_state(Constantes.envios_queue())
  def show_state_pagos, do: show_state(Constantes.pagos_queue())

  @doc """
  Envía un mensaje :show_products a la cola de mensajes de ventas.
  """
  def show_products do
    Middleware.send_message(Constantes.ventas_queue(), {:show_products})
    :ok
  end


  @doc """
  Envía un mensaje :show_clock a la cola de mensajes especificada.
  """
  def show_clock(queue) do
    Middleware.send_message(queue, {:show_clock})
    :ok
  end

  def show_clock_compras, do: show_clock(Constantes.compras_queue())
  def show_clock_infracciones, do: show_clock(Constantes.infracciones_queue())
  def show_clock_ventas, do: show_clock(Constantes.ventas_queue())
  def show_clock_envios, do: show_clock(Constantes.envios_queue())
  def show_clock_pagos, do: show_clock(Constantes.pagos_queue())

  def show_clocks do
    show_clock(Constantes.compras_queue())
    show_clock(Constantes.infracciones_queue())
    show_clock(Constantes.ventas_queue())
    show_clock(Constantes.envios_queue())
    show_clock(Constantes.pagos_queue())
  end

  @doc """
  Envía un mensaje :show_count_compras a la cola de mensajes de compras
  """
  def show_count_compras do
    Middleware.send_message(Constantes.compras_queue(), {:show_count_compras})
    :ok
  end

end
