
local titlesize   9
local subtitlesize 7
local labelsize    7
local textsize     7
local ysize		3
local xsize 	9

* response variables
local vars log_PUBINV log_GCONS log_RATIO
local varsnames `" "Public investment" "Government consumption" "Ratio" "'
local labels    `" "%" "%" "%" "'
local cntrls_log_PUBINV L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).D.log_PUBINV
local cntrls_log_GCONS L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).D.log_GCONS 
local cntrls_log_RATIO L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).D.log_RATIO

local horizon = 5
local estdiff = 2   // not used here; kept to mirror baseline style

local CI1 = 0.10
local CI2 = 0.32
local z1  = abs(invnormal(`CI1'/2))   // 90%
local z2  = abs(invnormal(`CI2'/2))   // 68%

local shock diff_STRUCBAL
local instr TOTAL


********************************************************************************
* ONLY EU COUNTRIES
********************************************************************************
preserve

keep if ccode=="AUT" | ccode=="BEL" | ccode=="DEU" | ccode=="DNK" | ccode=="ESP" | ccode=="FIN" | ccode=="FRA" | ccode=="IRL" | ccode=="ITA" | ccode=="NLD" | ccode=="PRT" | ccode=="SWE" 

* horizons index helper
cap drop t h
gen t = _n
gen h = t - 1


local ivar = 1
foreach var in `vars' {

    local cntrls `cntrls_`var''

    * preallocate IRFs: IV + OLS
    cap drop biv`var' up90biv`var' lo90biv`var' up68biv`var' lo68biv`var'

    qui gen biv`var'      = .
    qui gen up90biv`var'  = .
    qui gen lo90biv`var'  = .
    qui gen up68biv`var'  = .
    qui gen lo68biv`var'  = .

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

    }

    local ivar = `ivar' + 1
}

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
        saving("$FIGUREDIR/pirf_iv_`var'_EU.gph", replace)

    graph export "$FIGUREDIR/pirf_iv_`var'_EU.jpg", replace

    local ivar = `ivar' + 1
}

*========================
* Combine into one 3-panel figure (y already common)
*========================
graph use "$FIGUREDIR/pirf_iv_log_PUBINV_EU.gph",        name(g1, replace)
graph use "$FIGUREDIR/pirf_iv_log_GCONS_EU.gph",         name(g2, replace)
graph use "$FIGUREDIR/pirf_iv_log_RATIO_EU.gph",   name(g3, replace)

grc1leg2 g1 g2 g3, cols(3) ///
    loff ycommon ///
	ysize(`ysize') xsize(`xsize') 

graph export "$FIGUREDIRC/Robustness_EU.jpg", replace

restore

********************************************************************************
* IV Local Projections - Spending effects
* Robustness: LEAVE-ONE-COUNTRY-OUT
********************************************************************************

*--- keep the estimation sample safe: we switch datasets further down ---------
tempfile maindata
qui save "`maindata'", replace

levelsof ccode, local(allcc) clean
di as text "Leave-one-out over: `allcc'"

tempname pf
tempfile results

postfile `pf' str8 dropped str16 depvar byte h ///
    double(b up90 lo90 up68 lo68) using "`results'", replace

foreach cc in NONE `allcc' {

    preserve

    if "`cc'" != "NONE" drop if ccode == "`cc'"

    sort country_id year
    cap drop t h
    qui gen t = _n
    qui gen h = t - 1

    foreach var in `vars' {

        local cntrls `cntrls_`var''

        forvalues i = 0/`horizon' {

            * cumulative change t-1 to t+i (log units)
            cap drop dtmp
            qui gen dtmp = F`i'.`var' - L.`var'

            capture qui ivreg2 dtmp ///
                (`shock' = `instr') ///
                `cntrls' i.year i.country_id, ///
                dkraay(1) partial(i.year i.country_id)

            local rc = _rc

            if `rc' {
                di as error "  failed: drop `cc' | `var' | h=`i' | rc=`rc'"
                post `pf' ("`cc'") ("`var'") (`i') (.) (.) (.) (.) (.)
            }
            else {
                local bb = _b[`shock']
                local ss = _se[`shock']
                post `pf' ("`cc'") ("`var'") (`i') ///
                    (100*`bb') ///
                    (100*(`bb' + `z1'*`ss')) (100*(`bb' - `z1'*`ss')) ///
                    (100*(`bb' + `z2'*`ss')) (100*(`bb' - `z2'*`ss'))
            }

            cap drop dtmp
        }
    }

    restore
    di as text "done: leave out `cc'"
}

postclose `pf'


use "`results'", clear
qui save "$DATA/robustness_leaveoneout.dta", replace

gen zero = 0

* common y-range within each COLUMN (comparable across rows, not across
* variables - log_RATIO is on a much smaller scale than the two levels)
foreach var in `vars' {
    qui summarize lo90 if depvar=="`var'", meanonly
    local lo = r(min)
    qui summarize up90 if depvar=="`var'", meanonly
    local hi = r(max)
    local pad = 0.05*(`hi' - `lo')
    local ymin_`var' = `lo' - `pad'
    local ymax_`var' = `hi' + `pad'
}

* row order: baseline first, then countries alphabetically
levelsof dropped if dropped!="NONE", local(rows) clean
local rows NONE `rows'
local nrows : word count `rows'

graph drop _all
local combine ""
local irow = 1

foreach cc of local rows {

    local rowlab "`cc'"
    if "`cc'"=="NONE" local rowlab "Baseline"

    local ivar = 1
    foreach var in `vars' {

        local varname : word `ivar' of `varsnames'

        * variable titles only on the top row
        if `irow'==1 local ttl title("`varname'", size(`titlesize') col(black) margin(b=2))
        else         local ttl ""

        * country label only in the first column
        if `ivar'==1 local ytl ytitle("`rowlab'", size(`subtitlesize'))
        else         local ytl ytitle("")

        * x title only on the bottom row
        if `irow'==`nrows' local xtl xtitle("Years", size(`subtitlesize'))
        else               local xtl xtitle("")

        tw ///
            (rarea up90 lo90 h if dropped=="`cc'" & depvar=="`var'", fcolor("$mblue%12") lwidth(none)) ///
            (rarea up68 lo68 h if dropped=="`cc'" & depvar=="`var'", fcolor("$mblue%30") lwidth(none)) ///
            (line  b    h      if dropped=="`cc'" & depvar=="`var'", lcolor("$mblue") lpattern(solid) lwidth(medthick)) ///
            (line  zero h      if dropped=="`cc'" & depvar=="`var'", lcolor("$mred")  lpattern(solid) lwidth(medium)) ///
            , `ttl' `xtl' `ytl' ///
              xlabel(0(2)`horizon', labsize(`labelsize')) ///
              ylabel(, labsize(`labelsize')) ///
              yscale(range(`ymin_`var'' `ymax_`var'')) ///
              legend(off) ///
              plotregion(color(white)) graphregion(color(white)) ///
              name(p`irow'_`ivar', replace) nodraw

        local combine `combine' p`irow'_`ivar'
        local ivar = `ivar' + 1
    }

    local irow = `irow' + 1
}

graph combine `combine', cols(3) imargin(vsmall) ///
    graphregion(color(white)) ///
    ysize(`=1.6*`nrows'') xsize(9)

graph export "$FIGUREDIRC/Robustness_LeaveOneOut.jpg", width(2500) replace

* all leave-one-out paths overlaid in 3 panels
use "$DATA/robustness_leaveoneout.dta", clear
gen zero = 0
encode dropped, gen(dropid)
sort depvar dropid h

graph drop _all
local ivar = 1

foreach var in `vars' {

    local varname : word `ivar' of `varsnames'
    local labname : word `ivar' of `labels'

    tw ///
        (line b    h if depvar=="`var'" & dropped!="NONE", ///
              connect(ascending) lcolor(gs11) lwidth(vthin)) ///
        (line b    h if depvar=="`var'" & dropped=="NONE", ///
              lcolor("$mblue") lpattern(solid) lwidth(thick)) ///
        (line zero h if depvar=="`var'" & dropped=="NONE", ///
              lcolor("$mred") lpattern(solid) lwidth(medthick)) ///
        , title("`varname'", size(`titlesize') col(black) margin(b=2)) ///
          xtitle("Years", size(`subtitlesize')) ///
          ytitle("`labname'", size(`subtitlesize')) ///
          xlabel(0(2)`horizon', labsize(`labelsize')) ///
          ylabel(, labsize(`labelsize')) ///
          legend(off) ///
          plotregion(color(white)) graphregion(color(white)) ///
          name(loo_`ivar', replace) nodraw

    local ivar = `ivar' + 1
}

graph combine loo_1 loo_2 loo_3, cols(3) ///
    graphregion(color(white)) ///
    ysize(`ysize') xsize(`xsize')

graph export "$FIGUREDIRC/Robustness_LeaveOneOut_overlay.jpg", width(2500) replace

*--- back to the estimation sample -------------------------------------------
use "`maindata'", clear
xtset country_id year, yearly
