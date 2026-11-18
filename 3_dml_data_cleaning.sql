BEGIN;

-- 1. TABLE: states

-- Trim and make state abbreviations uppercase
UPDATE states
SET state_id = UPPER(TRIM(state_id));

-- Capitalize state names
UPDATE states
SET state_name = INITCAP(TRIM(state_name));

-- Standardize null/missing census region categories
UPDATE states
SET census_region = 'Unassigned'
WHERE census_region IS NULL OR TRIM(census_region) = '';

-- Update regional naming variations
UPDATE states
SET census_region = 'Midwest'
WHERE census_region = 'Mid-West';

-- Delete invalid state entries
DELETE FROM states
WHERE state_id NOT IN ('AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA',
                        'HI','ID','IL','IN','IA','KS','KY','LA','ME','MD',
                        'MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ',
                        'NM','NY','NC','ND','OH','OK','OR','PA','RI','SC',
                        'SD','TN','TX','UT','VT','VA','WA','WV','WI','WY','DC');


-- 2. TABLE: counties

-- Ensures FIPS codes are 5-digit strings
UPDATE counties
SET fips_code = LPAD(TRIM(fips_code), 5, '0');

-- Standardize county names
UPDATE counties
SET county_name = INITCAP(TRIM(county_name));

-- Impute missing SVI scores with the state average
UPDATE counties c
SET overall_svi_score = (
    SELECT ROUND(AVG(overall_svi_score), 3)
    FROM counties
    WHERE state_id = c.state_id AND overall_svi_score IS NOT NULL
)
WHERE c.overall_svi_score IS NULL;

-- Set outlier SVI scores outside valid range [0, 1] to bounds
UPDATE counties
SET overall_svi_score = CASE 
    WHEN overall_svi_score > 1.0 THEN 1.000
    WHEN overall_svi_score < 0.0 THEN 0.000
    ELSE overall_svi_score
END;

-- Remove counties with invalid state foreign keys
DELETE FROM counties
WHERE state_id NOT IN (SELECT state_id FROM states);


 
-- 3. TABLE: patients

-- Standardize demographics for race/ethnicity
UPDATE patients
SET race_ethnicity = 'Unknown / Unspecified'
WHERE race_ethnicity IS NULL OR TRIM(race_ethnicity) = '';

-- Clean biological sex column text
UPDATE patients
SET biological_sex = INITCAP(TRIM(biological_sex));

-- Make non-standard sex categories 'Other/Unknown'
UPDATE patients
SET biological_sex = 'Unknown'
WHERE biological_sex NOT IN ('Male', 'Female');

-- Format age group categories
UPDATE patients
SET age_group = TRIM(age_group);

-- Remove patient records referencing non-existent FIPS codes
DELETE FROM patients
WHERE fips_code NOT IN (SELECT fips_code FROM counties);


-- 4. TABLE: patient_economics

-- Convert blank income brackets to 'Unknown'  
UPDATE patient_economics
SET income_bracket = 'Unknown / Declined to Answer'
WHERE income_bracket IS NULL OR TRIM(income_bracket) = '';

-- Standardize employment status 
UPDATE patient_economics
SET employment_status = INITCAP(TRIM(employment_status));

-- Fill missing health insurance status with default option
UPDATE patient_economics
SET health_insurance_type = 'Unspecified Insurance'
WHERE health_insurance_type IS NULL OR TRIM(health_insurance_type) = '';

-- Standardize education level 
UPDATE patient_economics
SET education_level = 'High School / GED'
WHERE education_level IN ('High School', 'GED', 'HS Diploma');

-- Delete economic records disconnected from primary patient IDs
DELETE FROM patient_economics
WHERE patient_id NOT IN (SELECT patient_id FROM patients);


-- 5. TABLE: patient_housing

-- Clean housing tenure categories
UPDATE patient_housing
SET housing_tenure = INITCAP(TRIM(housing_tenure));

-- Default missing housing tenure to 'Unknown'
UPDATE patient_housing
SET housing_tenure = 'Unknown'
WHERE housing_tenure IS NULL OR TRIM(housing_tenure) = '';

-- Set eviction risk flag to FALSE if null for active homeowners
UPDATE patient_housing
SET eviction_risk_flag = FALSE
WHERE housing_tenure = 'Own' AND eviction_risk_flag IS NULL;

-- Make NULL missed payment indicators  FALSE
UPDATE patient_housing
SET missed_rent_payment = FALSE
WHERE missed_rent_payment IS NULL;

-- Delete orphaned housing records
DELETE FROM patient_housing
WHERE patient_id NOT IN (SELECT patient_id FROM patients);


-- 6. TABLE: patient_food_security

-- Clean food scarcity status 
UPDATE patient_food_security
SET food_scarcity_status = TRIM(food_scarcity_status);

-- Assign default option for missing food security responses
UPDATE patient_food_security
SET food_scarcity_status = 'Not Reported'
WHERE food_scarcity_status IS NULL OR TRIM(food_scarcity_status) = '';

-- Automatically flag food assistance usage for high scarcity responses if null
UPDATE patient_food_security
SET used_food_assistance = TRUE
WHERE food_scarcity_status = 'Often not enough to eat' 
  AND used_food_assistance IS NULL;

-- Set remaining null food assistance to FALSE
UPDATE patient_food_security
SET used_food_assistance = FALSE
WHERE used_food_assistance IS NULL;

-- Clean out records where patient_id has been removed
DELETE FROM patient_food_security
WHERE patient_id NOT IN (SELECT patient_id FROM patients);


-- 7. TABLE: surveys_taken

-- Standardize phase formatting
UPDATE surveys_taken
SET survey_phase = UPPER(TRIM(survey_phase));

-- Correct default collection date if null using defaults
UPDATE surveys_taken
SET collection_date = '2023-01-01'
WHERE collection_date IS NULL;

-- Trim survey phase codes
UPDATE surveys_taken
SET survey_phase = 'PHASE ' || SUBSTRING(survey_phase FROM '[0-9]+')
WHERE survey_phase LIKE 'PHASE%';

-- Delete future-dated survey entries beyond study period
DELETE FROM surveys_taken
WHERE collection_date > CURRENT_DATE;

-- Delete survey records that do not link to existing patients
DELETE FROM surveys_taken
WHERE patient_id NOT IN (SELECT patient_id FROM patients);


-- 8. TABLE: long_covid_cases

-- Make symptom duration 0 if long_covid_flag is FALSE
UPDATE long_covid_cases
SET symptom_duration_months = 0
WHERE long_covid_flag = FALSE AND (symptom_duration_months IS NULL OR symptom_duration_months > 0);

-- Default activity limitation level if long_covid_flag is FALSE
UPDATE long_covid_cases
SET activity_limitation_level = 'None'
WHERE long_covid_flag = FALSE;

-- Clean limitation formatting
UPDATE long_covid_cases
SET activity_limitation_level = INITCAP(TRIM(activity_limitation_level));

-- Assign 'Unspecified' to long COVID cases with missing limitation levels
UPDATE long_covid_cases
SET activity_limitation_level = 'Unspecified'
WHERE long_covid_flag = TRUE 
  AND (activity_limitation_level IS NULL OR TRIM(activity_limitation_level) = '');

-- Remove cases disconnected from parent survey response records
DELETE FROM long_covid_cases
WHERE survey_response_id NOT IN (SELECT survey_response_id FROM surveys_taken);

COMMIT;