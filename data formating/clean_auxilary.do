* Fama-French data clean
* Author: Sai Zhang (saizhang@london.edu)
* This project is prepared for the project of Prof. Stephen Schaefer

* This script cleans the dataset downloaded from Kenneth French's website for further analysis, the data will be formatted according to the matlab/python codes that run the main analysis.

*===============================================================================
* Import and clean dataset
*===============================================================================
* risk free rate
import delimited "F:\Stephen\french_website\ffRf.csv", encoding(ISO-8859-2) 
rename rf rfFFWebsite
rename date yyyymm
drop smb hml
rename mktrf risk_premium
save french_fama, replace
clear

* size portfolio breakpoints
import delimited "F:\Stephen\french_website\breakpoints_ME.csv", encoding(ISO-8859-2)
drop num
rename date yyyymm
drop p_5 p_15 p_25 p_35 p_45 p_55 p_65 p_75 p_85 p_95
save ME_breakpoints, replace
clear

* Book-to-Market ratio portfolio breakpoints
import delimited "F:\Stephen\french_website\breakpoints_BE-ME.csv", encoding(ISO-8859-2)
drop num_neg num_pos
drop p_5 p_15 p_25 p_35 p_45 p_55 p_65 p_75 p_85 p_95
replace year=year*100+6
rename year yyyymm
save BtM_breakpoints, replace
clear

*===============================================================================
* merge them all together
*===============================================================================
cd F:/Stephen/french_website
use french_fama

* merge with ME_breakpoints
keep if round(yyyymm/100)>=1961
merge 1:1 yyyymm using ME_breakpoints
drop if _merge==2
drop _merge

* rename variables
forvalues i=1/10{
local j=`i'*10
rename p_`j' ME_p`j'
}

* merge with BtM_breakpoints
merge 1:1 yyyymm using BtM_breakpoints, nogen
drop if round(yyyymm/100)<1960
sort yyyymm
forvalues i=1/10{
local j=`i'*10
replace p_`j'=p_`j'[_n-1] if p_`j'==.
rename p_`j' BtM_p`j'
}
keep if round(yyyymm/100)>=1961
save, replace

* ==============================================================================
* 