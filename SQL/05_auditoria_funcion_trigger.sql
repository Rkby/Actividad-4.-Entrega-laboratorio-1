-- LAB-01 | Parte B: esquema, tabla, funcion y trigger de auditoria
-- Ejecutar como superusuario en comercial.

CREATE SCHEMA auditoria;
REVOKE ALL ON SCHEMA auditoria FROM PUBLIC;

CREATE TABLE auditoria.cambios_clientes (
    id_evento        BIGSERIAL PRIMARY KEY,
    momento          TIMESTAMPTZ NOT NULL DEFAULT now(),
    usuario_sesion   TEXT NOT NULL DEFAULT session_user,
    usuario_efectivo TEXT NOT NULL DEFAULT current_user,
    aplicacion       TEXT DEFAULT current_setting('application_name'),
    ip_cliente       INET DEFAULT inet_client_addr(),
    operacion        TEXT NOT NULL,
    id_cliente       BIGINT,
    valores_antes    JSONB,
    valores_despues  JSONB
);

CREATE OR REPLACE FUNCTION auditoria.registrar_cambio_cliente()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria.cambios_clientes
            (operacion, id_cliente, valores_despues)
        VALUES
            (TG_OP, NEW.id, to_jsonb(NEW));
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria.cambios_clientes
            (operacion, id_cliente, valores_antes, valores_despues)
        VALUES
            (TG_OP, NEW.id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria.cambios_clientes
            (operacion, id_cliente, valores_antes)
        VALUES
            (TG_OP, OLD.id, to_jsonb(OLD));
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION auditoria.registrar_cambio_cliente() FROM PUBLIC;

CREATE TRIGGER trg_auditoria_clientes
AFTER INSERT OR UPDATE OR DELETE ON clientes
FOR EACH ROW
EXECUTE FUNCTION auditoria.registrar_cambio_cliente();

SELECT tgname, tgenabled, tgrelid::regclass
FROM pg_trigger
WHERE tgname = 'trg_auditoria_clientes';
