# Social Determinants of Health and Long COVID

### End-to-End Public Health Data Analytics | Python · PostgreSQL · R · Tableau

## Project Overview

Long COVID has affected people across demographic and socioeconomic groups, but the burden of persistent symptoms may not be evenly distributed. This project examines how **social determinants of health (SDoH)**—particularly income, food insecurity, housing instability, and community vulnerability—are associated with reported Long COVID outcomes.

**Research question:** *To what extent do social determinants of health independently predict persistent Long COVID symptoms after accounting for demographic and geographic factors?*

I developed an end-to-end analytical workflow that integrates federal survey and community-level data into a normalized PostgreSQL database, prepares records with Python, examines patterns using SQL, estimates adjusted associations using logistic regression in R, and communicates findings through Tableau.

The analysis is observational: the results describe associations, not causal effects.

## Technologies and Skills

| Technology | Application |
|---|---|
| Python, Pandas, SQLAlchemy | ETL, data cleaning, recoding, and database ingestion |
| PostgreSQL | Eight-table relational schema, constraints, data validation, analytical queries |
| SQL | Joins, CTEs, conditional aggregation, subqueries, window functions, and set operations |
| R, DBI, RPostgres | Database-connected statistical analysis |
| R `glm()`, `broom`, `car` | Logistic regression, adjusted odds ratios, confidence intervals, multicollinearity diagnostics |
| Tableau Desktop | Interactive public-health dashboard and data storytelling |

## Data Sources

**Household Pulse Survey (2023, Wave 61).** The individual-level survey extract contains **68,454 respondents and 247 variables**, including demographic characteristics, financial hardship, food sufficiency, COVID-19 history, persistent symptoms, and activity limitations.

**CDC/ATSDR Social Vulnerability Index (2022).** County-level community vulnerability data span **3,144 counties and 158 variables**, including population, poverty, and composite Social Vulnerability Index (SVI) percentile scores from 0 to 1.

The datasets operate at different geographic levels. Exact county identifiers are suppressed in the public survey data, so the project uses state-constrained county assignments for exploratory linkage. **These assigned counties are not verified respondent residences.** County-based comparisons must therefore be interpreted cautiously.

## Relational Database Architecture

I designed an eight-table PostgreSQL database structured around Third Normal Form principles to separate geographic, demographic, socioeconomic, survey, and health-outcome data.

| Table | Purpose |
|---|---|
| `states` | State identifiers and census regions |
| `counties` | County FIPS codes and SVI metrics |
| `patients` | Respondent identifiers and demographic attributes |
| `patient_economics` | Income, employment, education, and insurance coverage |
| `patient_housing` | Housing tenure, missed rent, and eviction risk |
| `patient_food_security` | Food sufficiency and assistance indicators |
| `surveys_taken` | Survey phase and collection records |
| `long_covid_cases` | COVID-19 history, symptom persistence, duration, and activity limitation |

The schema uses primary and foreign keys, one-to-one socioeconomic extensions, one-to-many survey tracking, check constraints, and cascading deletes to support data integrity.

*Add entity-relationship diagram here.*

## Python ETL and Data Preparation

I built a Python ETL pipeline with Pandas and SQLAlchemy to transform raw files into the relational model. Key operations included standardizing zero-padded five-digit FIPS codes, replacing nonresponse placeholders with SQL NULL values, recoding numeric survey responses into interpretable categories, and loading data in relational dependency order.

The ingestion process populated **51 state records, 3,144 county records, and 68,454 patient records**. Additional PostgreSQL cleaning operations standardized categorical fields, addressed missing or out-of-range SVI scores, and enforced consistency between Long COVID indicators and related outcomes.

## SQL Analysis and General Findings

I used **15 analytical SQL queries** to explore Long COVID prevalence across income, food security, housing circumstances, education, employment, demographic groups, geographic vulnerability, and cumulative SDoH exposure. The analysis uses CTEs, window functions, joins, conditional aggregation, and comparative cohort calculations.

### Income and Economic Vulnerability

A pronounced income gradient appears in the results: Long COVID prevalence was **39.86%** among respondents earning less than $25,000, compared with **19.43%** in the $150,000–$199,999 group and **14.86%** in the highest reported income category. Lower educational attainment also generally corresponded to higher prevalence: **33.58%** for respondents with some high school education versus **19.84%** among those with graduate degrees.

These comparisons are descriptive and do not, by themselves, adjust for differences between groups.

### Food and Housing Insecurity

Respondents reporting both housing and food insecurity had **60.43%** Long COVID prevalence, compared with **22.23%** among respondents classified as secure/stable. Food insecurity alone (**45.89%**) and housing insecurity alone (**44.94%**) were also associated with higher observed prevalence.

The food-sufficiency analysis showed elevated prevalence among respondents reporting insufficient food. Food-assistance records include missing values, so the analysis should not treat a blank assistance field as evidence that assistance was not received.

### Cumulative Socioeconomic Vulnerability

I constructed a composite score using three indicators: income below $25,000, missed rent payments, and food scarcity. Observed prevalence increased with each additional identified vulnerability:

| Number of vulnerabilities | Respondents | Long COVID prevalence |
|---|---:|---:|
| 0 | 26,018 | 24.19% |
| 1 | 3,077 | 39.26% |
| 2 | 796 | 48.99% |
| 3 | 95 | 61.05% |

This stepwise pattern supports the importance of considering overlapping social hardships, while the smallest group contains only 95 respondents and warrants cautious interpretation.

### Geographic and Demographic Patterns

Long COVID prevalence varied by state and demographic subgroup. Among the state-level results, **Mississippi (36.84%)**, **Oklahoma (33.22%)**, and **New Mexico (32.98%)** ranked highest. A separate comparison identified **26.81%** prevalence among respondents assigned to counties with SVI scores above their state's average versus **25.82%** for those at or below it.

Across county SVI quartiles, prevalence ranged narrowly from **25.68% to 27.23%**, without a consistent increase from lower to higher quartiles. Because county assignment is approximate, these geographic results are exploratory rather than evidence of a precise county-level effect.

At the intersection of race/ethnicity and age, Hispanic or Latino respondents ages **40–49** had **40.22%** prevalence in the analyzed subgroup. These descriptive comparisons should not be interpreted as causal explanations for demographic disparities.

### Employment and Health Outcomes

Unemployed respondents had **27.86%** Long COVID prevalence compared with **25.65%** among employed respondents. Recorded average symptom duration was **3.00 months** in both groups, so these results do not establish a difference in duration.

Among respondents with Long COVID, activity-limitation distributions also differed by insurance type. These categories describe reported limitations; they do not establish whether insurance status caused differences in severity.

## Statistical Modeling in R

To move beyond descriptive SQL comparisons, I connected R directly to PostgreSQL using `DBI` and `RPostgres` and estimated **two multivariable logistic regression models** with `glm(family = binomial)`.

**Model 1 — Individual SDoH predictors.** Evaluated income, food insecurity, housing insecurity, and insurance coverage while adjusting for race, age, and education. Reference categories included the highest income group, non-Hispanic White respondents, ages 18–29, and bachelor's degree attainment.

**Model 2 — Cumulative vulnerability.** Evaluated a composite score of 0–3 reflecting low income, missed rent, and food scarcity.

Regression coefficients were exponentiated with `broom::tidy()` to produce adjusted odds ratios (aORs) and 95% confidence intervals.

### Selected Regression Results

| Predictor | Adjusted odds ratio | 95% confidence interval |
|---|---:|---|
| Income below $25,000 | 2.80 | 2.13–3.69 |
| Food insecurity | 1.65 | 1.34–2.01 |
| Housing insecurity | 1.45 | 1.19–1.78 |
| Three concurrent vulnerabilities vs. none | 3.58 | 2.37–5.47 |

Lower income showed the largest adjusted association among the highlighted individual factors. Food insecurity and housing insecurity were also associated with elevated adjusted odds of persistent symptoms. In the cumulative model, adjusted odds increased from **1.74** for one vulnerability to **2.45** for two and **3.58** for all three, relative to none.

Multicollinearity was assessed using the `car` package; reported generalized variance inflation factors were below **1.6**, with adjusted root values below **1.19**.

**Interpretation:** An adjusted odds ratio describes a relative change in *odds*, not a percentage-point increase in prevalence or proof of causation. The R model findings were reproduced when the analysis was rerun.

## Tableau Dashboard

I created an interactive Tableau dashboard connected to PostgreSQL summary views and informed by the R modeling results. Its four components are:

- **KPI overview:** Survey population, reported acute COVID-19 cases, Long COVID cases, and the proportion of acute cases reporting persistent symptoms.
- **Geographic disparities map:** State-level patterns in Long COVID prevalence.
- **Cumulative vulnerability chart:** Prevalence across composite SDoH risk scores, with statistical-model context.
- **Demographic heat matrix and predictor view:** Intersections of age and race/ethnicity, alongside adjusted odds ratios and confidence intervals.

The source analysis reports **68,454 respondents**, **36,945 acute COVID-19 reports**, and **9,302 Long COVID reports**, corresponding to **25.18%** of acute COVID-19 reports. The SQL findings described above should be used when updating any dashboard labels or narrative text.

*Add dashboard screenshot and Tableau link here.*

## Limitations

1. **Geographic precision:** Public survey data do not identify respondents' counties. State-constrained county assignments introduce uncertainty into county-level SVI analyses.
2. **Timing:** The project combines 2022 SVI estimates with 2023 survey data.
3. **Observational design:** Associations cannot establish that economic or social hardship causes persistent symptoms.
4. **Self-reported measures and missingness:** Survey responses may contain reporting error or nonresponse; missing values and differences in available sample sizes affect comparisons.
5. **Model adjustment:** Adjusting for selected demographics does not rule out unmeasured confounding or guarantee geographic representativeness.

## Practical Applications and Future Work

The findings support further investigation into how social needs intersect with post-COVID care. Public health agencies could use validated geographic and socioeconomic indicators to inform outreach and resource allocation. Healthcare teams could consider food insecurity, housing instability, and insurance access as part of broader social-needs screening for patients experiencing persistent symptoms.

Future work could incorporate restricted-use geographic identifiers, additional Household Pulse Survey waves, more explicit survey-weighting and uncertainty analyses, and longitudinal or causal-inference methods to test whether addressing social hardships improves outcomes.

## Conclusion

This project demonstrates a complete analytics workflow: **federal data ingestion → Python ETL → relational PostgreSQL modeling → advanced SQL exploration → multivariable analysis in R → interactive Tableau reporting**.

Across the descriptive and adjusted analyses, economic insecurity and overlapping social hardships were associated with greater reported Long COVID burden. The project combines technical implementation with careful interpretation of data limitations to support evidence-informed public health questions.

## Project Resources

- **SQL analysis:** [Add repository path]
- **Python ETL:** [Add repository path]
- **Database schema / ERD:** [Add repository path]
- **R statistical analysis:** [Add repository path]
- **Tableau dashboard:** [Add link]
