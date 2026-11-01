
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
INSERT INTO vector_clock_compras (vc_compras, vc_infracciones, vc_ventas, vc_envios, vc_pagos) VALUES (0, 0, 0, 0, 0);




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
INSERT INTO vector_clock_infracciones (vc_compras, vc_infracciones, vc_ventas, vc_envios, vc_pagos) VALUES (0, 0, 0, 0, 0);




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
INSERT INTO productos (producto_id, stock)
VALUES (1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8), (9, 9), (10, 10);

CREATE TABLE IF NOT EXISTS vector_clock_ventas (
    unica_fila BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (unica_fila),
    vc_compras BIGINT NOT NULL,
    vc_infracciones BIGINT NOT NULL,
    vc_ventas BIGINT NOT NULL,
    vc_envios BIGINT NOT NULL,
    vc_pagos BIGINT NOT NULL
);
INSERT INTO vector_clock_ventas (vc_compras, vc_infracciones, vc_ventas, vc_envios, vc_pagos) VALUES (0, 0, 0, 0, 0);


-- ENVIOS
CREATE TABLE IF NOT EXISTS vector_clock_envios (
    unica_fila BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (unica_fila),
    vc_compras BIGINT NOT NULL,
    vc_infracciones BIGINT NOT NULL,
    vc_ventas BIGINT NOT NULL,
    vc_envios BIGINT NOT NULL,
    vc_pagos BIGINT NOT NULL
);
INSERT INTO vector_clock_envios (vc_compras, vc_infracciones, vc_ventas, vc_envios, vc_pagos) VALUES (0, 0, 0, 0, 0);

-- PAGOS
CREATE TABLE IF NOT EXISTS vector_clock_pagos (
    unica_fila BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (unica_fila),
    vc_compras BIGINT NOT NULL,
    vc_infracciones BIGINT NOT NULL,
    vc_ventas BIGINT NOT NULL,
    vc_envios BIGINT NOT NULL,
    vc_pagos BIGINT NOT NULL
);
INSERT INTO vector_clock_pagos (vc_compras, vc_infracciones, vc_ventas, vc_envios, vc_pagos) VALUES (0, 0, 0, 0, 0);






