
-- COMPRAS

CREATE TABLE IF NOT EXISTS compras (
    compra_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    producto_id BIGINT,
    forma_entrega TEXT,
    medio_pago TEXT,
    costo_envio NUMERIC,
    confirmada_por_usuario BOOLEAN,
    infraccion_detectada BOOLEAN,
    producto_esta_reservado BOOLEAN,
    pago_autorizado BOOLEAN,
    finalizado_con_exito BOOLEAN
);

CREATE TABLE IF NOT EXISTS vector_clock_compras (
    unica_fila BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (unica_fila),
    vc_compras BIGINT NOT NULL,
    vc_infracciones BIGINT NOT NULL,
    vc_ventas BIGINT NOT NULL,
    vc_envios BIGINT NOT NULL,
    vc_pagos BIGINT NOT NULL
);




-- INFRACCIONES
CREATE TABLE IF NOT EXISTS infracciones (
    compra_id BIGINT PRIMARY KEY,
    infraccion_detectada BOOLEAN
);

CREATE TABLE IF NOT EXISTS vector_clock_infracciones (
    unica_fila BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (unica_fila),
    vc_compras BIGINT NOT NULL,
    vc_infracciones BIGINT NOT NULL,
    vc_ventas BIGINT NOT NULL,
    vc_envios BIGINT NOT NULL,
    vc_pagos BIGINT NOT NULL
);




-- VENTAS
CREATE TABLE IF NOT EXISTS reservaciones (
    compra_id BIGINT PRIMARY KEY,
    producto_id BIGINT,
    reservado BOOLEAN,
    infraccion_detectada BOOLEAN,
    pago_autorizado BOOLEAN,
    fecha_envio TIMESTAMP
);

CREATE TABLE IF NOT EXISTS productos (
    producto_id BIGINT PRIMARY KEY,
    stock INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS vector_clock_ventas (
    unica_fila BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (unica_fila),
    vc_compras BIGINT NOT NULL,
    vc_infracciones BIGINT NOT NULL,
    vc_ventas BIGINT NOT NULL,
    vc_envios BIGINT NOT NULL,
    vc_pagos BIGINT NOT NULL
);


-- ENVIOS
CREATE TABLE IF NOT EXISTS vector_clock_envios (
    unica_fila BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (unica_fila),
    vc_compras BIGINT NOT NULL,
    vc_infracciones BIGINT NOT NULL,
    vc_ventas BIGINT NOT NULL,
    vc_envios BIGINT NOT NULL,
    vc_pagos BIGINT NOT NULL
);

-- PAGOS
CREATE TABLE IF NOT EXISTS vector_clock_pagos (
    unica_fila BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (unica_fila),
    vc_compras BIGINT NOT NULL,
    vc_infracciones BIGINT NOT NULL,
    vc_ventas BIGINT NOT NULL,
    vc_envios BIGINT NOT NULL,
    vc_pagos BIGINT NOT NULL
);






