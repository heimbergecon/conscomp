
local titlesize   9
local subtitlesize 7
local labelsize    7
local textsize     7
local ysize		3
local xsize 	9

local horizon = 5
local estdiff  = 2

local CI1 = 0.10
local CI2 = 0.32
local z1  = abs(invnormal(`CI1'/2))
local z2  = abs(invnormal(`CI2'/2))

local shock diff_STRUCBAL
local instr TOTAL

* response variables
local vars log_PUBINV log_GCONS log_RATIO
local varsnames `" "Public investment" "Government consumption" "Ratio" "'
local labels    `" "%" "%" "%" "'

* controls: 1 lag each; NO lag of response variable (matches R first-stage)
local cntrls_log_PUBINV L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).D.log_PUBINV
local cntrls_log_GCONS L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).D.log_GCONS 
local cntrls_log_RATIO L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).D.log_RATIO

global verb qui

* horizons index helper
cap drop t h
gen t = _n
gen h = t - 1

//========================
// Run LPs: IV + OLS, store IRFs, update global y-range
//========================
local ivar = 1
foreach var in `vars' {

    local cntrls `cntrls_`var''

    * preallocate IRFs: IV + OLS
    cap drop biv`var' up90biv`var' lo90biv`var' up68biv`var' lo68biv`var'
    cap drop bols`var' up90bols`var' lo90bols`var' up68bols`var' lo68bols`var'

    qui gen biv`var'      = .
    qui gen up90biv`var'  = .
    qui gen lo90biv`var'  = .
    qui gen up68biv`var'  = .
    qui gen lo68biv`var'  = .

    qui gen bols`var'      = .
    qui gen up90bols`var'  = .
    qui gen lo90bols`var'  = .
    qui gen up68bols`var'  = .
    qui gen lo68bols`var'  = .

    forvalues i = 0/`horizon' {

        local iname `i'

        * cumulative change t-1 to t+i (log units)
        cap drop d`iname'`var'
        gen d`iname'`var' = F`i'.`var' - L.`var'

        * IV
        ivreg2 d`iname'`var' ///
            (`shock' = `instr') ///
            `cntrls' i.year i.country_id, ///
            dkraay(1) partial(i.year i.country_id)

        cap drop btmp setmp
        gen btmp  = _b[`shock']
        gen setmp = _se[`shock']

        qui replace biv`var'     = 100*btmp if h==`i'
        qui replace up90biv`var' = 100*(btmp + `z1'*setmp) if h==`i'
        qui replace lo90biv`var' = 100*(btmp - `z1'*setmp) if h==`i'
        qui replace up68biv`var' = 100*(btmp + `z2'*setmp) if h==`i'
        qui replace lo68biv`var' = 100*(btmp - `z2'*setmp) if h==`i'
        drop btmp setmp

        * OLS (same FE + DK SE)
        ivreg2 d`iname'`var' ///
            `shock' `cntrls' i.year i.country_id, ///
            dkraay(1) partial(i.year i.country_id)

        cap drop btmp setmp
        gen btmp  = _b[`shock']
        gen setmp = _se[`shock']

        qui replace bols`var'     = 100*btmp if h==`i'
        qui replace up90bols`var' = 100*(btmp + `z1'*setmp) if h==`i'
        qui replace lo90bols`var' = 100*(btmp - `z1'*setmp) if h==`i'
        qui replace up68bols`var' = 100*(btmp + `z2'*setmp) if h==`i'
        qui replace lo68bols`var' = 100*(btmp - `z2'*setmp) if h==`i'
        drop btmp setmp
    }

    local ivar = `ivar' + 1
}


//========================
// Plot: three panels, IV + OLS overlaid, COMMON y scale
//========================
local ivar = 1
foreach var in `vars' {

    cap drop zero
    gen zero = 0

    local varname : word `ivar' of `varsnames'
    local labname : word `ivar' of `labels'

    tw ///
        (rarea up90biv`var'  lo90biv`var'  h, fcolor("$mblue%12") lwidth(none)) ///
        (rarea up68biv`var'  lo68biv`var'  h, fcolor("$mblue%30") lwidth(none)) ///
        (line  biv`var'      h, lcolor("$mblue")  lpattern(solid) lwidth(thick)) ///
        (rarea up90bols`var' lo90bols`var' h, fcolor("$mdred%10") lwidth(none)) ///
        (rarea up68bols`var' lo68bols`var' h, fcolor("$mdred%25") lwidth(none)) ///
        (line  bols`var'     h, lcolor("$mdred") lpattern(dash)  lwidth(thick)) ///
        (line  zero          h, lcolor("$mred")  lpattern(solid) lwidth(medthick)) ///
        if h<=`horizon', ///
               title("`varname'", size(`titlesize') col(black) margin(b=2)) ///
       xtitle("Years", size(`subtitlesize')) ///
       ytitle("`labname'", size(`subtitlesize')) ///
       xlabel(0(2)`horizon', labsize(`labelsize')) ///
	   ylabel(, labsize(`labelsize')) /// 
       plotregion(color(white)) ///
       graphregion(color(white)) ///
        legend(order(3 6) label(3 "IV") label(6 "OLS") rows(1) ring(0) position(6)) ///
        name("ivols_`var'", replace) ///
        saving("$FIGUREDIR/pirf_ivols_`var'.gph", replace)

    graph export "$FIGUREDIR/pirf_ivols_`var'.jpg", fontface($grfont) replace

    local ivar = `ivar' + 1
}

*========================
* Combine into one 3-panel figure (y already common)
*========================

graph use "$FIGUREDIR/pirf_ivols_log_PUBINV.gph",        name(g1, replace)
graph use "$FIGUREDIR/pirf_ivols_log_GCONS.gph",         name(g2, replace)
graph use "$FIGUREDIR/pirf_ivols_log_RATIO.gph",   name(g3, replace)

grc1leg2 g1 g2 g3, cols(3) ///
    loff ycommon ///
	ysize(3) xsize(12) 

graph export "$FIGUREDIRC/HEADLINE_iv_ols.jpg",  replace

//========================
// Plot: just IV
//========================
local ivar = 1
foreach var in `vars' {

    cap drop zero
    gen zero = 0

    local varname : word `ivar' of `varsnames'
    local labname : word `ivar' of `labels'

    tw ///
        (rarea up90biv`var'  lo90biv`var'  h, fcolor("$mblue%12") lwidth(none)) ///
        (rarea up68biv`var'  lo68biv`var'  h, fcolor("$mblue%30") lwidth(none)) ///
        (line  biv`var'      h, lcolor("$mblue")  lpattern(solid) lwidth(thick)) ///
        (line  zero          h, lcolor("$mred")  lpattern(solid) lwidth(medthick)) ///
        if h<=`horizon', ///
              title("`varname'", size(`titlesize') col(black) margin(b=2)) ///
       xtitle("Years", size(`subtitlesize')) ///
       ytitle("`labname'", size(`subtitlesize')) ///
       xlabel(0(2)`horizon', labsize(`labelsize')) ///
	   ylabel(, labsize(`labelsize')) /// 
       plotregion(color(white)) ///
       graphregion(color(white)) ///
        name("iv_`var'", replace) ///
        saving("$FIGUREDIR/pirf_iv_`var'.gph", replace)

    graph export "$FIGUREDIR/pirf_iv_`var'.jpg", replace

    local ivar = `ivar' + 1
}

*========================
* Combine into one 3-panel figure (y already common)
*========================
graph use "$FIGUREDIR/pirf_iv_log_PUBINV.gph",        name(g1, replace)
graph use "$FIGUREDIR/pirf_iv_log_GCONS.gph",         name(g2, replace)
graph use "$FIGUREDIR/pirf_iv_log_RATIO.gph",   name(g3, replace)

grc1leg2 g1 g2 g3, cols(3) ///
    loff ycommon ///
	ysize(`ysize') xsize(`xsize') 

graph export "$FIGUREDIRC/HEADLINE_iv.jpg", replace


preserve
keep h bivlog_PUBINV up90bivlog_PUBINV lo90bivlog_PUBINV up68bivlog_PUBINV lo68bivlog_PUBINV bivlog_GCONS up90bivlog_GCONS  lo90bivlog_GCONS up68bivlog_GCONS lo68bivlog_GCONS bivlog_RATIO up90bivlog_RATIO lo90bivlog_RATIO up68bivlog_RATIO lo68bivlog_RATIO 
		
export excel using "$TABLEDIR\EMPNIII_MainResult.xlsx", replace firstrow(variables)
restore	