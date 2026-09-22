
local titlesize   10
local subtitlesize 7
local labelsize    7
local textsize     7
local ysize		3
local xsize 	9

local horizon = 5

local CI1 = 0.10
local CI2 = 0.32
local z1  = abs(invnormal(`CI1'/2))
local z2  = abs(invnormal(`CI2'/2))

local treat TOTAL_binary

* response variables
local vars log_PUBINV log_GCONS log_RATIO
local varsnames `" "Public investment" "Government consumption" "Ratio" "'
local labels    `" "%" "%" "%" "'
local cntrls_log_PUBINV L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).D.log_PUBINV
local cntrls_log_GCONS L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).D.log_GCONS 
local cntrls_log_RATIO L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds L(1/1).D.log_RATIO


* horizons helper (one observation per horizon for plotting)
capture drop t h
gen t = _n
gen h = t - 1

//========================
// Propensity score (ONE model, used for all outcomes)
//========================
* Choose whether to truncate propensity scores (OFF by default to mimic your "no truncation" AIPW block)
local TRUNCATE = 0   // set to 1 to truncate pihat into [0.1, 0.9]

capture drop pihat0 pihat a invwt

* Probit with same controls + FE (country/year), as in your AIPW template structure
* (We do NOT include L.`treat' here to avoid "bad control" dynamics unless you explicitly want it.)
$verb xi: probit `treat' ///
    L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds ///
    i.country_id i.year
	outreg2 using "$TABLEDIR\probit_results_`aipwvar'.xls", excel replace ///
    se dec(3) label

* raw propensity score
predict pihat0, pr

* optional truncation
gen pihat = pihat0
if `TRUNCATE'==1 {
    replace pihat = .9 if pihat>.9 & pihat<.
    replace pihat = .1 if pihat<.1 & pihat<.
}

* treatment indicator "a" and inverse weights (Lunt et al.)
gen a = `treat'
gen invwt = a/pihat0 + (1-a)/(1-pihat0) if pihat0<.   // no truncation weights by default

* panel again
sort country_id year
xtset country_id year

//========================
// Storage for common y-axis range across ALL panels
//========================
scalar ymin_all = .
scalar ymax_all = .

capture program drop __upd_ybounds
program define __upd_ybounds
    args lovar upvar
    quietly summarize `lovar', meanonly
    scalar __lo = r(min)
    quietly summarize `upvar', meanonly
    scalar __up = r(max)

    if missing(ymin_all) | __lo < ymin_all scalar ymin_all = __lo
    if missing(ymax_all) | __up > ymax_all scalar ymax_all = __up
end

//========================
// Run LPs: AIPW, store IRFs, update global y-range
//========================
local ivar = 1
foreach var in `vars' {

    local cntrls `cntrls_`var''

    * preallocate IRFs for this outcome
    cap drop bAIPW_`var' up90bAIPW_`var' lo90bAIPW_`var' up68bAIPW_`var' lo68bAIPW_`var'
    qui gen bAIPW_`var'      = .
    qui gen up90bAIPW_`var'  = .
    qui gen lo90bAIPW_`var'  = .
    qui gen up68bAIPW_`var'  = .
    qui gen lo68bAIPW_`var'  = .

    forvalues i = 0/`horizon' {

        local iname `i'

        * cumulative change t-1 to t+i (log units)
        cap drop d`iname'`var'
        gen d`iname'`var' = F`i'.`var' - L.`var'

        * outcome regression (common slopes), weighted by invwt, with FE and same controls
        * (cluster at country level as in your AIPW template)
        $verb reg d`iname'`var' `treat' `cntrls' i.country_id i.year ///
            [pweight=invwt], cluster(country_id)

        * define estimation sample
        cap drop samp
        gen samp = e(sample)

        * predicted outcome under observed treatment (mu0/mu1 then "ghost" potential outcomes)
        cap drop mu0 mu1
        gen mu0 = .
        gen mu1 = .

        predict __mu if samp==1
        replace mu0 = __mu if samp==1 & `treat'==0
        replace mu1 = __mu if samp==1 & `treat'==1
        drop __mu

        * ghost counterfactuals using treatment coefficient
        replace mu0 = mu1 - _b[`treat'] if samp==1 & `treat'==1
        replace mu1 = mu0 + _b[`treat'] if samp==1 & `treat'==0

        * Doubly-robust score components (use pihat0 per "no truncation" design)
        cap drop mdiff1 iptw dr1
        gen mdiff1 = (-(a-pihat0)*mu1/pihat0) - ((a-pihat0)*mu0/(1-pihat0))
        gen iptw   = (2*a-1)*d`iname'`var'*invwt
        gen dr1    = iptw + mdiff1

        * Mean(dr1) via regression on constant; clustered SE
        cap drop ATE_IPWRA
        gen ATE_IPWRA = 1
        $verb reg dr1 ATE_IPWRA, nocons cluster(country_id)

        local b  = _b[ATE_IPWRA]
        local se = _se[ATE_IPWRA]

        qui replace bAIPW_`var'     = 100*`b' if h==`i'
        qui replace up90bAIPW_`var' = 100*(`b' + `z1'*`se') if h==`i'
        qui replace lo90bAIPW_`var' = 100*(`b' - `z1'*`se') if h==`i'
        qui replace up68bAIPW_`var' = 100*(`b' + `z2'*`se') if h==`i'
        qui replace lo68bAIPW_`var' = 100*(`b' - `z2'*`se') if h==`i'

        * clean horizon temp vars (keep only stored series)
        cap drop samp mu0 mu1 mdiff1 iptw dr1 ATE_IPWRA
    }

    * update common y-bounds using 90% band for this panel
    __upd_ybounds lo90bAIPW_`var' up90bAIPW_`var'

    local ivar = `ivar' + 1
}

* add padding to y-limits
scalar ypad = 0.05*(ymax_all - ymin_all)
scalar ymin_all = ymin_all - ypad
scalar ymax_all = ymax_all + ypad

//========================
// Plot: three panels, COMMON y scale (AIPW only)
//========================
local ivar = 1
foreach var in `vars' {

    cap drop zero
    gen zero = 0

    local varname : word `ivar' of `varsnames'
    local labname : word `ivar' of `labels'

    tw ///
        (rarea up90bAIPW_`var'  lo90bAIPW_`var'  h, fcolor("$mblue%12") lwidth(none)) ///
        (rarea up68bAIPW_`var'  lo68bAIPW_`var'  h, fcolor("$mblue%30") lwidth(none)) ///
        (line  bAIPW_`var'      h, lcolor("$mblue") lpattern(solid) lwidth(thick)) ///
        (line  zero            h, lcolor("$mred")  lpattern(solid) lwidth(medthick)) ///
        if h<=`horizon', ///
        title("`varname'", size(`titlesize') col(black) margin(b=2)) ///
       xtitle("Years", size(`subtitlesize')) ///
       ytitle("`labname'", size(`subtitlesize')) ///
       xlabel(0(1)`horizon', labsize(`labelsize')) ///
	   ylabel(, labsize(`labelsize')) /// 
       plotregion(color(white)) ///
       graphregion(color(white)) ///
       legend(off) ///
        legend(order(3) label(3 "AIPW") rows(1) ring(0) position(6)) ///
        name("aipw_`var'", replace) ///
        saving("$FIGUREDIR/pirf_aipw_`var'.gph", replace)

    graph export "$FIGUREDIR/pirf_aipw_`var'.jpg", fontface($grfont) replace

    local ivar = `ivar' + 1
}

*========================
* Combine into one 3-panel figure (y already common)
*========================
graph use "$FIGUREDIR/pirf_aipw_log_PUBINV.gph",        name(g1, replace)
graph use "$FIGUREDIR/pirf_aipw_log_GCONS.gph",         name(g2, replace)
graph use "$FIGUREDIR/pirf_aipw_log_RATIO.gph",   name(g3, replace)

grc1leg2 g1 g2 g3, cols(3) ///
    loff ycommon ///
	ysize(`ysize') xsize(`xsize')  

graph export "$FIGUREDIRC/Robustness_AIPW.jpg",  replace

********************************************************************************
* END
********************************************************************************
