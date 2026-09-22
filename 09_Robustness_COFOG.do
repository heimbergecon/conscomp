
local nspec = 3

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

* controls, per specification (0 = baseline)
local ctr0 "L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds"
local ctr1 "L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).PDEBT"
local ctr2 "L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).OGAP"
local ctr3 "L(1/1).RYIELD L(1/1).RGROWTH"

local lab1 "+ Public debt"
local lab2 "+ Output gap"
local lab3 "w/o left/right"

local col1 "black"
local col2 "$mred"
local col3 "$mgreen"
local pat1 "dash"
local pat2 "shortdash"
local pat3 "dash_dot"

*---------------------------------------------------------------
* Estimation
*---------------------------------------------------------------

cap drop t h
gen t = _n
gen h = t - 1

* Create zero line ONCE
cap drop zero
gen zero = 0

local gnames ""

foreach var of local vars {

    * --- storage
    cap drop biv`var' up90biv`var' lo90biv`var' up68biv`var' lo68biv`var'
    gen biv`var'     = .
    gen up90biv`var' = .
    gen lo90biv`var' = .
    gen up68biv`var' = .
    gen lo68biv`var' = .
    forvalues s = 1/`nspec' {
        cap drop r`s'`var'
        gen r`s'`var' = .
    }

    forvalues i = 0/`horizon' {

        cap drop d`i'`var'
        gen d`i'`var' = F`i'.`var' - L.`var'

        forvalues s = 0/`nspec' {

            local cntrls `ctr`s'' L(1/1).`var'

            ivreg2 d`i'`var' ///
                (`shock' = `instr') ///
                `cntrls' i.year i.country_id, ///
                dkraay(1) partial(i.year i.country_id)

            cap drop btmp setmp
            gen btmp  = _b[`shock']
            gen setmp = _se[`shock']

            if `s' == 0 {
                replace biv`var'     = btmp if h==`i'
                replace up90biv`var' = btmp + `z1'*setmp if h==`i'
                replace lo90biv`var' = btmp - `z1'*setmp if h==`i'
                replace up68biv`var' = btmp + `z2'*setmp if h==`i'
                replace lo68biv`var' = btmp - `z2'*setmp if h==`i'
            }
            else {
                replace r`s'`var' = btmp if h==`i'
            }
            drop btmp setmp
        }
    }

    * --- build the robustness plot commands
    local rplots ""
    forvalues s = 1/`nspec' {
        local rplots `rplots' (line r`s'`var' h, lcolor("`col`s''") ///
            lpattern(`pat`s'') lwidth(medthick))
    }

    local title "`lab_`var''"
    tw ///
        (rarea up90biv`var' lo90biv`var' h, fcolor("$mblue%12") lwidth(none)) ///
        (rarea up68biv`var' lo68biv`var' h, fcolor("$mblue%30") lwidth(none)) ///
        (line  biv`var' h, lcolor("$mblue") lpattern(solid) lwidth(thick)) ///
        `rplots' ///
        (line  zero h, lcolor("$mred") lpattern(solid) lwidth(medthick)) ///
        if h<=`horizon', ///
        title("`title'", size(`titlesize') col(black) margin(b=2)) ///
        xtitle("Years", size(`subtitlesize')) ///
        ytitle("`ylab'", size(`subtitlesize')) ///
        xlabel(0(2)`horizon', labsize(`labelsize')) ///
        ylabel(, labsize(`labelsize')) ///
        plotregion(color(white)) graphregion(color(white)) ///
        legend(order(3 "Baseline" 4 "`lab1'" 5 "`lab2'" 6 "`lab3'") ///
               rows(1) size(`labelsize') region(lstyle(none))) ///
        name("cofog_ln_`var'_Controls", replace)

    graph export "$FIGUREDIR/COFOG_`var'_Controls.jpg", replace
    local gnames "`gnames' cofog_ln_`var'_Controls"
}

grc1leg2 `gnames', cols(4) loff ysize(`ysize') xsize(`xsize')

graph export "$FIGUREDIRC/COFOG_robust_Controls.png", width(5000) height(4000) replace


////////////////////////////////////////////////////////////////////


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

keep if ccode=="AUT" | ccode=="BEL" | ccode=="DEU" | ccode=="DNK" | ccode=="ESP" | ccode=="FIN" | ccode=="FRA" | ccode=="IRL" | ccode=="ITA" | ccode=="NLD" | ccode=="PRT" | ccode=="SWE" 

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
        name("cofog_ln_`var'_EU", replace)

    graph export "$FIGUREDIR/COFOG_`var'_EU.jpg", replace

    local gnames "`gnames' cofog_ln_`var'_EU"
	 local ivar = `ivar' + 1
}


//========================
// Combine
//=======================

grc1leg2 `gnames', cols(4)  ///
    loff ///
	ysize(`ysize') xsize(`xsize')  

graph export "$FIGUREDIRC/COFOG_EU.png", ///
    width(5000) height(4000) replace

********************************************************************************
* END
********************************************************************************
