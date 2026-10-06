/* =====================================================================
   PRÁCTICAS PPP - Esquema físico (Oracle 12c o superior)
   Alcance: CU16_Registrar certificado  y  CU17_Constancia de Certificado
            y vista general  (RF130 - RF137)
   Nota: ROL, USUARIO, PPP e INFORME_FINAL se incluyen solo como
         dependencias mínimas; pertenecen a otros casos de uso
         (CU01, CU03-CU08, CU14-CU15).
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 1. Tablas de dependencia
-- ---------------------------------------------------------------------
CREATE TABLE rol (
    id_rol       NUMBER(2)     GENERATED ALWAYS AS IDENTITY,
    nombre_rol   VARCHAR2(40)  NOT NULL,
    CONSTRAINT pk_rol        PRIMARY KEY (id_rol),
    CONSTRAINT uq_rol_nombre UNIQUE (nombre_rol)
);

CREATE TABLE usuario (
    id_usuario            NUMBER(10)     GENERATED ALWAYS AS IDENTITY,
    id_rol                NUMBER(2)      NOT NULL,
    codigo_identificacion VARCHAR2(15)   NOT NULL,
    usuario               VARCHAR2(30)   NOT NULL,
    nombres_completos     VARCHAR2(150)  NOT NULL,
    correo_institucional  VARCHAR2(120)  NOT NULL,
    dni                   CHAR(8)        NOT NULL,
    telefono              VARCHAR2(15),
    contrasena_hash       VARCHAR2(255)  NOT NULL,
    estado                CHAR(1)        DEFAULT 'A' NOT NULL,
    fecha_registro        TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_usuario        PRIMARY KEY (id_usuario),
    CONSTRAINT fk_usuario_rol    FOREIGN KEY (id_rol) REFERENCES rol (id_rol),
    CONSTRAINT uq_usuario_codigo UNIQUE (codigo_identificacion),
    CONSTRAINT uq_usuario_login  UNIQUE (usuario),
    CONSTRAINT uq_usuario_correo UNIQUE (correo_institucional),
    CONSTRAINT uq_usuario_dni    UNIQUE (dni),
    CONSTRAINT ck_usuario_estado CHECK (estado IN ('A','I'))
);

CREATE TABLE ppp (
    id_ppp                 NUMBER(10)    GENERATED ALWAYS AS IDENTITY,
    id_estudiante          NUMBER(10)    NOT NULL,
    id_supervisor_academico NUMBER(10),
    nombre_empresa         VARCHAR2(150) NOT NULL,
    fecha_inicio           DATE          NOT NULL,
    fecha_fin              DATE,
    horas_acumuladas       NUMBER(4)     DEFAULT 0 NOT NULL,
    estado                 VARCHAR2(15)  DEFAULT 'EN_CURSO' NOT NULL,
    CONSTRAINT pk_ppp             PRIMARY KEY (id_ppp),
    CONSTRAINT fk_ppp_estudiante  FOREIGN KEY (id_estudiante)
                                  REFERENCES usuario (id_usuario),
    CONSTRAINT fk_ppp_supervisor  FOREIGN KEY (id_supervisor_academico)
                                  REFERENCES usuario (id_usuario),
    CONSTRAINT ck_ppp_estado      CHECK (estado IN ('EN_CURSO','CULMINADO','CERTIFICADO')),
    CONSTRAINT ck_ppp_fechas      CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT ck_ppp_horas       CHECK (horas_acumuladas >= 0)
);

CREATE TABLE informe_final (
    id_informe_final       NUMBER(10)    GENERATED ALWAYS AS IDENTITY,
    id_ppp                 NUMBER(10)    NOT NULL,
    id_supervisor_validador NUMBER(10),
    fecha_hora_subida      TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    ruta_archivo           VARCHAR2(300) NOT NULL,
    estado_validacion      VARCHAR2(15)  DEFAULT 'PENDIENTE' NOT NULL,
    fecha_validacion       TIMESTAMP,
    CONSTRAINT pk_informe_final   PRIMARY KEY (id_informe_final),
    CONSTRAINT uq_informe_ppp     UNIQUE (id_ppp),
    CONSTRAINT fk_informe_ppp     FOREIGN KEY (id_ppp) REFERENCES ppp (id_ppp),
    CONSTRAINT fk_informe_super   FOREIGN KEY (id_supervisor_validador)
                                  REFERENCES usuario (id_usuario),
    CONSTRAINT ck_informe_estado  CHECK (estado_validacion IN ('PENDIENTE','APROBADO','OBSERVADO'))
);

-- ---------------------------------------------------------------------
-- 2. Tablas propias de CU16 y CU17
-- ---------------------------------------------------------------------
CREATE TABLE certificado_ppp (
    id_certificado    NUMBER(10)    GENERATED ALWAYS AS IDENTITY,
    id_ppp            NUMBER(10)    NOT NULL,
    id_informe_final  NUMBER(10)    NOT NULL,
    id_secretaria     NUMBER(10)    NOT NULL,
    nro_certificado   VARCHAR2(30)  NOT NULL,
    total_horas       NUMBER(4)     NOT NULL,
    fecha_generacion  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    fecha_emision     TIMESTAMP,
    fecha_subida      TIMESTAMP,
    estado            VARCHAR2(15)  DEFAULT 'GENERADO' NOT NULL,
    ruta_archivo      VARCHAR2(300),
    CONSTRAINT pk_certificado      PRIMARY KEY (id_certificado),
    CONSTRAINT uq_cert_ppp         UNIQUE (id_ppp),
    CONSTRAINT uq_cert_nro         UNIQUE (nro_certificado),
    CONSTRAINT fk_cert_ppp         FOREIGN KEY (id_ppp) REFERENCES ppp (id_ppp),
    CONSTRAINT fk_cert_informe     FOREIGN KEY (id_informe_final)
                                   REFERENCES informe_final (id_informe_final),
    CONSTRAINT fk_cert_secretaria  FOREIGN KEY (id_secretaria)
                                   REFERENCES usuario (id_usuario),
    CONSTRAINT ck_cert_estado      CHECK (estado IN ('GENERADO','FIRMADO','EMITIDO','ANULADO')),
    CONSTRAINT ck_cert_horas       CHECK (total_horas > 0),
    CONSTRAINT ck_cert_emitido     CHECK (estado <> 'EMITIDO'
                                          OR (fecha_emision IS NOT NULL AND ruta_archivo IS NOT NULL))
);

CREATE TABLE resolucion_ppp (
    id_resolucion     NUMBER(10)    GENERATED ALWAYS AS IDENTITY,
    id_certificado    NUMBER(10)    NOT NULL,
    id_secretaria     NUMBER(10)    NOT NULL,
    nro_resolucion    VARCHAR2(30)  NOT NULL,
    fecha_resolucion  DATE          NOT NULL,
    ruta_archivo      VARCHAR2(300) NOT NULL,
    CONSTRAINT pk_resolucion       PRIMARY KEY (id_resolucion),
    CONSTRAINT uq_resol_cert       UNIQUE (id_certificado),
    CONSTRAINT uq_resol_nro        UNIQUE (nro_resolucion),
    CONSTRAINT fk_resol_cert       FOREIGN KEY (id_certificado)
                                   REFERENCES certificado_ppp (id_certificado),
    CONSTRAINT fk_resol_secretaria FOREIGN KEY (id_secretaria)
                                   REFERENCES usuario (id_usuario)
);

CREATE TABLE firma_digital (
    id_firma          NUMBER(10)    GENERATED ALWAYS AS IDENTITY,
    id_certificado    NUMBER(10)    NOT NULL,
    id_firmante       NUMBER(10)    NOT NULL,
    algoritmo         VARCHAR2(30)  DEFAULT 'SHA256withRSA' NOT NULL,
    hash_documento    VARCHAR2(128) NOT NULL,
    serie_certificado VARCHAR2(80),
    fecha_firma       TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_firma            PRIMARY KEY (id_firma),
    CONSTRAINT uq_firma_cert       UNIQUE (id_certificado),
    CONSTRAINT fk_firma_cert       FOREIGN KEY (id_certificado)
                                   REFERENCES certificado_ppp (id_certificado),
    CONSTRAINT fk_firma_firmante   FOREIGN KEY (id_firmante)
                                   REFERENCES usuario (id_usuario)
);

CREATE TABLE acceso_certificado (
    id_acceso         NUMBER(12)    GENERATED ALWAYS AS IDENTITY,
    id_certificado    NUMBER(10)    NOT NULL,
    id_usuario        NUMBER(10)    NOT NULL,
    tipo_acceso       VARCHAR2(15)  NOT NULL,
    fecha_hora        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    ip_origen         VARCHAR2(45),
    CONSTRAINT pk_acceso           PRIMARY KEY (id_acceso),
    CONSTRAINT fk_acceso_cert      FOREIGN KEY (id_certificado)
                                   REFERENCES certificado_ppp (id_certificado),
    CONSTRAINT fk_acceso_usuario   FOREIGN KEY (id_usuario)
                                   REFERENCES usuario (id_usuario),
    CONSTRAINT ck_acceso_tipo      CHECK (tipo_acceso IN ('VISUALIZACION','DESCARGA'))
);

-- ---------------------------------------------------------------------
-- 3. Índices sobre claves foráneas (Oracle no los crea automáticamente)
-- ---------------------------------------------------------------------
CREATE INDEX ix_usuario_rol       ON usuario (id_rol);
CREATE INDEX ix_ppp_estudiante    ON ppp (id_estudiante);
CREATE INDEX ix_ppp_supervisor    ON ppp (id_supervisor_academico);
CREATE INDEX ix_cert_informe      ON certificado_ppp (id_informe_final);
CREATE INDEX ix_cert_secretaria   ON certificado_ppp (id_secretaria);
CREATE INDEX ix_cert_estado       ON certificado_ppp (estado);
CREATE INDEX ix_resol_secretaria  ON resolucion_ppp (id_secretaria);
CREATE INDEX ix_firma_firmante    ON firma_digital (id_firmante);
CREATE INDEX ix_acceso_cert       ON acceso_certificado (id_certificado, fecha_hora);
CREATE INDEX ix_acceso_usuario    ON acceso_certificado (id_usuario);

-- ---------------------------------------------------------------------
-- 4. Regla de negocio: solo se genera certificado si el informe final
--    del mismo PPP está APROBADO (RF128, RF129 -> RF132)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_cert_valida_informe
BEFORE INSERT ON certificado_ppp
FOR EACH ROW
DECLARE
    v_estado informe_final.estado_validacion%TYPE;
BEGIN
    SELECT estado_validacion
      INTO v_estado
      FROM informe_final
     WHERE id_informe_final = :NEW.id_informe_final
       AND id_ppp           = :NEW.id_ppp;

    IF v_estado <> 'APROBADO' THEN
        RAISE_APPLICATION_ERROR(-20001,
            'No se puede generar el certificado: el informe final no está aprobado.');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002,
            'El informe final no corresponde al PPP indicado.');
END;
/

-- ---------------------------------------------------------------------
-- 5. Vista para CU17 (constancia de certificado y vista general)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_certificado_estudiante AS
SELECT c.id_certificado,
       c.nro_certificado,
       e.id_usuario            AS id_estudiante,
       e.codigo_identificacion AS codigo_estudiante,
       e.nombres_completos     AS estudiante,
       p.nombre_empresa,
       p.fecha_inicio,
       p.fecha_fin,
       c.total_horas,
       c.fecha_emision,
       c.fecha_subida,
       c.ruta_archivo,
       r.nro_resolucion,
       f.fecha_firma,
       c.estado
  FROM certificado_ppp c
  JOIN ppp      p ON p.id_ppp        = c.id_ppp
  JOIN usuario  e ON e.id_usuario    = p.id_estudiante
  LEFT JOIN resolucion_ppp r ON r.id_certificado = c.id_certificado
  LEFT JOIN firma_digital  f ON f.id_certificado = c.id_certificado
 WHERE c.estado = 'EMITIDO';

-- ---------------------------------------------------------------------
-- 6. Comentarios de diccionario (trazabilidad con la matriz)
-- ---------------------------------------------------------------------
COMMENT ON TABLE  certificado_ppp IS 'CU16. Certificado de culminación del PPP. RF130, RF132, RF133';
COMMENT ON COLUMN certificado_ppp.fecha_subida IS 'RF133. Fecha y hora en que el certificado se sube al sistema';
COMMENT ON COLUMN certificado_ppp.estado       IS 'GENERADO -> FIRMADO -> EMITIDO (o ANULADO)';
COMMENT ON TABLE  resolucion_ppp   IS 'CU16. Documento de resolución. RF131';
COMMENT ON TABLE  firma_digital    IS 'CU16. Firma digital del certificado. RF134';
COMMENT ON TABLE  acceso_certificado IS 'CU17. Bitácora de vistas y descargas. RF135, RF136, RF137';
COMMENT ON VIEW   vw_certificado_estudiante IS 'CU17. Vista general del certificado emitido para el estudiante';
