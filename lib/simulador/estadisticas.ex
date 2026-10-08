
defmodule Estadisticas do

  def contar(mapas, clave, valor_esperado) do
    Enum.count(mapas, fn mapa ->
      Map.get(mapa, clave) == valor_esperado
    end)
  end

end
