# Compare stable-coalition outcomes across benefit-policy scenarios.
# Run this script from the R_code directory so all paths remain relative.

# ================= Load packages =================
library(ggplot2)
library(tidyverse)
library(openxlsx)
library(cowplot)
library(grid)

options(digits = 2)


# =========================================================
# 1. Parameters and file paths
# =========================================================

path_base <- file.path("..", "code", "One Tipping Find Steady Coalition", "Results of Various Benefit Types")

save_dir <- file.path(".", "IEA Figures 4.3")


# ---------- Future scenario files ----------
files_future <- list(
  
  "Connection" = file.path(
    path_base,
    "Year_2025_Stable_Coalition_Result_Onetipping_Shapley_Future_r_0.03_Connection.xlsx"
  ),
  
  "Sanction" = file.path(
    path_base,
    "Year_2025_Stable_Coalition_Result_Onetipping_Shapley_Future_r_0.03_Sanction.xlsx"
  ),
  
  "Costly Sanction" = file.path(
    path_base,
    "Year_2025_Stable_Coalition_Result_Onetipping_Shapley_Future_r_0.03_Costly_Sanction.xlsx"
  ),
  
  "Connection & Sanction" = file.path(
    path_base,
    "Year_2025_Stable_Coalition_Result_Onetipping_Shapley_Future_r_0.03_Connection_Sanction.xlsx"
  ),
  
  "No Connection & Sanction" = file.path(
    path_base,
    "Year_2025_Stable_Coalition_Result_Onetipping_Shapley_Future_r_0.03_No_Connection_Sanction.xlsx"
  )
)


# ---------- Sheet ----------
sheet_list <- list(
  "Connection" = 1,
  "Sanction" = 1,
  "Costly Sanction" = 1,
  "Connection & Sanction" = 1,
  "No Connection & Sanction" = 1
)


# =========================================================
# 2. Plot settings
# =========================================================

# ---------------------------------------------------------
# Base size for all main text elements
#
# The same parameter controls the a, b, and c tags
# ---------------------------------------------------------
all_element_size <- 32

# tipping year
tipping_years <- c(2060)

color_tip <- "darkgray"


# =========================================================
# 3. Region names
# =========================================================

# Coalition membership indicator columns
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

# Emission columns
emission_cols <- paste0(
  "Emission of ",
  nations
)


# =========================================================
# 4. Validate input files
# =========================================================

for (f in files_future) {
  
  if (!file.exists(f)) {
    
    stop(
      paste(
        "Could not find the file; check the path:",
        f
      )
    )
  }
}


if (!dir.exists(save_dir)) {
  
  dir.create(
    save_dir,
    recursive = TRUE
  )
}


# =========================================================
# 5. Scenario data reader
# =========================================================

read_scenario_data <- function(
    name,
    path
) {
  
  current_sheet <- sheet_list[[name]]
  
  
  # ---------- Read data ----------
  df_raw <- read.xlsx(
    path,
    sheet = current_sheet,
    check.names = FALSE
  )
  
  
  # Keep consistent with the preceding workflow
  colnames(df_raw) <- gsub(
    "\\.",
    " ",
    colnames(df_raw)
  )
  
  
  df_raw <- as_tibble(
    df_raw
  )
  
  
  # =======================================================
  # Validate required variables
  # =======================================================
  
  required_cols <- c(
    "Year",
    nations,
    emission_cols,
    "Utility of All"
  )
  
  
  missing_cols <- required_cols[
    !(required_cols %in% colnames(df_raw))
  ]
  
  
  if (length(missing_cols) > 0) {
    
    stop(
      paste0(
        "\nFile: ",
        basename(path),
        "\nis missing the following required columns:\n",
        paste(
          missing_cols,
          collapse = ", "
        )
      )
    )
  }
  
  
  # =======================================================
  # Convert to numeric
  # =======================================================
  
  df_raw <- df_raw %>%
    
    mutate(
      
      Year = as.numeric(Year),
      
      across(
        all_of(nations),
        as.numeric
      ),
      
      across(
        all_of(emission_cols),
        as.numeric
      ),
      
      `Utility of All` =
        as.numeric(
          `Utility of All`
        )
    )
  
  
  # =======================================================
  # Calculate the three metrics
  # =======================================================
  
  df <- df_raw %>%
    
    rowwise() %>%
    
    mutate(
      
      # ---------------------------------------------------
      # Coalition Size
      #
      # ---------------------------------------------------
      
      Coalition_Size = sum(
        c_across(
          all_of(nations)
        ),
        na.rm = TRUE
      ),
      
      
      # ---------------------------------------------------
      # Total Emission
      # ---------------------------------------------------
      
      Total_Emission = sum(
        c_across(
          all_of(emission_cols)
        ),
        na.rm = TRUE
      )
    ) %>%
    
    ungroup() %>%
    
    mutate(
      
      # ---------------------------------------------------
      # Total Profit
      # ---------------------------------------------------
      
      Total_Profit =
        as.numeric(
          `Utility of All`
        ),
      
      Scenario = name
    ) %>%
    
    select(
      Year,
      Scenario,
      Coalition_Size,
      Total_Emission,
      Total_Profit
    ) %>%
    
    filter(
      !is.na(Year)
    )
  
  
  return(df)
}


# =========================================================
# =========================================================

df_raw_all <- map2_df(
  names(files_future),
  files_future,
  read_scenario_data
)


# =========================================================
# 7. Use no connection and sanction as the baseline
# =========================================================

df_baseline <- df_raw_all %>%
  
  filter(
    Scenario ==
      "No Connection & Sanction"
  ) %>%
  
  select(
    
    Year,
    
    Base_Coalition_Size =
      Coalition_Size,
    
    Base_Emission =
      Total_Emission,
    
    Base_Profit =
      Total_Profit
  )


# =========================================================
# 8. Calculate differences from the baseline
# =========================================================

df_future <- df_raw_all %>%
  
  left_join(
    df_baseline,
    by = "Year"
  ) %>%
  
  mutate(
    
    # =====================================================
    # Panel a
    #
    # Coalition Size(policy)
    # -
    # Coalition Size(No Connection & Sanction)
    # =====================================================
    
    Diff_Coalition_Size =
      Coalition_Size -
      Base_Coalition_Size,
    
    
    # =====================================================
    # Panel b
    # =====================================================
    
    Diff_Emission =
      Total_Emission -
      Base_Emission,
    
    
    # =====================================================
    # Panel c
    # =====================================================
    
    Diff_Profit =
      Total_Profit -
      Base_Profit
  )


# =========================================================
# 9. Baseline consistency check
# =========================================================

baseline_check <- df_future %>%
  
  filter(
    Scenario ==
      "No Connection & Sanction"
  ) %>%
  
  summarise(
    
    Max_Abs_Coalition_Diff =
      max(
        abs(Diff_Coalition_Size),
        na.rm = TRUE
      ),
    
    Max_Abs_Emission_Diff =
      max(
        abs(Diff_Emission),
        na.rm = TRUE
      ),
    
    Max_Abs_Profit_Diff =
      max(
        abs(Diff_Profit),
        na.rm = TRUE
      )
  )


print(
  baseline_check
)


# The baseline difference must equal zero
if (
  baseline_check$Max_Abs_Coalition_Diff > 1e-10
) {
  
  stop(
    paste0(
      "Coalition Size baseline check failed: ",
      "The No Connection and Sanction baseline difference is not zero."
    )
  )
}


# =========================================================
# 10. Remove the baseline from plotted scenarios
# =========================================================

# Use no connection and sanction only as the comparison baseline
# Do not plot the identically zero baseline line

df_future <- df_future %>%
  
  filter(
    Scenario !=
      "No Connection & Sanction"
  )


# =========================================================
# 11. Scenario order
# =========================================================

scenario_levels <- c(
  "Costly Sanction",
  "Connection",
  "Sanction",
  "Connection & Sanction"
)


df_future$Scenario <- factor(
  df_future$Scenario,
  levels = scenario_levels
)


# =========================================================
# 12. Colors and line types
# =========================================================

scenario_colors <- c(
  "Costly Sanction" = "black",
  "Connection" = "blue",
  "Sanction" = "red",
  "Connection & Sanction" = "darkgreen"
)


scenario_linetypes <- c(
  "Costly Sanction" = "solid",
  "Connection" = "solid",
  "Sanction" = "dashed",
  "Connection & Sanction" = "dashed"
)


# =========================================================
# 13. Y-axis range helper
# =========================================================

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
      y_max -
        y_min
    ) * padding_ratio
  }
  
  
  return(
    c(
      y_min - pad,
      y_max + pad
    )
  )
}


# =========================================================
# 14. Y-axis ranges for all panels
# =========================================================

ylim_coalition <- get_ylim_diff(
  df_future$Diff_Coalition_Size
)

ylim_emission <- get_ylim_diff(
  df_future$Diff_Emission
)

ylim_profit <- get_ylim_diff(
  df_future$Diff_Profit
)


# =========================================================
#
#
# Do not let patchwork add panel tags automatically
#
#
# labs(tag = panel_tag)
#
# Set a, b, and c separately for each panel
# =========================================================

make_panel <- function(
    plot_data,
    y_var,
    y_label,
    panel_tag,
    ylim_common,
    integer_y = FALSE,
    show_legend = FALSE
) {
  
  p <- ggplot(
    plot_data,
    aes(
      x = Year
    )
  ) +
    
    
    # =====================================================
  # Scenario curves
  # =====================================================
  
  geom_line(
    aes(
      y = .data[[y_var]],
      color = Scenario,
      linetype = Scenario
    ),
    linewidth = 1.25,
    show.legend = show_legend
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
    xintercept = tipping_years,
    color = color_tip,
    linetype = "twodash",
    linewidth = 0.8,
    alpha = 0.8,
    show.legend = FALSE
  ) +
    
    
    # =====================================================
  # Tipping label
  # =====================================================
  
  annotate(
    "text",
    x = tipping_years[1],
    y = ylim_common[2],
    label = "Tipping",
    vjust = -1.25,
    size = 10,
    fontface = "bold",
    color = "black"
  ) +
    
    
    # =====================================================
  # X axis
  # =====================================================
  
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
  ) +
    
    
    # =====================================================
  # Color
  #
  # name = NULL
  # =====================================================
  
  scale_color_manual(
    name = NULL,
    values = scenario_colors,
    breaks = scenario_levels,
    drop = FALSE
  ) +
    
    
    # =====================================================
  # Linetype
  # =====================================================
  
  scale_linetype_manual(
    name = NULL,
    values = scenario_linetypes,
    breaks = scenario_levels,
    drop = FALSE
  ) +
    
    
    guides(
      
      color = guide_legend(
        title = NULL,
        nrow = 1,
        byrow = TRUE
      ),
      
      linetype = "none"
    ) +
    
    
    # =====================================================
  # Axis range
  #
  # clip = "off"
  # =====================================================
  
  coord_cartesian(
    ylim = ylim_common,
    clip = "off"
  ) +
    
    
    # =====================================================
  #
  # Write the tag directly in each panel
  # =====================================================
  
  labs(
    x = "Year",
    y = y_label,
    tag = panel_tag
  ) +
    
    
    # =====================================================
  # Theme
  # =====================================================
  
  theme_bw() +
    
    theme(
      
      plot.title =
        element_blank(),
      
      
      # ===================================================
      # Panel-tag font size
      #
      # Controlled directly by all_element_size
      # ===================================================
      
      plot.tag = element_text(
        face = "bold",
        size = all_element_size,
        color = "black"
      ),
      
      
      # ---------- Axis title ----------
      
      axis.title = element_text(
        size = all_element_size - 2,
        face = "bold",
        color = "black"
      ),
      
      
      # ---------- Axis tick ----------
      
      axis.text = element_text(
        size = all_element_size - 4,
        face = "bold",
        color = "black"
      ),
      
      
      # ---------- Grid ----------
      
      panel.grid.minor =
        element_blank(),
      
      
      # ---------- Legend ----------
      
      legend.position =
        ifelse(
          show_legend,
          "bottom",
          "none"
        ),
      
      legend.direction =
        "horizontal",
      
      legend.justification =
        "center",
      
      legend.title =
        element_blank(),
      
      legend.text = element_text(
        size = all_element_size - 4,
        face = "bold"
      ),
      
      legend.key.width =
        unit(
          1.8,
          "cm"
        ),
      
      
      # ===================================================
      # Reserve top padding for the Tipping label
      # ===================================================
      
      plot.margin = margin(
        t = 25,
        r = 20,
        b = 10,
        l = 20
      )
    )
  
  
  # =======================================================
  # Use integer ticks for coalition-size differences
  # =======================================================
  
  if (integer_y) {
    
    p <- p +
      
      scale_y_continuous(
        breaks = scales::breaks_width(1)
      )
  }
  
  
  return(p)
}


# =========================================================
# 16. Panel a
# =========================================================

p_a <- make_panel(
  
  plot_data = df_future,
  
  y_var =
    "Diff_Coalition_Size",
  
  y_label =
    "Coalition Size Difference",
  
  panel_tag =
    "a",
  
  ylim_common =
    ylim_coalition,
  
  integer_y =
    TRUE,
  
  show_legend =
    FALSE
)


# =========================================================
# 17. Panel b
# =========================================================

p_b <- make_panel(
  
  plot_data = df_future,
  
  y_var =
    "Diff_Emission",
  
  y_label =
    "Total Emission Difference (GtC)",
  
  panel_tag =
    "b",
  
  ylim_common =
    ylim_emission,
  
  integer_y =
    FALSE,
  
  show_legend =
    FALSE
)


# =========================================================
# 18. Panel c
# =========================================================

p_c <- make_panel(
  
  plot_data = df_future,
  
  y_var =
    "Diff_Profit",
  
  y_label =
    "Total Utility Difference (Trillion $)",
  
  panel_tag =
    "c",
  
  ylim_common =
    ylim_profit,
  
  integer_y =
    FALSE,
  
  show_legend =
    FALSE
)


# =========================================================
# 19. Build the shared legend
# =========================================================

p_legend_source <- make_panel(
  
  plot_data = df_future,
  
  y_var =
    "Diff_Profit",
  
  y_label =
    "",
  
  panel_tag =
    "",
  
  ylim_common =
    ylim_profit,
  
  integer_y =
    FALSE,
  
  show_legend =
    TRUE
)


legend_block <- cowplot::get_legend(
  p_legend_source
)


# =========================================================
# 20. Arrange three panels horizontally
#
# Note: 
# Do not add tags at this stage.
#
# Panel tags are already defined in each ggplot.
# =========================================================

main_plot <- cowplot::plot_grid(
  
  p_a,
  p_b,
  p_c,
  
  ncol = 3,
  
  align = "h",
  
  axis = "tb",
  
  rel_widths = c(
    1,
    1,
    1
  )
)


# =========================================================
# =========================================================

final_plot <- cowplot::plot_grid(
  
  main_plot,
  legend_block,
  
  ncol = 1,
  
  rel_heights = c(
    1,
    0.10
  )
)


# =========================================================
# 22. Display plot
# =========================================================

print(
  final_plot
)


# =========================================================
# 23. Save output
# =========================================================

save_path <- file.path(
  save_dir,
  "Connection_VS_Sanction_Comparison.pdf"
)


ggsave(
  
  filename = save_path,
  
  plot = final_plot,
  
  device = "pdf",
  
  width = 24,
  
  height = 8
)


cat(
  "Plot complete; file saved to: ",
  save_path,
  "\n"
)
