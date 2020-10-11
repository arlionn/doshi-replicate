* Format merged dataset
* Author: Sai Zhang (saizhang@london.edu)
* This project is prepared for the project of Prof. Stephen Schaefer

* This script cleans the data set for further analysis, the data will be formatted according to the matlab/python codes that run the main analysis.

*===============================================================================
* Clean variables: direct analysis
*===============================================================================

* load dataset
clear
cd "F:/Stephen"
use full_data 
* merge the share adjustment factor
merge m:1 gvkey compustat_dt using "F:/Stephen/auxilary data/share_adjust.dta"
drop if _merge==2
drop _merge

* drop unused variables of interest
drop cshiq dd1q crsp_dt vol lltq ibq npq pstkrq teqq txdbq txdiq txditcq costat dvpq fyearq fqtr

* date variables
gen yyyymm = 100*year(datadate)+month(datadate)

gen DecDate = 100*(year(datadate)-1)+12 if month(datadate)<=12 & month(datadate)>=7
replace DecDate = 100*(year(datadate)-2)+12 if month(datadate)<=6 & month(datadate)>=1

gen Fq4Date = string(year(datadate)-1)+"Q4" if month(datadate)<=12 & month(datadate)>=7
replace Fq4Date = string(year(datadate)-2)+"Q4" if month(datadate)<=6 & month(datadate)>=1

gen JunDate = 100*(year(datadate)-1)+6 if month(datadate)<=12 & month(datadate)>=7
replace JunDate = 100*(year(datadate)-2)+6 if month(datadate)<=6 & month(datadate)>=1

* rename and label variables
rename ret RET_wD
label variable RET_wD "monthly return with dividend"
rename retx RET
label variable RET "monthly return (price)"
rename atq at
label variable at "book assets"
rename prc PRC
replace PRC = abs(PRC) if PRC<0

* CRSP use the negative of average of bid and ask price to impute missing close prices. 
label variable PRC "end-of-month price"
rename ltq ltq_f
label variable ltq_f "book liabilities"

label define compustat_code 11 "NYSE" 12 "AMEX" 13 "OTC" 14 "NASDAQ" 19 "Other OTC"
label values exchg compustat_code

* impute missing values ========================================================
* missing returns
sort cusip datadate
by cusip: replace RET=RET_wD if RET==. & _n==1
by cusip: replace RET=(PRC-PRC[_n-1])/PRC[_n-1] if RET==.c

* missing compustat items: replace missings with most recent data
merge m:1 gvkey compustat_dt using "F:/Stephen/auxilary data/liabilities.dta"
drop if _merge==2
drop _merge
replace at= at_m if at==.
replace lseq=at if lseq==.
replace ltq_f=ltq_m if ltq_f==.
drop at_m ltq_m
* only updated 12 more asset values and 9 more liability values

sort cusip datadate
foreach var in at ceqq cshoq dlcq dlttq lseq ltq_f pstkq{
by cusip: replace `var' = `var'[_n-1] if `var'==.
}

replace ltq_f = lseq-ceqq if ltq_f==.
replace ceqq = lseq-ltq_f if ceqq==.

* drop 66 0-common-share obs
replace cshoq =. if cshoq==0

* generate variables of interest ===============================================
gen BE = ceqq-pstkq
replace BE = ceqq if BE==.
label variable BE "book equity"

sort cusip datadate
by cusip: gen ME = cshoq*ajexq*PRC[_n-1]
label variable ME "market equity"

*---------------------------------------- form here, stored as data_analysis.dta
* transform CAD to USD
gen comp_ym = year(compustat_dt)*100 + month(compustat_dt)
merge m:1 comp_ym curcdq using "F:/Stephen/auxilary data/cad_usd.dta"
drop if _merge==2
drop _merge comp_ym
label variable cad_usd "CAD per USD"

foreach var in at ceqq dlcq dlttq lseq ltq_f pstkq BE{
replace `var' = `var'*cad_usd if curcdq=="CAD"
}

drop cad_usd curcdq

* reassign the at/BE/ME data in Fama-French fashion ============================
* generate atdec BEdec medec
preserve
tempfile data_dec
keep at BE ME gvkey compustat_dt
duplicates drop gvkey compustat_dt, force
rename at atdec
rename BE BEdec
rename ME MEdec
gen DecDate = 100*year(compustat_dt)+month(compustat_dt)
drop compustat_dt
save `data_dec', replace
restore

merge m:1 gvkey DecDate using `data_dec'
drop if _merge==2
drop _merge

* generate atFq4 BEFq4 meFq4
preserve
tempfile data_fq4
keep at BE ME gvkey datafqtr
duplicates drop gvkey datafqtr, force
rename at atfq4
rename BE BEfq4
rename ME MEfq4
rename datafqtr Fq4Date
save `data_fq4', replace
restore

merge m:1 gvkey Fq4Date using `data_fq4'
drop if _merge==2
drop _merge

sort cusip datadate
by cusip: gen MElag = ME[_n-1]

/*
Variables:
'PERMNO': Perm number from CRSP
'yyyymm': Four digit year(yyyy) + two digit month format of date (mm)
'RET': Stock return
'BE': Book equity, from fiscal year end in the previous calendar year (t-1). Held constant from July of year t to June of t+1 year 
'at': Book assets, same as BE for prepartion
'PRC': Price from Crsp, use absolute when computing market equity
'ltq_f': Total Liabilities, held constant over a quarter
'exchg': Exchange id from Compustat to decide whether the firm is listed on NYSE or not 
'Equity: Market equity

'DECILE': Size decile portfolio already computed
'rfFFWebsite': risk-free rate from Kenneth French's Website

'me': Market equity
'meLag': Lagged market equity, one lag needed to compute value-weighting
'mejun': Market equity in the June and held as it is from July to June of the following year 
'medec': Market equity in December, held as it is from July to June, for example 199212 market equity is held same from 199307 to 199406

'DecDate': December date that needs to be used to assign medec and others such as BE and AT
'RetExcess': Excess Stock Return, RET - rfFFWebsite
'Lev': Leverage measured as ltq_f/(ltq_f + me)
'LevLag': Lagged Leverage, one lag neeeded to compute the adjusted returns
*/

*===============================================================================
* Clean variables: used for Merton estimation
*===============================================================================
/*
'AssetValue': The unlevered equity value obtained from the Merton model, baseline specification of Table 4
'AssetValueLag': Lagged unlevered equity value, one lag
'AssetVolatility': The unlevered equity volatility obtained from the Merton model, baseline specification of Table 4 
'dlcq': debt in current liabilities used to compute total debt, which is used as face value of debt in one of the specification of Merton model 
'dlttq': Long term debt used to compute total debt, which is used as face value of debt in one of the specification of Merton model
'Debt': Total Liabilities, same as d.ltq_f

Not know yet -------------------------------------------------------------------
'EquityVolatility': Annualized stock volatility 
'rf338': risk-free rate (annualized) for debt maturity 3.38 years used only in the estimation of merton model, need to change for other assumptions of debt maturity
*/

clear
cd "F:/Stephen"