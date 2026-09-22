
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

local shock_base diff_STRUCBAL
local instr      TOTAL

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

* preferred controls as in your linear COFOG code (+ lag of response variable added below)
local cntrls_common L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds

* horizon helper (create once)
cap drop t h
gen t = _n
gen h = t - 1

* Create zero line ONCE
cap drop zero
gen zero = 0

//========================
// STATE DEFINITION: p20 OGAP
//========================
cap drop recession pOGAP
quietly _pctile OGAP if !missing(OGAP), p(20)
gen pOGAP = r(r1)

gen recession = .
replace recession = 1 if OGAP <  pOGAP & !missing(OGAP)
replace recession = 0 if OGAP >= pOGAP & !missing(OGAP)
label define rec20 0 "Expansion (>= p20)" 1 "Recession (< p20)", replace
label values recession rec20
tab recession, missing

* State-dependent shocks and instruments (created once)
capture drop diff_STRUCBAL_R diff_STRUCBAL_E TOTAL_R TOTAL_E
gen diff_STRUCBAL_R = recession * `shock_base'
gen diff_STRUCBAL_E = (1 - recession) * `shock_base'
gen TOTAL_R = recession * `instr'
gen TOTAL_E = (1 - recession) * `instr'

local shock_R diff_STRUCBAL_R
local shock_E diff_STRUCBAL_E


//========================
// Run state-dependent LPs and store IRFs + make graphs
//========================
local gnames ""
local ivar = 1

foreach var of local vars {

    local cntrls `cntrls_common' L(1/1).`var'

    * storage
    cap drop biv`var'_R up90biv`var'_R lo90biv`var'_R up68biv`var'_R lo68biv`var'_R
    cap drop biv`var'_E up90biv`var'_E lo90biv`var'_E up68biv`var'_E lo68biv`var'_E

    gen biv`var'_R      = .
    gen up90biv`var'_R  = .
    gen lo90biv`var'_R  = .
    gen up68biv`var'_R  = .
    gen lo68biv`var'_R  = .

    gen biv`var'_E      = .
    gen up90biv`var'_E  = .
    gen lo90biv`var'_E  = .
    gen up68biv`var'_E  = .
    gen lo68biv`var'_E  = .

    forvalues i = 0/`horizon' {

		local iname `i'
		
        cap drop d`iname'`var'
        gen d`iname'`var' = F`i'.`var' - L.`var'

        ivreg2 d`iname'`var' ///
            (`shock_R' `shock_E' = TOTAL_R TOTAL_E) ///
            `cntrls' i.year i.country_id, ///
            dkraay(1) partial(i.year i.country_id)

        * recession (R)
        tempvar bR seR
        gen `bR'  = _b[`shock_R']
        gen `seR' = _se[`shock_R']
        replace biv`var'_R     = `bR' if h==`i'
        replace up90biv`var'_R = `bR' + `z1'*`seR' if h==`i'
        replace lo90biv`var'_R = `bR' - `z1'*`seR' if h==`i'
        replace up68biv`var'_R = `bR' + `z2'*`seR' if h==`i'
        replace lo68biv`var'_R = `bR' - `z2'*`seR' if h==`i'

        * expansion (E)
        tempvar bE seE
        gen `bE'  = _b[`shock_E']
        gen `seE' = _se[`shock_E']
        replace biv`var'_E     = `bE' if h==`i'
        replace up90biv`var'_E = `bE' + `z1'*`seE' if h==`i'
        replace lo90biv`var'_E = `bE' - `z1'*`seE' if h==`i'
        replace up68biv`var'_E = `bE' + `z2'*`seE' if h==`i'
        replace lo68biv`var'_E = `bE' - `z2'*`seE' if h==`i'
    }

    local title "`lab_`var''"

    tw ///
        (rarea up90biv`var'_E lo90biv`var'_E h, fcolor("$mblue%12") lwidth(none)) ///
        (rarea up68biv`var'_E lo68biv`var'_E h, fcolor("$mblue%30") lwidth(none)) ///
        (line  biv`var'_E      h, lcolor("$mblue")  lpattern(dash)  lwidth(thick)) ///
        (rarea up90biv`var'_R lo90biv`var'_R h, fcolor("$mdred%10") lwidth(none)) ///
        (rarea up68biv`var'_R lo68biv`var'_R h, fcolor("$mdred%25") lwidth(none)) ///
        (line  biv`var'_R      h, lcolor("$mdred") lpattern(solid) lwidth(thick)) ///
        (line  zero          h, lcolor("$mred")  lpattern(solid) lwidth(medthick)) ///
        if h<=`horizon', ///
        title("`title'", size(`titlesize') col(black) margin(b=2)) ///
        xtitle("Years", size(`subtitlesize')) ///
        ytitle("`ylab'", size(`subtitlesize')) ///
         xlabel(0(2)`horizon', labsize(`labelsize')) ///
	   ylabel(, labsize(`labelsize')) /// 
       plotregion(color(white)) ///
       graphregion(color(white)) ///
        legend(order(3 6) ///
               label(3 "Expansion (OGAP >= p20)") ///
               label(6 "Recession (OGAP < p20)") ///
               rows(1) ring(0) position(6)) ///
        name("cofog_p20_ln_`var'", replace)

    graph export "$FIGUREDIR/COFOG_`var'_SD_p20.jpg", replace

    local gnames "`gnames' cofog_p20_ln_`var'"
}


//========================
// Combine 10 panels (automatic y-scale per panel)
//========================
grc1leg2 `gnames', cols(4)  ///
    loff  ///
	ysize(`ysize') xsize(`xsize')  

graph export "$FIGUREDIRC/SD_COFOG_p20.png", ///
  width(5000) height(4000) replace

	
	
********************************************************************************
** State dependency: plot the difference
********************************************************************************


* State-dependent shocks and instruments (created once)
capture drop diff_STRUCBAL_R diff_STRUCBAL_E TOTAL_R TOTAL_E
gen diff_STRUCBAL_R = recession * `shock_base'
gen TOTAL_R = recession * `instr'

local shock_R diff_STRUCBAL_R
local shock_E diff_STRUCBAL_E


//========================
// Run state-dependent LPs and store IRFs + make graphs
//========================
local gnames ""
local ivar = 1
foreach var of local vars {

    local cntrls `cntrls_common' L(1/1).`var'

    * storage
    cap drop biv`var'_R up90biv`var'_R lo90biv`var'_R up68biv`var'_R lo68biv`var'_R
    cap drop biv`var'_E up90biv`var'_E lo90biv`var'_E up68biv`var'_E lo68biv`var'_E

    gen biv`var'_R      = .
    gen up90biv`var'_R  = .
    gen lo90biv`var'_R  = .
    gen up68biv`var'_R  = .
    gen lo68biv`var'_R  = .

    gen biv`var'_E      = .
    gen up90biv`var'_E  = .
    gen lo90biv`var'_E  = .
    gen up68biv`var'_E  = .
    gen lo68biv`var'_E  = .

    forvalues i = 0/`horizon' {

		local iname `i'

        cap drop d`iname'`var'
        gen d`iname'`var' = F`i'.`var' - L.`var'

        ivreg2 d`iname'`var' ///
            (`shock_base' `shock_R'  = `instr' TOTAL_R) ///
            `cntrls' i.year i.country_id, ///
            dkraay(1) partial(i.year i.country_id)

        * recession (R)
        tempvar bR seR
        gen `bR'  = _b[`shock_R']
        gen `seR' = _se[`shock_R']
        replace biv`var'_R     = `bR' if h==`i'
        replace up90biv`var'_R = `bR' + `z1'*`seR' if h==`i'
        replace lo90biv`var'_R = `bR' - `z1'*`seR' if h==`i'
        replace up68biv`var'_R = `bR' + `z2'*`seR' if h==`i'
        replace lo68biv`var'_R = `bR' - `z2'*`seR' if h==`i'

 
    }

    local title "`lab_`var''"

    tw ///
        (rarea up90biv`var'_R lo90biv`var'_R h, fcolor("$mpurple%15") lwidth(none)) ///
        (rarea up68biv`var'_R lo68biv`var'_R h, fcolor("$mpurple%40") lwidth(none)) ///
        (line  biv`var'_R      h, lcolor("$mpurple") lpattern(solid) lwidth(thick)) ///
        (line  zero          h, lcolor(black)  lpattern(solid) lwidth(medthick)) ///
        if h<=`horizon', ///
        title("`title'", size(`titlesize') col(black) margin(b=2)) ///
        xtitle("Years", size(`subtitlesize')) ///
        ytitle("`ylab'", size(`subtitlesize')) ///
         xlabel(0(2)`horizon', labsize(`labelsize')) ///
	   ylabel(, labsize(`labelsize')) /// 
       plotregion(color(white)) ///
       graphregion(color(white)) ///
        legend(order(3 6) ///
               label(3 "Expansion (OGAP >= p20)") ///
               label(6 "Recession (OGAP < p20)") ///
               rows(1) ring(0) position(6)) ///
        name("cofog_p20_diff_`var'", replace)

    graph export "$FIGUREDIR/COFOG_`var'_SD_p20.jpg", replace

    local gnames "`gnames' cofog_p20_diff_`var'"
}


//========================
// Combine 10 panels (automatic y-scale per panel)
//========================
grc1leg2 `gnames', cols(4)  ///
    loff  ///
	ysize(`ysize') xsize(`xsize')  
	
graph export "$FIGUREDIRC/SD_COFOG_p20_diff.png",   width(5000) height(4000) replace

* COFOG
local cofog_lvl rSOCP rHEAL rEDUC rPUBS rHOUS rENVI rECON rPUBO rDEFE rRECR

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

* preferred controls as in your linear COFOG code (+ lag of response variable added below)
local cntrls_common L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds

* horizon helper (create once)
cap drop t h
gen t = _n
gen h = t - 1

* Create zero line ONCE
cap drop zero
gen zero = 0


//========================
// STATE DEFINITION: p20 OGAP
//========================
cap drop recession pOGAP
quietly _pctile OGAP if !missing(OGAP), p(20)
gen pOGAP = r(r1)

gen recession = .
replace recession = 1 if OGAP <  pOGAP & !missing(OGAP)
replace recession = 0 if OGAP >= pOGAP & !missing(OGAP)
label define rec20 0 "Expansion (>= p20)" 1 "Recession (< p20)", replace
label values recession rec20
tab recession, missing

* State-dependent shocks and instruments (created once)
capture drop diff_STRUCBAL_R 
capture drop diff_STRUCBAL_E 
capture drop TOTAL_R 
capture drop TOTAL_E
gen diff_STRUCBAL_R = recession * `shock_base'
gen diff_STRUCBAL_E = (1 - recession) * `shock_base'
gen TOTAL_R = recession * `instr'
gen TOTAL_E = (1 - recession) * `instr'

local shock_R diff_STRUCBAL_R
local shock_E diff_STRUCBAL_E


//========================
// Run state-dependent LPs and store IRFs + make graphs
//========================
local gnames ""

foreach v of local cofog_lvl {

    local var log_`v'
    capture confirm variable `var'
    if _rc continue

    * controls: preferred + lag of response variable (like your state-dependent template)
    local cntrls `cntrls_common' L(1/1).`var'

    * storage
    cap drop biv`v'_R up90biv`v'_R lo90biv`v'_R up68biv`v'_R lo68biv`v'_R
    cap drop biv`v'_E up90biv`v'_E lo90biv`v'_E up68biv`v'_E lo68biv`v'_E

    gen biv`v'_R      = .
    gen up90biv`v'_R  = .
    gen lo90biv`v'_R  = .
    gen up68biv`v'_R  = .
    gen lo68biv`v'_R  = .

    gen biv`v'_E      = .
    gen up90biv`v'_E  = .
    gen lo90biv`v'_E  = .
    gen up68biv`v'_E  = .
    gen lo68biv`v'_E  = .

    forvalues i = 0/`horizon' {

        cap drop d`i'`v'
        gen d`i'`v' = F`i'.`var' - L.`var'

        quietly count if !missing(d`i'`v', `shock_R', `shock_E', TOTAL_R, TOTAL_E, ///
                                  L.`var', L.PDEBT, L.RYIELD, L.RGROWTH, L.lrgov_cpds)
        if r(N)==0 continue

        ivreg2 d`i'`v' ///
            (`shock_R' `shock_E' = TOTAL_R TOTAL_E) ///
            `cntrls' i.year i.country_id, ///
            dkraay(1) partial(i.year i.country_id)

        * recession (R)
        tempvar bR seR
        gen `bR'  = _b[`shock_R']
        gen `seR' = _se[`shock_R']
        replace biv`v'_R     = `bR' if h==`i'
        replace up90biv`v'_R = `bR' + `z1'*`seR' if h==`i'
        replace lo90biv`v'_R = `bR' - `z1'*`seR' if h==`i'
        replace up68biv`v'_R = `bR' + `z2'*`seR' if h==`i'
        replace lo68biv`v'_R = `bR' - `z2'*`seR' if h==`i'

        * expansion (E)
        tempvar bE seE
        gen `bE'  = _b[`shock_E']
        gen `seE' = _se[`shock_E']
        replace biv`v'_E     = `bE' if h==`i'
        replace up90biv`v'_E = `bE' + `z1'*`seE' if h==`i'
        replace lo90biv`v'_E = `bE' - `z1'*`seE' if h==`i'
        replace up68biv`v'_E = `bE' + `z2'*`seE' if h==`i'
        replace lo68biv`v'_E = `bE' - `z2'*`seE' if h==`i'
    }

    local title "`lab_`v''"

    tw ///
        (rarea up90biv`v'_E lo90biv`v'_E h, fcolor("$mblue%12") lwidth(none)) ///
        (rarea up68biv`v'_E lo68biv`v'_E h, fcolor("$mblue%30") lwidth(none)) ///
        (line  biv`v'_E      h, lcolor("$mblue")  lpattern(dash)  lwidth(thick)) ///
        (rarea up90biv`v'_R lo90biv`v'_R h, fcolor("$mdred%10") lwidth(none)) ///
        (rarea up68biv`v'_R lo68biv`v'_R h, fcolor("$mdred%25") lwidth(none)) ///
        (line  biv`v'_R      h, lcolor("$mdred") lpattern(solid) lwidth(thick)) ///
        (line  zero          h, lcolor("$mred")  lpattern(solid) lwidth(medthick)) ///
        if h<=`horizon', ///
        title("`title'", size(`titlesize') col(black) margin(b=2)) ///
        xtitle("Years", size(`subtitlesize')) ///
        ytitle("`ylab'", size(`subtitlesize')) ///
         xlabel(0(2)`horizon', labsize(`labelsize')) ///
	   ylabel(, labsize(`labelsize')) /// 
       plotregion(color(white)) ///
       graphregion(color(white)) ///
        legend(order(3 6) ///
               label(3 "Expansion (OGAP >= p20)") ///
               label(6 "Recession (OGAP < p20)") ///
               rows(1) ring(0) position(6)) ///
        name("cofog_p20_ln_`v'", replace)

    graph export "$FIGUREDIR/pirf_iv_state_p20_cofog_ln_`v'.jpg", replace

    local gnames "`gnames' cofog_p20_ln_`v'"
}


//========================
// Combine 10 panels (automatic y-scale per panel)
//========================
grc1leg2 `gnames', cols(4)  ///
    loff  ///
	ysize(`ysize') xsize(`xsize')  

graph export "$FIGUREDIRC/SD_COFOG_states.png", ///
  width(5000) height(4000) replace

cap program drop lpdiffcofog
program define lpdiffcofog
	syntax , statevars(varlist) suffix(string)                            ///
	       [ shock(varname) instr(varname) horizon(integer 5)             ///
	         diffname1(string) diffname2(string) diffname3(string)        ///
	         combname(string) cols(integer 4)                             ///
	         titlesize(real 5) subtitlesize(real 3) labelsize(real 3)     ///
	         ysize(real 3) xsize(real 9) ]

	if "`shock'"    == "" local shock diff_STRUCBAL
	if "`instr'"    == "" local instr TOTAL
	if "`combname'" == "" local combname SD_COFOG_diff_`suffix'

* COFOG
local cofog_lvl rSOCP rHEAL rEDUC rPUBS rHOUS rENVI rECON rPUBO rDEFE rRECR

local lab_rSOCP   "Social protection"
local lab_rHEAL  "Health"
local lab_rEDUC    "Education"
local lab_rPUBS "General public services"
local lab_rHOUS    "Housing, amenities"
local lab_rENVI   "Environmental protection"
local lab_rECON   "Economic affairs"
local lab_rPUBO   "Public order, safety"
local lab_rDEFE    "Defence"
local lab_rRECR    "Recreation, culture, religion"

	local ylab "%"
	local cntrls_common L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds

	local z1 = abs(invnormal(0.10/2))
	local z2 = abs(invnormal(0.32/2))

	local pcol1 "$mpurple"
	local pcol2 "$mgreen"
	local pcol3 "$mdred"

	local k : word count `statevars'
	forvalues j = 1/`k' {
		if "`diffname`j''" == "" local diffname`j' "difference"
	}

	xtset country_id year

	cap drop stmiss
	qui egen byte stmiss = rowmiss(`statevars')

	cap drop shk_lvl ins_lvl
	qui gen double shk_lvl = `shock' if stmiss==0
	qui gen double ins_lvl = `instr' if stmiss==0

	local endog shk_lvl
	local instl ins_lvl
	forvalues j = 1/`k' {
		local sv : word `j' of `statevars'
		cap drop shk_d`j' ins_d`j'
		qui gen double shk_d`j' = `sv' * `shock'
		qui gen double ins_d`j' = `sv' * `instr'
		local endog `endog' shk_d`j'
		local instl `instl' ins_d`j'
	}

	cap drop t h
	qui gen t = _n
	qui gen h = t - 1
	cap drop zero
	qui gen zero = 0

	local gnames ""

	foreach v of local cofog_lvl {

		local var log_`v'
		capture confirm variable `var'
		if _rc continue

		local cntrls `cntrls_common' L(1/1).`var'

		* storage (one set of series per difference)
		forvalues j = 1/`k' {
			cap drop bd`v'_`j' up90bd`v'_`j' lo90bd`v'_`j' up68bd`v'_`j' lo68bd`v'_`j'
			qui gen double bd`v'_`j'     = .
			qui gen double up90bd`v'_`j' = .
			qui gen double lo90bd`v'_`j' = .
			qui gen double up68bd`v'_`j' = .
			qui gen double lo68bd`v'_`j' = .
		}

		forvalues i = 0/`horizon' {

			cap drop d`i'`v'
			qui gen double d`i'`v' = F`i'.`var' - L.`var'

			* guard against an empty estimation sample
			qui count if !missing(d`i'`v', shk_lvl, ins_lvl, L.`var', ///
			                      L.RYIELD, L.RGROWTH, L.lrgov_cpds)
			if r(N)==0 continue

			qui ivreg2 d`i'`v'                         ///
				(`endog' = `instl')                    ///
				`cntrls' i.year i.country_id,          ///
				dkraay(1) partial(i.year i.country_id)

			forvalues j = 1/`k' {
				local bb = _b[shk_d`j']
				local ss = _se[shk_d`j']
				qui replace bd`v'_`j'     = `bb'             if h==`i'
				qui replace up90bd`v'_`j' = `bb' + `z1'*`ss' if h==`i'
				qui replace lo90bd`v'_`j' = `bb' - `z1'*`ss' if h==`i'
				qui replace up68bd`v'_`j' = `bb' + `z2'*`ss' if h==`i'
				qui replace lo68bd`v'_`j' = `bb' - `z2'*`ss' if h==`i'
			}
		}

		local title "`lab_`v''"

		* assemble the plot layer by layer (one band pair + line per difference)
		local plots ""
		local legord ""
		forvalues j = 1/`k' {
			local c "`pcol`j''"
			local plots `"`plots' (rarea up90bd`v'_`j' lo90bd`v'_`j' h, fcolor("`c'%15") lwidth(none)) (rarea up68bd`v'_`j' lo68bd`v'_`j' h, fcolor("`c'%40") lwidth(none)) (line bd`v'_`j' h, lcolor("`c'") lpattern(solid) lwidth(thick))"'
			local ln = 3*`j'
			local legord `"`legord' `ln' "`diffname`j''""'
		}
		if `k' == 1 local legord `"`legord' 2 "68% CI" 1 "90% CI""'

		tw `plots' ///
			(line zero h, lcolor(black) lpattern(solid) lwidth(medthick)) ///
			if h<=`horizon', ///
			title("`title'", size(`titlesize') col(black) margin(b=2)) ///
			xtitle("Years", size(`subtitlesize')) ///
			ytitle("`ylab'", size(`subtitlesize')) ///
			xlabel(0(2)`horizon', labsize(`labelsize')) ///
			ylabel(, labsize(`labelsize')) ///
			plotregion(color(white)) ///
			graphregion(color(white)) ///
			legend(order(`legord') rows(1) ring(0) position(6)) ///
			name("cofog_`suffix'_diff_`v'", replace)

		graph export "$FIGUREDIR/pirf_iv_state_`suffix'_cofog_diff_`v'.jpg", replace

		local gnames "`gnames' cofog_`suffix'_diff_`v'"
	}

	*----------------------------------------------------------------------
	* Combine 10 panels (automatic y-scale per panel)
	*----------------------------------------------------------------------
	if `k' == 1 {
		grc1leg2 `gnames', cols(`cols') loff ysize(`ysize') xsize(`xsize')
	}
	else {
		grc1leg2 `gnames', cols(`cols') ysize(`ysize') xsize(`xsize')
	}

	graph export "$FIGUREDIRC/`combname'.png", width(5000) height(4000) replace
end


********************************************************************************
* STATE 3% DEFICIT BREACH
********************************************************************************

preserve

cap drop EDPBreachState
gen byte EDPBreachState = (FiscalBalance < -3) if !missing(FiscalBalance)

lpdiffcofog, statevars(EDPBreachState) suffix(EDPBreach) horizon(`horizon') ///
    diffname1("above - below 3% deficit")                                   ///
    titlesize(`titlesize') subtitlesize(`subtitlesize')                     ///
    labelsize(`labelsize') ysize(`ysize') xsize(`xsize')

restore


********************************************************************************
* STATE PUBLIC DEBT (median split)
********************************************************************************

preserve

cap drop PDState med_PDEBT
egen med_PDEBT = median(PDEBT)
gen byte PDState = (PDEBT >= med_PDEBT) if !missing(PDEBT)

lpdiffcofog, statevars(PDState) suffix(PDebt) horizon(`horizon')        ///
    diffname1("high - low public debt")                                 ///
    titlesize(`titlesize') subtitlesize(`subtitlesize')                 ///
    labelsize(`labelsize') ysize(`ysize') xsize(`xsize')

restore


********************************************************************************
* STATE POLITICAL FRAGMENTATION (median split)   -- USA not included
********************************************************************************

preserve

cap drop med_frag high_frag_d
egen med_frag = median(frag_parl)
gen byte high_frag_d = (frag_parl > med_frag) if !missing(frag_parl)

lpdiffcofog, statevars(high_frag_d) suffix(Frag) horizon(`horizon')     ///
    diffname1("high - low fragmentation")                               ///
    titlesize(`titlesize') subtitlesize(`subtitlesize')                 ///
    labelsize(`labelsize') ysize(`ysize') xsize(`xsize')

restore

