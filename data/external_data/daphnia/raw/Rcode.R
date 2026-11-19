#####Library#####
library(readr)
library(segmented)
library(plyr)
library(dplyr)
library(ggplot2)
library(ggthemes)
library(scales)
library(tidyr)
library(car)
library(multcompView)
library(lmtest)
library(nlstools)
library(sicegar)
library(outliers)
library(investr)
library(tidyverse)
library(rstatix)
library(RColorBrewer)
library(ggpmisc)
library(RColorBrewer)
library(emmeans)
library(mgcv)
library(broom)
library(boot)
library(gridExtra)

######data#####


data1 = read.table("resultats_manip_final.txt", sep="\t", header=T, dec=",")

data1$tqual = paste(data1$Temp,data1$Food,sep="")
data1$treatment = paste(data1$tqual,data1$Recup,sep="")
data1$repqual = paste(data1$Recup,data1$Food,sep="")

data2 = data1 %>%
  filter(!(Recup == 0))



facet_labels <- c("")


data2 = data2 %>% mutate(nom = 
                           case_when(repqual == "12CY" ~ "12h repos - Chlamy-Crypto",
                                     repqual == "12S" ~ "12h repos - Synecho",
                                     repqual ==  "2CY" ~ "2h repos - Chlamy-Crypto",
                                     repqual == "2S" ~ "2h repos - Synecho"))

data2$recup_min <- (data2$Recup*60)

TDT<-read.table("results_TDT.txt", sep="\t", header=T, dec=",")


#####TDT#####










#SD
pred_log_CY <- predict(model_CY, newdata = new_temp, se.fit = TRUE)
pred_log_S <- predict(model_S, newdata = new_temp, se.fit = TRUE)


sd_log_CY <- pred_log_CY$se.fit
sd_log_S <- pred_log_S$se.fit


mean_CY <- exp(pred_log_CY$fit)
sd_CY <- mean_CY * sd_log_CY  

mean_S <- exp(pred_log_S$fit)
sd_S <- mean_S * sd_log_S


cat("CHLA:CRY: mean =", round(mean_CY, 1), ", SD ???", round(sd_CY, 1), "\n")
# Traitement CY: moyenne = 182.6 , SD ~ 16.1 
cat("SYN : mean =", round(mean_S, 1), ", SD ???", round(sd_S, 1), "\n")
# Traitement S : moyenne = 126.6 , SD ~ 7.4 






###ANCOVA analysis on TDTs

TDT$Food <- as.factor(TDT$Food)
TDT$Temp <- as.numeric(TDT$Temp)



ancova_model <- lm(log10(Timm) ~ Temp * Food, data = TDT)


summary(ancova_model)
anova(ancova_model)
coefs <- coef(ancova_model)


#Plot data and model

# Adjust model for CHLA:CRY
new_data_CY <- data.frame(Temp = seq( 35.5, max(TDT$Temp),
                                      length.out = 100),Food=rep("CY", length.out=100))
pred_CY <- predict(ancova_model, newdata = new_data_CY, interval = "confidence")
new_data_CY <- cbind(new_data_CY, pred_CY)

# Adjust model for SYN
new_data_S <- data.frame(Temp = seq( 35.5, max(TDT$Temp),
                                     length.out = 100),Food=rep("S", length.out=100))
pred_S <- predict(ancova_model, newdata = new_data_S, interval = "confidence")
new_data_S <- cbind(new_data_S, pred_S)



p1 <- ggplot(TDT, aes(x = Temp, y = log10(Timm), col = Food)) +
  geom_point() +
  scale_color_manual(values=c("lightsalmon2","darkseagreen" ))+
  geom_ribbon(data = new_data_CY, aes(x = Temp, ymin = lwr, ymax = upr), 
              fill = "lightsalmon2", alpha = 0.2, inherit.aes = FALSE) +
  geom_line(data = new_data_CY, aes(x = Temp, y = fit), 
            color = "lightsalmon2", inherit.aes = FALSE) +
  geom_ribbon(data = new_data_S, aes(x = Temp, ymin = lwr, ymax = upr), 
              fill = "darkseagreen", alpha = 0.2, inherit.aes = FALSE) +
  geom_line(data = new_data_S, aes(x = Temp, y = fit), 
            color = "darkseagreen", inherit.aes = FALSE) +
  xlab("Temperature") +
  ylab("T_ref (min)") +
  scale_y_continuous(limits = c(0,log10(400)),
                     breaks = c(0, log10(c(5, 20, 50, 150, 400))),  
                     labels = c(0, 5, 20, 50, 150, 400)           
  ) +
  scale_x_continuous(breaks = c(35.5,36.5,37.5,38.5,39.5))+
  theme_minimal() +
  theme_bw(base_size = 22)
p1



# Predict log(Timm) with IC
pred_log_CY <- predict(ancova_model, newdata = data.frame(Temp = 36, Food="CY"), interval = "confidence")
pred_log_S <- predict(ancova_model, newdata = data.frame(Temp = 36, Food="S"), interval = "confidence")

# Conversion
pred_CY <- 10^(pred_log_CY)
pred_S <- 10^(pred_log_S)


pred_CY  # CHLA:CRY treatment

pred_S   # SYN treatment


#Bootstrap CTmax and z estimates to obtain 95% IC

#Define boot function

boot_fun <- function(data, indices) {
  
  d <- data[indices, ]   # resampled data
  
  model <- lm(log10(Timm) ~ Temp * Food, data = d)
  coefs <- coef(model)
  
  # CHLA:CRY
  intercept_CY <- coefs["(Intercept)"]
  slope_CY <- coefs["Temp"]
  
  CTmax_CY <- -intercept_CY / slope_CY
  Z_CY <- -1 / slope_CY
  
  # SYN
  intercept_S <- intercept_CY + coefs["FoodS"]
  slope_S <- slope_CY + coefs["Temp:FoodS"]
  
  CTmax_S <- -intercept_S / slope_S
  Z_S <- -1 / slope_S
  
  return(c(CTmax_CY, CTmax_S, Z_CY, Z_S))
}

# run boot 

set.seed(123)

boot_results <- boot(
  data = TDT,
  statistic = boot_fun,
  R = 10000
)

#Compute 95% IC and summarize  IC and visualise their distributions

boot.ci(boot_results, type="perc", index=1)  # CTmax_CY
boot.ci(boot_results, type="perc", index=2)  # CTmax_S
boot.ci(boot_results, type="perc", index=3)  # Z_CY
boot.ci(boot_results, type="perc", index=4)  # Z_S

apply(boot_results$t, 2, quantile, c(0.025, 0.975))
apply(boot_results$t, 2, mean)

par(mfrow=c(2,2))

hist(boot_results$t[,1], main="CTmax CY")
hist(boot_results$t[,2], main="CTmax S")
hist(boot_results$t[,3], main="Z CY")
hist(boot_results$t[,4], main="Z S")

######Recovery state#####


data2 <- data2 %>%
  mutate(rapport = ifelse(Food == "CY", 
                          (((Timm - (165.71 - 90)) / 90)*100), 
                          (((Timm - (147.13 - 90)) / 90)*100)))

#mean value and IC for tref :
S_init <- data1[data1$Food == "S" & data1$Recup == 0,]
CY_init <- data1[data1$Food == "CY" & data1$Recup == 0,]

mean(CY_init$Timm)
#165.71 --> 100%
mean(S_init$Timm)
#147.13 -->10%%

t.test(CY_init$Timm)$conf.int
#160.37 - 171.06 --> 96.78 and 97.16
t.test(S_init$Timm)$conf.int
#142.96 - 151.31 --> 103.23 and 102.84

mean2 <- c(100, 100)
lower2 <- c(96.78,97.16 )
upper2 <- c(103.23, 102.84)
Food <- c("CY", "S")

data_mean2 <-data.frame(mean = mean2, lower = lower2, upper = upper2, Food = Food)

#GAM models
# Colors
col_CY <- "lightsalmon2"
col_S <- "darkseagreen3"
    
# Loop on the 4 treatments
  gam_models <- list()
  plots <- list()
  treatments <- c("2CY", "12CY", "2S", "12S")
  cols <- c(col_CY, col_CY, col_S, col_S)
  
  for (i in seq_along(treatments)) {
    trt <- treatments[i]
    col <- cols[i]
    subset_data <- subset(data2, repqual == trt)
    
    #adjust gam
    gam_models[[trt]] <- gam(rapport ~ s(Temp, k = 4), data = subset_data)
    
    plots[[trt]] <- ggplot(data = subset_data, aes(x = Temp, y = rapport)) +
      geom_point(color = col) +
      geom_smooth(method = "gam", formula = y ~ s(x, k = 4), color = col, fill = col, se = TRUE) +
      geom_hline(data = data_mean2, aes(yintercept = mean), size = 1.5, col = "red") +
      geom_hline(data = data_mean2, aes(yintercept = lower), size = 1, col = "red", linetype = "dashed", alpha = .5) +
      geom_hline(data = data_mean2, aes(yintercept = upper), size = 1, col = "red", linetype = "dashed", alpha = .5) +
      geom_hline(yintercept = 0, size = 1.5, col = "red") +
      scale_x_continuous(breaks = seq(18, 30, by = 2), labels = as.character(seq(18, 30, by = 2)))+
      scale_y_continuous(limits = c(-50, 200), breaks = c(-50, 0, 50, 100, 150, 200)) +
      ggtitle(paste0("GAM - ", trt)) +
      theme_bw(base_size = 22) +
      theme(strip.background = element_blank(),
            strip.text.x = element_blank(),
            legend.title = element_text(size = 20),
            axis.text = element_text(size = 20),
            axis.title = element_text(size = 25),
            legend.position = "none")
  }
  

  grid.arrange(grobs = plots, ncol = 2)
  
  
  
  
  
#Dunn test comparaison recovery state

#kruskal test  
df_2CY <- data2 %>% filter(repqual == "2CY")
kruskal.test(rapport ~ Temp, data = df_2CY)
#pval < 0.05 so ok for dunn test as multiple comparison
  
dunn_test2CY<- dunn_test(rapport ~ Temp, data = df_2CY)
  

  
# Adjust to get directly significant letters associated to temeprature
pvals <- dunn_test2CY %>%
select(group1, group2, p.adj) %>%
pivot_wider(names_from = group2, values_from = p.adj)

pval_vector <- setNames(dunn_test2CY$p.adj, paste(dunn_test2CY$group1, dunn_test2CY$group2, sep = "-"))
letters <- multcompLetters(pval_vector, threshold = 0.05)
print(letters$Letters)
  
  
#Same for all 4 treatments  
  
df_12CY <- data2 %>% filter(repqual == "12CY")
kruskal.test(rapport ~ Temp, data = df_12CY)
#pval < 0.05 donc ok
  
dunn_test12CY<- dunn_test(rapport ~ Temp, data = df_12CY)
dunn_test12CY
  
  
pvals <- dunn_test12CY %>%
select(group1, group2, p.adj) %>%
pivot_wider(names_from = group2, values_from = p.adj)
  
  
pval_vector <- setNames(dunn_test12CY$p.adj, paste(dunn_test12CY$group1, dunn_test12CY$group2, sep = "-"))
letters <- multcompLetters(pval_vector, threshold = 0.05)
print(letters$Letters)
  
  
  
  
#SYN 2  
df_2S <- data2 %>% filter(repqual == "2S")
kruskal.test(rapport ~ Temp, data = df_2S)
#pval = 0.07 donc ok
  
dunn_test2S<- dunn_test(rapport ~ Temp, data = df_2S)
dunn_test2S
#no differences  
  
  
  
  
  
#SYN 12  
df_12S <- data2 %>% filter(repqual == "12S")
kruskal.test(rapport ~ Temp, data = df_12S)
#pval < 0.05 donc ok
  
dunn_test12S<- dunn_test(rapport ~ Temp, data = df_12S)
dunn_test12S
  
  
pvals <- dunn_test12S %>%
select(group1, group2, p.adj) %>%
pivot_wider(names_from = group2, values_from = p.adj)
  
  
pval_vector <- setNames(dunn_test12S$p.adj, paste(dunn_test12S$group1, dunn_test12S$group2, sep = "-"))
letters <- multcompLetters(pval_vector, threshold = 0.05)
print(letters$Letters)
  
  

#Comparaison pairwise  
pairwiseCY<-filter(data2, Food=="CY")
dunn_treatCY<-dunn_test(rapport ~ treatment, data = pairwiseCY)
  
pairwiseS<-filter(data2, Food=="S")
dunn_treatS<-dunn_test(rapport ~ treatment, data = pairwiseS)

tapply(data2$rapport, data2$treatment, mean, na.rm = TRUE)


######Recovery rate######

data2 <- data2 %>%
  mutate(time_win = ifelse(Food == "CY", 
                           ((Timm - (165.71 - 90)) / recup_min), 
                           ((Timm - (147.13 - 90)) / recup_min))) %>%
  mutate(time_win = round(time_win, 4)) 




#GAM recovery rate
# Colors
col_CY <- "lightsalmon2"
col_S <- "darkseagreen3"
    

  gam_models <- list()
  plots <- list()
  treatments <- c("2CY", "12CY", "2S", "12S")
  cols <- c(col_CY, col_CY, col_S, col_S)
  
  # Loop 4 treatments
  for (i in seq_along(treatments)) {
    trt <- treatments[i]
    col <- cols[i]
    subset_data <- subset(data2, repqual == trt)
    
    gam_models[[trt]] <- gam(time_win ~ s(Temp, k = 4), data = subset_data, method = "REML")
    
    mean_ci <- subset_data %>%
      group_by(Temp) %>%
      summarise(
        mean = mean(time_win, na.rm = TRUE),
        se = sd(time_win, na.rm = TRUE) / sqrt(n()),
        ci = qt(0.975, df = n() - 1) * se
      ) %>%
      mutate(lower = mean - ci, upper = mean + ci)
    
      plots[[trt]] <- ggplot() +
      geom_hline(yintercept = 0, size = 1.2, color = "red") +
      geom_point(data = subset_data, aes(x = Temp, y = time_win), color = col, size = 2) +
      geom_smooth(data = subset_data, aes(x = Temp, y = time_win),
                  method = "gam", formula = y ~ s(x, k = 4), color = col, fill=col, se = TRUE) +
      scale_x_continuous(breaks = seq(18, 30, by = 2)) +
      scale_y_continuous(limits = c(-0.35, 1), breaks = c(0, 0.5, 1)) +
      ggtitle(paste0("GAM - ", trt)) +
      theme_bw(base_size = 22) +
      theme(strip.background = element_blank(),
            strip.text.x = element_blank(),
            legend.title = element_text(size = 20),
            axis.text = element_text(size = 20),
            axis.title = element_text(size = 25),
            legend.position = "none")
  }
  
  
  grid.arrange(grobs = plots, ncol = 2)
  
  

#Dunn test comparaison recovery state
  
#kruskal test  
df_2CY <- data2 %>% filter(repqual == "2CY")
kruskal.test(time_win ~ Temp, data = df_2CY)
#pval < 0.05 so ok for dunn test as multiple comparison
  
dunn_test2CY<- dunn_test(time_win ~ Temp, data = df_2CY)
  
  
  
# Adjust to get directly significant letters associated to temeprature
pvals <- dunn_test2CY %>%
select(group1, group2, p.adj) %>%
pivot_wider(names_from = group2, values_from = p.adj)
  
pval_vector <- setNames(dunn_test2CY$p.adj, paste(dunn_test2CY$group1, dunn_test2CY$group2, sep = "-"))
letters <- multcompLetters(pval_vector, threshold = 0.05)
print(letters$Letters)
  
  
#Same for all 4 treatments  
df_12CY <- data2 %>% filter(repqual == "12CY")
kruskal.test(time_win ~ Temp, data = df_12CY)
#pval < 0.05 donc ok
  
dunn_test12CY<- dunn_test(time_win ~ Temp, data = df_12CY)
dunn_test12CY
  
  
pvals <- dunn_test12CY %>%
select(group1, group2, p.adj) %>%
pivot_wider(names_from = group2, values_from = p.adj)
  
  
pval_vector <- setNames(dunn_test12CY$p.adj, paste(dunn_test12CY$group1, dunn_test12CY$group2, sep = "-"))
letters <- multcompLetters(pval_vector, threshold = 0.05)
print(letters$Letters)
  
  
#SYN 2  
df_2S <- data2 %>% filter(repqual == "2S")
kruskal.test(time_win ~ Temp, data = df_2S)
#pval = 0.07 donc ok
  
dunn_test2S<- dunn_test(time_win ~ Temp, data = df_2S)
dunn_test2S
#no differences  
  
  
  
  
#SYN 12  
df_12S <- data2 %>% filter(repqual == "12S")
kruskal.test(time_win ~ Temp, data = df_12S)
#pval < 0.05 donc ok
  
dunn_test12S<- dunn_test(time_win ~ Temp, data = df_12S)
dunn_test12S
  
  
pvals <- dunn_test12S %>%
select(group1, group2, p.adj) %>%
pivot_wider(names_from = group2, values_from = p.adj)
  
  
pval_vector <- setNames(dunn_test12S$p.adj, paste(dunn_test12S$group1, dunn_test12S$group2, sep = "-"))
letters <- multcompLetters(pval_vector, threshold = 0.05)
print(letters$Letters)
  
  
  
#Comparaison pairwise  
pairwiseCY<-filter(data2, Food=="CY")
dunn_treatCY<-dunn_test(time_win ~ treatment, data = pairwiseCY)

pairwiseS<-filter(data2, Food=="S")
dunn_treatS<-dunn_test(time_win ~ treatment, data = pairwiseS)
  
tapply(data2$time_win, data2$treatment, mean, na.rm = TRUE)
  
wilcox.test(
  time_win ~ repqual,
  data = filter(data2, Temp == 18 & Food == "CY")
)
#p-val < 0.05

wilcox.test(
  time_win ~ repqual,
  data = filter(data2, Temp == 30 & Food == "CY"),
  exact = FALSE
)
#p-val < 0.05



######Mortality#####
mortality <- c(20,0,0,0,73.33,0,0,0,40,0,0,0,46.67,0,0,0,20,0,0,0,26.67,0,0,0)
summary_pourc$mortality <- mortality

treatCY <- subset(summary_pourc, Food == "CY")
treatCY12 <- subset(treatCY, Recup == "12")




ggplot(treatCY12, aes(x = treatment, y = mortality, group = 1, color = treatment)) +
  geom_line(size=1.5) +  # Ajoute une ligne continue
  geom_point(size=5) +  # Ajoute des points pour plus de visibilit?
  geom_hline(yintercept = 0, color = "darkseagreen3", size=1.5) + # Ligne ? y=0
  labs(title = "Mortalit? par traitement",
       x = "Traitement",
       y = "Mortalit?") +
  scale_y_continuous(limits = c(0, 100)) +
  theme_minimal() +
  scale_color_brewer(palette = "Set2") # Palette de couleurs


######Body mass distribution (fig. S2)#####


#For CHLA:CRY treatment
#Stat weight
data2$Timm_mass <- data2$Timm/data2$Weight
data2$Temp <- as.numeric(data2$Temp)

data2_CY <- subset(data2, Food == "CY")

# S'assurer que Temp est un facteur
data2_CY$Temp <- as.factor(data2_CY$Temp)

# Moyennes par treatment (pour les lignes verticales)
mean_df <- data2_CY %>% 
  group_by(treatment) %>% 
  summarise(mean_weight = mean(Weight, na.rm = TRUE))

data2_CY$Recup <- factor(data2_CY$Recup, levels = c("2", "12"))
data2_CY$Temp  <- factor(data2_CY$Temp)



mean_df <- data2_CY %>% 
  group_by(Temp, Recup) %>% 
  summarise(
    mean_weight = mean(Weight, na.rm = TRUE),
    sd_weight   = sd(Weight, na.rm = TRUE),
    n           = n(),
    se_weight   = sd_weight / sqrt(n),
    CI_low      = mean_weight - 1.96 * se_weight,
    CI_high     = mean_weight + 1.96 * se_weight,
    .groups = "drop"
  )




ggplot(data2_CY, aes(x = Weight, fill = Temp)) +
    geom_rect(data = mean_df,
            aes(xmin = CI_low,
                xmax = CI_high,
                ymin = 0,
                ymax = 0.046),
            inherit.aes = FALSE,
            fill = "red",
            alpha = 0.15) +
    geom_density(alpha = 0.6) +
    geom_rug(aes(color = Temp),
           alpha = 1,
           sides = "b",
           size = 1) +
    geom_vline(data = mean_df,
             aes(xintercept = mean_weight),
             color = "red",
             size = 1.2,
             linetype = "solid") +
  scale_x_continuous(limits = c(80, 275)) +
  scale_y_continuous(limits = c(0, 0.046)) +
  facet_grid(Recup ~ Temp) +
  scale_fill_viridis_d(option = "D") +
  scale_color_viridis_d(option = "D") +
  theme_classic(base_size = 20) +
  theme(legend.position = "none") +
  labs(x = "Dry body mass (µg)",
       y = "Density")


#For SYN treatment
#Stat weight
data2_S <- subset(data2, Food == "S")

# S'assurer que Temp est un facteur
data2_S$Temp <- as.factor(data2_S$Temp)

# Moyennes par treatment (pour les lignes verticales)
mean_df <- data2_S %>% 
  group_by(treatment) %>% 
  summarise(mean_weight = mean(Weight, na.rm = TRUE))

data2_S$Recup <- factor(data2_S$Recup, levels = c("2", "12"))
data2_S$Temp  <- factor(data2_S$Temp)



mean_df <- data2_S %>% 
  group_by(Temp, Recup) %>% 
  summarise(
    mean_weight = mean(Weight, na.rm = TRUE),
    sd_weight   = sd(Weight, na.rm = TRUE),
    n           = n(),
    se_weight   = sd_weight / sqrt(n),
    CI_low      = mean_weight - 1.96 * se_weight,
    CI_high     = mean_weight + 1.96 * se_weight,
    .groups = "drop"
  )




ggplot(data2_S, aes(x = Weight, fill = Temp)) +
  geom_rect(data = mean_df,
            aes(xmin = CI_low,
                xmax = CI_high,
                ymin = 0,
                ymax = 0.046),
            inherit.aes = FALSE,
            fill = "red",
            alpha = 0.15) +
  geom_density(alpha = 0.6) +
  geom_rug(aes(color = Temp),
           alpha = 1,
           sides = "b",
           size = 1) +
  geom_vline(data = mean_df,
             aes(xintercept = mean_weight),
             color = "red",
             size = 1.2,
             linetype = "solid") +
  scale_x_continuous(limits = c(80, 275)) +
  scale_y_continuous(limits = c(0, 0.046)) +
  facet_grid(Recup ~ Temp) +
  scale_fill_viridis_d(option = "D") +
  scale_color_viridis_d(option = "D") +
  theme_classic(base_size = 20) +
  theme(legend.position = "none") +
  labs(x = "Dry body mass (µg)",
       y = "Density")



#####Interindividual variability (fig S3)#####



ggplot(data1, aes(x = Recup, y = Timm)) +
  geom_point(aes(color = Food), size=2.5) +
  facet_wrap(~ Food) +
  
  # lignes horizontales
  geom_hline(yintercept = 0, color = "red", linetype = "solid") +
  geom_hline(data = data.frame(Food = c("CY", "S"),
                               y = c(165.71, 147.13)),
             aes(yintercept = y),
             color = "red",
             linetype = "solid") +
  
  scale_color_manual(values = c("CY" = "lightsalmon2",
                                "S"  = "darkseagreen3")) +
  
  scale_x_continuous(limits = c(0, 12.5), breaks = c(0, 2, 12)) +
  scale_y_continuous(limits = c(-25, 275)) +
  
  theme_bw(base_size = 20) +  # <-- grille propre
  theme(legend.position = "none") +
  
  labs(x = "Recovery duration (h)",
       y = "timm")



ggplot(data1, aes(x = Recup, y = Timm)) +
  geom_point(aes(color = Temp), size = 2.5) +
  
  facet_wrap(~ Food,
             labeller = labeller(Food = c("CY" = "CHLA:CRY",
                                          "S"  = "SYN"))) +
    geom_hline(yintercept = 0, color = "red", linetype = "solid", linewidth = 1.2) +
  geom_hline(data = data.frame(Food = c("CY", "S"),
                               y = c(165.71, 147.13)),
             aes(yintercept = y),
             color = "red",
             linetype = "solid",
             linewidth = 1.2) +
  
  scale_color_viridis_c(option = "viridis") +
  
  scale_x_continuous(limits = c(0, 12.5), breaks = c(0, 2, 12)) +
  scale_y_continuous(limits = c(-25, 275), breaks=c(0, 50, 100, 150, 200, 250)) +
  
  theme_bw(base_size = 20) +
  theme(legend.position = "right") +
  
  labs(x = "Recovery duration (h)",
       y = "t (min)",
       color = "Temp")




                                                                   
#######STATS#####

#Stat weight
data2$Timm_mass <- data2$Timm/data2$Weight
data2$Temp <- as.numeric(data2$Temp)

data2_CY <- subset(data2, Food == "CY")

ggplot(data2_CY,  aes(x = Weight, color = treatment, fill = treatment)) +
  geom_density(alpha = 0.3, size = 1) +
  geom_rug(alpha = 0.4) +
  scale_x_continuous(limits=c(80,270))+
  facet_wrap(~ treatment, scales = "free", ncol = 2) +
  theme_minimal() +
  theme(legend.position = "none") +
  labs(x = "Weight", y = "Densit?")


mean_df <- data2_CY %>% 
  group_by(treatment) %>% 
  summarise(mean_weight = mean(Weight, na.rm = TRUE))

ggplot(data2_CY, aes(x = Weight, color = treatment, fill = treatment)) +
  geom_density(alpha = 0.3, size = 1) +
  geom_rug(alpha = 0.4) +
  geom_vline(data = mean_df, aes(xintercept = mean_weight, color = treatment),
             linetype = "dashed", size = 1) +
  scale_x_continuous(limits = c(80, 270)) +
  facet_wrap(~ treatment, scales = "free", ncol = 2) +
  theme_classic(base_size = 22) +
  theme(legend.position = "none") +
  labs(x = "Weight", y = "Densit?")




# Test t de Student
t_test_result <- t.test(Weight ~ Food, data = data2)
print(t_test_result)


ggplot(data2, aes(x = Food, y = Weight)) +
  geom_boxplot(fill = "lightblue", color = "black", alpha = 0.7) +  # Boxplot
  geom_jitter(width = 0.2, size = 1.5, color = "darkblue", alpha = 0.5) +  # Points
  xlab("Type de Nourriture (Food)") +
  ylab("Masse") +
  ggtitle("Distribution des tailles selon la nourriture") +
  theme_minimal(base_size = 16)


#Conclusion results
moyenne_weight <- aggregate(Weight ~ Food, data = data2, FUN = function(x) c(mean = mean(x), sd = sd(x)))
print(moyenne_weight)







#Wilcox test recovery state (rapport) compared to 100%
data_stat<-data2

print(data_stat %>%
        group_by(Recup, Temp, Food) %>%
        summarise(p_value = wilcox.test(rapport, mu = 100)$p.value,
                  statistic = wilcox.test(rapport, mu = 100)$statistic,
                  .groups = "drop"), n = Inf)

# Recup Temp  Food    p_value statistic
# <fct> <fct> <fct>     <dbl>     <dbl>
# 1 2     18    CY    0.000723          0
# 2 2     18    S     0.000725          0
# 3 2     20    CY    0.000481          0
# 4 2     20    S     0.000719          0
# 5 2     24    CY    0.00336          14
# 6 2     24    S     0.000723          0
# 7 2     26    CY    0.0000153         0
# 8 2     26    S     0.00109           0
# 9 2     28    CY    0.000725          0
# 10 2     28    S     0.00252           0
# 11 2     30    CY    0.000709          0
# 12 2     30    S     0.00164           0
# 13 12    18    CY    0.151            58
# 14 12    18    S     0.0000610         0
# 15 12    20    CY    0.125             0
# 16 12    20    S     0.0353           23
# 17 12    24    CY    0.910            21
# 18 12    24    S     0.000244          1
# 19 12    26    CY    0.0547            4
# 20 12    26    S     0.000244          0
# 21 12    28    CY    0.0269           11
# 22 12    28    S     0.00237           6
# 23 12    30    CY    0.00293           2
# 24 12    30    S     0.000725          0





#Stat GAMs recovery state

data2$FoodRecovery <- interaction(data2$Food, data2$Recup)


m1 <- gam(rapport~s(Temp, k=6),data=data2, method ="ML")
m2 <- gam(rapport~s(Temp, k=6) + Food,data=data2, method ="ML")
m3 <- gam(rapport~s(Temp, k=6) + Recup,data=data2, method ="ML")
m4 <- gam(rapport~s(Temp, k=6) + Food + Recup,data=data2, method ="ML")
m5 <- gam(rapport~s(Temp, k=6) + Food*Recup ,data=data2, method ="ML")
m6 <- gam(rapport ~ s(Temp, by = as.factor(Food), k = 6) + Food + Recup, data = data2, method = "ML")
m7 <- gam(rapport ~ s(Temp, by = as.factor(Recup), k = 6) + Food + Recup, data = data2, method = "ML")
m8 <- gam(rapport ~ 
            s(Temp, by = as.factor(Food), k = 6) + 
            s(Temp, by = as.factor(Recup), k = 6) + 
            Food + Recup, 
          data = data2, method = "ML")

m9 <- gam(rapport ~ 
            s(Temp, by = interaction(Food, Recup), k = 6) + 
            Food + Recup, 
          data =  data2, method = "ML")

m10 <- gam( rapport~ 
              s(Temp, by = interaction(Food, Recup), k = 6), 
            data =  data2, method = "ML")



AIC(m1,m2,m3,m4,m5,m6,m7,m8,m9,m10)
#best model = m9
logLik(m9)
summary(m9)$r.sq

gam.check(m9)
summary(m9)
# Parametric coefficients:
#                 Estimate Std. Error t value Pr(>|t|)    
#   (Intercept)  20.2087     3.8253   5.283 2.41e-07 ***
#   FoodS       -49.4426     4.1422 -11.936  < 2e-16 ***
#   Recup         3.7161     0.4158   8.937  < 2e-16 ***
anova(m9)
#                             edf Ref.df      F p-value
# s(Temp):FoodRecoveryCY.2  3.062  3.709 11.595  <2e-16
# s(Temp):FoodRecoveryS.2   1.000  1.000  0.011   0.916
# s(Temp):FoodRecoveryCY.12 1.000  1.000 46.126  <2e-16
# s(Temp):FoodRecoveryS.12  4.575  4.907 11.782  <2e-16






#Wilcow test recovery rate compared to 0

data_stat %>%
  group_by(Recup, Temp, Food) %>%  
  summarise(p_value = wilcox.test(time_win, mu = 0)$p.value,
            statistic = wilcox.test(time_win, mu = 0)$statistic) %>%
  ungroup()

print(data_stat %>%
        group_by(Recup, Temp, Food) %>%
        summarise(p_value = wilcox.test(time_win, mu = 0)$p.value,
                  statistic = wilcox.test(time_win, mu = 0)$statistic,
                  .groups = "drop"), n = Inf)

# Recup  Temp Food    p_value statistic
# <int> <int> <chr>     <dbl>     <dbl>
# 1     2    18 CY    0.00586         109
# 2     2    18 S     0.000725          0
# 3     2    20 CY    0.000583        135
# 4     2    20 S     0.000719          0
# 5     2    24 CY    0.0000305       136
# 6     2    24 S     0.0381           23
# 7     2    26 CY    0.0000305       152
# 8     2    26 S     0.00136           1
# 9     2    28 CY    0.0938           90
# 10     2    28 S     0.00418           2
# 11     2    30 CY    0.000709          0
# 12     2    30 S     0.00164           0
# 13    12    18 CY    0.000488         78
# 14    12    18 S     0.252            39
# 15    12    20 CY    0.375             8
# 16    12    20 S     0.00671         106
# 17    12    24 CY    0.0117           43
# 18    12    24 S     0.000610        102
# 19    12    26 CY    0.0391           33
# 20    12    26 S     0.735            40
# 21    12    28 CY    0.0425           65
# 22    12    28 S     0.0134          104
# 23    12    30 CY    0.966            34
# 24    12    30 S     0.00133           3


#Stat GAMs recovery rate
m1 <- gam(time_win~s(Temp, k=6),data=data2, method ="ML")
m2 <- gam(time_win~s(Temp, k=6) + Food,data=data2, method ="ML")
m3 <- gam(time_win~s(Temp, k=6) + Recup,data=data2, method ="ML")
m4 <- gam(time_win~s(Temp, k=6) + Food + Recup,data=data2, method ="ML")
m5 <- gam(time_win~s(Temp, k=6) + Food*Recup ,data=data2, method ="ML")

m6 <- gam(time_win ~ s(Temp, by = as.factor(Food), k = 6) + Food + Recup, data = data2, method = "ML")
m7 <- gam(time_win ~ s(Temp, by = as.factor(Recup), k = 6) + Food + Recup, data = data2, method = "ML")
m8 <- gam(time_win ~ 
            s(Temp, by = as.factor(Food), k = 6) + 
            s(Temp, by = as.factor(Recup), k = 6) + 
            Food + Recup, 
          data = data2, method = "ML")

m9 <- gam(time_win ~ 
            s(Temp, by = interaction(Food, Recup), k = 6) + 
            Food + Recup, 
          data =  data2, method = "ML")

m10 <- gam( time_win~ 
              s(Temp, by = interaction(Food, Recup), k = 6), 
            data =  data2, method = "ML")



AIC(m1,m2,m3,m4,m5,m6,m7,m8,m9,m10)
#best model = m9
logLik(m9)
summary(m9)$r.sq

gam.check(m9)
summary(m9)
#                 Estimate Std. Error t value Pr(>|t|)    
# (Intercept)    0.131130   0.015003   8.740  < 2e-16 ***
#   FoodS       -0.227806   0.016240 -14.027  < 2e-16 ***
#   Recup        0.004311   0.001630   2.645  0.00859 ** 
anova(m9)
# Approximate significance of smooth terms:
#                             edf Ref.df      F p-value
# s(Temp):FoodRecoveryCY.2  3.92   4.51 37.743 < 2e-16
# s(Temp):FoodRecoveryS.2   1.00   1.00  0.261 0.60950
# s(Temp):FoodRecoveryCY.12 1.00   1.00  7.197 0.00769
# s(Temp):FoodRecoveryS.12  1.00   1.00  0.755 0.38550












lm_weight <- lm(Weight ~ Recup * Temp * Food, data = data2)
anova(lm_weight)
# Analysis of Variance Table
# 
# Response: Weight
#                   Df Sum Sq Mean Sq  F value    Pr(>F)    
# Recup             1  90374   90374 127.2571 < 2.2e-16 ***
# Temp              1    994     994   1.4001  0.237610    
# Food              1  17153   17153  24.1539 1.437e-06 ***
# Recup:Temp        1   2892    2892   4.0720  0.044453 *  
# Recup:Food        1   5239    5239   7.3773  0.006972 ** 
# Temp:Food         1      1       1   0.0018  0.966641    
# Recup:Temp:Food   1   1284    1284   1.8076  0.179773    
# Residuals       313 222282     710      