gl root "\\data4\users10\aalvarado\My Documents\GTM\export_decomposition"
cd "$root"

capture program drop growth_contribution 
program growth_contribution 
args initialyear endyear varinit varend
tempvar dif c t_init t_end growth
gen `dif'=`varend'-`varinit'
egen `c'=pc(`dif'), prop
egen `t_init'=sum(`varinit')
egen `t_end'=sum(`varend')		
gen grow_`varinit'_`varend'=(`t_end'/`t_init'-1)*100
gen contr_`varinit'_`varend'=grow_`varinit'_`varend'*`c'
end

local initialyear=2002
local endyear=2022
local country="GTM"

use  "$root\bases\\`country'_`initialyear'_`endyear'", clear

*Destination
preserve
collapse (sum) rvalue, by(destine year) 
reshape wide rvalue, i(destine) j(year)
gen dest=1 if rvalue`initialyear'!=. & rvalue`endyear'!=. // surviving destination
replace dest=2 if rvalue`initialyear'==. & rvalue`endyear'!=. // new destination
replace dest=3 if rvalue`initialyear'!=. & rvalue`endyear'==. // old D
tempfile b
save `b'
restore

*Product
preserve
collapse (sum) rvalue, by (code year) 
reshape wide rvalue, i(code) j(year)
gen prod=1 if rvalue`initialyear'!=. & rvalue`endyear'!=. // surviving product
replace prod=2 if rvalue`initialyear'==. & rvalue`endyear'!=. // new product
replace prod=3 if rvalue`initialyear'!=. & rvalue`endyear'==. // old P
tempfile c
save `c'
restore

** Product-destination
keep rvalue destine code code6 year
reshape wide rvalue, i(destine code code6) j(year)
gen prod_dest=1 if rvalue`initialyear'!=. & rvalue`endyear'!=. // surviving destination-product
replace prod_dest=2 if rvalue`initialyear'==. & rvalue`endyear'!=. // new destination-product
replace prod_dest=3 if rvalue`initialyear'!=. & rvalue`endyear'==. // old D-P

merge m:1 destine using  `b', keepus(dest) nogen
merge m:1 code using  `c', keepus(prod) nogen

gen exp_decomp=1 if prod_dest==1 // Surviving P-D
replace exp_decomp=2 if prod_dest==2 & dest==1 & prod==1 // New P-D, old space
replace exp_decomp=3 if prod_dest==2 & dest==2 & prod==1 // New D, old P
replace exp_decomp=4 if prod_dest==2 & dest==1 & prod==2 // New P, old D
replace exp_decomp=5 if prod_dest==2 & dest==2 & prod==2 // New P, New D
replace exp_decomp=6 if prod_dest==3  // Dead P-D

lab def exp_decomp 1 "Surviving P-D" 2 "New P-D, old space" 3 "New D, old P" 4 "New P, old D" 5 "New P, New D" 6 "Dead P-D"
lab val exp_decomp exp_decomp 


collapse (sum) rvalue`initialyear' rvalue`endyear', by(code code6 exp_decomp)
merge m:1 code6 using  "$root\bases\prody`initialyear'", keepus(prod) nogen keep(master match)
rename prody prody`initialyear'
merge m:1 code6 using  "$root\bases\prody`endyear'", keepus(prod) nogen keep(master match)
rename prody prody`endyear'

** EXPY for each of the six decomposition categories
egen sum_`initialyear'_t=sum(rvalue`initialyear'*!mi(prody`initialyear')) // Total start value 
egen sum_`endyear'_t=sum(rvalue`endyear'*!mi(prody`endyear')) // Total end value 
bys exp_decomp: egen sum_`initialyear'=sum(rvalue`initialyear'*!mi(prody`initialyear')) // Total start value per each category
bys exp_decomp: egen sum_`endyear'=sum(rvalue`endyear'*!mi(prody`endyear')) // Total end value per each of the six decomposition categories
gen expyshare`initialyear'=rvalue`initialyear'*prody`initialyear' 
gen expyshare`endyear'=rvalue`endyear'*prody`endyear'
gen expyshare`endyear'_i=rvalue`endyear'*prody`initialyear'
gen expy`initialyear'=expyshare`initialyear'/sum_`initialyear' // EXPY starting year with initial PRODY values
gen expy`endyear'=expyshare`endyear'/sum_`endyear' // EXPY ending year with ending PRODY values
gen expy`endyear'_i=expyshare`endyear'_i/sum_`endyear' // EXPY ending year with initial PRODY values
gen expy`initialyear'_t=expyshare`initialyear'/sum_`initialyear'_t // Total EXPY starting year with initial PRODY values
gen expy`endyear'_t=expyshare`endyear'/sum_`endyear'_t // Total EXPY ending year with ending PRODY values
gen expy`endyear'_i_t=expyshare`endyear'_i/sum_`endyear'_t // Total EXPY ending year with initial PRODY values


preserve
collapse (sum) expy`initialyear'_t expy`endyear'_i_t expy`endyear'_t // Total EXPY starting year, ending year and ending year with initial PRODY
gen x=1
tempfile t
save `t'
restore


collapse (sum) rvalue`initialyear' rvalue`endyear' expy`initialyear' expy`endyear'_i expy`endyear', by(exp_decomp)

growth_contribution `initialyear' `endyear'  rvalue`initialyear' rvalue`endyear'
gen x=1
merge m:1 x using `t', nogen
drop x

** EXPY growth decomposition
gen death=expy`initialyear'[1]-expy`initialyear'_t // Death = Surviving EXPY in starting year - Total EXPY in starting year 
gen rebalancing=expy`endyear'_i[1]-expy`initialyear'[1] // Rebalancing = Surviving EXPY in ending year (w/ init prody) - Surviving EXPY in starting year 
egen value`endyear'_=pc(rvalue`endyear'), prop
gen expy_`endyear'_=value`endyear'_*expy`endyear'_i
egen surv_newmark_=sum(value`endyear'_) if exp_decomp<4 // New markets = (Surviving P-D + New P-D, old space + New D, old P) - Surviving P-D (all w/ init prody) 
egen surv_newmark=sum(expy_`endyear'_) if exp_decomp<4
replace surv_newmark=surv_newmark/surv_newmark_
gen newmarkets=surv_newmark-expy`endyear'_i[1]
gen newproducts=expy`endyear'_i_t[1]-newmarkets-expy`endyear'_i[1] // New products = Total EXPY in ending year - new markets - surviving 
gen grebalancing=expy`endyear'[1]-expy`endyear'_i_t[1] // Global rebalancing = Surviving EXPY in ending year (w/ ending prody) - Total EXPY in ending year (w/ init prody)
gen gexpy_`endyear'_=value`endyear'_*expy`endyear' // Global New markets = (Surviving P-D + New P-D, old space + New D, old P) - Surviving P-D (all w/ ending prody)
egen gsurv_newmark=sum(gexpy_`endyear'_) if exp_decomp<4
replace gsurv_newmark=gsurv_newmark/surv_newmark_
gen gnewmarkets=gsurv_newmark-expy`endyear'[1]
gen gnewproducts=expy`endyear'_t-gnewmarkets-expy`endyear'[1] // Global New products

keep exp_decomp rvalue`initialyear' rvalue`endyear' expy`initialyear' expy`endyear'_i expy`endyear' grow_rvalue`initialyear'_rvalue`endyear' contr_rvalue`initialyear'_rvalue`endyear' expy`initialyear'_t expy`endyear'_i_t expy`endyear'_t death rebalancing newmarkets newproducts grebalancing gnewmarkets gnewproducts

*/

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
clonevar grow_contr_neg_value=grow_contr_pos_value if grow_contr_pos_value <0 
replace grow_contr_neg_value=. if grow_contr_neg_value ==.
replace grow_contr_pos_value=. if grow_contr_pos_value <0 


reshape wide growth grow_contr_pos_value grow_contr_neg_value, i(periods) j(exp_decomp)
	 foreach value of local col_levels{        
		 label variable grow_contr_pos_value`value' "`colvl`value''"
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
	capture	 label variable grow_contr_pos_value`value'_sum "`colvl`value''"
	capture	 label variable grow_contr_neg_value`value'_sum "`colvl`value''"
	 }


twoway bar `list_pos_graph' `list_neg_graph' periods if periods==1 || scatter totalgrowth periods if periods==1  
di "`list_pos_graph' `list_neg_graph'"
