DROP TABLE api.simulation;

CREATE TABLE IF NOT EXISTS api.simulation
(
    "time" timestamp with time zone NOT NULL,
    "message" json  NOT NULL,
	"name" text NOT NULL,
	"instance_id" text NOT NULL
)

TABLESPACE pg_default;

SELECT create_hypertable('api.simulation', by_range('time'));


-- JSONObject messageObject, InfluxDB influxDB, String measurementName, String instanceId, Long currentTime)

CREATE OR REPLACE FUNCTION api.insert_simulation_record(
    p_time timestamp with time zone,
    p_message json,
    p_name text,
    p_instance_id text
)
RETURNS void AS
$$
BEGIN
    INSERT INTO api.simulation ("time", "message", "name", "instance_id")
    VALUES (p_time, p_message, p_name, p_instance_id);
END;
$$
LANGUAGE plpgsql;
