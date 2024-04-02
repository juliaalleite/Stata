/*
___________________________________________
                   INDEX
				   --*--
1. DATA CLEANING AND MANAGEMENT
  1.1 PREPARING COUNTY 1 FILE
  1.2 PREPARING COUNTY 2 FILE
  1.3 APPENDING THE 2 COUNTIES DATA
  1.4 PREPARING EXPERIMENT FILE
  1.5 MERGING EXPERIMENT AND DEMOGRAPHIC DATA
  1.6 PREPARING THE EXPERIMENT DATA
2. LINEAR PROBABILITY MODELS
____________________________________________
*/

* Setting the working directory
cd "C:\Users\julia\OneDrive\Julia\Acadêmico\Mestrado\MPA Columbia\3. Cover Letters & Other Documents\Writing & Code Samples\Stata"

*===========================================
* 1. DATA CLEANING AND MANAGEMENT
*===========================================

* 1.1 PREPARING COUNTY 1 FILE
*-------------------------------------------

*Opening and inspecting the data
import delimited "County 1 data.csv", clear
browse
codebook

* Creating an unique ID, concatenating county and student_id
egen unique_id = concat(county student_id)

* Variable female (dummy) is coded as a string, and has "X" as missing observations
replace female = "" if female == "X" // Recoding the missing observations 
destring female, replace // Changing the type to numeric
codebook female // Checking that it worked

* Checking for duplicates
duplicates list unique_id, nolabel sepby(unique_id) // studenta 111541 and 123140 have repeated values
browse unique_id age female race if unique_id == "111541" | unique_id == "123140"
// Student 123140 has only repeated information, I'll drop one.
// Student 111541 has very discrepant information, different rage, gender and age. As it is not
// possible to clarify data collection details, I'll just keep one line, with missing values for
// the variables, not to bias the analysis.
duplicates drop unique_id, force
replace age = . if unique_id == "111541"
replace female = . if unique_id == "111541"
replace race = . if unique_id == "111541"

* saving it as a dta file
save county1.dta, replace


* 1.2 PREPARING COUNTY 2 FILE
*-------------------------------------------

*Opening and inspecting the data
**# Bookmark #1
import delimited "County 2 data.csv", clear
browse
codebook

* County 2 is the only file with a different structure

* Checking for duplicate values
duplicates list student_id variable, nolabel sepby(student_id) //  The Student 6296 has 2 ages
browse value if student_id == 6296 & variable == "age" // The same person is recorded as being both 30 and 31 years old
// without further information, let's assume his age was recorded in 2 different years, and we will keep the most recent age (31)
bysort student_id variable: keep if _n == _N

* Reshaping County 2 data from long to wide format
reshape wide value, i(student_id) j(variable) string
codebook // checking to see it worked

* Renaming variables
rename valueage age
rename valuecounty county
rename valuemale male
rename valuerace race

* Creating an unique ID, concatenating county and student_id
egen unique_id = concat(county student_id)

* Creating a female dummy, to standardie with county 1's data
gen female = 1 - male

* saving it as a dta file
save county2.dta, replace

* 1.3 APPENDING THE 2 COUNTIES DATA
*-------------------------------------------

* Append data from county 1
append using county1.dta
codebook // Checking it worked

* saving the result as a dta file
save demographic_data.dta, replace

* 1.4 PREPARING EXPERIMENT FILE
*-------------------------------------------

*Opening and inspecting the data
import delimited "Experiment data.csv", clear
browse
codebook

* recoding dummies that have only 1 and .
replace norms_condition = 0 if missing(norms_condition)
replace info_condition = 0 if missing(info_condition)
replace control_condition = 0 if missing(control_condition)

* Creating an unique ID
egen unique_id = concat(county student_id)

* Checking for duplicates
duplicates list unique_id, nolabel sepby(unique_id)

* saving it as a dta file
save experiment.dta, replace

* 1.5 MERGING EXPERIMENT AND DEMOGRAPHIC DATA
*-------------------------------------------
* Merging the data (full join)
merge 1:1 unique_id using demographic_data.dta
browse
codebook

* 1.6 PREPARING THE EXPERIMENT DATA
*-------------------------------------------

* Dropping observations with only demographic information, not experiment info (to get the equivalent of a left join)
drop if _merge == 2

* Dropping unnecesary variables
drop student_id male _merge

* Creating a dummy variable for applied, with 1 when the person applied and zero otherwise
generate applied_dummy = cond(applied == 1, 1, 0)
tab applied applied_dummy // confirming it worked

* To analyze the efficacy of the separate treatments vs. control
* Creating a variable that indicates whether the observation is in the control,
* treatment norms or treatment information groups
generate groups = cond(control_condition, 1, cond(info_condition, 2, 3))

* testing to see if it worked
tab groups control_condition
tab groups info_condition
tab groups norms_condition

* creating and assigning a lable to the new variable
label define groups_label 1 "control" 2 "info" 3 "norms"
label values groups groups_label
codebook groups

* To analyze the efficacy of the norms treatments vs. the information treatment
* Creating a dummy variable with value 1 if the observation was in the norms condition,
* and 0 otherwise, with the control variable coded as missing
generate norms_over_info = cond(norms_condition, 1, cond(info_condition, 0, .))

* testing to see if it worked
tab norms_over_info control_condition
tab norms_over_info info_condition
tab norms_over_info norms_condition

* creating and assigning a lable to the new variable
label define NoI_label 1 "norms" 0 "info"
label values norms_over_info NoI_label
codebook norms_over_info

* saving it as a dta file
save experiment_complete.dta, replace


*===========================================
* 2. LINEAR PROBABILITY MODELS
*===========================================

* Model 1: Basic OLS model with group dummies (compares both treatments with control)
regress applied i.groups, vce(robust)
outreg2 using summary_table.doc, replace //Creating a regression Table

* Model 2: Adding demographic controls to model 1
regress applied i.groups female age i.race, vce(robust)
outreg2 using summary_table.doc, append //Add the new model to the regression Table

* Model 3: Treatment effect of norms over information (compares the norms treatment with the information treatment)
regress applied norms_over_info, vce(robust)
outreg2 using summary_table.doc, append //Add the new model to the regression Table

* Model 4: Adding demographic controls to model 3
regress applied norms_over_info female age i.race, vce(robust)
outreg2 using summary_table.doc, append //Add the new model to the regression Table
