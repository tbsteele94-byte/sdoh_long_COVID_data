-- Database Creation

CREATE DATABASE long_covid_sdoh;

-- Table 1: states (Geographic Lookup)
CREATE TABLE states (
	state_id VARCHAR(2) PRIMARY KEY,
	state_name VARCHAR(50) NOT NULL,
	census_region VARCHAR(20)
);

-- Table 2: counties (Geographic Social Determinant of Health Lookup)
CREATE TABLE counties (
	fips_code VARCHAR(5) PRIMARY KEY,
	state_id VARCHAR(2) NOT NULL,
	county_name VARCHAR(100) NOT NULL,
	overall_svi_score DECIMAL(4,3) CHECK (overall_svi_score BETWEEN 0.000 AND 1.000),
	FOREIGN KEY (state_id) REFERENCES states(state_id)
);

-- Table 3: patients (Population Identifier)
CREATE TABLE patients (
	patient_id INT PRIMARY KEY,
	fips_code VARCHAR(5) NOT NULL,
	age_group VARCHAR(20),
	biological_sex VARCHAR (10),
	race_ethnicity VARCHAR(50),
	FOREIGN KEY (fips_code) REFERENCES counties(fips_code)
);

-- Table 4: patient_economics (Social Determinant of Health Identifier and 1:1 Normalization Extension)
CREATE TABLE patient_economics (
	patient_id INT PRIMARY KEY,
	income_bracket VARCHAR(50),
	employment_status VARCHAR(50),
	education_level VARCHAR(50),
	health_insurance_type VARCHAR(50),
	CONSTRAINT fk_patient_economics
		FOREIGN KEY (patient_id)
		REFERENCES patients(patient_id)
		ON DELETE CASCADE
);

-- Table 5: patient_housing (Social Determinant of Health Identifier and 1:1 Normalization Extension)
CREATE TABLE patient_housing (
	patient_id INT PRIMARY KEY,
	housing_tenure VARCHAR(20),
	eviction_risk_flag BOOLEAN,
	missed_rent_payment BOOLEAN,
	CONSTRAINT fk_patient_housing
		FOREIGN KEY (patient_id)
		REFERENCES patients(patient_id)
		ON DELETE CASCADE
);

-- Table 6: patient_food_security (Social Determinant of Health Identifier and 1:1 Normalization Extension)
CREATE TABLE patient_food_security (
	patient_id INT PRIMARY KEY,
	food_scarcity_status VARCHAR(50),
	used_food_assistance BOOLEAN,
	CONSTRAINT fk_patient_food_security
		FOREIGN KEY (patient_id)
		REFERENCES patients(patient_id)
		ON DELETE CASCADE
);

-- Table 7: surveys_taken (Timeframe Identifier and 1:N Mapping)
CREATE TABLE surveys_taken (
	survey_response_id INT PRIMARY KEY,
	patient_id INT NOT NULL,
	survey_phase VARCHAR(10),
	collection_date DATE,
	FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

-- Table 8: long_covid_cases (Health Outcomes)
CREATE TABLE long_covid_cases (
	case_id INT PRIMARY KEY,
	survey_response_id INT NOT NULL,
	had_acute_covid BOOLEAN,
	long_covid_flag BOOLEAN,
	symptom_duration_months INT,
	activity_limitation_level VARCHAR(50),
	CONSTRAINT fk_long_covid_surveys
		FOREIGN KEY (survey_response_id)
		REFERENCES surveys_taken(survey_response_id)
		ON DELETE CASCADE
);