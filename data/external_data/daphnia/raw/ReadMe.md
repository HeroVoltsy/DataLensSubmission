\#Data and R script - Riding the heatwave: the effects of temperature and nutrition on heat-injury accumulation and repair in Daphnia magna



This README file contain the description of raw data files and R script used for analysis and figures of the article





\#Content of the deposit:

\- "results\_TDT.txt" : raw data file used for Experiment 1, for TDTs

\- "resultats\_manip\_final.txt": raw data file used for Experiment 2 treatment, for recovery state and rate analysis

\- "Rcode.R": R script used for data processing, statistical analysis and figures conception





\#Understanding data files for analysis

results\_TDT:

 	- Food: food quality, S for SYN treatment and CY for CHLA:CRY treatment

 	- Temp: temperature of exposition in °C

&#x09;- Tin : Initial stopwatch time at which the individual was exposed to the heat stress

&#x09;- Tout : Stopwatch time at which the heat-stressed individual became immobilized

&#x09;- Tdiff : Difference between Tout and Tin

 	- Timm: immobilization time/thermal tolerance (in minutes) = time before the immobilization while exposed to the stressing temperature

 	- Pportoir: position of the individual during the experiment

&#x09;- Pvide : Empty weighing boat mass (g)

&#x09;- Pplein : Filled weighing boat mass (with individuals, g)

 	- Poids: weight of the individual (in µg)

&#x09;- Code : Laboratory identification code for the individual 



resultats\_mani\_final.txt:

 	- Wave: use to discriminate individuals used for tref (1), individuals after recovery of 2 hours (2) and of 12 hours (3)

 	- Recup: duration of the recovery period in hours

 	- Temp: temperature of the recovery period in °C

 	- Food: food quality, S for SYN treatment and CY for CHLA:CRY treatment

&#x09;- Num : Identification code use during the experiment

 	- Pos : position of the individual during the experiment

 	- Timm: immobilization time/thermal tolerance in minutes = time before the immobilization while exposed	to the stressing temperature

&#x09;- Box : Position of the individual in weighing boxes at the end of the experiment

&#x09;- Pvide : Empty weighing boat mass (g)

&#x09;- Pplein : Filled weighing boat mass (with individuals, g)

 	- Weight : weight of the individual in µg

&#x09;- Length : length of the individual 

 

Rcode.R

 	-The script is divided in multiple parts for a better understanding

 	-Library: all packages used in the script

 	-data: load data file --> /!\\ think to set your set directory before

 	-TDT: statistical analysis and figure conception for TDTs

 	-Recovery state: conception of figure of the recovery state, adjusting GAM for each Food x Recovery duration combination treatment ; dunn test

 	-Recovery rate: conception of figure of the recovery rate, adjusting GAM for each Food x Recovery duration combination treatment ; dunn test

 	-Mortality: conception of the figure for mortality

 	-STATS: all statistical analysis made on recovery rate and state, meaning general GAM model for each, and Wilcoxon test to compare with 0 and 100 respectively ; statistical analysis for weight of individual between food treatement

