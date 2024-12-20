gl root "\\data4\users10\aalvarado\My Documents\GTM\export_decomposition"
cd "$root"


local initialyear=2012
local endyear=2022
/*
import delimited "C:\Users\aalvarado\Downloads\BACI_HS96_V202401b\country_codes_V202401b.csv",  clear
keep country_code country_iso3
rename country_code i
keep if country_iso3=="GTM"
tempfile iso
save `iso'

import delimited "C:\Users\aalvarado\Downloads\BACI_HS96_V202401b\BACI_HS96_Y`initialyear'_V202401b.csv", clear 
drop q
merge m:1 i using `iso', keep(match) nogen
tempfile init
save `init'
import delimited "C:\Users\aalvarado\Downloads\BACI_HS96_V202401b\BACI_HS96_Y`endyear'_V202401b.csv", clear 
merge m:1 i using `iso', keep(match) nogen
drop q
append using `init'
rename (t i j v) (year origin destine value)
save "$root\bases\tradegtm1222", replace
*/

use "$root\bases\tradegtm1222", clear
replace value=value/1000

* Alex cleaning
	gen code6=string(k, "%06.0f")
	replace k=854230 if k==854213
	replace code6="854230" if code6=="854213"


*Destination
preserve
collapse (sum) value, by(destine year) 
reshape wide value, i(destine) j(year)
gen dest=1 if value`initialyear'!=. & value`endyear'!=. // surviving destination
replace dest=2 if value`initialyear'==. & value`endyear'!=. // new destination
replace dest=3 if value`initialyear'!=. & value`endyear'==. // old D
tempfile b
save `b'
restore

*Product
preserve
collapse (sum) value, by (k year) 
reshape wide value, i(k) j(year)
gen prod=1 if value`initialyear'!=. & value`endyear'!=. // surviving product
replace prod=2 if value`initialyear'==. & value`endyear'!=. // new product
replace prod=3 if value`initialyear'!=. & value`endyear'==. // old P
tempfile c
save `c'
restore

** Product-destination
reshape wide value, i(destine k) j(year)
gen prod_dest=1 if value`initialyear'!=. & value`endyear'!=. // surviving destination-product
replace prod_dest=2 if value`initialyear'==. & value`endyear'!=. // new destination-product
replace prod_dest=3 if value`initialyear'!=. & value`endyear'==. // old D-P

merge m:1 destine using  `b', keepus(dest) nogen
merge m:1 k using  `c', keepus(prod) nogen

gen exp_decomp=1 if prod_dest==1 // Surviving P-D
replace exp_decomp=2 if prod_dest==2 & dest==1 & prod==1 // New P-D, old space
replace exp_decomp=3 if prod_dest==2 & dest==2 & prod==1 // New D, old P
replace exp_decomp=4 if prod_dest==2 & dest==1 & prod==2 // New P, old D
replace exp_decomp=5 if prod_dest==2 & dest==2 & prod==2 // New P, New D
replace exp_decomp=6 if prod_dest==3  // Dead P-D

lab def exp_decomp 1 "Surviving P-D" 2 "New P-D, old space" 3 "New D, old P" 4 "New P, old D" 5 "New P, New D" 6 "Dead P-D"
lab val exp_decomp exp_decomp 


collapse (sum) value`initialyear' value`endyear', by(k exp_decomp)
merge m:1 k using  "$root\bases\prody`initialyear'", keepus(prod) nogen keep(master match)
rename prody prody`initialyear'
merge m:1 k using  "$root\bases\prody`endyear'", keepus(prod) nogen keep(master match)
rename prody prody`endyear'

** EXPY analysis
egen sum_`initialyear'_t=sum(value`initialyear'*!mi(prody`initialyear')) // Total start value 
egen sum_`endyear'_t=sum(value`endyear'*!mi(prody`endyear')) // Total end value 
bys exp_decomp: egen sum_`initialyear'=sum(value`initialyear'*!mi(prody`initialyear')) // Total start value per each of the six decomposition categories
bys exp_decomp: egen sum_`endyear'=sum(value`endyear'*!mi(prody`endyear')) // Total end value per each of the six decomposition categories
gen expyshare`initialyear'=value`initialyear'*prody`initialyear' 
gen expyshare`endyear'=value`endyear'*prody`endyear'
gen expyshare`endyear'_i=value`endyear'*prody`initialyear'
gen expy`initialyear'=expyshare`initialyear'/sum_`initialyear' // EXPY starting year with initial PRODY values
gen expy`endyear'=expyshare`endyear'/sum_`endyear' // EXPY ending year with ending PRODY values
gen expy`endyear'_i=expyshare`endyear'_i/sum_`endyear' // EXPY ending year with initial PRODY values
gen expy`initialyear'_t=expyshare`initialyear'/sum_`initialyear'_t // Total EXPY starting year with initial PRODY values
gen expy`endyear'_t=expyshare`endyear'/sum_`endyear'_t // Total EXPY ending year with ending PRODY values
gen expy`endyear'_i_t=expyshare`endyear'_i/sum_`endyear'_t // Total EXPY ending year with initial PRODY values


preserve
collapse (sum) value`initialyear' value`endyear'  expy`initialyear'=expy`initialyear'_t expy`endyear'_i=expy`endyear'_i_t expy`endyear'=expy`endyear'_t // Total EXPY starting year, ending year and ending year with initial PRODY
gen exp_decomp=7
tempfile t
save `t'
restore


collapse (sum) value`initialyear' value`endyear' expy`initialyear' expy`endyear'_i expy`endyear', by(exp_decomp)
append using `t'
gen dif=value`endyear'-value`initialyear'
egen contr`initialyear'_`endyear'=pc(dif), prop
egen total`initialyear'=sum(value`initialyear')
egen total`endyear'=sum(value`endyear')		
gen growth=(total`endyear'/total`initialyear'-1)*100
gen growth_contr_pos=growth*contr`initialyear'_`endyear'

gen dif_e=expy`endyear'-expy`initialyear'
egen contr`initialyear'_`endyear'_e=pc(dif_e), prop
egen total`initialyear'_e=sum(expy`initialyear')
egen total`endyear'_e=sum(expy`endyear')		
gen growth_e=(total`endyear'_e/total`initialyear'_e-1)*100
gen growth_contr_pos_e=growth_e*contr`initialyear'_`endyear'_e

keep  exp_decomp growth* growth_contr*


/*

collapse (sum) value`initialyear' value`endyear', by(exp_decomp)
gen dif=value`endyear'-value`initialyear'
egen contr`initialyear'_`endyear'=pc(dif), prop
egen total`initialyear'=sum(value`initialyear')
egen total`endyear'=sum(value`endyear')		
gen growth=(total`endyear'/total`initialyear'-1)*100
gen growth_contr_pos=growth*contr`initialyear'_`endyear'

keep  exp_decomp growth growth_contr
gen periods=1

*Converting to panel data format and saving the variable labels

levelsof exp_decomp, local(col_levels)       
	 foreach val of local col_levels {   
      	 local colvl`val' : label exp_decomp `val'    
       }
	  
keep periods growth growth_contr exp_decomp
clonevar growth_contr_neg=growth_contr_pos if growth_contr_pos <0 
replace growth_contr_neg=. if growth_contr_neg ==.
replace growth_contr_pos=. if growth_contr_pos <0 


reshape wide growth growth_contr_pos growth_contr_neg, i(periods) j(exp_decomp)
	 foreach value of local col_levels{        
		 label variable growth_contr_pos`value' "`colvl`value''"
	 }
	 
	 
rename growth1 totalgrowth
lab var totalgrowth "Total growth"
drop growth?

** make the graph bar stack and scatter total growth

foreach prefix in pos neg {
    gen list_`prefix'_stack =0
	local list_`prefix'_graph ""
    ds growth_contr_`prefix'*
    local varlist `r(varlist)'
    foreach var of local varlist {
		if `var'!=. {
        replace list_`prefix'_stack  = list_`prefix'_stack  + `var'
        gen `var'_sum = list_`prefix'_stack
		local list_`prefix'_graph "`var'_sum `list_`prefix'_graph'"
		}
    }
}

** recover the labels

	 foreach value of local col_levels{
	capture	 label variable growth_contr_pos`value'_sum "`colvl`value''"
	capture	 label variable growth_contr_neg`value'_sum "`colvl`value''"
	 }


twoway bar `list_pos_graph' `list_neg_graph' periods if periods==1 || scatter totalgrowth periods if periods==1  
di "`list_pos_graph' `list_neg_graph'"