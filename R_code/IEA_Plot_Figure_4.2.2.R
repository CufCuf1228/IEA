# Compare one-tipping coalition scenarios with the grand coalition.
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
    stop(paste("Could not find the file; check the path:", f))
  }
}

if (!dir.exists(save_main_dir)) {
  dir.create(save_main_dir, recursive = TRUE)
}

# ================= Plot settings =================
all_element_size <- 30
color_tip <- "darkgray"

# One tipping event with a single tipping year.
tip_years <- c(2060)

nations <- c(
  "China", "US", "EU", "Japan", "Russia", "India",
  "MidEast", "LatAm", "OthAsia", "Eurasia", "OHI", "Africa"
)

emission_cols <- paste0("Emission of ", nations)

# ================= Core data extraction =================
extract_metrics <- function(filepath, sheet_name) {
  
  if (!file.exists(filepath)) {
    warning(paste("File does not exist:", filepath))
    return(NULL)
  }
  
  sheet_list <- getSheetNames(filepath)
  
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
    sheet = sheet_name
  )
  
  colnames(df) <- gsub(
    "\\.",
    " ",
    colnames(df)
  )
  
  req_cols <- c(
    "Year",
    "Temp",
    "Utility of All",
    emission_cols
  )
  
  if (!all(req_cols %in% colnames(df))) {
    
    missing_cols <- req_cols[
      !(req_cols %in% colnames(df))
    ]
    
    warning(
      paste(
        "File",
        basename(filepath),
        "Sheet",
        sheet_name,
        "is missing required columns:",
        paste(
          missing_cols,
          collapse = ", "
        )
      )
    )
    
    return(NULL)
  }
  
  df_clean <- df %>%
    
    rowwise() %>%
    
    mutate(
      Total_Emission = sum(
        c_across(
          all_of(emission_cols)
        ),
        na.rm = TRUE
      )
    ) %>%
    
    ungroup() %>%
    
    mutate(
      Year = as.numeric(Year),
      Temp = as.numeric(Temp),
      Total_Profit = as.numeric(
        `Utility of All`
      ),
      Total_Emission = as.numeric(
        Total_Emission
      )
    ) %>%
    
    select(
      Year,
      Temp,
      Total_Emission,
      Total_Profit
    ) %>%
    
    filter(
      !is.na(Year)
    )
  
  return(df_clean)
}

# ================= Difference calculation =================
calc_diff_vs_grand <- function(
    df_target,
    df_grand,
    scenario_name
) {
  
  if (
    is.null(df_target) ||
    is.null(df_grand)
  ) {
    return(NULL)
  }
  
  left_join(
    df_target,
    df_grand,
    by = "Year",
    suffix = c(
      "_sc",
      "_grand"
    )
  ) %>%
    
    mutate(
      Scenario = scenario_name,
      
      Temp_Diff =
        Temp_sc -
        Temp_grand,
      
      Emission_Diff =
        Total_Emission_sc -
        Total_Emission_grand,
      
      Profit_Diff =
        Total_Profit_sc -
        Total_Profit_grand
    ) %>%
    
    select(
      Year,
      Scenario,
      Temp_Diff,
      Emission_Diff,
      Profit_Diff
    ) %>%
    
    filter(
      !is.na(Year)
    )
}

make_merged_plot_data <- function(
    sheet_name
) {
  
  df_grand_future <- extract_metrics(
    file_grand_future,
    sheet_name
  )
  
  if (is.null(df_grand_future)) {
    return(NULL)
  }
  
  df_no_coalition <- extract_metrics(
    file_no_coalition_future,
    sheet_name
  )
  
  df_advanced <- extract_metrics(
    file_advanced_future,
    sheet_name
  )
  
  df_emerging_and_developing <- extract_metrics(
    file_emerging_and_developing_future,
    sheet_name
  )
  
  df_stable_future <- extract_metrics(
    file_stable_future,
    sheet_name
  )
  
  diff_no_coalition <- calc_diff_vs_grand(
    df_no_coalition,
    df_grand_future,
    "No Coalition"
  )
  
  diff_advanced <- calc_diff_vs_grand(
    df_advanced,
    df_grand_future,
    "Advanced Coalition"
  )
  
  diff_emerging_and_developing <- calc_diff_vs_grand(
    df_emerging_and_developing,
    df_grand_future,
    "Emerging & Developing Coalition"
  )
  
  diff_stable_future <- calc_diff_vs_grand(
    df_stable_future,
    df_grand_future,
    "Stable Coalition"
  )
  
  plot_data <- bind_rows(
    diff_no_coalition,
    diff_advanced,
    diff_emerging_and_developing,
    diff_stable_future
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
get_ylim <- function(
    x,
    padding_ratio = 0.05
) {
  
  values <- x[
    is.finite(x)
  ]
  
  if (
    length(values) == 0
  ) {
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

# ================= Shared plot settings =================
scenario_levels <- c(
  "No Coalition",
  "Advanced Coalition",
  "Emerging & Developing Coalition",
  "Stable Coalition"
)

scenario_colors <- c(
  "No Coalition" = "black",
  "Advanced Coalition" = "red",
  "Emerging & Developing Coalition" = "darkgreen",
  "Stable Coalition" = "blue"
)

scenario_linetypes <- c(
  "No Coalition" = "solid",
  "Advanced Coalition" = "dashed",
  "Emerging & Developing Coalition" = "dashed",
  "Stable Coalition" = "solid"
)

legend_levels <- c(
  "No Coalition",
  "Advanced Coalition",
  "Emerging & Developing Coalition",
  "Stable Coalition",
  "Tipping Time"
)

legend_colors <- c(
  scenario_colors,
  "Tipping Time" = color_tip
)

legend_linetypes <- c(
  scenario_linetypes,
  "Tipping Time" = "twodash"
)

legend_linewidths <- c(
  "No Coalition" = 1.2,
  "Advanced Coalition" = 1.2,
  "Emerging & Developing Coalition" = 1.2,
  "Stable Coalition" = 1.2,
  "Tipping Time" = 0.8
)

# ================= Shared layers =================
# Note: 
common_layers <- list(
  
  geom_hline(
    yintercept = 0,
    linetype = "solid",
    color = "gray50",
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
      size = all_element_size - 2,
      face = "bold",
      color = "black"
    ),
    
    panel.grid.minor = element_blank(),
    
    # Add top padding, 
    plot.margin = margin(
      t = 25,
      r = 10,
      b = 5,
      l = 10
    )
  )
)

# ================= Panel builder =================
make_panel <- function(
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
    
  geom_line(
    aes(
      y = .data[[y_var]],
      color = Scenario,
      linetype = Scenario
    ),
    linewidth = 1.2,
    show.legend = FALSE
  ) +
    
    # ---------- Shared layers ----------
  common_layers +
    
  # Place the label above the 2060 vertical line
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
    
    # ---------- Y-axis range ----------
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

# ================= Main processing =================
cat(
  "Plotting Figure 1 for one tipping event using Future results only...\n"
)

sheet_names <- getSheetNames(
  file_grand_future
)

for (
  sheet_name in sheet_names
) {
  
  cat(
    "  -> Calculating and plotting Sheet:",
    sheet_name,
    "\n"
  )
  
  plot_data <- make_merged_plot_data(
    sheet_name
  )
  
  if (
    is.null(plot_data)
  ) {
    
    cat(
      "    Data are missing; skipping...\n"
    )
    
    next
  }
  
  plot_data$Scenario <- factor(
    plot_data$Scenario,
    levels = scenario_levels
  )
  
  # ================= Get each panel Y-axis range =================
  ylim_temp <- get_ylim(
    plot_data$Temp_Diff
  )
  
  ylim_emission <- get_ylim(
    plot_data$Emission_Diff
  )
  
  ylim_Profit <- get_ylim(
    plot_data$Profit_Diff
  )
  
  # ================= Panel a =================
  p_a <- make_panel(
    plot_data = plot_data,
    y_var = "Temp_Diff",
    y_label = "Temp Difference (°C)",
    panel_tag = "a",
    ylim_common = ylim_temp
  )
  
  # ================= Panel b =================
  p_b <- make_panel(
    plot_data = plot_data,
    y_var = "Emission_Diff",
    y_label = "Total Emission Difference (GtC)",
    panel_tag = "b",
    ylim_common = ylim_emission
  )
  
  # ================= Panel c =================
  p_c <- make_panel(
    plot_data = plot_data,
    y_var = "Profit_Diff",
    y_label = "Total Utility Difference (Trillion $)",
    panel_tag = "c",
    ylim_common = ylim_Profit
  )
  
  # ================= Arrange three panels horizontally =================
  main_plot <- p_a + p_b + p_c +
    plot_layout(
      ncol = 3
    )
  
  legend_block <- make_custom_legend(
    legend_levels = legend_levels,
    nrow = 1
  )
  
  # ================= Main plot and legend =================
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
      "Scenarios_vs_GrandCoalition_",
      safe_sheet_name,
      "_Onetipping.pdf"
    )
  )
  
  suppressWarnings(
    ggsave(
      filename = save_name,
      plot = final_plot,
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
  "==== Figure 1 generated for one tipping event using Future results only!  ====\n"
)
