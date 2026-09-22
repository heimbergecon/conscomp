
cap program drop run_iv_spending_robust
program define run_iv_spending_robust
    version 16.0
	
	local titlesize   9
local subtitlesize 7
local labelsize    7
local textsize     7
local ysize		3
local xsize 	9

    syntax, SPECname(string) ///
        [ADDPDEBT(integer 0) ADDOGAP(integer 0) DROPLRGOV(integer 0)]

    * LP + CI settings (match your spending baseline)
    local horizon = 5
    local CI1 = 0.10
    local CI2 = 0.32
    local z90 = abs(invnormal(`CI1'/2))
    local z68 = abs(invnormal(`CI2'/2))

    local shock diff_STRUCBAL
    local instr TOTAL

    ********************************************************************************
    * LP Setup
    ********************************************************************************
    
* Horizon index variables (storage trick)
cap drop t h
gen t = _n
gen h = t - 1

* response variables
local vars log_PUBINV log_GCONS log_RATIO
local varsnames `" "Public investment" "Government consumption" "Ratio" "'
local labels    `" "%" "%" "%" "'

    ********************************************************************************
    * Build baseline control block, then apply ONE modification per robustness spec
    * Baseline controls: 1 lag each + lag of response variable (as in your baseline)
    ********************************************************************************
    local BASE_COMMON "L(1/1).RYIELD L(1/1).RGROWTH L(1/1).lrgov_cpds"
	
    if `droplrgov'==1 {
        local BASE_COMMON : subinstr local BASE_COMMON "L(1/1).lrgov_cpds" "", all
    }

    local C_log_RPUBINV        "`BASE_COMMON' L(1/1).log_RPUBINV"
    local C_log_RGCONS         "`BASE_COMMON' L(1/1).log_RGCONS"
    local C_log_RATIOINVCONS   "`BASE_COMMON' L(1/1).log_RATIOINVCONS"

    * (1) add PDEBT
    if `addpdebt'==1 {
       
        local C_log_RPUBINV        "`C_log_RPUBINV' L(1/1).PDEBT"
        local C_log_RGCONS         "`C_log_RGCONS' L(1/1).PDEBT"
        local C_log_RATIOINVCONS   "`C_log_RATIOINVCONS' L(1/1).PDEBT"
    }

    * (2) add output gap 
    local ogapvar ""
    if `addogap'==1 {
 
        local C_log_RPUBINV        "`C_log_RPUBINV' L(1/1).OGAP"
        local C_log_RGCONS         "`C_log_RGCONS' L(1/1).OGAP"
        local C_log_RATIOINVCONS   "`C_log_RATIOINVCONS' L(1/1).OGAP"
    }

    ********************************************************************************
    * Run LP-IV for each outcome (CUMULATIVE response: F(i).y - L.y)
    * IMPORTANT: short variable names (avoid r(198))
    ********************************************************************************
    local ivar = 1
    foreach y in `vars' {

        * short tag for names (<=32 chars)
        local ytag = cond("`y'"=="log_RPUBINV","pinv", ///
                     cond("`y'"=="log_RGCONS","gcon","ratio"))

        local CNTRLS `C_`y''

        * preallocate IRF storage (short names)
        cap drop b_`ytag' up90_`ytag' lo90_`ytag' up68_`ytag' lo68_`ytag'
        qui gen b_`ytag'     = .
        qui gen up90_`ytag'  = .
        qui gen lo90_`ytag'  = .
        qui gen up68_`ytag'  = .
        qui gen lo68_`ytag'  = .

        forvalues i = 0/`horizon' {

            * cumulative change t-1 to t+i (log units)
            cap drop d_`ytag'_h`i'
            gen d_`ytag'_h`i' = F`i'.`y' - L.`y'

            $verb ivreg2 d_`ytag'_h`i' ///
                (`shock' = `instr') ///
                `CNTRLS' i.year i.country_id, ///
                dkraay(1) partial(i.year i.country_id)

            * store coefficient + SE for shock
            cap drop btmp setmp
            gen btmp  = _b[`shock']
            gen setmp = _se[`shock']

            qui replace b_`ytag'     = 100*btmp if h==`i'
            qui replace up90_`ytag'  = 100*(btmp + `z90'*setmp) if h==`i'
            qui replace lo90_`ytag'  = 100*(btmp - `z90'*setmp) if h==`i'
            qui replace up68_`ytag'  = 100*(btmp + `z68'*setmp) if h==`i'
            qui replace lo68_`ytag'  = 100*(btmp - `z68'*setmp) if h==`i'
            drop btmp setmp
        }

        cap drop zero
        gen zero = 0

        local yttl : word `ivar' of `varsnames'
        local ylab : word `ivar' of `labels'

        local gname = "g_`specname'_`ytag'"

        tw ///
            (rarea up90_`ytag' lo90_`ytag' h, fcolor("$mblue%12") lwidth(none)) ///
            (rarea up68_`ytag' lo68_`ytag' h, fcolor("$mblue%30") lwidth(none)) ///
            (line  b_`ytag' h, lcolor("$mblue") lpattern(solid) lwidth(thick)) ///
            (line  zero h,     lcolor("$mred")  lpattern(solid) lwidth(medthick)) ///
            if h<=`horizon', ///
            title("`yttl'", size(`titlesize') col(black) margin(b=2)) ///
            xtitle("Years", size(`subtitlesize')) ///
            ytitle("`ylab'", size(`subtitlesize')) ///
            xlabel(0(1)`horizon', labsize(`labelsize')) ///
            ylabel(, labsize(`labelsize')) /// 
			plotregion(color(white)) ///
			graphregion(color(white)) ///
			legend(off) ///
			
        graph export "$FIGUREDIR/irf_iv_spend_`specname'_`y'.pdf", fontface($grfont) replace
        graph save   "$FIGUREDIR/irf_iv_spend_`specname'_`y'.gph", replace

        local ivar = `ivar' + 1
    }

    ********************************************************************************
    * Three-panel plot for this robustness check (ycommon)
    ********************************************************************************
	graph use "$FIGUREDIR/irf_iv_spend_`specname'_log_PUBINV.gph",        name(g1, replace)
	graph use "$FIGUREDIR/irf_iv_spend_`specname'_log_GCONS.gph",         name(g2, replace)
	graph use "$FIGUREDIR/irf_iv_spend_`specname'_log_RATIO.gph",   name(g3, replace)

	grc1leg2 g1 g2 g3, cols(3) ///
    loff ycommon ///
	ysize(`ysize') xsize(`xsize')  

	graph export "$FIGUREDIRC/Robustness_`specname'.jpg",  replace

		
		end

********************************************************************************
* RUN ROBUSTNESS CHECKS (NO BASELINE RUN HERE)
********************************************************************************

* (1) Add PDEBT as control variable
run_iv_spending_robust, specname("addPDEBT") addpdebt(1)

* (2) Add output gap as control variable
run_iv_spending_robust, specname("addOGAP") addogap(1)

* (3) Drop lrgov_cpds as control variable
run_iv_spending_robust, specname("dropLRGOV") droplrgov(1)

display as text "Done. Robustness outputs written to: $FIGUREDIR"

********************************************************************************
* END
********************************************************************************
