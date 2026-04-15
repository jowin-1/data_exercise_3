/*
Joseph Winters
Data Exercise #3
Econ 388 - Dr. Eastmond
*/

cd "C:\Users\jowin\Box\388\Exercise3"

cap log close
log using data_exercise_3.log, replace

** DATA CLEANING **

use pwt1001, clear

// used AI to automate the following code based on my findings of mismatches

replace country = "Bolivia"                     if country == "Bolivia (Plurinational State of)"
replace country = "Bosnia-Herzegovina"          if country == "Bosnia and Herzegovina"
replace country = "Ivory Coast"                 if country == "Côte d'Ivoire"
replace country = "Iran"                        if country == "Iran (Islamic Republic of)"
replace country = "Laos"                        if country == "Lao People's DR"
replace country = "Macedonia"                   if country == "North Macedonia"
replace country = "Moldova"                     if country == "Republic of Moldova"
replace country = "Burma"                       if country == "Myanmar"
replace country = "Russia"                      if country == "Russian Federation"
replace country = "Slovak Republic"             if country == "Slovakia"
replace country = "South Korea"                 if country == "Republic of Korea"
replace country = "Syria"                       if country == "Syrian Arab Republic"
replace country = "Tanzania"                    if country == "U.R. of Tanzania: Mainland"
replace country = "Venezuela"                   if country == "Venezuela (Bolivarian Republic of)"
replace country = "Vietnam"                     if country == "Viet Nam"
replace country = "Hong Kong"                   if country == "China, Hong Kong SAR"
replace country = "Democratic Republic of the Congo" if country == "D.R. of the Congo"
replace country = "Republic of the Congo"            if country == "Congo"

save pwt1001_updated, replace

use chat, clear


* Renaming country variable to prepare for merge *
rename country_name country 

// there were a couple countries I fixed in this dataset as well:

replace country = "Venezuela" if country == "Venezuala"
replace country = "Yemen" if country == "South Yemen"


** had to collapse because I combined Yemen and South Yemen:

collapse (mean) ag_tractor ag_harvester ag_milkingmachine ///
               irrigatedarea fert_total pest_total, by(country year)
save chat_collapsed, replace


use pwt1001_updated, clear

*merging the datasets*
merge 1:1 country year using chat_collapsed
keep if _m == 3
drop _m

* Limiting the sample to only 1970 to 2000 *
drop if year < 1970 | year > 2000

* Making GDP per capita variable *

/* Originally, I made a gdp per capita variable that divided gdp by population.
However, this made my output wrong later because I had missingness in population.
So, here I set gdppercapita = rgdpe, because the growth rate will remain unchanged
in either situation, but it will be incorrect if I divide by population because of 
missingness. */

gen gdppercapita = rgdpe

*reshaping the data to wide* 
keep rgdpe pop country year ag_tractor ag_harvester ///
	irrigatedarea fert_total pest_total gdppercapita ///
	emp avh 
	
greshape wide rgdpe pop emp avh gdppercapita ag_tractor ag_harvester ///
	irrigatedarea fert_total pest_total , i(country) j(year)
	

*Growth rate formula for GDP and technologies*
forvalues i=1970/1999 {
	local j = `i' + 1
	gen gdppc_growth`i' = ((gdppercapita`j' / gdppercapita`i') - 1) * 100
	gen tractor_growth`i' = ((ag_tractor`j' / ag_tractor`i') - 1) * 100
	gen harvester_growth`i' = ((ag_harvester`j' / ag_harvester`i') - 1) * 100
	gen irr_growth`i' = ((irrigatedarea`j' / irrigatedarea`i') - 1) * 100
	gen fert_growth`i' = ((fert_total`j' / fert_total`i') - 1) * 100
	gen pest_growth`i' = ((pest_total`j' / pest_total`i') - 1) * 100
}


* Reshaping back to long *
greshape long emp avh gdppc_growth tractor_growth harvester_growth irr_growth ///
	rgdpe pop gdppercapita ag_tractor ag_harvester irrigatedarea fert_total pest_total ///
	fert_growth pest_growth, i(country) j(year)
	
** Converting pop variable into integer so I can collapse by frequency:
replace pop = round(pop * 1000000)

save master_dataset, replace 

* Sorting developed and non-developed nations
gen developed = 0
replace developed = 1 if ///
	country == "France" | ///
	country == "Germany" | ///
	country == "Italy" | ///
	country == "United Kingdom" | ///
	country == "United States"
	
** Collapse by developed, weighted for population **
collapse (mean) gdppc_growth tractor_growth harvester_growth irr_growth ///
	fert_growth pest_growth [fweight = pop] , by(developed)

* summary statistics:
bysort developed: summarize
		
/* We observe that non-developed countries have higher gdp per capita growth rates
and higher growth rates for all technologies included in my analysis. */

************************
*** regression ***
************************

use master_dataset, clear	

* We want to determine the impact of agricultural tech growth rate on gdp per cap growth *
* Controls: population, emp - employed people, year (time trends)
reg gdppc_growth tractor_growth harvester_growth irr_growth fert_growth pest_growth ///
	pop emp year // <- controls 

/* We observe only one statistically significant independent variable: the 
harvester growth rate, with a p-value of 0.027. With an R-squared of 0.0321 and 
only 497 observations without missingness in our regression, we are suspiscious of
any inference and are likely not observing the true causal effecct. */

log close 



