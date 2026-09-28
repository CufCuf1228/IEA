# Compare connection and tipping-damage sensitivity cases with the benchmark.
# Run this script from the R_code directory so all paths remain relative.

# ================= Load packages =================
library(ggplot2)
library(tidyverse)
library(openxlsx)
library(stringr)
library(patchwork)
library(cowplot)

options(digits = 2)

# ================= Parameters =================
base_dir <- file.path("..", "code", "One Tipping Find Steady Coalition", "Results of SA Con Tipping")

save_dir <- file.path(".", "IEA Figures 4.5", "IEA Figures 4.5.1")

if (!dir.exists(save_dir)) {
  dir.create(
    save_dir,
    recursive = TRUE
  )
}

# =========================================================
# File paths
# =========================================================

benchmark_file <- file.path(
  base_dir,
  "Year_2025_Stable_Coalition_Result_Onetipping_Shapley_Future_r_0.03.xlsx"
)

# ---------------------------------------------------------
# Keep only: 
# 1. Connection
# 2. Tipping Damage
# ---------------------------------------------------------
scenario_files <- list(
  
  "Connection" = file.path(
    base_dir,
    "Year_2025_Stable_Coalition_Result_Onetipping_Shapley_Future_r_0.03_Connection.xlsx"
  ),
  
  "Tipping_Damage" = file.path(
    base_dir,
    "Year_2025_Stable_Coalition_Result_Onetipping_Shapley_Future_r_0.03_Tipping_Damage.xlsx"
  )
)

benchmark_sheet <- 1

scenario_sheets <- list(
  "Connection" = 1,
  "Tipping_Damage" = 1
)

# =========================================================
# Plot settings
# =========================================================

all_element_size <- 30

color_tip <- "darkgray"

# One tipping event
tip_years <- c(2060)

x_axis_limits <- c(
  2025,
  2100
)

x_axis_breaks <- seq(
  2025,
  2100,
  by = 15
)

# =========================================================
# Regions
# =========================================================

nations <- c(
  "China",
  "US",
  "EU",
  "Japan",
  "Russia",
  "India",
  "MidEast",
  "LatAm",
  "OthAsia",
  "Eurasia",
  "OHI",
  "Africa"
)

nation_order_plot <- rev(
  nations
)

status_cols <- nations

emission_cols <- paste0(
  "Emission of ",
  nations
)

# =========================================================
# scenario
# =========================================================

scenario_levels <- c(
  "Connection",
  "Tipping_Damage"
)

scenario_labels <- c(
  "Connection" = "Connection",
  "Tipping_Damage" = "Tipping Damage"
)

# =========================================================
# Coalition membership
# =========================================================

membership_levels <- c(
  "In coalition",
  "Out of coalition"
)

membership_colors <- c(
  "In coalition" = "darkgray",
  "Out of coalition" = "white"
)

# =========================================================
# Validate input files
# =========================================================

if (!file.exists(benchmark_file)) {
  
  stop(
    "Could not find the benchmark file; check the path: ",
    benchmark_file
  )
}

scenario_file_vec <- unlist(
  scenario_files,
  use.names = FALSE
)

missing_files <- scenario_file_vec[
  !file.exists(scenario_file_vec)
]

if (length(missing_files) > 0) {
  
  stop(
    "The following scenario files do not exist; check the paths: \n",
    paste(
      missing_files,
      collapse = "\n"
    )
  )
}

# =========================================================
# Data reader
# =========================================================

extract_plot_data <- function(
    filepath,
    sheet_name
) {
  
  filepath <- unlist(
    filepath,
    use.names = FALSE
  )
  
  filepath <- as.character(
    filepath
  )
  
  if (length(filepath) != 1) {
    
    stop(
      "filepath must contain one file path; check scenario_files or benchmark_file. Current value: ",
      paste(
        filepath,
        collapse = " | "
      )
    )
  }
  
  if (
    is.na(filepath) ||
    filepath == ""
  ) {
    
    stop(
      "filepath is empty; check the file-path settings."
    )
  }
  
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
  
  if (is.numeric(sheet_name)) {
    
    sheet_real <- sheet_name
    
  } else {
    
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
    
    sheet_real <- sheet_name
  }
  
  df <- read.xlsx(
    filepath,
    sheet = sheet_real
  )
  
  # Restore spaces that openxlsx converted to periods
  colnames(df) <- gsub(
    "\\.",
    " ",
    colnames(df)
  )
  
  df <- as_tibble(
    df
  )
  
  required_cols <- c(
    "Year",
    "Temp",
    status_cols,
    emission_cols
  )
  
  if (!all(required_cols %in% colnames(df))) {
    
    missing_cols <- required_cols[
      !(required_cols %in% colnames(df))
    ]
    
    warning(
      paste(
        "File",
        basename(filepath),
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
    
    mutate(
      Year = as.numeric(Year),
      Temp = as.numeric(Temp)
    ) %>%
    
    filter(
      !is.na(Year)
    )
  
  # =======================================================
  # Summary data
  # =======================================================
  
  summary_data <- df_clean %>%
    
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
    
    select(
      Year,
      Temp,
      Total_Emission
    ) %>%
    
    mutate(
      Temp = as.numeric(Temp),
      Total_Emission = as.numeric(Total_Emission)
    )
  
  # =======================================================
  # Coalition membership
  # =======================================================
  
  coalition_matrix <- df_clean %>%
    
    select(
      all_of(status_cols)
    ) %>%
    
    mutate(
      across(
        everything(),
        as.numeric
      )
    )
  
  colnames(coalition_matrix) <- nations
  
  coalition_long <- coalition_matrix %>%
    
    mutate(
      Year = df_clean$Year
    ) %>%
    
    pivot_longer(
      cols = all_of(nations),
      names_to = "Region",
      values_to = "IsMember"
    ) %>%
    
    mutate(
      Year = as.numeric(Year),
      IsMember = as.numeric(IsMember)
    )
  
  return(
    list(
      summary = summary_data,
      membership = coalition_long
    )
  )
}

# =========================================================
# Read the benchmark
# =========================================================

benchmark_data <- extract_plot_data(
  benchmark_file,
  benchmark_sheet
)

if (is.null(benchmark_data)) {
  
  stop(
    "Failed to read benchmark data."
  )
}

benchmark_summary <- benchmark_data$summary %>%
  
  rename(
    Benchmark_Temp = Temp,
    Benchmark_Emission = Total_Emission
  )

benchmark_membership <- benchmark_data$membership %>%
  
  rename(
    Benchmark_Member = IsMember
  )

# =========================================================
# =========================================================

build_scenario_diff_data <- function(
    scenario_name
) {
  
  scenario_file <- scenario_files[[scenario_name]]
  scenario_sheet <- scenario_sheets[[scenario_name]]
  
  scenario_data <- extract_plot_data(
    scenario_file,
    scenario_sheet
  )
  
  if (is.null(scenario_data)) {
    
    stop(
      "Failed to read scenario data: ",
      scenario_name
    )
  }
  
  scenario_summary <- scenario_data$summary %>%
    
    rename(
      Scenario_Temp = Temp,
      Scenario_Emission = Total_Emission
    )
  
  scenario_membership <- scenario_data$membership %>%
    
    rename(
      Scenario_Member = IsMember
    )
  
  # =======================================================
  # top plot: 
  # Total Emissions Difference
  # Temperature Difference
  # =======================================================
  
  top_data <- scenario_summary %>%
    
    left_join(
      benchmark_summary,
      by = "Year"
    ) %>%
    
    mutate(
      
      Temperature_Difference =
        Scenario_Temp -
        Benchmark_Temp,
      
      Total_Emissions_Difference =
        Scenario_Emission -
        Benchmark_Emission,
      
      Scenario =
        scenario_name
    ) %>%
    
    filter(
      !is.na(Year)
    )
  
  # =======================================================
  # Bottom membership comparison grid
  # =======================================================
  
  grid_base <- scenario_membership %>%
    
    left_join(
      benchmark_membership,
      by = c(
        "Year",
        "Region"
      )
    ) %>%
    
    mutate(
      
      Scenario_Member = ifelse(
        is.na(Scenario_Member),
        0,
        Scenario_Member
      ),
      
      Benchmark_Member = ifelse(
        is.na(Benchmark_Member),
        0,
        Benchmark_Member
      ),
      
      Region = factor(
        Region,
        levels = nation_order_plot
      ),
      
      Region_Num =
        as.numeric(
          Region
        )
    ) %>%
    
    filter(
      !is.na(Region_Num)
    ) %>%
    
    select(
      Year,
      Region,
      Region_Num,
      Scenario_Member,
      Benchmark_Member
    )
  
  # -------------------------------------------------------
  # Scenario: upper half
  # -------------------------------------------------------
  
  scenario_grid <- grid_base %>%
    
    transmute(
      Year = Year,
      Region = Region,
      Region_Num = Region_Num,
      Half_Type = "Scenario",
      IsMember = Scenario_Member,
      Y_Pos = Region_Num + 0.22
    )
  
  # -------------------------------------------------------
  # Benchmark: lower half
  # -------------------------------------------------------
  
  benchmark_grid <- grid_base %>%
    
    transmute(
      Year = Year,
      Region = Region,
      Region_Num = Region_Num,
      Half_Type = "Benchmark",
      IsMember = Benchmark_Member,
      Y_Pos = Region_Num - 0.22
    )
  
  grid_data <- bind_rows(
    scenario_grid,
    benchmark_grid
  ) %>%
    
    mutate(
      
      Membership_Status = ifelse(
        IsMember == 1,
        "In coalition",
        "Out of coalition"
      ),
      
      Membership_Status = factor(
        Membership_Status,
        levels = membership_levels
      ),
      
      Half_Type = factor(
        Half_Type,
        levels = c(
          "Scenario",
          "Benchmark"
        )
      ),
      
      Scenario =
        scenario_name
    ) %>%
    
    filter(
      !is.na(Year)
    )
  
  return(
    list(
      top = top_data,
      grid = grid_data
    )
  )
}

# =========================================================
# Read both sensitivity scenarios.
# =========================================================

all_scenario_data <- lapply(
  scenario_levels,
  build_scenario_diff_data
)

names(all_scenario_data) <- scenario_levels

# =========================================================
# Shared dual-axis scaling
#
# Implementation notes: 
# Left axis = Total Emissions Difference
# Right axis = Temperature Difference
#
# Map Temperature Difference to
# the emission-difference scale
# =========================================================

get_dual_axis_params <- function(
    all_data_list
) {
  
  all_top_data <- map_dfr(
    all_data_list,
    function(x) {
      x$top
    }
  )
  
  # Maximum absolute emission difference
  max_abs_emis <- max(
    abs(
      all_top_data$Total_Emissions_Difference
    ),
    na.rm = TRUE
  )
  
  # Maximum absolute temperature difference
  max_abs_temp <- max(
    abs(
      all_top_data$Temperature_Difference
    ),
    na.rm = TRUE
  )
  
  if (
    !is.finite(max_abs_emis) ||
    max_abs_emis <= 0
  ) {
    max_abs_emis <- 1
  }
  
  if (
    !is.finite(max_abs_temp) ||
    max_abs_temp <= 0
  ) {
    max_abs_temp <- 1
  }
  
  # =======================================================
  #
  # Primary axis = emissions
  #
  # Temperature_Difference_Scaled
  #   = Temperature_Difference * coeff
  #
  # Therefore: 
  # coeff = emission scale / temperature scale
  # =======================================================
  
  coeff <-
    max_abs_emis /
    max_abs_temp
  
  all_scaled_temp <-
    all_top_data$Temperature_Difference *
    coeff
  
  # Express the left-axis range in emission units
  y_vals <- c(
    all_top_data$Total_Emissions_Difference,
    all_scaled_temp,
    0
  )
  
  y_min <- min(
    y_vals,
    na.rm = TRUE
  )
  
  y_max <- max(
    y_vals,
    na.rm = TRUE
  )
  
  pad <-
    (
      y_max -
        y_min
    ) * 0.08
  
  if (
    !is.finite(pad) ||
    pad <= 0
  ) {
    pad <- 0.1
  }
  
  return(
    list(
      
      coeff = coeff,
      
      ylim = c(
        y_min - pad,
        y_max + pad
      )
    )
  )
}

axis_params <- get_dual_axis_params(
  all_scenario_data
)

# =========================================================
# Top dual-axis difference plot
#
# Left axis: Total Emissions Difference
# Right axis: Temperature Difference
# =========================================================

make_top_diff_plot <- function(
    top_data,
    scenario_name,
    panel_tag,
    axis_params,
    show_legend = FALSE
) {
  
  top_data <- top_data %>%
    
    mutate(
      
      # ===================================================
      # Map temperature to the left emission scale
      # ===================================================
      Temperature_Difference_Scaled =
        Temperature_Difference *
        axis_params$coeff
    )
  
  ggplot(
    top_data,
    aes(
      x = Year
    )
  ) +
    
    # =====================================================
  # Zero line
  # =====================================================
  
  geom_hline(
    yintercept = 0,
    color = "gray50",
    linetype = "solid",
    linewidth = 0.5,
    show.legend = FALSE
  ) +
    
    # =====================================================
  # Tipping vertical line
  # =====================================================
  
  geom_vline(
    xintercept = tip_years,
    color = color_tip,
    linetype = "twodash",
    linewidth = 0.8,
    alpha = 0.7,
    show.legend = FALSE
  ) +
    
    # =====================================================
  # Tipping label
  # =====================================================
  
  annotate(
    "text",
    x = tip_years[1],
    y = axis_params$ylim[2],
    label = "Tipping",
    vjust = 0.5,
    size = 8,
    fontface = "bold",
    color = "black"
  ) +
    
    # =====================================================
  # Total Emissions Difference
  #
  # The original left-axis unit is GtC
  # =====================================================
  
  geom_line(
    aes(
      y = Total_Emissions_Difference,
      color = "Total Emissions Difference",
      linetype = "Total Emissions Difference"
    ),
    linewidth = 1.2
  ) +
    
    # =====================================================
  # Temperature Difference
  #
  # Plot after mapping to the left-axis scale
  # Read temperature values from the right axis
  # =====================================================
  
  geom_line(
    aes(
      y = Temperature_Difference_Scaled,
      color = "Temperature Difference",
      linetype = "Temperature Difference"
    ),
    linewidth = 1.2
  ) +
    
    # =====================================================
  # X axis
  # =====================================================
  
  scale_x_continuous(
    expand = c(
      0,
      0
    ),
    limits = x_axis_limits,
    breaks = x_axis_breaks
  ) +
    
    # =====================================================
  # Dual Y axis
  #
  # Left: Total Emissions Difference
  # Right: Temperature Difference
  # =====================================================
  
  scale_y_continuous(
    
    name = "EM Difference (GtC)",
    
    limits = axis_params$ylim,
    
    sec.axis = sec_axis(
      
      ~ . / axis_params$coeff,
      
      name = "Temp Difference (°C)"
    )
  ) +
    
    # =====================================================
  # =====================================================
  
  coord_cartesian(
    clip = "off"
  ) +
    
    # =====================================================
  # Colors
  # =====================================================
  
  scale_color_manual(
    
    name = NULL,
    
    values = c(
      "Total Emissions Difference" = "blue",
      "Temperature Difference" = "red"
    ),
    
    breaks = c(
      "Total Emissions Difference",
      "Temperature Difference"
    )
  ) +
    
    # =====================================================
  # Linetypes
  # =====================================================
  
  scale_linetype_manual(
    
    name = NULL,
    
    values = c(
      "Total Emissions Difference" = "dashed",
      "Temperature Difference" = "solid"
    ),
    
    breaks = c(
      "Total Emissions Difference",
      "Temperature Difference"
    )
  ) +
    
    guides(
      
      color = guide_legend(
        nrow = 1,
        byrow = TRUE,
        override.aes = list(
          linewidth = 1.2
        )
      ),
      
      linetype = "none"
    ) +
    
    # =====================================================
  # Labels
  # =====================================================
  
  labs(
    
    title =
      scenario_labels[[scenario_name]],
    
    x = NULL,
    
    tag =
      panel_tag
  ) +
    
    # =====================================================
  # Theme
  # =====================================================
  
  theme_bw() +
    
    theme(
      
      # ---------- Scenario title ----------
      plot.title = element_text(
        size = all_element_size - 2,
        face = "bold",
        hjust = 0.5
      ),
      
      # ---------- a / b ----------
      plot.tag = element_text(
        size = all_element_size,
        face = "bold"
      ),
      
      # ---------- X axis ----------
      axis.title.x =
        element_blank(),
      
      axis.text.x =
        element_blank(),
      
      axis.ticks.x =
        element_blank(),
      
      # ---------- Left Y title ----------
      axis.title.y.left = element_text(
        size = all_element_size - 4,
        face = "bold",
        color = "black"
      ),
      
      # ---------- Right Y title ----------
      axis.title.y.right = element_text(
        size = all_element_size - 4,
        face = "bold",
        color = "black"
      ),
      
      # ---------- Axis labels ----------
      axis.text = element_text(
        size = all_element_size - 4,
        face = "bold",
        color = "black"
      ),
      
      # ---------- Legend ----------
      legend.position = ifelse(
        show_legend,
        "bottom",
        "none"
      ),
      
      legend.direction =
        "horizontal",
      
      legend.justification =
        "center",
      
      legend.text = element_text(
        size = all_element_size - 4,
        face = "bold"
      ),
      
      legend.key.width = unit(
        2.5,
        "cm"
      ),
      
      legend.background =
        element_blank(),
      
      # ---------- Grid ----------
      panel.grid.minor =
        element_blank(),
      
      # ---------- Top margin for Tipping ----------
      plot.margin = margin(
        t = 32,
        r = 8,
        b = 2,
        l = 8
      )
    )
}

# =========================================================
# Bottom split membership grid
# =========================================================

make_membership_compare_grid <- function(
    grid_data,
    show_legend = FALSE
) {
  
  ggplot(
    grid_data
  ) +
    
    # =====================================================
  # Scenario and benchmark halves
  # =====================================================
  
  geom_tile(
    
    aes(
      x = Year,
      y = Y_Pos,
      fill = Membership_Status
    ),
    
    color = "gray75",
    linewidth = 0.12,
    width = 1,
    height = 0.44
  ) +
    
    # =====================================================
  # Region separator
  # =====================================================
  
  geom_hline(
    
    yintercept = seq(
      1.5,
      length(nation_order_plot) - 0.5,
      by = 1
    ),
    
    color = "gray70",
    linewidth = 0.25,
    show.legend = FALSE
  ) +
    
    # =====================================================
  # Tipping vertical line
  # =====================================================
  
  geom_vline(
    
    xintercept = tip_years,
    
    color = color_tip,
    
    linetype = "twodash",
    
    linewidth = 0.7,
    
    alpha = 0.8,
    
    show.legend = FALSE
  ) +
    
    # =====================================================
  # Membership colors
  # =====================================================
  
  scale_fill_manual(
    
    name = "Coalition Membership",
    
    values = membership_colors,
    
    breaks = membership_levels,
    
    labels = c(
      "In coalition",
      "Out of coalition"
    ),
    
    drop = FALSE
  ) +
    
    # =====================================================
  # X axis
  # =====================================================
  
  scale_x_continuous(
    
    expand = c(
      0,
      0
    ),
    
    limits = x_axis_limits,
    
    breaks = x_axis_breaks
  ) +
    
    # =====================================================
  # Y axis
  # =====================================================
  
  scale_y_continuous(
    
    expand = c(
      0,
      0
    ),
    
    limits = c(
      0.5,
      length(nation_order_plot) + 0.5
    ),
    
    breaks =
      1:length(nation_order_plot),
    
    labels =
      nation_order_plot
  ) +
    
    labs(
      x = "Year",
      y = NULL
    ) +
    
    theme_bw() +
    
    theme(
      
      panel.grid =
        element_blank(),
      
      # ---------- X axis title ----------
      axis.title.x = element_text(
        size = all_element_size - 4,
        face = "bold"
      ),
      
      # ---------- X tick labels ----------
      axis.text.x = element_text(
        size = all_element_size - 4,
        color = "black",
        face = "bold"
      ),
      
      # ---------- Region labels ----------
      axis.text.y = element_text(
        size = all_element_size - 4,
        color = "black",
        face = "bold"
      ),
      
      # ---------- Legend ----------
      legend.position = ifelse(
        show_legend,
        "bottom",
        "none"
      ),
      
      legend.direction =
        "horizontal",
      
      legend.justification =
        "center",
      
      legend.title = element_text(
        size = all_element_size - 4,
        face = "bold"
      ),
      
      legend.text = element_text(
        size = all_element_size - 4,
        face = "bold"
      ),
      
      legend.key.width = unit(
        1.5,
        "cm"
      ),
      
      legend.background =
        element_blank(),
      
      plot.margin = margin(
        t = 2,
        r = 8,
        b = 5,
        l = 8
      )
    )
}

# =========================================================
# =========================================================

make_scenario_block <- function(
    scenario_name,
    panel_tag,
    show_legend = FALSE
) {
  
  top_data <-
    all_scenario_data[[scenario_name]]$top
  
  grid_data <-
    all_scenario_data[[scenario_name]]$grid
  
  p_top <- make_top_diff_plot(
    
    top_data =
      top_data,
    
    scenario_name =
      scenario_name,
    
    panel_tag =
      panel_tag,
    
    axis_params =
      axis_params,
    
    show_legend =
      show_legend
  )
  
  p_grid <- make_membership_compare_grid(
    
    grid_data =
      grid_data,
    
    show_legend =
      show_legend
  )
  
  block_plot <- cowplot::plot_grid(
    
    p_top,
    
    p_grid,
    
    ncol = 1,
    
    align = "v",
    
    axis = "lr",
    
    rel_heights = c(
      1.0,
      1.45
    )
  )
  
  return(
    block_plot
  )
}

# =========================================================
# Extract the shared legend
# =========================================================

p_line_legend_src <- make_top_diff_plot(
  
  top_data =
    all_scenario_data[[scenario_levels[1]]]$top,
  
  scenario_name =
    scenario_levels[1],
  
  panel_tag =
    "",
  
  axis_params =
    axis_params,
  
  show_legend =
    TRUE
)

p_member_legend_src <- make_membership_compare_grid(
  
  grid_data =
    all_scenario_data[[scenario_levels[1]]]$grid,
  
  show_legend =
    TRUE
)

line_legend <- cowplot::get_legend(
  p_line_legend_src
)

member_legend <- cowplot::get_legend(
  p_member_legend_src
)

# =========================================================
# Panel a: Connection
# =========================================================

p_connection <- make_scenario_block(
  
  scenario_name =
    "Connection",
  
  panel_tag =
    "a",
  
  show_legend =
    FALSE
)

# =========================================================
# Panel b: Tipping Damage
# =========================================================

p_tipping_damage <- make_scenario_block(
  
  scenario_name =
    "Tipping_Damage",
  
  panel_tag =
    "b",
  
  show_legend =
    FALSE
)

# =========================================================
# =========================================================

main_plot <- cowplot::plot_grid(
  
  p_connection,
  
  p_tipping_damage,
  
  ncol = 2,
  
  align = "hv",
  
  axis = "tblr",
  
  rel_widths = c(
    1,
    1
  )
)

# =========================================================
# Membership legend note
# =========================================================

legend_note <- cowplot::ggdraw() +
  
  cowplot::draw_label(
    
    "Membership tiles: upper half = current scenario; lower half = benchmark",
    
    fontface = "bold",
    
    size = all_element_size - 4,
    
    x = 0.5,
    
    hjust = 0.5
  )

# =========================================================
# Legend block
# =========================================================

legend_block <- cowplot::plot_grid(
  
  line_legend,
  
  member_legend,
  
  legend_note,
  
  ncol = 1,
  
  align = "v",
  
  rel_heights = c(
    1,
    1,
    0.55
  )
)

# =========================================================
# Final plot
# =========================================================

final_plot <- cowplot::plot_grid(
  
  main_plot,
  
  legend_block,
  
  ncol = 1,
  
  rel_heights = c(
    1,
    0.16
  )
)

# =========================================================
# Display plot
# =========================================================

print(
  final_plot
)

# =========================================================
# Save figure
# =========================================================

save_name <- file.path(
  save_dir,
  "Sensitivity_Analysis_Connection_TippingDamage_Temp_Emission_Membership_vs_Benchmark.pdf"
)

suppressWarnings(
  
  ggsave(
    
    filename =
      save_name,
    
    plot =
      final_plot,
    
    width =
      20,
    
    height =
      13
  )
)

cat(
  "Plot complete; file saved to: ",
  save_name,
  "\n"
)
