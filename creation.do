gl root "\\data4\users10\aalvarado\My Documents\GTM\export_decomposition"
cd "$root"


/* US CPI
import excel "$root/bases/us_cpi",  clear cellrange(A2) firstrow
drop PCPIA
rename (Series_code ) (year )
save "$root/bases/us_cpi", replace	
*/

/* Corresponde between country code number and country iso code
import delimited "C:\Users\aalvarado\Downloads\BACI_HS96_V202401b\country_codes_V202401b.csv",  clear
keep country_code country_iso3
rename (country_iso3 country_code) (partner destine)
save "$root/bases/partner", replace	

*/


local initialyear=2002
local endyear=2022
local country="GTM"
local countries="GTM CRI HND SLV DOM PAN NIC"

foreach country of local countries {

import delimited "C:\Users\aalvarado\Downloads\BACI_HS96_V202401b\country_codes_V202401b.csv",  clear
keep country_code country_iso3
rename country_code i
keep if country_iso3=="`country'"
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


* Alex cleaning
	gen code6=string(k, "%06.0f")
	replace k=854230 if k==854213
	replace code6="854230" if code6=="854213"

* Adapting

rename (k ) (code )
merge m:1 destine using  "$root/bases/partner", nogen keep(master match)	
gen desc=""

** us deflating 
merge m:1 year using  "$root/bases/us_cpi", nogen keep(master match)	
gen rvalue=(value/us_cpi)*100

* Identify manufacturing exports
merge m:1 code using "$root/bases/hs_manuf", keep(match master) nogen
replace isManuf=0 if code<=280000 | code==999999

save "$root\bases\\`country'_`initialyear'_`endyear'", replace
}



