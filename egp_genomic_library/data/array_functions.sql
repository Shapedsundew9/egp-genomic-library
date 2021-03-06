CREATE OR REPLACE FUNCTION
	total_weighted_values(
		cscv DOUBLE PRECISION[],
		cscc BIGINT[],
		pscv DOUBLE PRECISION[],
		pscc BIGINT[],
		cspv DOUBLE PRECISION[],
		cspc BIGINT[],
		default_value DOUBLE PRECISION,
        default_count BIGINT)
    RETURNS DOUBLE PRECISION[]
    SET SCHEMA 'public'
    LANGUAGE plpgsql
    AS $$
	DECLARE
		csc_len INT = cardinality(cscv);
		psc_len INT = cardinality(pscv);
		csp_len INT = cardinality(cspv);
		max_len INT;
		delta_len INT;
		ccw DOUBLE PRECISION[];
		pcw DOUBLE PRECISION[];
		ppw DOUBLE PRECISION[];
		twa DOUBLE PRECISION[];
		tw DOUBLE PRECISION[];
		tv DOUBLE PRECISION[];
		tca BIGINT[];
		tc BIGINT[];
    BEGIN
		-- Overall calculation
		-- result = (CSCV * CSCC + PSCV * PSCC - CSPV * CSPC) / (CSCC + PSCC - CSPC)

		-- The lengths of the arrays must all be the same. Arrays that need to be
		-- extended are padded out with the defaults.
		max_len = GREATEST(csc_len, psc_len, csp_len);
		IF csc_len < max_len THEN
			delta_len = max_len - csc_len;
			cscv = array_cat(cscv, array_fill(default_value, ARRAY[delta_len]));
			cscc = array_cat(cscc, array_fill(default_count, ARRAY[delta_len]));
		END IF;
		IF psc_len < max_len THEN
			delta_len = max_len - psc_len;
			pscv = array_cat(pscv, array_fill(default_value, ARRAY[delta_len]));
			pscc = array_cat(pscc, array_fill(default_count, ARRAY[delta_len]));
		END IF;
		IF csp_len < max_len THEN
			delta_len = max_len - csp_len;
			cspv = array_cat(cspv, array_fill(default_value, ARRAY[delta_len]));
			cspc = array_cat(cspc, array_fill(default_count, ARRAY[delta_len]));
		END IF;

		-- ccw = cscv * cscc, pcw = pscv * pscc, ppw = cspv * cspc
		ccw = array_agg(e.el1 * e.el2) FROM unnest(cscv, cscc) e(el1, el2);
		pcw = array_agg(e.el1 * e.el2) FROM unnest(pscv, pscc) e(el1, el2);
		ppw = array_agg(e.el1 * e.el2) FROM unnest(cspv, cspc) e(el1, el2);

		-- twa = ccw + pcw, tw = twa - ppw
		twa = array_agg(e.el1 + e.el2) FROM unnest(ccw, pcw) e(el1, el2);
		tw = array_agg(e.el1 - e.el2) FROM unnest(twa, ppw) e(el1, el2);

		-- tca = cscc + pscc, tc = tca - cspc
		tca = array_agg(e.el1 + e.el2) FROM unnest(cscc, pscc) e(el1, el2);
		tc = array_agg(e.el1 - e.el2) FROM unnest(tca, cspc) e(el1, el2);

		-- tv = tw / tc
		tv = array_agg(e.el1 / e.el2) FROM unnest(tw, tc) e(el1, el2);

		RETURN tv;
	END;
$$;


CREATE OR REPLACE FUNCTION
	total_counts(
		cscc BIGINT[],
		pscc BIGINT[],
		cspc BIGINT[],
        default_count BIGINT)
    RETURNS BIGINT[]
    SET SCHEMA 'public'
    LANGUAGE plpgsql
    AS $$
	DECLARE
		csc_len INT = cardinality(cscc);
		psc_len INT = cardinality(pscc);
		csp_len INT = cardinality(cspc);
		max_len INT;
		delta_len INT;
		tca BIGINT[];
		tc BIGINT[];
    BEGIN
		-- Overall calculation
		-- result = CSCC + PSCC - CSPC

		-- The lengths of the arrays must all be the same. Arrays that need to be
		-- extended are padded out with the defaults.
		max_len = GREATEST(csc_len, psc_len, csp_len);
		IF csc_len < max_len THEN
			cscc = array_cat(cscc, array_fill(default_count, ARRAY[max_len - csc_len]));
		END IF;
		IF psc_len < max_len THEN
			pscc = array_cat(pscc, array_fill(default_count, ARRAY[max_len - psc_len]));
		END IF;
		IF csp_len < max_len THEN
			cspc = array_cat(cspc, array_fill(default_count, ARRAY[max_len - csp_len]));
		END IF;

		-- tca = cscc + pscc, tc = tca - cspc
		tca = array_agg(e.el1 + e.el2) FROM unnest(cscc, pscc) e(el1, el2);
		tc = array_agg(e.el1 - e.el2) FROM unnest(tca, cspc) e(el1, el2);

		RETURN tc;
	END;
$$;