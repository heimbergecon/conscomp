*========================
* Replication Files
* Uneven cuts: Fiscal consolidation and the composition of government spending
* Heimberger, Matzner, Schütz
*========================

* Setting

clear all
discard
graph drop _all
set graphics on

global PATH "C:\Users\matzner\Wiener Institut für internationale Wirtschaftsvergleiche\P2026-02_EMPN_Fiscal consolidation - Dokumente\General\02_Project\WP3 - Spending effects of fiscal consolidation shocks\Replication_EMPNIII"
cd "$PATH"
global FIGUREDIR "$PATH/figures"
global TABLEDIR "$PATH/tables"
global FIGUREDIRC "$PATH/figures_combined"
global DATA      "$PATH/data"

* packages (install if needed)
* ssc install ivreg2
* ssc install grstyle

* graphstyle
grstyle clear
grstyle init
grstyle set grid
global grfont "P052"
graph set window fontface $grfont

global mblue "0 114 189"
global mred "217 83 25"
global morange "237 177 32"
global mdred "162 20 47"
global mpurple "126 47 142"
global mgreen "119 172 48"

* Data
use "$DATA\data_empnIII.dta", clear
 
* Figures & Tables 
 
do "$PATH\01_MainResult.do"

do "$PATH\02_COFOGCategories.do"

do "$PATH\03_SD.do"

do "$PATH\04_SD_COFOG.do"

do "$PATH\05_Robustness_AIPW.do"

do "$PATH\06_Robustness_DropCountries.do"

do "$PATH\07_Robustness_Controls.do"

do "$PATH\08_Robustness_IV.do"

do "$PATH\09_Robustness_COFOG.do"



