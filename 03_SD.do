
global titlesize   9
global subtitlesize 7
global labelsize    7
global textsize     7
global ysize		3
global xsize 	9

local horizon = 5
local estdiff = 2     // cumulative (t-1 to t+h)

local CI1 = 0.10
local CI2 = 0.32
local z1 = abs(invnormal(`CI1'/2))
local z2 = abs(invnormal(`CI2'/2))

local shock_base diff_STRUCBAL
local instr_base TOTAL

* response variables (spending specs)
local vars log_PUBINV log_GCONS log_RATIO
local varsnames `" "Public investment" "Government consumption" "Ratio" "'
local labels    `" "%" "%" "%" "'

* controls: 1 lag each; NO lag of response variable (matches R first-stage)
local cntrls_log_PUBINV L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).D.log_PUBINV
local cntrls_log_GCONS L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).D.log_GCONS 
local cntrls_log_RATIO L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).D.log_RATIO


* horizons index helper
cap drop t h
gen t = _n
gen h = t - 1


********************************************************************************
*  BUSINESS CYCLE REGIME: recession vs non-recession (P20)
********************************************************************************

*------------------------
* Binary regime: recession vs non-recession
*------------------------
cap drop recession
generate recession = .
sum OGAP, detail
	cap drop pOGAP
	_pctile OGAP, p(20)
    gen pOGAP = r(r1)
replace recession = 1 if OGAP < pOGAP & !missing(OGAP)
replace recession = 0 if OGAP > pOGAP & !missing(OGAP)
tab recession

label define reclbl 0 "Non-recession (RGROWTH >= 0)" 1 "Recession (RGROWTH < 0)"
label values recession reclbl
tab recession

* Regime-specific endogenous + instruments
capture drop diff_STRUCBAL_REC diff_STRUCBAL_NREC TOTAL_REC TOTAL_NREC
gen diff_STRUCBAL_REC  = recession * `shock_base'
gen diff_STRUCBAL_NREC = (1 - recession) * `shock_base'
gen TOTAL_REC  = recession * `instr_base'
gen TOTAL_NREC = (1 - recession) * `instr_base'

local shock_REC  diff_STRUCBAL_REC
local shock_NREC diff_STRUCBAL_NREC

*------------------------
* Run LP-IV + graphs
*------------------------
local ivar = 1
foreach var in `vars' {

    local cntrls `cntrls_`var''

    * preallocate IRF storage (REC + NREC)
    capture drop biv`var'_REC up90biv`var'_REC lo90biv`var'_REC up68biv`var'_REC lo68biv`var'_REC
    capture drop biv`var'_NREC up90biv`var'_NREC lo90biv`var'_NREC up68biv`var'_NREC lo68biv`var'_NREC

    gen biv`var'_REC      = .
    gen up90biv`var'_REC  = .
    gen lo90biv`var'_REC  = .
    gen up68biv`var'_REC  = .
    gen lo68biv`var'_REC  = .

    gen biv`var'_NREC     = .
    gen up90biv`var'_NREC = .
    gen lo90biv`var'_NREC = .
    gen up68biv`var'_NREC = .
    gen lo68biv`var'_NREC = .

    forvalues i = 0/`horizon' {

        local iname `i'

        cap drop d`iname'`var'
        gen d`iname'`var' = F`i'.`var' - L.`var'

        ivreg2 d`iname'`var' ///
            (`shock_REC' `shock_NREC' = TOTAL_REC TOTAL_NREC) ///
            `cntrls' i.year i.country_id, ///
            dkraay(1) partial(i.year i.country_id)

        cap drop bR seR bN seN
        gen bR  = _b[`shock_REC']
        gen seR = _se[`shock_REC']
        gen bN  = _b[`shock_NREC']
        gen seN = _se[`shock_NREC']

        replace biv`var'_REC      = 100*bR if h==`i'
        replace up90biv`var'_REC  = 100*(bR + `z1'*seR) if h==`i'
        replace lo90biv`var'_REC  = 100*(bR - `z1'*seR) if h==`i'
        replace up68biv`var'_REC  = 100*(bR + `z2'*seR) if h==`i'
        replace lo68biv`var'_REC  = 100*(bR - `z2'*seR) if h==`i'

        replace biv`var'_NREC     = 100*bN if h==`i'
        replace up90biv`var'_NREC = 100*(bN + `z1'*seN) if h==`i'
        replace lo90biv`var'_NREC = 100*(bN - `z1'*seN) if h==`i'
        replace up68biv`var'_NREC = 100*(bN + `z2'*seN) if h==`i'
        replace lo68biv`var'_NREC = 100*(bN - `z2'*seN) if h==`i'

        drop bR seR bN seN
    }

    cap drop zero
    gen zero = 0

    local varname : word `ivar' of `varsnames'
    local labname : word `ivar' of `labels'

    tw ///
        (rarea up90biv`var'_NREC lo90biv`var'_NREC h, fcolor("$mblue%15") lwidth(none)) ///
        (rarea up68biv`var'_NREC lo68biv`var'_NREC h, fcolor("$mblue%40") lwidth(none)) ///
        (line  biv`var'_NREC h, lcolor("$mblue") lpattern(solid) lwidth(thick)) ///
        (rarea up90biv`var'_REC  lo90biv`var'_REC  h, fcolor("$mdred%15") lwidth(none)) ///
        (rarea up68biv`var'_REC  lo68biv`var'_REC  h, fcolor("$mdred%40") lwidth(none)) ///
        (line  biv`var'_REC  h, lcolor("$mdred") lpattern(dash) lwidth(thick)) ///
        (line  zero h, lcolor("$mred") lpattern(solid) lwidth(medthick)) ///
        if h<=`horizon', ///
		title("`varname'", size(`titlesize') col(black) margin(b=2)) ///
       xtitle("Years", size(`subtitlesize')) ///
       ytitle("`labname'", size(`subtitlesize')) ///
       xlabel(0(1)`horizon', labsize(`labelsize')) ///
	   ylabel(, labsize(`labelsize')) /// 
       plotregion(color(white)) ///
       graphregion(color(white)) ///
        legend(order(3 6) ///
               label(3 "Non-recession (RGROWTH >= 0)") ///
               label(6 "Recession (RGROWTH < 0)") ///
               rows(1) ring(0) position(6)) ///
        name("sdrec_iv_`var'", replace) ///
        saving("$FIGUREDIR/pirf_sdrec_iv_`var'.gph", replace)

    graph export "$FIGUREDIR/pirf_sdrec_iv_`var'.jpg", fontface($grfont) replace

    local ivar = `ivar' + 1
}


graph use "$FIGUREDIR/pirf_sdrec_iv_log_PUBINV.gph",        name(g1, replace)
graph use "$FIGUREDIR/pirf_sdrec_iv_log_GCONS.gph",         name(g2, replace)
graph use "$FIGUREDIR/pirf_sdrec_iv_log_RATIO.gph",   name(g3, replace)

grc1leg2 g1 g2 g3, cols(3) ///
    loff ycommon ///
	ysize(`ysize') xsize(`xsize')  

graph export "$FIGUREDIRC/SD_BC_p20.jpg",  width(5000) height(2000) replace

preserve
keep h bivlog_PUBINV_NREC up90bivlog_PUBINV_NREC lo90bivlog_PUBINV_NREC up68bivlog_PUBINV_NREC lo68bivlog_PUBINV_NREC bivlog_PUBINV_REC up90bivlog_PUBINV_REC lo90bivlog_PUBINV_REC up68bivlog_PUBINV_REC lo68bivlog_PUBINV_REC bivlog_GCONS_NREC up90bivlog_GCONS_NREC lo90bivlog_GCONS_NREC up68bivlog_GCONS_NREC lo68bivlog_GCONS_NREC bivlog_GCONS_REC up90bivlog_GCONS_REC lo90bivlog_GCONS_REC up68bivlog_GCONS_REC lo68bivlog_GCONS_REC bivlog_RATIO_NREC up90bivlog_RATIO_NREC lo90bivlog_RATIO_NREC up68bivlog_RATIO_NREC lo68bivlog_RATIO_NREC bivlog_RATIO_REC up90bivlog_RATIO_REC lo90bivlog_RATIO_REC up68bivlog_RATIO_REC lo68bivlog_RATIO_REC
		
export excel using "$TABLEDIR\EMPNIII_StateDependence.xlsx", replace firstrow(variables)
restore	

********************************************************************************
* BUSINESS CYCLE REGIME: recession vs non-recession (P20) – DIFFERENCE
********************************************************************************

*------------------------
* Binary regime: recession vs non-recession
*------------------------
cap drop recession
generate recession = .
sum OGAP, detail
	cap drop pOGAP
	_pctile OGAP, p(20)
    gen pOGAP = r(r1)
replace recession = 1 if OGAP < pOGAP & !missing(OGAP)
replace recession = 0 if OGAP > pOGAP & !missing(OGAP)
tab recession

* Regime-specific endogenous + instruments
drop diff_STRUCBAL_REC diff_STRUCBAL_NREC TOTAL_REC TOTAL_NREC
gen diff_STRUCBAL_REC  = recession * `shock_base'
gen TOTAL_REC  = recession * `instr_base'

local shock_REC  diff_STRUCBAL_REC

*------------------------
* Run LP-IV + graphs
*------------------------
local ivar = 1
foreach var in `vars' {

    local cntrls `cntrls_`var''

    * preallocate IRF storage (REC + NREC)
    capture drop biv`var'_REC up90biv`var'_REC lo90biv`var'_REC up68biv`var'_REC lo68biv`var'_REC
    capture drop biv`var'_NREC up90biv`var'_NREC lo90biv`var'_NREC up68biv`var'_NREC lo68biv`var'_NREC

    qui gen biv`var'_REC      = .
    qui gen up90biv`var'_REC  = .
    qui gen lo90biv`var'_REC  = .
    qui gen up68biv`var'_REC  = .
    qui gen lo68biv`var'_REC  = .


    forvalues i = 0/`horizon' {

        local iname `i'

        cap drop d`iname'`var'
        gen d`iname'`var' = F`i'.`var' - L.`var'

        * Guard against empty estimation sample
         ivreg2 d`iname'`var' ///
            (`shock_base' `shock_REC'  = `instr_base' TOTAL_REC) ///
            `cntrls' i.year i.country_id, ///
            dkraay(1) partial(i.year i.country_id)

        cap drop bR seR 
        gen bR  = _b[`shock_REC']
        gen seR = _se[`shock_REC']

        replace biv`var'_REC      = 100*bR if h==`i'
        replace up90biv`var'_REC  = 100*(bR + `z1'*seR) if h==`i'
        replace lo90biv`var'_REC  = 100*(bR - `z1'*seR) if h==`i'
        replace up68biv`var'_REC  = 100*(bR + `z2'*seR) if h==`i'
        replace lo68biv`var'_REC  = 100*(bR - `z2'*seR) if h==`i'

        drop bR seR 
    }

    cap drop zero
    gen zero = 0

    local varname : word `ivar' of `varsnames'
    local labname : word `ivar' of `labels'

    tw ///
        (rarea up90biv`var'_REC  lo90biv`var'_REC  h, fcolor("$mpurple%15") lwidth(none)) ///
        (rarea up68biv`var'_REC  lo68biv`var'_REC  h, fcolor("$mpurple%40") lwidth(none)) ///
        (line  biv`var'_REC  h, lcolor("$mpurple") lpattern(dash) lwidth(thick)) ///
        (line  zero h, lcolor(black) lpattern(solid) lwidth(medthick)) ///
        if h<=`horizon', ///
		title("`varname'", size($titlesize) col(black) margin(b=2)) ///
       xtitle("Years", size(`subtitlesize')) ///
       ytitle("`labname'", size(`subtitlesize')) ///
       xlabel(0(1)`horizon', labsize(`labelsize')) ///
	   ylabel(, labsize(`labelsize')) /// 
       plotregion(color(white)) ///
       graphregion(color(white)) ///
        legend(order(3 6) ///
               label(3 "Non-recession (RGROWTH >= 0)") ///
               label(6 "Recession (RGROWTH < 0)") ///
               rows(1) ring(0) position(6)) ///
        name("sdrec_iv_`var'", replace) ///
        saving("$FIGUREDIR/pirf_sdrec_iv_diff_`var'.gph", replace)

    graph export "$FIGUREDIR/pirf_sdrec_iv_diff_`var'.jpg", fontface($grfont) replace

    local ivar = `ivar' + 1
}


graph use "$FIGUREDIR/pirf_sdrec_iv_diff_log_PUBINV.gph",        name(g1, replace)
graph use "$FIGUREDIR/pirf_sdrec_iv_diff_log_GCONS.gph",         name(g2, replace)
graph use "$FIGUREDIR/pirf_sdrec_iv_diff_log_RATIO.gph",   name(g3, replace)

grc1leg2 g1 g2 g3, cols(3) ///
    loff ycommon ///
	ysize(`ysize') xsize(`xsize')  

graph export "$FIGUREDIRC/SD_BC_p20_diff.jpg",  replace


********************************************************************************
* BUSINESS CYCLE REGIME: recession vs non-recession (P40)
********************************************************************************

*------------------------
* Binary regime: recession vs non-recession
*------------------------
cap drop recession
generate recession = .
sum OGAP, detail
	cap drop pOGAP
	_pctile OGAP, p(40)
    gen pOGAP = r(r1)
replace recession = 1 if OGAP < pOGAP & !missing(OGAP)
replace recession = 0 if OGAP > pOGAP & !missing(OGAP)
tab recession


* Regime-specific endogenous + instruments
drop diff_STRUCBAL_REC TOTAL_REC 
gen diff_STRUCBAL_REC  = recession * `shock_base'
gen diff_STRUCBAL_NREC = (1 - recession) * `shock_base'
gen TOTAL_REC  = recession * `instr_base'
gen TOTAL_NREC = (1 - recession) * `instr_base'

local shock_REC  diff_STRUCBAL_REC
local shock_NREC diff_STRUCBAL_NREC

*------------------------
* Run LP-IV + graphs
*------------------------
local ivar = 1
foreach var in `vars' {

    local cntrls `cntrls_`var''

    * preallocate IRF storage (REC + NREC)
    capture drop biv`var'_REC up90biv`var'_REC lo90biv`var'_REC up68biv`var'_REC lo68biv`var'_REC
    capture drop biv`var'_NREC up90biv`var'_NREC lo90biv`var'_NREC up68biv`var'_NREC lo68biv`var'_NREC

    qui gen biv`var'_REC      = .
    qui gen up90biv`var'_REC  = .
    qui gen lo90biv`var'_REC  = .
    qui gen up68biv`var'_REC  = .
    qui gen lo68biv`var'_REC  = .

    qui gen biv`var'_NREC     = .
    qui gen up90biv`var'_NREC = .
    qui gen lo90biv`var'_NREC = .
    qui gen up68biv`var'_NREC = .
    qui gen lo68biv`var'_NREC = .

    forvalues i = 0/`horizon' {

        local iname `i'

        cap drop d`iname'`var'
        gen d`iname'`var' = F`i'.`var' - L.`var'

        * Guard against empty estimation sample
         ivreg2 d`iname'`var' ///
            (`shock_REC' `shock_NREC' = TOTAL_REC TOTAL_NREC) ///
            `cntrls' i.year i.country_id, ///
            dkraay(1) partial(i.year i.country_id)

        cap drop bR seR bN seN
        gen bR  = _b[`shock_REC']
        gen seR = _se[`shock_REC']
        gen bN  = _b[`shock_NREC']
        gen seN = _se[`shock_NREC']

        replace biv`var'_REC      = 100*bR if h==`i'
        replace up90biv`var'_REC  = 100*(bR + `z1'*seR) if h==`i'
        replace lo90biv`var'_REC  = 100*(bR - `z1'*seR) if h==`i'
        replace up68biv`var'_REC  = 100*(bR + `z2'*seR) if h==`i'
        replace lo68biv`var'_REC  = 100*(bR - `z2'*seR) if h==`i'

        replace biv`var'_NREC     = 100*bN if h==`i'
        replace up90biv`var'_NREC = 100*(bN + `z1'*seN) if h==`i'
        replace lo90biv`var'_NREC = 100*(bN - `z1'*seN) if h==`i'
        replace up68biv`var'_NREC = 100*(bN + `z2'*seN) if h==`i'
        replace lo68biv`var'_NREC = 100*(bN - `z2'*seN) if h==`i'

        drop bR seR bN seN
    }

    cap drop zero
    gen zero = 0

    local varname : word `ivar' of `varsnames'
    local labname : word `ivar' of `labels'

    tw ///
        (rarea up90biv`var'_NREC lo90biv`var'_NREC h, fcolor("$mblue%15") lwidth(none)) ///
        (rarea up68biv`var'_NREC lo68biv`var'_NREC h, fcolor("$mblue%40") lwidth(none)) ///
        (line  biv`var'_NREC h, lcolor("$mblue") lpattern(solid) lwidth(thick)) ///
        (rarea up90biv`var'_REC  lo90biv`var'_REC  h, fcolor("$mdred%15") lwidth(none)) ///
        (rarea up68biv`var'_REC  lo68biv`var'_REC  h, fcolor("$mdred%40") lwidth(none)) ///
        (line  biv`var'_REC  h, lcolor("$mdred") lpattern(dash) lwidth(thick)) ///
        (line  zero h, lcolor("$mred") lpattern(solid) lwidth(medthick)) ///
        if h<=`horizon', ///
		title("`varname'", size($titlesize) col(black) margin(b=2)) ///
       xtitle("Years", size(`subtitlesize')) ///
       ytitle("`labname'", size(`subtitlesize')) ///
       xlabel(0(1)`horizon', labsize(`labelsize')) ///
	   ylabel(, labsize(`labelsize')) /// 
       plotregion(color(white)) ///
       graphregion(color(white)) ///
        legend(order(3 6) ///
               label(3 "Non-recession (RGROWTH >= 0)") ///
               label(6 "Recession (RGROWTH < 0)") ///
               rows(1) ring(0) position(6)) ///
        name("sdrec_iv_`var'", replace) ///
        saving("$FIGUREDIR/pirf_sdrec_iv_`var'_p40.gph", replace)

    graph export "$FIGUREDIR/pirf_sdrec_iv_`var'_p40.jpg", fontface($grfont) replace

    local ivar = `ivar' + 1
}


graph use "$FIGUREDIR/pirf_sdrec_iv_log_PUBINV_p40.gph",        name(g1, replace)
graph use "$FIGUREDIR/pirf_sdrec_iv_log_GCONS_p40.gph",         name(g2, replace)
graph use "$FIGUREDIR/pirf_sdrec_iv_log_RATIO_p40.gph",   name(g3, replace)

grc1leg2 g1 g2 g3, cols(3) ///
    loff ycommon ///
	ysize(`ysize') xsize(`xsize')  

graph export "$FIGUREDIRC/SD_BC_p40.jpg",  replace


* horizons index helper
cap drop t h
gen t = _n
gen h = t - 1

cap program drop lpdiff
program define lpdiff
	syntax , statevar(varname) suffix(string)                     ///
	       [ horizon(integer 5) shock(varname) instr(varname)     ///
	         diffname(string) ]

	if "`shock'" == "" local shock diff_STRUCBAL
	if "`instr'" == "" local instr TOTAL
	if `"`diffname'"' == "" local diffname "State 1 - State 0"

	* sizes come from the globals at the top of the do-file
	foreach o in titlesize subtitlesize labelsize textsize ysize xsize {
		if "${`o'}" == "" {
			di as err "global `o' is not set -- define it at the top of the do-file"
			exit 198
		}
	}

	local vars      log_PUBINV log_GCONS log_RATIO
	local varsnames `" "Public investment" "Government consumption" "Investment ratio" "'
	local labels    `" "%" "%" "%" "'

	local cntrls_log_PUBINV L(1/1).RGROWTH L(1/1).RYIELD L(1/1).REER
	local cntrls_log_GCONS  L(1/1).RGROWTH L(1/1).RYIELD L(1/1).REER
	local cntrls_log_RATIO  L(1/1).RGROWTH L(1/1).RYIELD L(1/1).REER

	local z1 = abs(invnormal(0.10/2))
	local z2 = abs(invnormal(0.32/2))

	xtset country_id year
	
	cap drop shk_lvl shk_int ins_lvl ins_int
	qui gen double shk_lvl = `shock' if !missing(`statevar')
	qui gen double shk_int = `statevar' * `shock'
	qui gen double ins_lvl = `instr' if !missing(`statevar')
	qui gen double ins_int = `statevar' * `instr'

	cap drop t h
	qui gen t = _n
	qui gen h = t - 1
	cap drop zero
	qui gen zero = 0

	local ivar = 1
	foreach var in `vars' {
		local cntrls `cntrls_`var''

		* preallocate IRF storage (difference)
		capture drop biv`var'_D up90biv`var'_D lo90biv`var'_D up68biv`var'_D lo68biv`var'_D
		qui gen biv`var'_D     = .
		qui gen up90biv`var'_D = .
		qui gen lo90biv`var'_D = .
		qui gen up68biv`var'_D = .
		qui gen lo68biv`var'_D = .

		forvalues i = 0/`horizon' {
			local iname `i'
			cap drop d`iname'`var'
			qui gen double d`iname'`var' = F`i'.`var' - L.`var'

			qui ivreg2 d`iname'`var'                     ///
				(shk_lvl shk_int = ins_lvl ins_int)      ///
				`cntrls' i.year i.country_id,            ///
				dkraay(1) partial(i.year i.country_id)

			cap drop bD seD
			gen bD  = _b[shk_int]
			gen seD = _se[shk_int]

			qui replace biv`var'_D     = 100*bD if h==`i'
			qui replace up90biv`var'_D = 100*(bD + `z1'*seD) if h==`i'
			qui replace lo90biv`var'_D = 100*(bD - `z1'*seD) if h==`i'
			qui replace up68biv`var'_D = 100*(bD + `z2'*seD) if h==`i'
			qui replace lo68biv`var'_D = 100*(bD - `z2'*seD) if h==`i'

			drop bD seD
		}

		local varname : word `ivar' of `varsnames'
		local labname : word `ivar' of `labels'

		tw ///
			(rarea up90biv`var'_D lo90biv`var'_D h, fcolor("$mpurple%15") lwidth(none)) ///
			(rarea up68biv`var'_D lo68biv`var'_D h, fcolor("$mpurple%40") lwidth(none)) ///
			(line  biv`var'_D h, lcolor("$mpurple") lpattern(dash) lwidth(thick)) ///
			(line  zero h, lcolor(black) lpattern(solid) lwidth(medthick)) ///
			if h<=`horizon', ///
			title("`varname'", size($titlesize) col(black) margin(b=2)) ///
			xtitle("Years", size($subtitlesize)) ///
			ytitle("`labname'", size($subtitlesize)) ///
			xlabel(0(1)`horizon', labsize($labelsize)) ///
			ylabel(, labsize($labelsize)) ///
			plotregion(color(white)) ///
			graphregion(color(white)) ///
			legend(order(3 "`diffname'" 2 "68% CI" 1 "90% CI") ///
			       rows(1) ring(0) position(6) size($textsize) region(lcolor(none))) ///
			name("sd`suffix'_iv_`var'", replace) ///
			saving("$FIGUREDIR/pirf_`suffix'_`var'.gph", replace)

		graph export "$FIGUREDIR/pirf_`suffix'_`var'.jpg", fontface($grfont) replace

		local ivar = `ivar' + 1
	}

	graph use "$FIGUREDIR/pirf_`suffix'_log_PUBINV.gph", name(gd1, replace)
	graph use "$FIGUREDIR/pirf_`suffix'_log_GCONS.gph",  name(gd2, replace)
	graph use "$FIGUREDIR/pirf_`suffix'_log_RATIO.gph",  name(gd3, replace)

	grc1leg2 gd1 gd2 gd3, cols(3)  ysize($ysize) xsize($xsize) loff ycommon
	graph export "$FIGUREDIRC/StateDependence_`suffix'_Diff.jpg", replace
end



//////////////////////// STATE DEPENDENCE: 3% DEFICIT BREACH ////////////////////////

preserve

local vars log_PUBINV log_GCONS log_RATIO
local varsnames " "Public investment" "Government consumption" "Investment ratio" "
local labels    " "%""%""%""

local cntrls_log_PUBINV L(1/1).RGROWTH L(1/1).RYIELD L(1/1).REER
local cntrls_log_GCONS  L(1/1).RGROWTH L(1/1).RYIELD L(1/1).REER
local cntrls_log_RATIO  L(1/1).RGROWTH L(1/1).RYIELD L(1/1).REER

cap drop EDPState
gen EDPState = .
replace EDPState = 1 if EDP_breach == 1 & !missing(EDP_breach)
replace EDPState = 0 if EDP_breach == 0 & !missing(EDP_breach)

capture drop diff_STRUCBAL_R 
capture drop diff_STRUCBAL_E 
capture drop TOTAL_R 
capture drop TOTAL_E
gen diff_STRUCBAL_R = EDPState * `shock_base'
gen diff_STRUCBAL_E = (1 - EDPState) * `shock_base'
gen TOTAL_R = EDPState * `instr_base'
gen TOTAL_E = (1 - EDPState) * `instr_base'

xtset country_id year

local horizon = 5
local CI1 = 0.10
local CI2 = 0.32
local z1 = abs(invnormal(`CI1'/2))
local z2 = abs(invnormal(`CI2'/2))

local shock_R diff_STRUCBAL_R
local shock_E diff_STRUCBAL_E

global savefigs 1
global verb qui

drop t h
gen t = _n
gen h = t - 1

local ivar = 1
foreach var in `vars' {
	local cntrls `cntrls_`var''

	foreach st in R E {
		capture drop biv`var'_`st' up90biv`var'_`st' lo90biv`var'_`st' up68biv`var'_`st' lo68biv`var'_`st'
		qui gen biv`var'_`st'     = .
		qui gen up90biv`var'_`st' = .
		qui gen lo90biv`var'_`st' = .
		qui gen up68biv`var'_`st' = .
		qui gen lo68biv`var'_`st' = .
	}

	forvalues i = 0/`horizon' {
		local iname `i'
		cap drop d`iname'`var'
		gen d`iname'`var' = F`i'.`var' - L.`var'

		`verb' ivreg2 d`iname'`var' ///
			(diff_STRUCBAL_R diff_STRUCBAL_E = TOTAL_R TOTAL_E) ///
			`cntrls' i.year i.country_id, ///
			dkraay(1) partial(i.year i.country_id)

		foreach st in R E {
			cap drop biv`var'h`iname'_`st' seiv`var'h`iname'_`st'
			gen biv`var'h`iname'_`st'  = _b[`shock_`st'']
			gen seiv`var'h`iname'_`st' = _se[`shock_`st'']
			qui replace biv`var'_`st'     = 100*biv`var'h`iname'_`st' if h==`i'
			qui replace up90biv`var'_`st' = 100*(biv`var'h`iname'_`st' + `z1'*seiv`var'h`iname'_`st') if h==`i'
			qui replace lo90biv`var'_`st' = 100*(biv`var'h`iname'_`st' - `z1'*seiv`var'h`iname'_`st') if h==`i'
			qui replace up68biv`var'_`st' = 100*(biv`var'h`iname'_`st' + `z2'*seiv`var'h`iname'_`st') if h==`i'
			qui replace lo68biv`var'_`st' = 100*(biv`var'h`iname'_`st' - `z2'*seiv`var'h`iname'_`st') if h==`i'
		}
	}

	cap drop zero
	gen zero = 0
	local varname : word `ivar' of `varsnames'
	local labname : word `ivar' of `labels'
	tw (rarea up90biv`var'_E lo90biv`var'_E h, fcolor("$mblue%15")  lw(none)) ///
	   (rarea up68biv`var'_E lo68biv`var'_E h, fcolor("$mblue%40")  lw(none)) ///
	   (line  biv`var'_E h, lcolor("$mblue") lpattern(dash) lwidth(thick)) ///
	   (rarea up90biv`var'_R lo90biv`var'_R h, fcolor("$mdred%15") lw(none)) ///
	   (rarea up68biv`var'_R lo68biv`var'_R h, fcolor("$mdred%40") lw(none)) ///
	   (line  biv`var'_R h, lcolor("$mdred") lpattern(dash) lwidth(thick)) ///
	   (line  zero h, lcolor(black) lpattern(solid) lwidth(medthick)) if h<=`horizon', ///
		title("`varname'", size($titlesize) col(black) margin(b=2)) ///
			xtitle("Years", size($subtitlesize)) ///
			ytitle("`labname'", size($subtitlesize)) ///
			xlabel(0(1)`horizon', labsize($labelsize)) ///
			ylabel(, labsize($labelsize)) ///
			plotregion(color(white)) ///
			graphregion(color(white)) ///
			name("irfgs_`var'_ts", replace) ///
		legend(order(3 6) label(3 "below 3% deficit") label(6 "above 3% deficit") size($textsize) region(lcolor(none))) ///
		saving("$FIGUREDIR/pirf_iv_EDPBreachState_`var'.gph", replace)

	graph export "$FIGUREDIR\pirf_iv_EDPBreachState_`var'.pdf", replace

	local ivar = `ivar'+1
}

foreach stat in b se up90b lo90b up68b lo68b {
	capture drop `stat'
	capture drop `stat'*
}

graph use "$FIGUREDIR/pirf_iv_EDPBreachState_log_PUBINV.gph", name(g1, replace)
graph use "$FIGUREDIR/pirf_iv_EDPBreachState_log_GCONS.gph",  name(g2, replace)
graph use "$FIGUREDIR/pirf_iv_EDPBreachState_log_RATIO.gph",  name(g3, replace)

grc1leg2 g1 g2 g3, cols(3)   ysize($ysize) xsize($xsize) loff ycommon
graph export "$FIGUREDIRC/StateDependence_EDPBreachState.jpg", replace

* --- additional specification: difference between states ----------------------
lpdiff, statevar(EDPState) suffix(EDPBreach) horizon(`horizon') ///
        diffname("above - below 3% deficit")

restore


//////////////////////// STATE DEPENDENCE: PUBLIC DEBT (median split) ////////////////////////

preserve

local vars log_PUBINV log_GCONS log_RATIO
local varsnames " "Public investment" "Government consumption" "Investment ratio" "
local labels    " "%""%""%""

local cntrls_log_PUBINV L(1/1).RGROWTH L(1/1).RYIELD L(1/1).REER
local cntrls_log_GCONS  L(1/1).RGROWTH L(1/1).RYIELD L(1/1).REER
local cntrls_log_RATIO  L(1/1).RGROWTH L(1/1).RYIELD L(1/1).REER

* Median public-debt split
cap drop PDState
gen PDState = .
egen median_PDEBT = median(PDEBT)
replace PDState = 1 if PDEBT >= median_PDEBT & !missing(PDEBT)
replace PDState = 0 if PDEBT < median_PDEBT & !missing(PDEBT)

capture drop diff_STRUCBAL_R 
capture drop diff_STRUCBAL_E 
capture drop TOTAL_R 
capture drop TOTAL_E
gen diff_STRUCBAL_R = PDState * `shock_base'
gen diff_STRUCBAL_E = (1 - PDState) * `shock_base'
gen TOTAL_R = PDState * `instr_base'
gen TOTAL_E = (1 - PDState) * `instr_base'

xtset country_id year

local horizon = 5
local CI1 = 0.10
local CI2 = 0.32
local z1 = abs(invnormal(`CI1'/2))
local z2 = abs(invnormal(`CI2'/2))

local shock_R diff_STRUCBAL_R
local shock_E diff_STRUCBAL_E

global savefigs 1
global verb qui

drop t h
gen t = _n
gen h = t - 1

local ivar = 1
foreach var in `vars' {
	local cntrls `cntrls_`var''

	foreach st in R E {
		capture drop biv`var'_`st' up90biv`var'_`st' lo90biv`var'_`st' up68biv`var'_`st' lo68biv`var'_`st'
		qui gen biv`var'_`st'     = .
		qui gen up90biv`var'_`st' = .
		qui gen lo90biv`var'_`st' = .
		qui gen up68biv`var'_`st' = .
		qui gen lo68biv`var'_`st' = .
	}

	forvalues i = 0/`horizon' {
		local iname `i'
		cap drop d`iname'`var'
		gen d`iname'`var' = F`i'.`var' - L.`var'

		`verb' ivreg2 d`iname'`var' ///
			(diff_STRUCBAL_R diff_STRUCBAL_E = TOTAL_R TOTAL_E) ///
			`cntrls' i.year i.country_id, ///
			dkraay(1) partial(i.year i.country_id)

		foreach st in R E {
			cap drop biv`var'h`iname'_`st' seiv`var'h`iname'_`st'
			gen biv`var'h`iname'_`st'  = _b[`shock_`st'']
			gen seiv`var'h`iname'_`st' = _se[`shock_`st'']
			qui replace biv`var'_`st'     = 100*biv`var'h`iname'_`st' if h==`i'
			qui replace up90biv`var'_`st' = 100*(biv`var'h`iname'_`st' + `z1'*seiv`var'h`iname'_`st') if h==`i'
			qui replace lo90biv`var'_`st' = 100*(biv`var'h`iname'_`st' - `z1'*seiv`var'h`iname'_`st') if h==`i'
			qui replace up68biv`var'_`st' = 100*(biv`var'h`iname'_`st' + `z2'*seiv`var'h`iname'_`st') if h==`i'
			qui replace lo68biv`var'_`st' = 100*(biv`var'h`iname'_`st' - `z2'*seiv`var'h`iname'_`st') if h==`i'
		}
	}

	cap drop zero
	gen zero = 0
	local varname : word `ivar' of `varsnames'
	local labname : word `ivar' of `labels'
	tw (rarea up90biv`var'_E lo90biv`var'_E h, fcolor("$mblue%15")  lw(none)) ///
	   (rarea up68biv`var'_E lo68biv`var'_E h, fcolor("$mblue%40")  lw(none)) ///
	   (line  biv`var'_E h, lcolor("$mblue") lpattern(dash) lwidth(thick)) ///
	   (rarea up90biv`var'_R lo90biv`var'_R h, fcolor("$mdred%15") lw(none)) ///
	   (rarea up68biv`var'_R lo68biv`var'_R h, fcolor("$mdred%40") lw(none)) ///
	   (line  biv`var'_R h, lcolor("$mdred") lpattern(dash) lwidth(thick)) ///
	   (line  zero h, lcolor(black) lpattern(solid) lwidth(medthick)) if h<=`horizon', ///
		title("`varname'", size($titlesize) col(black) margin(b=2)) ///
			xtitle("Years", size($subtitlesize)) ///
			ytitle("`labname'", size($subtitlesize)) ///
			xlabel(0(1)`horizon', labsize($labelsize)) ///
			ylabel(, labsize($labelsize)) ///
			plotregion(color(white)) ///
			graphregion(color(white)) ///
			name("irfgs_`var'_ts", replace) ///
		legend(order(3 6) label(3 "PDEBT < median") label(6 "PDEBT >= median") size($textsize) region(lcolor(none))) ///
		saving("$FIGUREDIR/pirf_iv_PDState_`var'.gph", replace)

	graph export "$FIGUREDIR\pirf_iv_PDState_`var'.pdf", replace

	local ivar = `ivar'+1
}

foreach stat in b se up90b lo90b up68b lo68b {
	capture drop `stat'
	capture drop `stat'*
}

graph use "$FIGUREDIR/pirf_iv_PDState_log_PUBINV.gph", name(g1, replace)
graph use "$FIGUREDIR/pirf_iv_PDState_log_GCONS.gph",  name(g2, replace)
graph use "$FIGUREDIR/pirf_iv_PDState_log_RATIO.gph",  name(g3, replace)

grc1leg2 g1 g2 g3, cols(3)   ysize($ysize) xsize($xsize) loff ycommon
graph export "$FIGUREDIRC/StateDependence_PDState.jpg", replace

* --- additional specification: difference between states ----------------------
lpdiff, statevar(PDState) suffix(PDebt) horizon(`horizon') ///
        diffname("high - low public debt")

restore

//////////////////////// STATE DEPENDENCE: POLITICAL FRAGMENTATION ////////////////////////

// USA is not included

preserve

local vars log_PUBINV log_GCONS log_RATIO
local varsnames " "Public investment" "Government consumption" "Investment ratio" "
local labels    " "%""%""%""

local cntrls_log_PUBINV L(1/1).RGROWTH L(1/1).RYIELD L(1/1).REER
local cntrls_log_GCONS  L(1/1).RGROWTH L(1/1).RYIELD L(1/1).REER
local cntrls_log_RATIO  L(1/1).RGROWTH L(1/1).RYIELD L(1/1).REER

* Median public-debt split
egen med_frag = median(frag_parl)
gen byte high_frag_d = frag_parl > med_frag if !missing(frag_parl)

capture drop diff_STRUCBAL_R 
capture drop diff_STRUCBAL_E 
capture drop TOTAL_R 
capture drop TOTAL_E
gen diff_STRUCBAL_R = high_frag_d * `shock_base'
gen diff_STRUCBAL_E = (1 - high_frag_d) * `shock_base'
gen TOTAL_R = high_frag_d * `instr_base'
gen TOTAL_E = (1 - high_frag_d) * `instr_base'

xtset country_id year

local horizon = 5
local CI1 = 0.10
local CI2 = 0.32
local z1 = abs(invnormal(`CI1'/2))
local z2 = abs(invnormal(`CI2'/2))

local shock_R diff_STRUCBAL_R
local shock_E diff_STRUCBAL_E

global savefigs 1
global verb qui

drop t h
gen t = _n
gen h = t - 1

local ivar = 1
foreach var in `vars' {
	local cntrls `cntrls_`var''

	foreach st in R E {
		capture drop biv`var'_`st' up90biv`var'_`st' lo90biv`var'_`st' up68biv`var'_`st' lo68biv`var'_`st'
		qui gen biv`var'_`st'     = .
		qui gen up90biv`var'_`st' = .
		qui gen lo90biv`var'_`st' = .
		qui gen up68biv`var'_`st' = .
		qui gen lo68biv`var'_`st' = .
	}

	forvalues i = 0/`horizon' {
		local iname `i'
		cap drop d`iname'`var'
		gen d`iname'`var' = F`i'.`var' - L.`var'

		`verb' ivreg2 d`iname'`var' ///
			(diff_STRUCBAL_R diff_STRUCBAL_E = TOTAL_R TOTAL_E) ///
			`cntrls' i.year i.country_id, ///
			dkraay(1) partial(i.year i.country_id)

		foreach st in R E {
			cap drop biv`var'h`iname'_`st' seiv`var'h`iname'_`st'
			gen biv`var'h`iname'_`st'  = _b[`shock_`st'']
			gen seiv`var'h`iname'_`st' = _se[`shock_`st'']
			qui replace biv`var'_`st'     = 100*biv`var'h`iname'_`st' if h==`i'
			qui replace up90biv`var'_`st' = 100*(biv`var'h`iname'_`st' + `z1'*seiv`var'h`iname'_`st') if h==`i'
			qui replace lo90biv`var'_`st' = 100*(biv`var'h`iname'_`st' - `z1'*seiv`var'h`iname'_`st') if h==`i'
			qui replace up68biv`var'_`st' = 100*(biv`var'h`iname'_`st' + `z2'*seiv`var'h`iname'_`st') if h==`i'
			qui replace lo68biv`var'_`st' = 100*(biv`var'h`iname'_`st' - `z2'*seiv`var'h`iname'_`st') if h==`i'
		}
	}

	cap drop zero
	gen zero = 0
	local varname : word `ivar' of `varsnames'
	local labname : word `ivar' of `labels'
	tw (rarea up90biv`var'_E lo90biv`var'_E h, fcolor("$mblue%15")  lw(none)) ///
	   (rarea up68biv`var'_E lo68biv`var'_E h, fcolor("$mblue%40")  lw(none)) ///
	   (line  biv`var'_E h, lcolor("$mblue") lpattern(dash) lwidth(thick)) ///
	   (rarea up90biv`var'_R lo90biv`var'_R h, fcolor("$mdred%15") lw(none)) ///
	   (rarea up68biv`var'_R lo68biv`var'_R h, fcolor("$mdred%40") lw(none)) ///
	   (line  biv`var'_R h, lcolor("$mdred") lpattern(dash) lwidth(thick)) ///
	   (line  zero h, lcolor(black) lpattern(solid) lwidth(medthick)) if h<=`horizon', ///
		title("`varname'", size($titlesize) col(black) margin(b=2)) ///
			xtitle("Years", size($subtitlesize)) ///
			ytitle("`labname'", size($subtitlesize)) ///
			xlabel(0(1)`horizon', labsize($labelsize)) ///
			ylabel(, labsize($labelsize)) ///
			plotregion(color(white)) ///
			graphregion(color(white)) ///
			name("irfgs_`var'_ts", replace) ///
		legend(order(3 6) label(3 "low fragmentation") label(6 "high fragmentation") size($textsize) region(lcolor(none))) ///
		saving("$FIGUREDIR/pirf_iv_FragState_`var'.gph", replace)

	graph export "$FIGUREDIR\pirf_iv_FragState_`var'.pdf", replace

	local ivar = `ivar'+1
}

foreach stat in b se up90b lo90b up68b lo68b {
	capture drop `stat'
	capture drop `stat'*
}

graph use "$FIGUREDIR/pirf_iv_FragState_log_PUBINV.gph", name(g1, replace)
graph use "$FIGUREDIR/pirf_iv_FragState_log_GCONS.gph",  name(g2, replace)
graph use "$FIGUREDIR/pirf_iv_FragState_log_RATIO.gph",  name(g3, replace)

grc1leg2 g1 g2 g3, cols(3)   ysize($ysize) xsize($xsize) loff ycommon
graph export "$FIGUREDIRC/StateDependence_FragState.jpg", replace

* --- additional specification: difference between states ----------------------
lpdiff, statevar(high_frag_d) suffix(Frag) horizon(`horizon') ///
        diffname("high - low fragmentation")

restore
