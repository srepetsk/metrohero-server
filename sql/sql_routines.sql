\c metrohero

create function ts_round(timestamp with time zone, integer) returns timestamp with time zone
    language sql
as $$
SELECT 'epoch'::timestamptz + '1 second'::INTERVAL * ( $2 * ( extract( epoch FROM $1 )::INT4 / $2 ) );
$$
;

create function interval_to_seconds(interval) returns double precision
    language sql
as $$
SELECT (extract(days from $1) * 86400)
       + (extract(hours from $1) * 3600)
       + (extract(minutes from $1) * 60)
       + extract(seconds from $1);
$$
;

create function weighted_stddev_state(state numeric[], val numeric, weight numeric) returns numeric[]
    language plpgsql
as $$
BEGIN
  IF weight IS NULL OR val IS NULL
  THEN RETURN state;
  ELSE RETURN ARRAY[state[1]+weight, state[2]+val*weight, state[3]+val^2*weight];
  END IF;
END;
$$
;

create function weighted_stddev_combiner(state numeric[], numeric, numeric) returns numeric
    language plpgsql
as $$
BEGIN
  RETURN sqrt((state[3]-(state[2]^2)/state[1])/(state[1]-1));
END;
$$
;

CREATE OR REPLACE FUNCTION weighted_stddev_state(state numeric[], val numeric, weight numeric) RETURNS numeric[3] AS
$$
BEGIN
        IF weight IS NULL OR val IS NULL
        THEN RETURN state;
        ELSE RETURN ARRAY[state[1]+weight, state[2]+val*weight, state[3]+val^2*weight];
        END IF;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION weighted_stddev_combiner(state numeric[], numeric, numeric) RETURNS numeric AS
$$
BEGIN
        RETURN sqrt((state[3]-(state[2]^2)/state[1])/(state[1]-1));
END;
$$
LANGUAGE plpgsql;


CREATE AGGREGATE weighted_stddev(var numeric, weight numeric)
(
        sfunc = weighted_stddev_state,
        stype = numeric[3],
        finalfunc = weighted_stddev_combiner,
        initcond = '{0,0,0}',
        finalfunc_extra
);
COMMENT ON AGGREGATE weighted_stddev(numeric, numeric) IS 'Usage: select weighted_stddev(var::numeric, weight::numeric) from X;';

CREATE AGGREGATE array_accum (anycompatiblearray)
(
    sfunc = array_cat,
    stype = anycompatiblearray,
    initcond = '{}'
);

CREATE EXTENSION btree_gist;

-- https://stackoverflow.com/a/38066008/1072621
CREATE OR REPLACE FUNCTION merge_train_departure_info(new_train_id CHARACTER VARYING, new_real_train_id CHARACTER VARYING, new_departure_station_name CHARACTER VARYING, new_departure_station_code CHARACTER VARYING, new_line_name CHARACTER VARYING, new_line_code CHARACTER VARYING, new_direction_name CHARACTER VARYING, new_direction_number INTEGER, new_scheduled_destination_station_name CHARACTER VARYING, new_scheduled_destination_station_code CHARACTER VARYING, new_observed_destination_station_name CHARACTER VARYING, new_observed_destination_station_code CHARACTER VARYING, new_observed_num_cars INTEGER, new_observed_departure_time TIMESTAMP WITHOUT TIME ZONE, new_scheduled_departure_time TIMESTAMP WITHOUT TIME ZONE, new_observed_time_since_last_departure NUMERIC, new_scheduled_time_since_last_departure NUMERIC, new_headway_deviation NUMERIC, new_schedule_deviation DOUBLE PRECISION) RETURNS BOOLEAN AS
$$
BEGIN
  LOOP
    -- first try to update an existing record
    BEGIN
      UPDATE train_departure_info
      SET
        train_id = new_train_id,
        real_train_id = new_real_train_id,
        departure_station_name = new_departure_station_name,
        line_name = new_line_name,
        direction_name = new_direction_name,
        scheduled_destination_station_name = new_scheduled_destination_station_name,
        scheduled_destination_station_code = new_scheduled_destination_station_code,
        observed_destination_station_name = new_observed_destination_station_name,
        observed_destination_station_code = new_observed_destination_station_code,
        observed_num_cars = new_observed_num_cars,
        observed_departure_time = new_observed_departure_time,
        scheduled_departure_time = new_scheduled_departure_time,
        observed_time_since_last_departure = new_observed_time_since_last_departure,
        scheduled_time_since_last_departure = new_scheduled_time_since_last_departure,
        headway_deviation = new_headway_deviation,
        schedule_deviation = new_schedule_deviation
      WHERE
        train_departure_info.departure_station_code = new_departure_station_code AND
        train_departure_info.line_code = new_line_code AND
        train_departure_info.direction_number = new_direction_number AND
        ((observed_departure_time IS NOT NULL AND scheduled_departure_time IS NULL AND observed_departure_time = new_observed_departure_time AND new_scheduled_departure_time IS NULL) OR
         (observed_departure_time IS NULL AND scheduled_departure_time IS NOT NULL AND new_observed_departure_time IS NULL AND scheduled_departure_time = new_scheduled_departure_time) OR
         (observed_departure_time IS NOT NULL AND scheduled_departure_time IS NOT NULL AND observed_departure_time = new_observed_departure_time AND scheduled_departure_time = new_scheduled_departure_time) OR
         (observed_departure_time IS NOT NULL AND scheduled_departure_time IS NULL AND observed_departure_time = new_observed_departure_time AND new_scheduled_departure_time IS NOT NULL) OR
         (observed_departure_time IS NULL AND scheduled_departure_time IS NOT NULL AND new_observed_departure_time IS NOT NULL AND scheduled_departure_time = new_scheduled_departure_time) OR
         (observed_departure_time IS NOT NULL AND scheduled_departure_time IS NOT NULL AND observed_departure_time != new_observed_departure_time AND scheduled_departure_time = new_scheduled_departure_time) OR
         (observed_departure_time IS NOT NULL AND scheduled_departure_time IS NOT NULL AND observed_departure_time = new_observed_departure_time AND scheduled_departure_time != new_scheduled_departure_time));
      IF found THEN
        -- update succeeded, so our job is done
        RETURN TRUE;
      END IF;
    EXCEPTION WHEN unique_violation THEN
      -- the update we requested would produce duplicate records
      -- delete the records we'd be updating and insert a new record instead by allowing the function to proceed
      RAISE WARNING 'Attempted to update multiple records to (%, %, %, %, %), which is not allowed as this would produce duplicate records. Deleting these records instead and inserting a new one. If some of these records should not be deleted but will be anyway because of this action, it is assumed their updated records will be inserted this tick or next tick.', new_departure_station_code, new_line_code, new_direction_number, new_observed_departure_time, new_scheduled_departure_time;
      DELETE FROM train_departure_info
      WHERE
          train_departure_info.departure_station_code = new_departure_station_code AND
          train_departure_info.line_code = new_line_code AND
          train_departure_info.direction_number = new_direction_number AND
          ((observed_departure_time IS NOT NULL AND scheduled_departure_time IS NULL AND observed_departure_time = new_observed_departure_time AND new_scheduled_departure_time IS NULL) OR
           (observed_departure_time IS NULL AND scheduled_departure_time IS NOT NULL AND new_observed_departure_time IS NULL AND scheduled_departure_time = new_scheduled_departure_time) OR
           (observed_departure_time IS NOT NULL AND scheduled_departure_time IS NOT NULL AND observed_departure_time = new_observed_departure_time AND scheduled_departure_time = new_scheduled_departure_time) OR
           (observed_departure_time IS NOT NULL AND scheduled_departure_time IS NULL AND observed_departure_time = new_observed_departure_time AND new_scheduled_departure_time IS NOT NULL) OR
           (observed_departure_time IS NULL AND scheduled_departure_time IS NOT NULL AND new_observed_departure_time IS NOT NULL AND scheduled_departure_time = new_scheduled_departure_time) OR
           (observed_departure_time IS NOT NULL AND scheduled_departure_time IS NOT NULL AND observed_departure_time != new_observed_departure_time AND scheduled_departure_time = new_scheduled_departure_time) OR
           (observed_departure_time IS NOT NULL AND scheduled_departure_time IS NOT NULL AND observed_departure_time = new_observed_departure_time AND scheduled_departure_time != new_scheduled_departure_time));
    END;

    -- no matching record to update, so insert a new one
    BEGIN
      INSERT INTO train_departure_info (
        train_id,
        real_train_id,
        departure_station_name,
        departure_station_code,
        line_name,
        line_code,
        direction_name,
        direction_number,
        scheduled_destination_station_name,
        scheduled_destination_station_code,
        observed_destination_station_name,
        observed_destination_station_code,
        observed_num_cars,
        observed_departure_time,
        scheduled_departure_time,
        observed_time_since_last_departure,
        scheduled_time_since_last_departure,
        headway_deviation,
        schedule_deviation
      ) VALUES (
        new_train_id,
        new_real_train_id,
        new_departure_station_name,
        new_departure_station_code,
        new_line_name,
        new_line_code,
        new_direction_name,
        new_direction_number,
        new_scheduled_destination_station_name,
        new_scheduled_destination_station_code,
        new_observed_destination_station_name,
        new_observed_destination_station_code,
        new_observed_num_cars,
        new_observed_departure_time,
        new_scheduled_departure_time,
        new_observed_time_since_last_departure,
        new_scheduled_time_since_last_departure,
        new_headway_deviation,
        new_schedule_deviation
      )
      ON CONFLICT (departure_station_code, line_code, direction_number, observed_departure_time) DO UPDATE
        SET
          train_id = EXCLUDED.train_id,
          real_train_id = EXCLUDED.real_train_id,
          departure_station_name = EXCLUDED.departure_station_name,
          departure_station_code = EXCLUDED.departure_station_code,
          line_name = EXCLUDED.line_name,
          line_code = EXCLUDED.line_code,
          direction_name = EXCLUDED.direction_name,
          direction_number = EXCLUDED.direction_number,
          scheduled_destination_station_name = EXCLUDED.scheduled_destination_station_name,
          scheduled_destination_station_code = EXCLUDED.scheduled_destination_station_code,
          observed_destination_station_name = EXCLUDED.observed_destination_station_name,
          observed_destination_station_code = EXCLUDED.observed_destination_station_code,
          observed_num_cars = EXCLUDED.observed_num_cars,
          observed_departure_time = EXCLUDED.observed_departure_time,
          scheduled_departure_time = EXCLUDED.scheduled_departure_time,
          observed_time_since_last_departure = EXCLUDED.observed_time_since_last_departure,
          scheduled_time_since_last_departure = EXCLUDED.scheduled_time_since_last_departure,
          headway_deviation = EXCLUDED.headway_deviation,
          schedule_deviation = EXCLUDED.schedule_deviation;
      -- all is well; record inserted
      RETURN TRUE;
    EXCEPTION WHEN unique_violation THEN
      -- insert failed due to another constraint, probably the scheduled_departure_time one
      -- try again with an upsert against that particular constraint
      BEGIN
        INSERT INTO train_departure_info (
          train_id,
          real_train_id,
          departure_station_name,
          departure_station_code,
          line_name,
          line_code,
          direction_name,
          direction_number,
          scheduled_destination_station_name,
          scheduled_destination_station_code,
          observed_destination_station_name,
          observed_destination_station_code,
          observed_num_cars,
          observed_departure_time,
          scheduled_departure_time,
          observed_time_since_last_departure,
          scheduled_time_since_last_departure,
          headway_deviation,
          schedule_deviation
        ) VALUES (
          new_train_id,
          new_real_train_id,
          new_departure_station_name,
          new_departure_station_code,
          new_line_name,
          new_line_code,
          new_direction_name,
          new_direction_number,
          new_scheduled_destination_station_name,
          new_scheduled_destination_station_code,
          new_observed_destination_station_name,
          new_observed_destination_station_code,
          new_observed_num_cars,
          new_observed_departure_time,
          new_scheduled_departure_time,
          new_observed_time_since_last_departure,
          new_scheduled_time_since_last_departure,
          new_headway_deviation,
          new_schedule_deviation
        )
        ON CONFLICT (departure_station_code, line_code, direction_number, scheduled_departure_time) DO UPDATE
          SET
            train_id = EXCLUDED.train_id,
            real_train_id = EXCLUDED.real_train_id,
            departure_station_name = EXCLUDED.departure_station_name,
            departure_station_code = EXCLUDED.departure_station_code,
            line_name = EXCLUDED.line_name,
            line_code = EXCLUDED.line_code,
            direction_name = EXCLUDED.direction_name,
            direction_number = EXCLUDED.direction_number,
            scheduled_destination_station_name = EXCLUDED.scheduled_destination_station_name,
            scheduled_destination_station_code = EXCLUDED.scheduled_destination_station_code,
            observed_destination_station_name = EXCLUDED.observed_destination_station_name,
            observed_destination_station_code = EXCLUDED.observed_destination_station_code,
            observed_num_cars = EXCLUDED.observed_num_cars,
            observed_departure_time = EXCLUDED.observed_departure_time,
            scheduled_departure_time = EXCLUDED.scheduled_departure_time,
            observed_time_since_last_departure = EXCLUDED.observed_time_since_last_departure,
            scheduled_time_since_last_departure = EXCLUDED.scheduled_time_since_last_departure,
            headway_deviation = EXCLUDED.headway_deviation,
            schedule_deviation = EXCLUDED.schedule_deviation;
        -- all is well (finally); record inserted
        RETURN TRUE;
      EXCEPTION WHEN unique_violation THEN
        -- another constraint (probably the first observed_departure_time one we checked) is now the problem
        -- do nothing; next iteration of the loop will try that again (after trying to update again first)
        RAISE WARNING 'failed to insert (%, %, %, %, %)', new_departure_station_code, new_line_code, new_direction_number, new_observed_departure_time, new_scheduled_departure_time;
      END;
    END;
  END LOOP;
END;
$$
LANGUAGE plpgsql;
