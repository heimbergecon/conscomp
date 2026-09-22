
local titlesize   5
local subtitlesize 3
local labelsize    3
local textsize     3
local ysize		3
local xsize 	9

local horizon = 5

local CI1 = 0.10
local CI2 = 0.32
local z1  = abs(invnormal(`CI1'/2))
local z2  = abs(invnormal(`CI2'/2))

local shock diff_STRUCBAL
local instr TOTAL

* COFOG
local vars log_rSOCP log_rHEAL log_rEDUC log_rPUBS log_rHOUS log_rENVI log_rECON log_rPUBO log_rDEFE log_rRECR

local lab_log_rSOCP   "Social protection"
local lab_log_rHEAL  "Health"
local lab_log_rEDUC    "Education"
local lab_log_rPUBS "General public services"
local lab_log_rHOUS    "Housing, amenities"
local lab_log_rENVI   "Environmental protection"
local lab_log_rECON   "Economic affairs"
local lab_log_rPUBO   "Public order, safety"
local lab_log_rDEFE    "Defence"
local lab_log_rRECR    "Recreation, culture, religion"

local ylab "%"

local cntrls_common L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds

cap drop t h
gen t = _n
gen h = t - 1

* Create zero line ONCE
cap drop zero
gen zero = 0

//========================
// Run LPs and store IRFs + make graphs
//========================
local gnames ""
local ivar = 1
foreach var of local vars {

    local cntrls `cntrls_common' L(1/1).`var'

    cap drop biv`var' up90biv`var' lo90biv`var' up68biv`var' lo68biv`var'
    gen biv`var'      = .
    gen up90biv`var'  = .
    gen lo90biv`var'  = .
    gen up68biv`var'  = .
    gen lo68biv`var'  = .

    forvalues i = 0/`horizon' {

		local iname `i'
		 
        cap drop d`iname'`var'
        gen d`iname'`var' = F`i'.`var' - L.`var'


     ivreg2 d`iname'`var' ///
            (`shock' = `instr') ///
            `cntrls' i.year i.country_id, ///
            dkraay(1) partial(i.year i.country_id)

        * use tempvars (safer than gen btmp/setmp repeatedly)
        capture drop btmp setmp
        gen btmp  = _b[`shock']
        gen setmp = _se[`shock']

        replace biv`var'     = btmp if h==`i'
        replace up90biv`var' = btmp + `z1'*setmp if h==`i'
        replace lo90biv`var' = btmp - `z1'*setmp if h==`i'
        replace up68biv`var' = btmp + `z2'*setmp if h==`i'
        replace lo68biv`var' = btmp - `z2'*setmp if h==`i'
        drop btmp setmp

    }


    local title "`lab_`var''"

    tw ///
        (rarea up90biv`var' lo90biv`var' h, fcolor("$mblue%12") lwidth(none)) ///
        (rarea up68biv`var' lo68biv`var' h, fcolor("$mblue%30") lwidth(none)) ///
        (line  biv`var'     h, lcolor("$mblue") lpattern(solid) lwidth(thick)) ///
        (line  zero       h, lcolor("$mred")  lpattern(solid) lwidth(medthick)) ///
        if h<=`horizon', ///
        title("`title'", size(`titlesize') col(black) margin(b=2)) ///
        xtitle("Years", size(`subtitlesize')) ///
        ytitle("`ylab'", size(`subtitlesize')) ///
         xlabel(0(2)`horizon', labsize(`labelsize')) ///
	   ylabel(, labsize(`labelsize')) /// 
       plotregion(color(white)) ///
       graphregion(color(white)) ///
        legend(off) ///
        name("cofog_ln_`var'", replace)

    graph export "$FIGUREDIR/COFOG_`var'.jpg", replace

    local gnames "`gnames' cofog_ln_`var'"
	 local ivar = `ivar' + 1
}


//========================
// Combine
//=======================

grc1leg2 `gnames', cols(4)  ///
    loff ///
	ysize(`ysize') xsize(`xsize')  

graph export "$FIGUREDIRC/COFOG_headline.png", ///
    width(5000) height(4000) replace

********************************************************************************
* END
********************************************************************************
preserve
keep h bivlog_rSOCP up90bivlog_rSOCP lo90bivlog_rSOCP up68bivlog_rSOCP lo68bivlog_rSOCP bivlog_rHEAL up90bivlog_rHEAL lo90bivlog_rHEAL up68bivlog_rHEAL lo68bivlog_rHEAL bivlog_rEDUC up90bivlog_rEDUC lo90bivlog_rEDUC up68bivlog_rEDUC lo68bivlog_rEDUC bivlog_rPUBS up90bivlog_rPUBS lo90bivlog_rPUBS up68bivlog_rPUBS lo68bivlog_rPUBS bivlog_rHOUS up90bivlog_rHOUS lo90bivlog_rHOUS up68bivlog_rHOUS lo68bivlog_rHOUS bivlog_rENVI up90bivlog_rENVI lo90bivlog_rENVI up68bivlog_rENVI lo68bivlog_rENVI bivlog_rECON up90bivlog_rECON lo90bivlog_rECON up68bivlog_rECON lo68bivlog_rECON bivlog_rPUBO up90bivlog_rPUBO lo90bivlog_rPUBO up68bivlog_rPUBO lo68bivlog_rPUBO bivlog_rDEFE up90bivlog_rDEFE lo90bivlog_rDEFE up68bivlog_rDEFE lo68bivlog_rDEFE bivlog_rRECR up90bivlog_rRECR lo90bivlog_rRECR up68bivlog_rRECR lo68bivlog_rRECR
		
export excel using "$TABLEDIR\EMPNIII_COFOG.xlsx", replace firstrow(variables)
restore	