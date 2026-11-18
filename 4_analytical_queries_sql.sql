/*
QUESTION 1: How does Long COVID prevalence vary by household income?
- Count respondents and Long COVID cases by income bracket; rank prevalence.
- Why? Identify income-related disparities in persistent symptoms.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
SELECT pe.income_bracket, COUNT(*) AS total_patients,
       COUNT(*) FILTER (WHERE lo.long_covid_flag) AS long_covid_cases,
       ROUND(100.0 * COUNT(*) FILTER (WHERE lo.long_covid_flag) / NULLIF(COUNT(*),0),2) AS prevalence_pct
FROM latest_outcome lo JOIN patient_economics pe USING (patient_id)
WHERE pe.income_bracket IS NOT NULL AND pe.income_bracket <> 'Unknown / Declined to Answer'
GROUP BY pe.income_bracket ORDER BY prevalence_pct DESC;


/*
QUESTION 2: Does combined housing and food insecurity relate to Long COVID?
- Assign four mutually exclusive housing/food insecurity profiles and calculate prevalence.
- Why? Examine whether overlapping hardships correspond to greater vulnerability.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
 , risk AS (
 SELECT lo.patient_id, lo.long_covid_flag,
 CASE WHEN (ph.missed_rent_payment IS TRUE OR ph.eviction_risk_flag IS TRUE)
           AND pfs.food_scarcity_status IN ('Sometimes not enough to eat','Often not enough to eat') THEN 'High Dual Insecurity'
      WHEN (ph.missed_rent_payment IS TRUE OR ph.eviction_risk_flag IS TRUE) THEN 'Housing Insecure Only'
      WHEN pfs.food_scarcity_status IN ('Sometimes not enough to eat','Often not enough to eat') THEN 'Food Insecure Only'
      ELSE 'Secure / Stable' END AS risk_profile
 FROM latest_outcome lo
 JOIN patient_housing ph USING (patient_id)
 JOIN patient_food_security pfs USING (patient_id)
 WHERE ph.missed_rent_payment IS NOT NULL AND ph.eviction_risk_flag IS NOT NULL
   AND pfs.food_scarcity_status IS NOT NULL
   AND pfs.food_scarcity_status NOT IN ('Not Reported','Unknown','Unspecified')
)
SELECT risk_profile, COUNT(*) AS patient_count,
 COUNT(*) FILTER (WHERE long_covid_flag) AS long_covid_cases,
 ROUND(100.0 * COUNT(*) FILTER (WHERE long_covid_flag)/NULLIF(COUNT(*),0),2) AS prevalence_pct
FROM risk GROUP BY risk_profile ORDER BY prevalence_pct DESC;


/*
QUESTION 3: How does Long COVID prevalence differ across county SVI quartiles?
- Rank counties by SVI, assign four quartiles, and compare linked respondent prevalence.
- Why: Explore geographic vulnerability patterns, subject to approximate county assignment.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
 , county_quartiles AS (
 SELECT fips_code, NTILE(4) OVER (ORDER BY overall_svi_score, fips_code) AS svi_quartile
 FROM counties WHERE overall_svi_score IS NOT NULL
)
SELECT cq.svi_quartile,
 CASE cq.svi_quartile WHEN 1 THEN 'Q1 - Lowest Vulnerability' WHEN 2 THEN 'Q2 - Moderate-Low'
 WHEN 3 THEN 'Q3 - Moderate-High' ELSE 'Q4 - Highest Vulnerability' END AS quartile_label,
 COUNT(*) AS total_patients, COUNT(*) FILTER (WHERE lo.long_covid_flag) AS long_covid_cases,
 ROUND(100.0 * COUNT(*) FILTER (WHERE lo.long_covid_flag)/NULLIF(COUNT(*),0),2) AS prevalence_pct
FROM latest_outcome lo JOIN patients p USING (patient_id)
JOIN county_quartiles cq ON cq.fips_code = p.fips_code
GROUP BY cq.svi_quartile ORDER BY cq.svi_quartile;


/*
QUESTION 4: How does activity limitation severity vary by insurance type?
- Within Long COVID cases, calculate the count and percentage of each reported limitation level by insurance.
- Why: Assess whether severity distributions differ by insurance coverage.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
SELECT pe.health_insurance_type, lo.activity_limitation_level,
 COUNT(*) AS long_covid_cases,
 ROUND(100.0 * COUNT(*)/NULLIF(SUM(COUNT(*)) OVER (PARTITION BY pe.health_insurance_type),0),2) AS pct_within_insurance_group
FROM latest_outcome lo JOIN patient_economics pe USING (patient_id)
WHERE lo.long_covid_flag IS TRUE AND pe.health_insurance_type IS NOT NULL
 AND pe.health_insurance_type NOT IN ('Unspecified Insurance','Unknown')
 AND lo.activity_limitation_level IS NOT NULL
 AND lo.activity_limitation_level NOT IN ('Unspecified','Unknown','N/A')
GROUP BY pe.health_insurance_type, lo.activity_limitation_level
ORDER BY pe.health_insurance_type, pct_within_insurance_group DESC;


/*
QUESTION 5: Which race/ethnicity and age intersections show higher prevalence?
- Calculate Long COVID prevalence by race/ethnicity and age for groups with at least 30 respondents.
- Why? Identify demographic intersections warranting further investigation.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
SELECT p.race_ethnicity, p.age_group, COUNT(*) AS total_respondents,
 COUNT(*) FILTER (WHERE lo.long_covid_flag) AS long_covid_cases,
 ROUND(100.0 * COUNT(*) FILTER (WHERE lo.long_covid_flag)/NULLIF(COUNT(*),0),2) AS prevalence_pct
FROM latest_outcome lo JOIN patients p USING (patient_id)
WHERE p.race_ethnicity IS NOT NULL AND p.race_ethnicity <> 'Unknown / Unspecified'
 AND p.age_group IS NOT NULL
GROUP BY p.race_ethnicity,p.age_group HAVING COUNT(*) >= 30
ORDER BY prevalence_pct DESC;


/*
QUESTION 6: Which states have the highest Long COVID prevalence?
- Calculate state-level respondent prevalence for states with at least 50 respondents and assign dense ranks.
- Why? Compare geographic patterns using state groupings rather than approximate counties.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
 , state_rates AS (
 SELECT s.state_id, s.state_name, COUNT(*) AS patient_count,
 COUNT(*) FILTER (WHERE lo.long_covid_flag) AS long_covid_cases,
 ROUND(100.0 * COUNT(*) FILTER (WHERE lo.long_covid_flag)/NULLIF(COUNT(*),0),2) AS prevalence_pct
 FROM latest_outcome lo JOIN patients p USING (patient_id)
 JOIN counties c ON p.fips_code=c.fips_code JOIN states s ON c.state_id=s.state_id
 GROUP BY s.state_id,s.state_name HAVING COUNT(*) >= 50
)
SELECT *, DENSE_RANK() OVER (ORDER BY prevalence_pct DESC) AS state_prevalence_rank
FROM state_rates ORDER BY state_prevalence_rank,state_name;


/*
QUESTION 7: How do Long COVID prevalence and symptom duration vary by employment?
- Report prevalence by employment status and average symptom duration in months among Long COVID cases with known duration.
- Why? Investigate whether employment status is associated with persistence and duration.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
SELECT pe.employment_status, COUNT(*) AS total_patients,
 COUNT(*) FILTER (WHERE lo.long_covid_flag) AS long_covid_patients,
 ROUND(100.0 * COUNT(*) FILTER (WHERE lo.long_covid_flag)/NULLIF(COUNT(*),0),2) AS prevalence_pct,
 COUNT(*) FILTER (WHERE lo.long_covid_flag AND lo.symptom_duration_months IS NOT NULL) AS cases_with_duration,
 ROUND(AVG(lo.symptom_duration_months) FILTER (WHERE lo.long_covid_flag),2) AS avg_symptom_duration_months
FROM latest_outcome lo JOIN patient_economics pe USING (patient_id)
WHERE pe.employment_status IS NOT NULL AND pe.employment_status NOT IN ('Unknown','Unspecified')
GROUP BY pe.employment_status ORDER BY prevalence_pct DESC;


/*
QUESTION 8: How does prevalence vary by food scarcity and assistance use?
- Cross-tabulate food scarcity status and food assistance utilization against Long COVID prevalence.
- Why? Explore differences among people reporting distinct food-related circumstances; not a causal impact estimate.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
SELECT pfs.food_scarcity_status,pfs.used_food_assistance,
 COUNT(*) AS total_patients, COUNT(*) FILTER (WHERE lo.long_covid_flag) AS long_covid_cases,
 ROUND(100.0 * COUNT(*) FILTER (WHERE lo.long_covid_flag)/NULLIF(COUNT(*),0),2) AS prevalence_pct
FROM latest_outcome lo JOIN patient_food_security pfs USING (patient_id)
WHERE pfs.food_scarcity_status IS NOT NULL AND pfs.food_scarcity_status <> 'Not Reported'
 AND pfs.used_food_assistance IS NOT NULL
GROUP BY pfs.food_scarcity_status,pfs.used_food_assistance
ORDER BY pfs.food_scarcity_status,pfs.used_food_assistance;


/*
QUESTION 9: Does prevalence differ above versus at/below state-average SVI?
- Compare respondents assigned to counties above versus at or below the unweighted average county SVI within their state.
- Why? Explore relative vulnerability within states; county assignments are approximate.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
 , state_svi AS (
 SELECT state_id, AVG(overall_svi_score) AS avg_state_county_svi
 FROM counties WHERE overall_svi_score IS NOT NULL GROUP BY state_id
), classified AS (
 SELECT lo.long_covid_flag,
 CASE WHEN c.overall_svi_score > ss.avg_state_county_svi THEN 'Above State Average'
 ELSE 'At or Below State Average' END AS vulnerability_group
 FROM latest_outcome lo JOIN patients p USING (patient_id)
 JOIN counties c ON c.fips_code=p.fips_code
 JOIN state_svi ss ON ss.state_id=c.state_id
 WHERE c.overall_svi_score IS NOT NULL
)
SELECT vulnerability_group,COUNT(*) AS total_patients,
 COUNT(*) FILTER (WHERE long_covid_flag) AS long_covid_cases,
 ROUND(100.0 * COUNT(*) FILTER (WHERE long_covid_flag)/NULLIF(COUNT(*),0),2) AS prevalence_pct
FROM classified GROUP BY vulnerability_group ORDER BY vulnerability_group;


/*
QUESTION 10: How does prevalence compare between the lowest and highest income groups?
- Use UNION ALL to compare respondents earning under $25,000 with those earning $150,000 or more.
- Why? Quantify the prevalence gap between the two income extremes.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
SELECT 'Low Income (<$25k)' AS cohort_name, COUNT(*) AS patient_count,
 COUNT(*) FILTER (WHERE lo.long_covid_flag) AS long_covid_cases,
 ROUND(100.0 * COUNT(*) FILTER (WHERE lo.long_covid_flag)/NULLIF(COUNT(*),0),2) AS prevalence_pct
FROM latest_outcome lo JOIN patient_economics pe USING (patient_id)
WHERE pe.income_bracket LIKE '%Less than $25,000%'
UNION ALL
SELECT 'High Income ($150k+)', COUNT(*), COUNT(*) FILTER (WHERE lo.long_covid_flag),
 ROUND(100.0 * COUNT(*) FILTER (WHERE lo.long_covid_flag)/NULLIF(COUNT(*),0),2)
FROM latest_outcome lo JOIN patient_economics pe USING (patient_id)
WHERE pe.income_bracket LIKE '%$150,000%';


/*
QUESTION 11: Which states exceed the national respondent Long COVID prevalence?
- Compare each state prevalence (minimum 50 respondents) with the pooled prevalence across all respondents.
- Why? Flag states with above-overall rates rather than confusing large case counts with higher risk.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
 , national_rate AS (
 SELECT AVG(long_covid_flag::int) AS prevalence_fraction FROM latest_outcome
), state_rates AS (
 SELECT s.state_id,s.state_name,COUNT(*) AS sample_size,
 COUNT(*) FILTER (WHERE lo.long_covid_flag) AS long_covid_cases,
 AVG(lo.long_covid_flag::int) AS prevalence_fraction
 FROM latest_outcome lo JOIN patients p USING (patient_id)
 JOIN counties c ON c.fips_code=p.fips_code JOIN states s ON s.state_id=c.state_id
 GROUP BY s.state_id,s.state_name HAVING COUNT(*) >= 50
)
SELECT sr.state_id,sr.state_name,sr.sample_size,sr.long_covid_cases,
 ROUND(100.0*sr.prevalence_fraction,2) AS state_rate_pct,
 ROUND(100.0*nr.prevalence_fraction,2) AS overall_rate_pct
FROM state_rates sr CROSS JOIN national_rate nr
WHERE sr.prevalence_fraction > nr.prevalence_fraction
ORDER BY sr.prevalence_fraction DESC;


/*
QUESTION 12: How does prevalence vary by housing tenure and eviction risk?
- Cross-tabulate reported housing tenure and eviction risk with Long COVID prevalence.
- Why? Investigate whether housing insecurity differs across tenure categories.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
SELECT ph.housing_tenure,ph.eviction_risk_flag,COUNT(*) AS total_patients,
 COUNT(*) FILTER (WHERE lo.long_covid_flag) AS long_covid_cases,
 ROUND(100.0 * COUNT(*) FILTER (WHERE lo.long_covid_flag)/NULLIF(COUNT(*),0),2) AS prevalence_pct
FROM latest_outcome lo JOIN patient_housing ph USING (patient_id)
WHERE ph.housing_tenure IS NOT NULL AND ph.housing_tenure <> 'Unknown'
 AND ph.eviction_risk_flag IS NOT NULL
GROUP BY ph.housing_tenure,ph.eviction_risk_flag ORDER BY prevalence_pct DESC;


/*
QUESTION 13: How does Long COVID prevalence differ by education?
- Calculate respondent counts and prevalence for each reported education level, sorted by prevalence.
- Why? Assess education-related disparities without assuming a monotonic gradient.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
SELECT pe.education_level,COUNT(*) AS patient_count,
 COUNT(*) FILTER (WHERE lo.long_covid_flag) AS long_covid_cases,
 ROUND(100.0 * COUNT(*) FILTER (WHERE lo.long_covid_flag)/NULLIF(COUNT(*),0),2) AS prevalence_pct
FROM latest_outcome lo JOIN patient_economics pe USING (patient_id)
WHERE pe.education_level IS NOT NULL AND pe.education_level NOT IN ('Unknown','Unspecified')
GROUP BY pe.education_level ORDER BY prevalence_pct DESC;

/*
QUESTION 14: How do survey volume and Long COVID proportions vary by phase/date?
- Count survey responses, acute COVID reports, and Long COVID reports by survey phase and collection date; calculate the fraction of acute cases reporting Long COVID.
- Why? Track cross-sectional reporting patterns, not longitudinal conversion or incidence.
*/

SELECT st.survey_phase,st.collection_date,
 COUNT(DISTINCT st.survey_response_id) AS total_surveys_logged,
 COUNT(DISTINCT st.survey_response_id) FILTER (WHERE lcc.had_acute_covid IS TRUE) AS acute_covid_reports,
 COUNT(DISTINCT st.survey_response_id) FILTER (WHERE lcc.long_covid_flag IS TRUE) AS long_covid_reports,
 ROUND(100.0 * COUNT(DISTINCT st.survey_response_id) FILTER (WHERE lcc.had_acute_covid IS TRUE AND lcc.long_covid_flag IS TRUE)
 / NULLIF(COUNT(DISTINCT st.survey_response_id) FILTER (WHERE lcc.had_acute_covid IS TRUE),0),2) AS long_covid_pct_among_acute_reports
FROM surveys_taken st JOIN long_covid_cases lcc ON lcc.survey_response_id=st.survey_response_id
GROUP BY st.survey_phase,st.collection_date ORDER BY st.collection_date,st.survey_phase;


/*
QUESTION 15: Does cumulative socioeconomic vulnerability relate to prevalence?
- Score income under $25k, missed rent, and food scarcity (0–3), then calculate prevalence by score.
- Why? Test whether overlapping hardships correspond to progressively higher Long COVID prevalence.
*/

WITH latest_outcome AS (
    SELECT DISTINCT ON (st.patient_id)
        st.patient_id,
        lcc.long_covid_flag,
        lcc.had_acute_covid,
        lcc.activity_limitation_level,
        lcc.symptom_duration_months
    FROM surveys_taken st
    JOIN long_covid_cases lcc ON lcc.survey_response_id = st.survey_response_id
    WHERE lcc.long_covid_flag IS NOT NULL
    ORDER BY st.patient_id, st.collection_date DESC NULLS LAST, st.survey_response_id DESC
)
 , scored AS (
 SELECT lo.patient_id,lo.long_covid_flag,
 (CASE WHEN pe.income_bracket LIKE '%Less than $25,000%' THEN 1 ELSE 0 END
 + CASE WHEN ph.missed_rent_payment IS TRUE THEN 1 ELSE 0 END
 + CASE WHEN pfs.food_scarcity_status IN ('Sometimes not enough to eat','Often not enough to eat') THEN 1 ELSE 0 END) AS vulnerability_score
 FROM latest_outcome lo
 JOIN patient_economics pe USING (patient_id)
 JOIN patient_housing ph USING (patient_id)
 JOIN patient_food_security pfs USING (patient_id)
 WHERE pe.income_bracket IS NOT NULL AND pe.income_bracket NOT IN ('Unknown / Declined to Answer','Unknown')
 AND ph.missed_rent_payment IS NOT NULL
 AND pfs.food_scarcity_status IS NOT NULL
 AND pfs.food_scarcity_status NOT IN ('Not Reported','Unknown','Unspecified')
)
SELECT vulnerability_score,COUNT(*) AS cohort_size,
 COUNT(*) FILTER (WHERE long_covid_flag) AS long_covid_cases,
 ROUND(100.0 * COUNT(*) FILTER (WHERE long_covid_flag)/NULLIF(COUNT(*),0),2) AS prevalence_pct
FROM scored GROUP BY vulnerability_score ORDER BY vulnerability_score;
