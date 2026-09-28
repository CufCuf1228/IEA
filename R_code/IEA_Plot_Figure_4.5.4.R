# Compare stable-coalition results for one and two tipping events.
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
base_dir <- file.path("..", "code", "One Tipping Find Steady Coalition", "Results of SA Tipping Events")

save_dir <- file.path(".", "IEA Figures 4.5", "IEA Figures 4.5.4")

file_once_future <- file.path(
  base_dir,
  "Year_2025_Stable_Coalition_Result_Onetipping_Shapley_Future_r_0.03.xlsx"
)

file_twice_future <- file.path(
  base_dir,
  "Year_2025_Stable_Coalition_Result_Twicetipping_Shapley_Future_r_0.03.xlsx"
)

if (!file.exists(file_once_future)) {
  stop("Could not find the one-tipping Future file. Check the relative path.")
}

if (!file.exists(file_twice_future)) {
  stop("Could not find the two-tipping Future file. Check the relative path.")
}

if (!dir.exists(save_dir)) {
  dir.create(
    save_dir,
    recursive = TRUE
  )
}

# ================= Plot settings =================
all_element_size <- 34

color_tip <- "darkgray"

# One-tipping year
tip_years_once <- c(2080)

# Two-tipping years
tip_years_twice <- c(2050, 2080)

x_axis_limits <- c(
  2025,
  2100
)

x_axis_breaks <- seq(
  2025,
  2100,
  by = 15
)

# ================= Regions =================
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
# Data extraction
# =========================================================
extract_plot_data <- function(
    filepath,
    sheet_name
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
    sheet = sheet_name
  )
  
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
    mutate(
      Year = as.numeric(Year),
      Temp = as.numeric(Temp)
    ) %>%
    filter(
      !is.na(Year)
    )
  
  # ================= Summary =================
  summary_data <- df_clean %>%
    
    rowwise() %>%
    
    mutate(
      
      Total_Emission = sum(
        c_across(
          all_of(emission_cols)
        ),
        na.rm = TRUE
      ),
      
      Coalition_Emission = sum(
        c_across(
          all_of(status_cols)
        ) *
          c_across(
            all_of(emission_cols)
          ),
        na.rm = TRUE
      ),
      
      Non_Coalition_Emission =
        Total_Emission -
        Coalition_Emission
    ) %>%
    
    ungroup() %>%
    
    select(
      Year,
      Temp,
      Coalition_Emission,
      Non_Coalition_Emission
    ) %>%
    
    mutate(
      Coalition_Emission =
        as.numeric(
          Coalition_Emission
        ),
      
      Non_Coalition_Emission =
        as.numeric(
          Non_Coalition_Emission
        )
    )
  
  # ================= Membership matrix =================
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
  
  # ================= Emission matrix =================
  emission_matrix <- df_clean %>%
    
    select(
      all_of(emission_cols)
    ) %>%
    
    mutate(
      across(
        everything(),
        as.numeric
      )
    )
  
  colnames(coalition_matrix) <- nations
  colnames(emission_matrix) <- nations
  
  # ================= Normalize emissions =================
  norm_emission_matrix <- as.data.frame(
    
    lapply(
      emission_matrix,
      
      function(x) {
        
        x <- as.numeric(x)
        
        x_max <- max(
          x,
          na.rm = TRUE
        )
        
        x_min <- min(
          x,
          na.rm = TRUE
        )
        
        if (
          is.na(x_max) ||
          is.na(x_min) ||
          x_max == x_min
        ) {
          
          return(
            rep(
              0.5,
              length(x)
            )
          )
        }
        
        (
          x - x_min
        ) /
          (
            x_max - x_min
          )
      }
    )
  )
  
  colnames(norm_emission_matrix) <- nations
  
  # ================= Membership long =================
  df_long_member <- coalition_matrix %>%
    
    mutate(
      Year = df_clean$Year
    ) %>%
    
    pivot_longer(
      cols = all_of(nations),
      names_to = "Region",
      values_to = "IsMember"
    )
  
  # ================= Emission long =================
  df_long_emission <- norm_emission_matrix %>%
    
    mutate(
      Year = df_clean$Year
    ) %>%
    
    pivot_longer(
      cols = all_of(nations),
      names_to = "Region",
      values_to = "NormEmission"
    )
  
  # ================= Grid =================
  grid_data <- df_long_member %>%
    
    left_join(
      df_long_emission,
      by = c(
        "Year",
        "Region"
      )
    ) %>%
    
    mutate(
      
      Region = factor(
        Region,
        levels = nation_order_plot
      ),
      
      Region_Num =
        as.numeric(
          Region
        ),
      
      IsMember = factor(
        IsMember,
        levels = c(
          0,
          1
        )
      ),
      
      xmin =
        Year -
        0.45,
      
      xmax =
        Year +
        0.45,
      
      y_line =
        Region_Num -
        0.45 +
        NormEmission *
        0.9
    )
  
  return(
    list(
      summary = summary_data,
      grid = grid_data
    )
  )
}

# =========================================================
# Top dual-axis plot
# =========================================================
make_emission_temp_plot <- function(
    plot_data,
    panel_tag,
    axis_max,
    nice_step,
    coeff,
    tip_years,
    show_legend = FALSE
) {
  
  # -------------------------------------------------------
  # Create one label for each tipping year
  # -------------------------------------------------------
  tip_label_data <- data.frame(
    Year = tip_years,
    Label = rep(
      "Tipping",
      length(tip_years)
    )
  )
  
  ggplot(
    plot_data,
    aes(
      x = Year
    )
  ) +
    
    # =====================================================
  # Tipping vertical lines
  # =====================================================
  geom_vline(
    xintercept = tip_years,
    color = color_tip,
    linetype = "twodash",
    linewidth = 0.8,
    alpha = 0.7
  ) +
    
    # =====================================================
  # Tipping labels
  #
  # =====================================================
  geom_text(
    data = tip_label_data,
    aes(
      x = Year,
      y = axis_max,
      label = Label
    ),
    inherit.aes = FALSE,
    vjust = -1.2,
    size = 9,
    fontface = "bold",
    color = "black"
  ) +
    
    # ================= Coalition emission =================
  geom_line(
    aes(
      y = Coalition_Emission,
      color = "Coalition Emission",
      linetype = "Coalition Emission"
    ),
    linewidth = 1.2
  ) +
    
    # ================= Non-coalition emission =================
  geom_line(
    aes(
      y = Non_Coalition_Emission,
      color = "Non-Coalition Emission",
      linetype = "Non-Coalition Emission"
    ),
    linewidth = 1.2
  ) +
    
    # ================= Temperature =================
  geom_line(
    aes(
      y = (Temp - 1) * coeff,
      color = "Temperature Path",
      linetype = "Temperature Path"
    ),
    linewidth = 1.2
  ) +
    
    # ================= X axis =================
  scale_x_continuous(
    expand = c(
      0,
      0
    ),
    limits = x_axis_limits,
    breaks = x_axis_breaks
  ) +
    
    # ================= Y axis =================
  scale_y_continuous(
    
    name = "Emission (GtC)",
    
    limits = c(
      0,
      axis_max
    ),
    
    breaks = seq(
      0,
      axis_max,
      by = nice_step
    ),
    
    sec.axis = sec_axis(
      ~ . / coeff + 1,
      name = "Temperature (°C)",
      breaks = seq(
        1,
        4,
        by = 0.5
      )
    )
  ) +
    
    # =====================================================
  # =====================================================
  coord_cartesian(
    clip = "off"
  ) +
    
    # ================= Colors =================
  scale_color_manual(
    
    name = NULL,
    
    values = c(
      "Coalition Emission" = "blue",
      "Non-Coalition Emission" = "black",
      "Temperature Path" = "red"
    )
  ) +
    
    # ================= Linetype =================
  scale_linetype_manual(
    
    name = NULL,
    
    values = c(
      "Coalition Emission" = "solid",
      "Non-Coalition Emission" = "solid",
      "Temperature Path" = "dashed"
    )
  ) +
    
    # ================= Legend =================
  guides(
    
    color = guide_legend(
      nrow = 1,
      byrow = TRUE
    ),
    
    linetype = guide_legend(
      nrow = 1,
      byrow = TRUE
    )
  ) +
    
    theme_bw() +
    
    labs(
      x = NULL,
      tag = panel_tag
    ) +
    
    theme(
      
      plot.title =
        element_blank(),
      
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
      
      # ---------- Left Y ----------
      axis.title.y.left = element_text(
        size = all_element_size - 4,
        face = "bold",
        color = "black"
      ),
      
      # ---------- Right Y ----------
      axis.title.y.right = element_text(
        size = all_element_size - 4,
        face = "bold",
        color = "black"
      ),
      
      # ---------- Axis text ----------
      axis.text = element_text(
        size = all_element_size - 6,
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
      
      panel.grid.minor =
        element_blank(),
      
      # ===================================================
      # Add top padding
      # Prevent clipping of the Tipping label
      # ===================================================
      plot.margin = margin(
        t = 28,
        r = 8,
        b = 2,
        l = 8
      )
    )
}

# =========================================================
# Bottom membership grid
# =========================================================
make_membership_grid_plot <- function(
    grid_data,
    tip_years,
    show_legend = FALSE
) {
  
  ggplot(
    grid_data
  ) +
    
    # ================= Membership =================
  geom_tile(
    aes(
      x = Year,
      y = Region_Num,
      fill = IsMember
    ),
    color = "gray90",
    width = 1,
    height = 1
  ) +
    
    # =====================================================
  # Tipping vertical lines
  #
  # Draw only vertical lines in the lower panel
  # =====================================================
  geom_vline(
    xintercept = tip_years,
    color = color_tip,
    linetype = "twodash",
    linewidth = 0.7,
    alpha = 0.8
  ) +
    
    # ================= Normalized regional emission =================
  geom_segment(
    aes(
      x = xmin,
      xend = xmax,
      y = y_line,
      yend = y_line
    ),
    color = "black",
    linewidth = 0.65,
    show.legend = FALSE
  ) +
    
    # ================= Membership fill =================
  scale_fill_manual(
    
    name = "Coalition Membership",
    
    values = c(
      "0" = "white",
      "1" = "gray70"
    ),
    
    labels = c(
      "Out of Coalition",
      "In Coalition"
    ),
    
    drop = FALSE
  ) +
    
    # ================= X axis =================
  scale_x_continuous(
    expand = c(
      0,
      0
    ),
    limits = x_axis_limits,
    breaks = x_axis_breaks
  ) +
    
    # ================= Y axis =================
  scale_y_continuous(
    expand = c(
      0,
      0
    ),
    breaks = 1:length(
      nation_order_plot
    ),
    labels = nation_order_plot
  ) +
    
    labs(
      x = "Year",
      y = "Region"
    ) +
    
    theme_bw() +
    
    theme(
      
      panel.grid =
        element_blank(),
      
      axis.title = element_text(
        size = all_element_size - 4,
        face = "bold"
      ),
      
      axis.text.x = element_text(
        size = all_element_size - 4,
        color = "black",
        face = "bold"
      ),
      
      axis.text.y = element_text(
        size = all_element_size - 4,
        color = "black",
        face = "bold"
      ),
      
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
        color = "black",
        face = "bold"
      ),
      
      legend.text = element_text(
        size = all_element_size - 4,
        color = "black",
        face = "bold"
      ),
      
      legend.key.width = unit(
        2.2,
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
# Shared dual-axis scaling
# =========================================================
get_axis_params <- function(
    df_all
) {
  
  max_emis <- max(
    c(
      df_all$Coalition_Emission,
      df_all$Non_Coalition_Emission
    ),
    na.rm = TRUE
  )
  
  if (
    max_emis <= 0 ||
    is.na(max_emis)
  ) {
    
    max_emis <- 10
  }
  
  n_intervals <- 6
  
  raw_step <-
    max_emis /
    n_intervals
  
  mag <-
    10^floor(
      log10(
        raw_step
      )
    )
  
  rel_step <-
    raw_step /
    mag
  
  if (rel_step <= 1) {
    
    nice_rel <- 1
    
  } else if (rel_step <= 2) {
    
    nice_rel <- 2
    
  } else if (rel_step <= 2.5) {
    
    nice_rel <- 2.5
    
  } else if (rel_step <= 5) {
    
    nice_rel <- 5
    
  } else {
    
    nice_rel <- 10
  }
  
  nice_step <-
    nice_rel *
    mag
  
  axis_max <-
    nice_step *
    n_intervals
  
  coeff <-
    axis_max /
    3
  
  return(
    list(
      axis_max = axis_max,
      nice_step = nice_step,
      coeff = coeff
    )
  )
}

# =========================================================
# Scenario panel block
# =========================================================
make_scenario_block <- function(
    data_obj,
    panel_tag,
    tip_years,
    axis_params
) {
  
  p_top <- make_emission_temp_plot(
    
    plot_data =
      data_obj$summary,
    
    panel_tag =
      panel_tag,
    
    axis_max =
      axis_params$axis_max,
    
    nice_step =
      axis_params$nice_step,
    
    coeff =
      axis_params$coeff,
    
    tip_years =
      tip_years,
    
    show_legend =
      FALSE
  )
  
  p_grid <- make_membership_grid_plot(
    
    grid_data =
      data_obj$grid,
    
    tip_years =
      tip_years,
    
    show_legend =
      FALSE
  )
  
  block_plot <- cowplot::plot_grid(
    
    p_top,
    
    p_grid,
    
    ncol = 1,
    
    align = "v",
    
    axis = "lr",
    
    rel_heights = c(
      1.0,
      1.35
    )
  )
  
  return(
    block_plot
  )
}

# =========================================================
# Main workflow
# =========================================================
cat(
  "Processing one- and two-tipping Future files...\n"
)

sheet_once <- getSheetNames(
  file_once_future
)[1]

sheet_twice <- getSheetNames(
  file_twice_future
)[1]

cat(
  "  -> One-tipping sheet:",
  sheet_once,
  "\n"
)

cat(
  "  -> Two-tipping sheet:",
  sheet_twice,
  "\n"
)

data_once <- extract_plot_data(
  file_once_future,
  sheet_once
)

data_twice <- extract_plot_data(
  file_twice_future,
  sheet_twice
)

if (is.null(data_once)) {
  
  stop(
    "One-tipping data are missing; cannot create the plot."
  )
}

if (is.null(data_twice)) {
  
  stop(
    "Two-tipping data are missing; cannot create the plot."
  )
}

# ================= Shared scales =================
df_all <- bind_rows(
  data_once$summary,
  data_twice$summary
)

axis_params <- get_axis_params(
  df_all
)

# =========================================================
# Extract the line legend
# =========================================================
p_line_legend_src <- make_emission_temp_plot(
  
  plot_data =
    data_once$summary,
  
  panel_tag =
    "",
  
  axis_max =
    axis_params$axis_max,
  
  nice_step =
    axis_params$nice_step,
  
  coeff =
    axis_params$coeff,
  
  tip_years =
    tip_years_once,
  
  show_legend =
    TRUE
)

# =========================================================
# Extract the membership legend
# =========================================================
p_member_legend_src <- make_membership_grid_plot(
  
  grid_data =
    data_once$grid,
  
  tip_years =
    tip_years_once,
  
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
# Panel a: One tipping event
#
# 2080
# =========================================================
p_once_block <- make_scenario_block(
  
  data_obj =
    data_once,
  
  panel_tag =
    "a",
  
  tip_years =
    tip_years_once,
  
  axis_params =
    axis_params
)

# =========================================================
# Panel b: Two tipping events
#
# 2050 + 2080
# =========================================================
p_twice_block <- make_scenario_block(
  
  data_obj =
    data_twice,
  
  panel_tag =
    "b",
  
  tip_years =
    tip_years_twice,
  
  axis_params =
    axis_params
)

# =========================================================
# Arrange two panels horizontally
# =========================================================
main_plot <- cowplot::plot_grid(
  
  p_once_block,
  
  p_twice_block,
  
  ncol = 2,
  
  align = "hv",
  
  axis = "tblr",
  
  rel_widths = c(
    1,
    1
  )
)

# =========================================================
# Legend
# =========================================================
legend_block <- cowplot::plot_grid(
  
  line_legend,
  
  member_legend,
  
  ncol = 1,
  
  align = "v",
  
  rel_heights = c(
    1,
    1
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
# Save output
# =========================================================
safe_sheet_name_once <- gsub(
  "[\\\\/:*?\"<>|]",
  "_",
  sheet_once
)

safe_sheet_name_twice <- gsub(
  "[\\\\/:*?\"<>|]",
  "_",
  sheet_twice
)

save_name <- file.path(
  
  save_dir,
  
  paste0(
    "Coalition_Emissions_MembershipGrid_Once_vs_Twice_",
    safe_sheet_name_once,
    "_",
    safe_sheet_name_twice,
    ".pdf"
  )
)

suppressWarnings(
  
  ggsave(
    
    filename =
      save_name,
    
    plot =
      final_plot,
    
    width =
      26,
    
    height =
      14
  )
)

cat(
  "     Saved to:",
  save_name,
  "\n"
)

cat(
  "==== One- and two-tipping Future plots generated with Tipping annotations!  ====\n"
)
