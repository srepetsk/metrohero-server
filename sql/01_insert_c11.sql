\c metrohero

--Original database additions:
--INSERT INTO public.station_to_station_travel_time (station_codes_key, distance, from_station_code, last_updated, to_station_code) VALUES ('C10_C12', 15483, 'C10', '2017-06-16 19:28:41.066000', 'C12') ON CONFLICT (station_codes_key) DO UPDATE SET distance = EXCLUDED.distance;
--INSERT INTO public.station_to_station_travel_time (station_codes_key, distance, from_station_code, last_updated, to_station_code) VALUES ('C12_C10', 15483, 'C12', '2017-09-16 10:07:13.434000', 'C10') ON CONFLICT (station_codes_key) DO UPDATE SET distance = EXCLUDED.distance;

-- Drop the old data
DELETE FROM public.station_to_station_travel_time WHERE station_codes_key = 'C10_C12';
DELETE FROM public.station_to_station_travel_time WHERE station_codes_key = 'C12_C10';

-- C1
INSERT INTO public.station_to_station_travel_time (station_codes_key, distance, from_station_code, last_updated, to_station_code) VALUES ('C12_C11', 6814, 'C12', '2023-07-09 16:49:00.000000', 'C11') ON CONFLICT (station_codes_key) DO UPDATE SET distance = EXCLUDED.distance;
INSERT INTO public.station_to_station_travel_time (station_codes_key, distance, from_station_code, last_updated, to_station_code) VALUES ('C11_C10', 8703, 'C11', '2023-07-09 16:49:00.000000', 'C10') ON CONFLICT (station_codes_key) DO UPDATE SET distance = EXCLUDED.distance;

-- C2
INSERT INTO public.station_to_station_travel_time (station_codes_key, distance, from_station_code, last_updated, to_station_code) VALUES ('C10_C11', 9137, 'C10', '2023-07-09 16:49:00.000000', 'C11') ON CONFLICT (station_codes_key) DO UPDATE SET distance = EXCLUDED.distance;
INSERT INTO public.station_to_station_travel_time (station_codes_key, distance, from_station_code, last_updated, to_station_code) VALUES ('C11_C12', 7579, 'C11', '2023-07-09 16:49:00.000000', 'C12') ON CONFLICT (station_codes_key) DO UPDATE SET distance = EXCLUDED.distance;
