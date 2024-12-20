gl root "\\data4\users10\aalvarado\My Documents\GTM\export_decomposition"

*use "C:\Users\aalvarado\Downloads\hs92_country_product_year_6.dta", clear


/** GDP and country code to merge with BACI data
import delimited "C:\Users\aalvarado\Downloads\BACI_HS96_V202401b\country_codes_V202401b.csv",  clear
keep country_code country_iso3
drop if country_code==58 | country_code==280 | country_code==729
tempfile iso
save `iso'
import excel "\\data4\users10\aalvarado\My Documents\GTM\export_decomposition\bases\gdp_r_ppp_pc.xlsx", sheet("GDP") firstrow clear
keep CountryISO3code J-AG
ds J-AG
local var=r(varlist)
local i=2000
foreach v of local var {
	rename `v' gdp`i'
	local i=`i'+1
}
reshape long gdp, i(CountryISO3code) j(year)
rename CountryISO3code country_iso3
merge m:1 country_iso3 using `iso', keep(match) nogen 
save "\\data4\users10\aalvarado\My Documents\GTM\export_decomposition\bases\gdp", replace
*/

foreach y in 2002 2003 2004 2012 2013 2014 2020 2021 2022 {
import delimited "C:\Users\aalvarado\Downloads\BACI_HS96_V202401b\BACI_HS96_Y`y'_V202401b.csv", clear 
collapse (sum) v, by(i k t)
rename (t i v) (year country_code value)
merge m:1 year country_code using "$root\bases\gdp", keep(match) nogen
*
	bys country_code year: egen valueCountryTot=sum(value*!mi(gdp))
	label var valueCountryTot "Total annual exports by country "
	bys k year: egen valueCodeTot=sum(value*!mi(gdp))
	label var valueCodeTot "Total annual exports by product "
	bys year: egen valueWld=sum(value*!mi(gdp))
	label var valueWld "Global annual exports "
	gen valueCountrySh=value/valueCountryTot
	label var valueCountrySh "Share of product in country's annual exports "
	gen shareWld=valueCodeTot/valueWld
	label var shareWld "Product's share in global exports "
	bys year k: egen valueShTot=sum(valueCountrySh)
	label var valueShTot "PRODY denominator (sum of product shares for each country) "
	bys year k: egen prody=sum(valueCountrySh/valueShTot*gdp)
	label var prody "PRODY"
	collapse (first) prody , by(k year)
gen code6=string(k, "%06.0f")

save "$root\bases\prody`y'", replace
}

	*/
	
	/*
* Step 1: Calculate the total export value for each country in each year
bysort country_code year: egen total_export = sum(value*!mi(gdp))
* Step 2: Calculate the share of each product (k) in each country's total export basket in each year
gen share = value / total_export
* Step 3: 4: Calculate the importance in the world total export of each product (k) in each year
bysort k year: egen world_share = sum(share*!mi(gdp))
* Step 4: Calculate the "revealed comparative advantage" (RCA) proxy used as weights
gen RCA_weight = share / world_share
* Step 5: Calculate the PRODY for each product (k) in each year
gen GDP_weighted = RCA_weight * gdp
collapse (sum) prody=GDP_weighted, by(k year)
