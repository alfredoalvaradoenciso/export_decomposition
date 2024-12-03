cd "C:\Users\Dell\Downloads"

/*
import excel "C:\Users\Dell\Downloads\TradeData2023.xlsx", sheet("Sheet1") firstrow clear
keep refYear reporterISO  partnerISO cmdCode fobvalue
tempfile a
save `a'
import excel "C:\Users\Dell\Downloads\TradeData2019_2022.xlsx", sheet("Sheet1") firstrow clear
keep refYear reporterISO  partnerISO cmdCode fobvalue
tempfile a1
save `a1'
import excel "C:\Users\Dell\Downloads\TradeData2016_2018.xlsx", sheet("Sheet1") firstrow clear
keep refYear reporterISO  partnerISO cmdCode fobvalue
tempfile a2
save `a2'
import excel "C:\Users\Dell\Downloads\TradeData2011_2014.xlsx", sheet("Sheet1") firstrow clear
keep refYear reporterISO  partnerISO cmdCode fobvalue
tempfile a3
save `a3'
import excel "C:\Users\Dell\Downloads\TradeData2015.xlsx", sheet("Sheet1") firstrow clear
keep refYear reporterISO  partnerISO cmdCode fobvalue
append using `a'
append using `a1'
append using `a2'
append using `a3'
destring cmdCode, replace
egen destine=group(partnerISO), label
drop partnerISO
save tradegtm, replace
*/

use tradegtm, clear
local initialyear=2011
local endyear=2023

keep if refYear==`initialyear' | refYear==`endyear'

preserve
collapse (sum) fobvalue, by(destine refYear) 
reshape wide fobvalue, i(destine) j(refYear)
gen dest=1 if fobvalue`initialyear'!=. & fobvalue`endyear'!=. // surviving destination
replace dest=2 if fobvalue`initialyear'==. & fobvalue`endyear'!=. // new destination
replace dest=3 if fobvalue`initialyear'!=. & fobvalue`endyear'==. // old D
tempfile b
save `b'
restore

preserve
collapse (sum) fobvalue, by (cmdCode refYear) 
reshape wide fobvalue, i(cmdCode) j(refYear)
gen prod=1 if fobvalue`initialyear'!=. & fobvalue`endyear'!=. // surviving product
replace prod=2 if fobvalue`initialyear'==. & fobvalue`endyear'!=. // new product
replace prod=3 if fobvalue`initialyear'!=. & fobvalue`endyear'==. // old P
tempfile c
save `c'
restore

reshape wide fobvalue, i(destine cmdCode) j(refYear)
gen prod_dest=1 if fobvalue`initialyear'!=. & fobvalue`endyear'!=. // surviving destination-product
replace prod_dest=2 if fobvalue`initialyear'==. & fobvalue`endyear'!=. // new destination-product
replace prod_dest=3 if fobvalue`initialyear'!=. & fobvalue`endyear'==. // old D-P

merge m:1 destine using  `b', keepus(dest) nogen
merge m:1 cmdCode using  `c', keepus(prod) nogen


gen exp_decomp=1 if prod_dest==1 // Surviving P-D
replace exp_decomp=2 if prod_dest==2 & dest==1 & prod==1 // New P-D, old space
replace exp_decomp=3 if prod_dest==2 & dest==2 & prod==1 // New D, old P
replace exp_decomp=4 if prod_dest==2 & dest==1 & prod==2 // New P, old D
replace exp_decomp=5 if prod_dest==2 & dest==2 & prod==2 // New P, New D
replace exp_decomp=6 if prod_dest==3  // Dead P-D

lab def exp_decomp 1 "Surviving P-D" 2 "New P-D, old space" 3 "New D, old P" 4 "New P, old D" 5 "New P, New D" 6 "Dead P-D"
lab val exp_decomp exp_decomp 

collapse (sum) fobvalue`initialyear' fobvalue`endyear', by(exp_decomp)
gen dif=fobvalue`endyear'-fobvalue`initialyear'
egen contr`initialyear'_`endyear'=pc(dif), prop
egen total`initialyear'=sum(fobvalue`initialyear')
egen total`endyear'=sum(fobvalue`endyear')		
gen growth=total`endyear'/total`initialyear'-1
gen growth_contr=growth*contr`initialyear'_`endyear'

keep  exp_decomp growth growth_contr
gen x=1

*Converting to panel data format and saving the variable labels

levelsof exp_decomp, local(col_levels)       
	 foreach val of local col_levels {   
      	 local colvl`val' : label exp_decomp `val'    
       }
	  
keep x growth growth_contr exp_decomp
reshape wide growth growth_contr, i(x) j(exp_decomp)
	 foreach value of local col_levels{        
		 label variable growth_contr`value' "`colvl`value''"
	 }
lab var growth1 "Total growth"

ds growth_contr*
local varlist `r(varlist)'  // Store the variable list


local first = 1  // Track whether this is the first variable to handle initial syntax
local graphcmd = ""  // Initialize the graph command as an empty string

foreach var of local varlist {
    if `first' {
        local graphcmd "twoway (bar `var' x)"
        local first = 0
    }
    else {
        local graphcmd "`graphcmd' || (bar `var' x)"
    }
}
`graphcmd' || scatter growth1 x


