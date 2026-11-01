 TRUNCATE TABLE
    compras,
    vector_clock_compras,
    infracciones,
    vector_clock_infracciones,
    productos,
    reservaciones,
    vector_clock_ventas,
    vector_clock_pagos,
    vector_clock_envios
RESTART IDENTITY CASCADE;
