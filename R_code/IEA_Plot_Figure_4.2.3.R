# Plot benefit, damage, and profit differences relative to no coalition.
# Run this script from the R_code directory so all paths remain relative.

# ================= Load packages =================
library(ggplot2)
library(tidyverse)
library(openxlsx)
library(patchwork)
library(stringr)
library(cowplot)

options(digits = 2)

# ================= Parameters =================
base_dir <- file.path("..", "code", "One Tipping Find Steady Coalition", "Results of Various Coalitions")
save_main_dir <- file.path(".", "IEA Figures 4.2")

r_value <- "0.03"

# Whether to include the grand coalition
include_grand <- TRUE

# Set a sheet name to plot one sheet, or use NULL to process all sheets
sheet_to_plot <- NULL

# ---------- Future files ----------
file_no_coalition_future <- file.path(
  base_dir,
  paste0(
    "Year_2025_No_Coalition_Result_Onetipping_Shapley_Future_r_",
    r_value,
    ".xlsx"
  )
)

file_stable_future <- file.path(
  base_dir,
  paste0(
    "Year_2025_Stable_Coalition_Result_Onetipping_Shapley_Future_r_",
    r_value,
    ".xlsx"
  )
)

file_grand_future <- file.path(
  base_dir,
  paste0(
    "Year_2025_Grand_Coalition_Result_Onetipping_Shapley_Future_r_",
    r_value,
    ".xlsx"
  )
)

file_advanced_future <- file.path(
  base_dir,
  paste0(
    "Year_2025_Developed_Coalition_Result_Onetipping_Shapley_Future_r_",
    r_value,
    ".xlsx"
  )
)

file_emerging_and_developing_future <- file.path(
  base_dir,
  paste0(
    "Year_2025_Developing_Coalition_Result_Onetipping_Shapley_Future_r_",
    r_value,
    ".xlsx"
  )
)

required_files <- c(
  file_no_coalition_future,
  file_stable_future,
  file_grand_future,
  file_advanced_future,
  file_emerging_and_developing_future
)

for (f in required_files) {
  if (!file.exists(f)) {
    stop(
      paste(
        "Could not find the file; check the path:",
        f
      )
    )
  }
}

if (!dir.exists(save_main_dir)) {
  dir.create(
    save_main_dir,
    recursive = TRUE
  )
}

# ================= Plot settings =================
all_element_size <- 30
color_tip <- "darkgray"

# One tipping event
tip_years <- c(2060)

benefit_diff_ylim_manual <- NULL
damage_diff_ylim_manual <- NULL
Profit_diff_ylim_manual <- NULL

# Example manual settings: 
# benefit_diff_ylim_manual <- c(-10, 20)
# damage_diff_ylim_manual  <- c(-10, 10)
# Profit_diff_ylim_manual  <- c(-10, 20)

# ================= Data extraction =================
extract_calibration_metrics <- function(
    filepath,
    sheet_name,
    scenario_name
) {
  
  if (!file.exists(filepath)) {
    warning(
      paste(
        "File does not exist:",
        filepath
      )
    )
    return(NULL)
  }
  
  sheet_list <- getSheetNames(
    filepath
  )
  
  if (!(sheet_name %in% sheet_list)) {
    warning(
      paste(
        "File",
        basename(filepath),
        "does not contain sheet:",
        sheet_name
      )
    )
    return(NULL)
  }
  
  df <- read.xlsx(
    filepath,
    sheet = sheet_name,
    check.names = FALSE
  )
  
  colnames(df) <- gsub(
    "\\.",
    " ",
    colnames(df)
  )
  
  df <- as_tibble(df)
  
  if (!("Year" %in% colnames(df))) {
    warning(
      paste(
        "Sheet",
        sheet_name,
        "is missing the Year column."
      )
    )
    return(NULL)
  }
  
  if (!("Utility of All" %in% colnames(df))) {
    warning(
      paste(
        "Sheet",
        sheet_name,
        "is missing the Utility of All column."
      )
    )
    return(NULL)
  }
  
  # Utility of All = total instantaneous utility
  df <- df %>%
    mutate(
      Year = as.numeric(Year),
      Total_Profit = as.numeric(
        `Utility of All`
      )
    )
  
  # Accept both Benifit and Benefit column spellings
  benefit_total_cols <- intersect(
    c(
      "Benifit of All",
      "Benefit of All"
    ),
    colnames(df)
  )
  
  if (length(benefit_total_cols) > 0) {
    
    benefit_total_col <- benefit_total_cols[1]
    
    df_clean <- df %>%
      mutate(
        Total_Benefit = as.numeric(
          .data[[benefit_total_col]]
        )
      )
    
  } else {
    
    benefit_country_cols <- grep(
      "^(Benifit|Benefit) of ",
      colnames(df),
      value = TRUE
    )
    
    benefit_country_cols <- setdiff(
      benefit_country_cols,
      c(
        "Benifit of All",
        "Benefit of All"
      )
    )
    
    if (length(benefit_country_cols) == 0) {
      warning(
        paste(
          "Sheet",
          sheet_name,
          "does not contain Benifit of ... or Benefit of ... columns."
        )
      )
      return(NULL)
    }
    
    df_clean <- df %>%
      rowwise() %>%
      mutate(
        Total_Benefit = sum(
          c_across(
            all_of(
              benefit_country_cols
            )
          ),
          na.rm = TRUE
        )
      ) %>%
      ungroup()
  }
  
  df_clean <- df_clean %>%
    mutate(
      # Negative damage term in utility
      Total_Damage =
        Total_Benefit -
        Total_Profit,
      
      Scenario =
        scenario_name
    ) %>%
    select(
      Year,
      Scenario,
      Total_Benefit,
      Total_Profit,
      Total_Damage
    ) %>%
    filter(
      !is.na(Year)
    )
  
  return(df_clean)
}

# ================= Calculate differences from no coalition =================
calc_diff_vs_no_coalition <- function(
    df_target,
    df_no_coalition
) {
  
  if (
    is.null(df_target) ||
    is.null(df_no_coalition)
  ) {
    return(NULL)
  }
  
  df_base <- df_no_coalition %>%
    select(
      Year,
      Base_Benefit = Total_Benefit,
      Base_Damage = Total_Damage,
      Base_Profit = Total_Profit
    )
  
  df_target %>%
    left_join(
      df_base,
      by = "Year"
    ) %>%
    mutate(
      Benefit_Diff =
        Total_Benefit -
        Base_Benefit,
      
      Damage_Diff =
        Total_Damage -
        Base_Damage,
      
      Profit_Diff =
        Total_Profit -
        Base_Profit
    ) %>%
    select(
      Year,
      Scenario,
      Benefit_Diff,
      Damage_Diff,
      Profit_Diff
    ) %>%
    filter(
      !is.na(Year)
    )
}

# ================= Combine coalition scenarios =================
make_calibration_plot_data <- function(
    sheet_name
) {
  
  df_no_coalition <- extract_calibration_metrics(
    file_no_coalition_future,
    sheet_name,
    "No Coalition"
  )
  
  if (is.null(df_no_coalition)) {
    return(NULL)
  }
  
  df_advanced <- extract_calibration_metrics(
    file_advanced_future,
    sheet_name,
    "Advanced Coalition"
  )
  
  df_emerging_and_developing <- extract_calibration_metrics(
    file_emerging_and_developing_future,
    sheet_name,
    "Emerging & Developing Coalition"
  )
  
  df_stable_future <- extract_calibration_metrics(
    file_stable_future,
    sheet_name,
    "Stable Coalition"
  )
  
  # Exclude no coalition and instantaneous-profit scenarios
  data_list <- list(
    calc_diff_vs_no_coalition(
      df_advanced,
      df_no_coalition
    ),
    
    calc_diff_vs_no_coalition(
      df_emerging_and_developing,
      df_no_coalition
    ),
    
    calc_diff_vs_no_coalition(
      df_stable_future,
      df_no_coalition
    )
  )
  
  if (include_grand) {
    
    df_grand <- extract_calibration_metrics(
      file_grand_future,
      sheet_name,
      "Grand Coalition"
    )
    
    data_list <- c(
      list(
        calc_diff_vs_no_coalition(
          df_grand,
          df_no_coalition
        )
      ),
      data_list
    )
  }
  
  plot_data <- bind_rows(
    data_list
  )
  
  if (
    is.null(plot_data) ||
    nrow(plot_data) == 0
  ) {
    return(NULL)
  }
  
  return(plot_data)
}

# ================= Y-axis range helper =================
get_ylim_diff <- function(
    x,
    padding_ratio = 0.08
) {
  
  values <- x[
    is.finite(x)
  ]
  
  if (length(values) == 0) {
    return(
      c(-1, 1)
    )
  }
  
  y_min <- min(
    0,
    min(
      values,
      na.rm = TRUE
    )
  )
  
  y_max <- max(
    0,
    max(
      values,
      na.rm = TRUE
    )
  )
  
  if (
    abs(y_max - y_min) < 1e-12
  ) {
    
    pad <- max(
      abs(y_max),
      1
    ) * padding_ratio
    
  } else {
    
    pad <- (
      y_max - y_min
    ) * padding_ratio
  }
  
  return(
    c(
      y_min - pad,
      y_max + pad
    )
  )
}

# ================= Line and legend settings =================
if (include_grand) {
  
  scenario_levels <- c(
    "Grand Coalition",
    "Advanced Coalition",
    "Emerging & Developing Coalition",
    "Stable Coalition"
  )
  
  scenario_colors <- c(
    "Grand Coalition" = "purple",
    "Advanced Coalition" = "red",
    "Emerging & Developing Coalition" = "darkgreen",
    "Stable Coalition" = "blue"
  )
  
  scenario_linetypes <- c(
    "Grand Coalition" = "solid",
    "Advanced Coalition" = "dashed",
    "Emerging & Developing Coalition" = "dashed",
    "Stable Coalition" = "solid"
  )
  
  legend_levels <- c(
    "Grand Coalition",
    "Advanced Coalition",
    "Emerging & Developing Coalition",
    "Stable Coalition",
    "Tipping Time"
  )
  
} else {
  
  scenario_levels <- c(
    "Advanced Coalition",
    "Emerging & Developing Coalition",
    "Stable Coalition"
  )
  
  scenario_colors <- c(
    "Advanced Coalition" = "red",
    "Emerging & Developing Coalition" = "darkgreen",
    "Stable Coalition" = "blue"
  )
  
  scenario_linetypes <- c(
    "Advanced Coalition" = "solid",
    "Emerging & Developing Coalition" = "dashed",
    "Stable Coalition" = "solid"
  )
  
  legend_levels <- c(
    "Advanced Coalition",
    "Emerging & Developing Coalition",
    "Stable Coalition",
    "Tipping Time"
  )
}

legend_colors <- c(
  scenario_colors,
  "Tipping Time" = color_tip
)

legend_linetypes <- c(
  scenario_linetypes,
  "Tipping Time" = "twodash"
)

legend_linewidths <- c(
  setNames(
    rep(
      1.2,
      length(scenario_levels)
    ),
    scenario_levels
  ),
  "Tipping Time" = 0.8
)

# ================= Shared layers =================
common_layers <- list(
  
  geom_hline(
    yintercept = 0,
    color = "gray50",
    linetype = "solid",
    linewidth = 0.5,
    show.legend = FALSE
  ),
  
  geom_vline(
    data = data.frame(
      TipYear = tip_years
    ),
    aes(
      xintercept = TipYear
    ),
    color = color_tip,
    linetype = "twodash",
    linewidth = 0.8,
    alpha = 0.8,
    inherit.aes = FALSE,
    show.legend = FALSE
  ),
  
  scale_x_continuous(
    breaks = seq(
      2025,
      2100,
      by = 15
    ),
    limits = c(
      2025,
      2100
    ),
    expand = expansion(
      mult = c(
        0,
        0.05
      )
    )
  ),
  
  scale_color_manual(
    values = scenario_colors,
    breaks = scenario_levels,
    drop = FALSE,
    guide = "none"
  ),
  
  scale_linetype_manual(
    values = scenario_linetypes,
    breaks = scenario_levels,
    drop = FALSE,
    guide = "none"
  ),
  
  scale_y_continuous(
    labels = scales::comma
  ),
  
  theme_bw(),
  
  theme(
    plot.title = element_blank(),
    
    plot.tag = element_text(
      face = "bold",
      size = all_element_size
    ),
    
    axis.title = element_text(
      size = all_element_size - 2,
      face = "bold",
      color = "black"
    ),
    
    axis.text = element_text(
      size = all_element_size - 4,
      face = "bold",
      color = "black"
    ),
    
    panel.grid.minor = element_blank(),
    
    # Add top padding to prevent clipping of the Tipping label
    plot.margin = margin(
      t = 25,
      r = 20,
      b = 10,
      l = 20
    )
  )
)

# ================= Panel builder =================
# Add the Tipping label consistently to all three panels
make_calibration_panel <- function(
    plot_data,
    y_var,
    y_label,
    panel_tag,
    ylim_common
) {
  
  ggplot(
    plot_data,
    aes(
      x = Year
    )
  ) +
    
    # ---------- Scenario curves ----------
  geom_line(
    aes(
      y = .data[[y_var]],
      color = Scenario,
      linetype = Scenario
    ),
    linewidth = 1.25,
    show.legend = FALSE
  ) +
    
    # ---------- Shared layers ----------
  common_layers +
    
  annotate(
    "text",
    x = tip_years[1],
    y = ylim_common[2],
    label = "Tipping",
    vjust = -1.2,
    size = 9,
    fontface = "bold",
    color = "black"
  ) +
    
    # ---------- Axis range ----------
  coord_cartesian(
    ylim = ylim_common,
    clip = "off"
  ) +
    
    labs(
      x = "Year",
      y = y_label,
      tag = panel_tag
    )
}

# ================= Custom legend builder =================
make_custom_legend <- function(
    legend_levels,
    nrow = 1
) {
  
  legend_df <- expand.grid(
    Year = c(
      2025,
      2026
    ),
    Scenario = legend_levels
  ) %>%
    arrange(
      factor(
        Scenario,
        levels = legend_levels
      ),
      Year
    ) %>%
    mutate(
      y = as.numeric(
        factor(
          Scenario,
          levels = legend_levels
        )
      )
    )
  
  p_legend <- ggplot(
    legend_df,
    aes(
      x = Year,
      y = y,
      color = Scenario,
      linetype = Scenario,
      group = Scenario
    )
  ) +
    
    geom_line(
      linewidth = 1.2
    ) +
    
    scale_color_manual(
      name = NULL,
      values = legend_colors[
        legend_levels
      ],
      breaks = legend_levels,
      drop = FALSE
    ) +
    
    scale_linetype_manual(
      name = NULL,
      values = legend_linetypes[
        legend_levels
      ],
      breaks = legend_levels,
      drop = FALSE
    ) +
    
    guides(
      color = guide_legend(
        nrow = nrow,
        byrow = TRUE,
        override.aes = list(
          color = unname(
            legend_colors[
              legend_levels
            ]
          ),
          linetype = unname(
            legend_linetypes[
              legend_levels
            ]
          ),
          linewidth = unname(
            legend_linewidths[
              legend_levels
            ]
          )
        )
      ),
      linetype = "none"
    ) +
    
    theme_void() +
    
    theme(
      legend.position = "bottom",
      legend.direction = "horizontal",
      legend.box = "horizontal",
      
      legend.text = element_text(
        size = all_element_size - 4,
        face = "bold"
      ),
      
      legend.key.width = unit(
        1.6,
        "cm"
      ),
      
      legend.spacing.x = unit(
        0.25,
        "cm"
      ),
      
      legend.margin = margin(
        t = 0,
        r = 0,
        b = 0,
        l = 0
      ),
      
      plot.margin = margin(
        t = 0,
        r = 0,
        b = 0,
        l = 0
      )
    )
  
  cowplot::get_legend(
    p_legend
  )
}

# ================= Main loop =================
cat(
  "Plotting calibration differences from no coalition across coalition scenarios; one tipping event, Future only...\n"
)

sheet_names <- Reduce(
  intersect,
  lapply(
    required_files,
    getSheetNames
  )
)

if (!is.null(sheet_to_plot)) {
  
  if (!(sheet_to_plot %in% sheet_names)) {
    stop(
      paste(
        "The requested sheet does not exist:",
        sheet_to_plot
      )
    )
  }
  
  sheet_names <- sheet_to_plot
}

for (sheet_name in sheet_names) {
  
  cat(
    "  -> Processing Sheet:",
    sheet_name,
    "\n"
  )
  
  plot_data <- make_calibration_plot_data(
    sheet_name
  )
  
  if (is.null(plot_data)) {
    
    cat(
      "    Data are missing; skipping...\n"
    )
    
    next
  }
  
  plot_data$Scenario <- factor(
    plot_data$Scenario,
    levels = scenario_levels
  )
  
  # ================= Y-axis range =================
  ylim_benefit <- if (
    is.null(
      benefit_diff_ylim_manual
    )
  ) {
    
    get_ylim_diff(
      plot_data$Benefit_Diff
    )
    
  } else {
    
    benefit_diff_ylim_manual
  }
  
  ylim_damage <- if (
    is.null(
      damage_diff_ylim_manual
    )
  ) {
    
    get_ylim_diff(
      plot_data$Damage_Diff
    )
    
  } else {
    
    damage_diff_ylim_manual
  }
  
  ylim_Profit <- if (
    is.null(
      Profit_diff_ylim_manual
    )
  ) {
    
    get_ylim_diff(
      plot_data$Profit_Diff
    )
    
  } else {
    
    Profit_diff_ylim_manual
  }
  
  # ================= Panel a: Benefit =================
  p_benefit <- make_calibration_panel(
    plot_data = plot_data,
    y_var = "Benefit_Diff",
    y_label = "Total Benefit Difference (Trillion $)",
    panel_tag = "a",
    ylim_common = ylim_benefit
  )
  
  # ================= Panel b: Damage =================
  p_damage <- make_calibration_panel(
    plot_data = plot_data,
    y_var = "Damage_Diff",
    y_label = "Total Damage Difference (Trillion $)",
    panel_tag = "b",
    ylim_common = ylim_damage
  )
  
  # ================= Panel c: Profit =================
  p_Profit <- make_calibration_panel(
    plot_data = plot_data,
    y_var = "Profit_Diff",
    y_label = "Total Utility Difference (Trillion $)",
    panel_tag = "c",
    ylim_common = ylim_Profit
  )
  
  # ================= Arrange three panels horizontally =================
  main_plot <- cowplot::plot_grid(
    p_benefit,
    p_damage,
    p_Profit,
    ncol = 3,
    align = "h",
    axis = "tb",
    rel_widths = c(
      1,
      1,
      1
    )
  )
  
  # ================= Legend =================
  legend_block <- make_custom_legend(
    legend_levels = legend_levels,
    nrow = 1
  )
  
  # ================= Final plot =================
  final_plot <- cowplot::plot_grid(
    main_plot,
    legend_block,
    ncol = 1,
    rel_heights = c(
      1,
      0.1
    )
  )
  
  # ================= Save output =================
  safe_sheet_name <- gsub(
    "[\\\\/:*?\"<>|]",
    "_",
    sheet_name
  )
  
  save_name <- file.path(
    save_main_dir,
    paste0(
      "Calibration_Benefit_Damage_Profit_Diff_vs_NoCoalition_",
      safe_sheet_name,
      ".pdf"
    )
  )
  
  suppressWarnings(
    ggsave(
      filename = save_name,
      plot = final_plot,
      device = "pdf",
      width = 24,
      height = 8
    )
  )
  
  cat(
    "     Saved to:",
    save_name,
    "\n"
  )
}

cat(
  "==== Benefit, damage, and profit differences from no coalition generated; One tipping event, Future-only!  ====\n"
)
