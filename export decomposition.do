cd "C:\Users\Dell\Downloads"

import excel "C:\Users\Dell\Downloads\TradeData.xlsx", sheet("Sheet1") firstrow clear

keep refYear reporterISO  partnerISO cmdCode fobvalue
tempfile a
save `a'

import excel "C:\Users\Dell\Downloads\TradeData2015.xlsx", sheet("Sheet1") firstrow clear

keep refYear reporterISO  partnerISO cmdCode fobvalue
append using `a'

destring cmdCode, replace
egen destine=group(partnerISO), label
drop partnerISO

preserve
collapse (sum) fobvalue, by(destine refYear) 
reshape wide fobvalue, i(destine) j(refYear)
gen dest=1 if fobvalue2015!=. & fobvalue2023!=. // surviving destination
replace dest=2 if fobvalue2015==. & fobvalue2023!=. // new destination
replace dest=3 if fobvalue2015!=. & fobvalue2023==. // old D
tempfile b
save `b'
restore

preserve
collapse (sum) fobvalue, by (cmdCode refYear) 
reshape wide fobvalue, i(cmdCode) j(refYear)
gen prod=1 if fobvalue2015!=. & fobvalue2023!=. // surviving product
replace prod=2 if fobvalue2015==. & fobvalue2023!=. // new product
replace prod=3 if fobvalue2015!=. & fobvalue2023==. // old P
tempfile c
save `c'
restore

reshape wide fobvalue, i(destine cmdCode) j(refYear)
gen prod_dest=1 if fobvalue2015!=. & fobvalue2023!=. // surviving destination-product
replace prod_dest=2 if fobvalue2015==. & fobvalue2023!=. // new destination-product
replace prod_dest=3 if fobvalue2015!=. & fobvalue2023==. // old D-P

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

collapse (sum) fobvalue2015 fobvalue2023, by(exp_decomp)
gen dif=fobvalue2023-fobvalue2015
egen contr2015_2023=pc(dif), prop
egen total2015=sum(fobvalue2015)
egen total2023=sum(fobvalue2023)
gen growth=total2023/total2015-1
gen growth_contr=growth*contr2015_2023

keep  exp_decomp growth growth_contr
gen x=1
reshape wide growth growth_contr, i(x) j(exp_decomp)

ds growth_contr*
local varlist `r(varlist)'  // Store the variable list

// Generate the graph command with a loop
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


