# Compare Shapley and no-transfer allocation outcomes.
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
base_dir <- file.path("..", "code", "One Tipping Find Steady Coalition", "Results of Various Allocation Types")
save_dir <- file.path(".", "IEA Figures 4.4")

r_value <- "0.03"

file_shapley_future <- file.path(
  base_dir,
  paste0(
    "Year_2025_Stable_Coalition_Result_Onetipping_Shapley_Future_r_",
    r_value,
    ".xlsx"
  )
)

file_notransfer_future <- file.path(
  base_dir,
  paste0(
    "Year_2025_Stable_Coalition_Result_Onetipping_NoTransfer_Future_r_",
    r_value,
    ".xlsx"
  )
)

file_list <- list(
  "Shapley_Future" = file_shapley_future,
  "NoTransfer_Future" = file_notransfer_future
)

for (f in file_list) {
  
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


# ================= Plot settings =================

# Base size for all main text elements
all_element_size <- 28

# Tipping settings
color_tip <- "darkgray"

# One tipping event
tip_years <- c(2060)


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

status_cols <- nations

emission_cols <- paste0(
  "Emission of ",
  nations
)


# =========================================================
# Data reader
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
  
  
  plot_data <- df %>%
    
    rowwise() %>%
    
    mutate(
      
      # ---------- Total emissions ----------
      Total_Emission = sum(
        c_across(
          all_of(emission_cols)
        ),
        na.rm = TRUE
      ),
      
      
      # ---------- Coalition emissions ----------
      Coalition_Emission = sum(
        
        c_across(
          all_of(status_cols)
        ) *
          
          c_across(
            all_of(emission_cols)
          ),
        
        na.rm = TRUE
      ),
      
      
      # ---------- Non-member emissions ----------
      Non_Member_Emission =
        Total_Emission -
        Coalition_Emission
    ) %>%
    
    ungroup() %>%
    
    select(
      Year,
      Temp,
      Coalition_Emission,
      Non_Member_Emission
    ) %>%
    
    mutate(
      
      Year =
        as.numeric(Year),
      
      Temp =
        as.numeric(Temp),
      
      Coalition_Emission =
        as.numeric(
          Coalition_Emission
        ),
      
      Non_Member_Emission =
        as.numeric(
          Non_Member_Emission
        )
    ) %>%
    
    filter(
      !is.na(Year)
    )
  
  
  return(
    plot_data
  )
}


# =========================================================
# Shared dual-axis scaling
# =========================================================
get_axis_params <- function(
    data_list
) {
  
  max_emis <- max(
    
    unlist(
      
      lapply(
        
        data_list,
        
        function(df) {
          
          c(
            df$Coalition_Emission,
            df$Non_Member_Emission
          )
        }
      )
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
      log10(raw_step)
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
  
  
  # -------------------------------------------------------
  # Map 1--4 degrees C to 0--axis_max on the left axis
  # -------------------------------------------------------
  coeff <-
    axis_max /
    3
  
  
  return(
    list(
      
      axis_max =
        axis_max,
      
      nice_step =
        nice_step,
      
      coeff =
        coeff
    )
  )
}


# =========================================================
# Panel builder
#
# Implementation notes: 
# =========================================================
make_panel_plot <- function(
    plot_data,
    panel_tag,
    axis_max,
    nice_step,
    coeff,
    show_legend = FALSE
) {
  
  tip_df <- data.frame(
    Year = tip_years
  )
  
  
  ggplot(
    plot_data,
    aes(
      x = Year
    )
  ) +
    
    
    # =====================================================
  # Tipping vertical line
  # =====================================================
  geom_vline(
    
    data = tip_df,
    
    aes(
      xintercept = Year,
      color = "Tipping year",
      linetype = "Tipping year"
    ),
    
    linewidth = 0.8,
    alpha = 0.8
  ) +
    
    
    # =====================================================
  # Tipping label
  #
  # Place the label above the 2060 vertical line
  # =====================================================
  annotate(
    
    "text",
    
    x = tip_years[1],
    
    y = axis_max,
    
    label = "Tipping",
    
    vjust = -1.3,
    
    size = 8,
    
    fontface = "bold",
    
    color = "black"
  ) +
    
    
    # =====================================================
  # Coalition emissions
  # =====================================================
  geom_line(
    
    aes(
      y = Coalition_Emission,
      color = "Coalition emissions",
      linetype = "Coalition emissions"
    ),
    
    linewidth = 1.2
  ) +
    
    
    # =====================================================
  # Non-member emissions
  # =====================================================
  geom_line(
    
    aes(
      y = Non_Member_Emission,
      color = "Non-member emissions",
      linetype = "Non-member emissions"
    ),
    
    linewidth = 1.2
  ) +
    
    
    # =====================================================
  # Temperature path
  # =====================================================
  geom_line(
    
    aes(
      y = (Temp - 1) * coeff,
      color = "Temperature path",
      linetype = "Temperature path"
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
    
    limits = c(
      2025,
      2100
    ),
    
    breaks = seq(
      2025,
      2100,
      15
    )
  ) +
    
    
    # =====================================================
  # Y axis
  # =====================================================
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
  # Allow the Tipping label above the panel
  # =====================================================
  coord_cartesian(
    clip = "off"
  ) +
    
    
    # =====================================================
  # Color
  # =====================================================
  scale_color_manual(
    
    name = NULL,
    
    values = c(
      
      "Coalition emissions" =
        "blue",
      
      "Non-member emissions" =
        "black",
      
      "Temperature path" =
        "red",
      
      "Tipping year" =
        color_tip
    ),
    
    breaks = c(
      
      "Coalition emissions",
      
      "Non-member emissions",
      
      "Temperature path",
      
      "Tipping year"
    )
  ) +
    
    
    # =====================================================
  # Linetype
  # =====================================================
  scale_linetype_manual(
    
    name = NULL,
    
    values = c(
      
      "Coalition emissions" =
        "solid",
      
      "Non-member emissions" =
        "solid",
      
      "Temperature path" =
        "dashed",
      
      "Tipping year" =
        "twodash"
    ),
    
    breaks = c(
      
      "Coalition emissions",
      
      "Non-member emissions",
      
      "Temperature path",
      
      "Tipping year"
    )
  ) +
    
    
    # =====================================================
  # Legend
  # =====================================================
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
    
    
    # =====================================================
  # Labels
  #
  # Do not set a title
  # =====================================================
  labs(
    
    x = "Year",
    
    tag = panel_tag
  ) +
    
    
    # =====================================================
  # Theme
  # =====================================================
  theme_bw() +
    
    theme(
      
      # ===================================================
      # Remove panel titles
      # ===================================================
      plot.title =
        element_blank(),
      
      
      # ===================================================
      # a / b
      #
      # ===================================================
      plot.tag = element_text(
        face = "bold",
        size = all_element_size,
        color = "black"
      ),
      
      
      # ---------- X-axis title ----------
      axis.title.x = element_text(
        size = all_element_size - 2,
        face = "bold",
        color = "black"
      ),
      
      
      # ---------- Left Y-axis title ----------
      axis.title.y.left = element_text(
        size = all_element_size - 2,
        face = "bold",
        color = "black"
      ),
      
      
      # ---------- Right Y-axis title ----------
      axis.title.y.right = element_text(
        size = all_element_size - 2,
        face = "bold",
        color = "black"
      ),
      
      
      # ---------- Axis numbers ----------
      axis.text = element_text(
        size = all_element_size - 2,
        face = "bold",
        color = "black"
      ),
      
      
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
      
      legend.text = element_text(
        size = all_element_size,
        face = "bold"
      ),
      
      legend.key.width =
        unit(
          2.4,
          "cm"
        ),
      
      legend.background =
        element_blank(),
      
      
      # ---------- Grid ----------
      panel.grid.minor =
        element_blank(),
      
      
      # ===================================================
      # Reserve top padding for panel tags and the Tipping label
      # ===================================================
      plot.margin = margin(
        t = 28,
        r = 8,
        b = 5,
        l = 8
      )
    )
}


# =========================================================
# Main loop
# =========================================================
cat(
  "Reading Future results for Shapley and NoTransfer...\n"
)


sheet_names <- Reduce(
  
  intersect,
  
  lapply(
    file_list,
    getSheetNames
  )
)


for (sheet_name in sheet_names) {
  
  cat(
    "  -> Plotting Sheet:",
    sheet_name,
    "\n"
  )
  
  
  # =======================================================
  # Shapley Future
  # =======================================================
  data_shapley_future <- extract_plot_data(
    file_shapley_future,
    sheet_name
  )
  
  
  # =======================================================
  # No-transfer Future
  # =======================================================
  data_notransfer_future <- extract_plot_data(
    file_notransfer_future,
    sheet_name
  )
  
  
  if (
    is.null(data_shapley_future) ||
    is.null(data_notransfer_future)
  ) {
    
    cat(
      "    ⚠️ At least one Future file is missing this sheet or required columns; skipping...\n"
    )
    
    next
  }
  
  
  # =======================================================
  # Use the same dual-axis scale for both plots
  # =======================================================
  data_list <- list(
    data_shapley_future,
    data_notransfer_future
  )
  
  
  axis_params <- get_axis_params(
    data_list
  )
  
  
  # =======================================================
  # Extract the shared legend from a temporary plot
  #
  # Do not pass a panel title
  # =======================================================
  p_legend_src <- make_panel_plot(
    
    plot_data =
      data_shapley_future,
    
    panel_tag =
      "",
    
    axis_max =
      axis_params$axis_max,
    
    nice_step =
      axis_params$nice_step,
    
    coeff =
      axis_params$coeff,
    
    show_legend =
      TRUE
  )
  
  
  shared_legend <- cowplot::get_legend(
    p_legend_src
  )
  
  
  # =======================================================
  # Panel a
  # Shapley
  #
  # =======================================================
  p_a <- make_panel_plot(
    
    plot_data =
      data_shapley_future,
    
    panel_tag =
      "a",
    
    axis_max =
      axis_params$axis_max,
    
    nice_step =
      axis_params$nice_step,
    
    coeff =
      axis_params$coeff,
    
    show_legend =
      FALSE
  )
  
  
  # =======================================================
  # Panel b
  # No Transfer
  #
  # =======================================================
  p_b <- make_panel_plot(
    
    plot_data =
      data_notransfer_future,
    
    panel_tag =
      "b",
    
    axis_max =
      axis_params$axis_max,
    
    nice_step =
      axis_params$nice_step,
    
    coeff =
      axis_params$coeff,
    
    show_legend =
      FALSE
  )
  
  
  # =======================================================
  # Arrange two panels horizontally
  # =======================================================
  main_plot <- wrap_plots(
    
    list(
      p_a,
      p_b
    ),
    
    ncol = 2,
    
    widths = c(
      1,
      1
    )
  )
  
  
  # =======================================================
  # Main plot and shared legend
  # =======================================================
  final_plot <- cowplot::plot_grid(
    
    main_plot,
    
    shared_legend,
    
    ncol = 1,
    
    rel_heights = c(
      1,
      0.10
    )
  )
  
  
  # =======================================================
  # Output filename
  # =======================================================
  safe_sheet_name <- gsub(
    "[\\\\/:*?\"<>|]",
    "_",
    sheet_name
  )
  
  
  save_name <- file.path(
    
    save_dir,
    
    paste0(
      "Allocation_Emission_Temperature_",
      safe_sheet_name,
      ".pdf"
    )
  )
  
  
  # =======================================================
  # Save output
  # =======================================================
  suppressWarnings(
    
    ggsave(
      
      filename =
        save_name,
      
      plot =
        final_plot,
      
      width =
        22,
      
      height =
        8
    )
  )
  
  
  cat(
    "     Saved to:",
    save_name,
    "\n"
  )
}


cat(
  "==== Shapley and NoTransfer Future figures generated without panel titles and with Tipping annotations!  ====\n"
)
