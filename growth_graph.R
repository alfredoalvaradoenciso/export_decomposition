# Load necessary libraries
library(readxl)    # For importing Excel files
library(dplyr)     # For data manipulation
library(tidyr)
library(ggplot2)
library(here)

source(here("utils/theme_and_colors_IMF.R"))

# Set file path and read the Excel file
file_path <- file.path("//data4/users10/aalvarado/My Documents/GTM/export_decomposition/bases/RUS2001_2008_2015.xlsx")
data <- read_excel(file_path, sheet = "Sheet1", col_names = TRUE)

# Keep selected columns
data <- data %>%
  select(refYear, reporterISO, partnerISO, cmdCode, fobvalue)

# Create a new variable 'destine' as a grouped numeric identifier for 'partnerISO'
data <- data %>%
  mutate(destine = as.numeric(as.factor(partnerISO)))

# Drop the 'partnerISO' column
data <- data %>%
  select(-partnerISO)


# Define the initial and end years
initialyear <- 2008
endyear <- 2015

# Filter for specified years
data_filtered <- data %>%
  filter(refYear == initialyear | refYear == endyear)

# Total growth
total <- data_filtered %>%
  group_by(refYear) %>%
  summarise(fobvalue = sum(fobvalue, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = refYear, values_from = fobvalue, names_prefix = "fobvalue") %>%
  mutate(exp_decomp = 7) %>%
  mutate(growth_contr = ((!!sym(paste0("fobvalue", endyear))/!!sym(paste0("fobvalue", initialyear))) -1)*100) %>%
  select(growth_contr, exp_decomp)

# 1. Destination Analysis
# Collapse by 'destine' and 'refYear'
destine_data <- data_filtered %>%
  group_by(destine, refYear) %>%
  summarise(fobvalue = sum(fobvalue, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = refYear, values_from = fobvalue, names_prefix = "fobvalue") 

# Generate the 'dest' column
destine_data <- destine_data %>%
  mutate(dest = case_when(
    !is.na(get(paste0("fobvalue", initialyear))) & !is.na(get(paste0("fobvalue", endyear))) ~ 1, # surviving destination
    is.na(get(paste0("fobvalue", initialyear))) & !is.na(get(paste0("fobvalue", endyear))) ~ 2, # new destination
    !is.na(get(paste0("fobvalue", initialyear))) & is.na(get(paste0("fobvalue", endyear))) ~ 3  # old destination
  )) %>%
  select(destine, dest)


# 2. Product Analysis
# Collapse by 'cmdCode' and 'refYear'
product_data <- data_filtered %>%
  group_by(cmdCode, refYear) %>%
  summarise(fobvalue = sum(fobvalue, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = refYear, values_from = fobvalue, names_prefix = "fobvalue") 

# Generate the 'prod' column
product_data <- product_data %>%
  mutate(prod = case_when(
    !is.na(get(paste0("fobvalue", initialyear))) & !is.na(get(paste0("fobvalue", endyear))) ~ 1, # surviving product
    is.na(get(paste0("fobvalue", initialyear))) & !is.na(get(paste0("fobvalue", endyear))) ~ 2, # new product
    !is.na(get(paste0("fobvalue", initialyear))) & is.na(get(paste0("fobvalue", endyear))) ~ 3  # old product
  )) %>%
  select(cmdCode, prod)


# 3. Product-Destination Analysis
# Reshape for product-destination analysis
prod_dest_data <- data_filtered %>%
  group_by(destine, cmdCode, refYear) %>%
  summarise(fobvalue = sum(fobvalue, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = refYear, values_from = fobvalue, names_prefix = "fobvalue")

# Generate the 'prod_dest' column
prod_dest_data <- prod_dest_data %>%
  mutate(prod_dest = case_when(
    !is.na(get(paste0("fobvalue", initialyear))) & !is.na(get(paste0("fobvalue", endyear))) ~ 1, # surviving destination-product
    is.na(get(paste0("fobvalue", initialyear))) & !is.na(get(paste0("fobvalue", endyear))) ~ 2, # new destination-product
    !is.na(get(paste0("fobvalue", initialyear))) & is.na(get(paste0("fobvalue", endyear))) ~ 3  # old destination-product
  ))


# Merge 'destine_data' into 'prod_dest_data'
prod_dest_data <- prod_dest_data %>%
  left_join(destine_data %>% select(destine, dest), by = "destine")

# Merge 'product_data' into 'prod_dest_data'
prod_dest_data <- prod_dest_data %>%
  left_join(product_data %>% select(cmdCode, prod), by = "cmdCode")


prod_dest_data <- prod_dest_data %>%
  mutate(exp_decomp = case_when(
    prod_dest == 1 ~ 1,  # Surviving P-D
    prod_dest == 2 & dest == 1 & prod == 1 ~ 2,  # New P-D, old space
    prod_dest == 2 & dest == 2 & prod == 1 ~ 3,  # New D, old P
    prod_dest == 2 & dest == 1 & prod == 2 ~ 4,  # New P, old D
    prod_dest == 2 & dest == 2 & prod == 2 ~ 5,  # New P, New D
    prod_dest == 3 ~ 6  # Dead P-D
  ))

# Step 3: Summarize data by `exp_decomp`
collapsed_exp <- prod_dest_data %>%
  group_by(exp_decomp) %>%
  summarise(
    !!paste0("fobvalue", initialyear) := sum(get(paste0("fobvalue", initialyear)), na.rm = TRUE),
    !!paste0("fobvalue", endyear) := sum(get(paste0("fobvalue", endyear)), na.rm = TRUE),
    .groups = "drop"
  )

# Calculate dif, contr, totals, growth, and growth_contr
data2 <- collapsed_exp %>%
  mutate(
    dif = !!sym(paste0("fobvalue", endyear)) - !!sym(paste0("fobvalue", initialyear))
  ) %>%
  mutate(
    contr = dif / sum(dif, na.rm = TRUE)  # Proportional contributions
  ) %>%
  mutate(
    growth = (sum(!!sym(paste0("fobvalue", endyear)))/sum(!!sym(paste0("fobvalue", initialyear))))-1
  ) %>%
  mutate(
    growth_contr = (growth * contr) * 100
  )

# Append collapsed summary to the original data
data3 <- bind_rows(data2, total)  %>%
  select(exp_decomp, growth_contr) %>%
  mutate(periods = !!paste0("g", initialyear, "_", endyear))

data_frame_name <- paste0("d", initialyear, "_", endyear)
assign(data_frame_name, data3)


#final df
df <- bind_rows(d2001_2015, d2001_2008, d2008_2015)

# IMF procedure to make contribution graph


df <- df %>%
  mutate(
    desc = recode(
      exp_decomp,
      `1` = "Surviving P-D",
      `2` = "New P-D, old space",
      `3` = "New D, old P",
      `4` = "New P, old D",
      `5` = "New P, New D",
      `6` = "Dead P-D",
      `7` = "Total Growth"
    )
  )

custom_colors <- c(
  "Surviving P-D" = "#e41a1c",
  "New P-D, old space" = "#FF7F0E",
  "New D, old P" = "#56B4E9",
  "New P, old D" = "#377eb8",
  "New P, New D" = "#4daf4a",
  "Dead P-D" = "#900000"
)

df <- df %>%
  mutate(growth_contr = ifelse(exp_decomp == 7, growth_contr / 20, growth_contr))

fig <- ggplot(df %>% filter(desc != "Total Growth"),
              aes(x = periods, y = growth_contr, fill = desc)) + geom_col() +
  geom_point(data = df %>% filter(desc == "Total Growth"),
             aes(x = periods, y = growth_contr), size = 3.4, show.legend = FALSE, 
             position = position_nudge(y = 0)) +
  xlab("") + ylab("") +
  theme_imf_panel() +
  theme(
    legend.position = "bottom",
    legend.title = element_blank()
  ) +
  scale_fill_manual(values = custom_colors) +
  scale_shape_manual(values = c(GDP = 16)) +  # Customize the point shape for "GDP"
  labs(
    title = "Export Growth Decomposition for Russia, 2001-2015",
    subtitle = "(Percentage points)"
  ) +
  geom_text(aes(label = sprintf("%.1f", growth_contr)), 
            position = position_stack(vjust = 0.5), 
            size = 3, color = "white")

# Print the plot
plot(fig)
