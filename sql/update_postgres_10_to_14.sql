DROP AGGREGATE array_accum (anyarray);

CREATE AGGREGATE array_accum (anycompatiblearray)
(
    sfunc = array_cat,
    stype = anycompatiblearray,
    initcond = '{}'
);