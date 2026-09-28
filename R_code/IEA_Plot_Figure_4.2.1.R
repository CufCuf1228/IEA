# Plot one-tipping emissions, temperature, and coalition membership.
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
base_dir <- file.path("..", "code", "One Tipping Find Steady Coalition", "Results of Various Coalitions")
save_dir <- file.path(".", "IEA Figures 4.2")

file_future <- file.path(
  base_dir,
  "Year_2025_Stable_Coalition_Result_Onetipping_Shapley_Future_r_0.03.xlsx"
)

if (!file.exists(file_future)) {
  stop("Could not find the Future file; check the relative path.")
}

if (!dir.exists(save_dir)) {
  dir.create(save_dir, recursive = TRUE)
}

# ================= Plot settings =================
all_element_size <- 30
color_tip <- "darkgray"
tip_years <- c(2060)

x_axis_limits <- c(2024.5, 2100.5)
x_axis_breaks <- seq(2025, 2100, by = 5)

nations <- c(
  "China", "US", "EU", "Japan", "Russia", "India",
  "MidEast", "LatAm", "OthAsia", "Eurasia", "OHI", "Africa"
)

nation_order_plot <- rev(nations)

status_cols <- nations
emission_cols <- paste0("Emission of ", nations)

# ================= Data extraction =================
extract_plot_data <- function(filepath, sheet_name) {
  
  if (!file.exists(filepath)) {
    warning(paste("File does not exist:", filepath))
    return(NULL)
  }
  
  sheet_list <- getSheetNames(filepath)
  
  if (!(sheet_name %in% sheet_list)) {
    warning(paste("File", basename(filepath), "does not contain sheet:", sheet_name))
    return(NULL)
  }
  
  df <- read.xlsx(filepath, sheet = sheet_name)
  colnames(df) <- gsub("\\.", " ", colnames(df))
  df <- as_tibble(df)
  
  required_cols <- c("Year", "Temp", status_cols, emission_cols)
  
  if (!all(required_cols %in% colnames(df))) {
    missing_cols <- required_cols[!(required_cols %in% colnames(df))]
    warning(paste(
      "File", basename(filepath), "Sheet", sheet_name,
      "is missing required columns:",
      paste(missing_cols, collapse = ", ")
    ))
    return(NULL)
  }
  
  df_clean <- df %>%
    mutate(
      Year = as.numeric(Year),
      Temp = as.numeric(Temp)
    ) %>%
    filter(!is.na(Year))
  
  summary_data <- df_clean %>%
    rowwise() %>%
    mutate(
      Total_Emission = sum(c_across(all_of(emission_cols)), na.rm = TRUE),
      Coalition_Emission = sum(
        c_across(all_of(status_cols)) * c_across(all_of(emission_cols)),
        na.rm = TRUE
      ),
      Non_Coalition_Emission = Total_Emission - Coalition_Emission
    ) %>%
    ungroup() %>%
    select(
      Year,
      Temp,
      Coalition_Emission,
      Non_Coalition_Emission
    ) %>%
    mutate(
      Coalition_Emission = as.numeric(Coalition_Emission),
      Non_Coalition_Emission = as.numeric(Non_Coalition_Emission)
    )
  
  coalition_matrix <- df_clean %>%
    select(all_of(status_cols)) %>%
    mutate(across(everything(), as.numeric))
  
  emission_matrix <- df_clean %>%
    select(all_of(emission_cols)) %>%
    mutate(across(everything(), as.numeric))
  
  colnames(coalition_matrix) <- nations
  colnames(emission_matrix) <- nations
  
  norm_emission_matrix <- as.data.frame(
    lapply(emission_matrix, function(x) {
      x <- as.numeric(x)
      x_max <- max(x, na.rm = TRUE)
      x_min <- min(x, na.rm = TRUE)
      
      if (is.na(x_max) || is.na(x_min) || x_max == x_min) {
        return(rep(0.5, length(x)))
      }
      
      (x - x_min) / (x_max - x_min)
    })
  )
  
  colnames(norm_emission_matrix) <- nations
  
  df_long_member <- coalition_matrix %>%
    mutate(Year = df_clean$Year) %>%
    pivot_longer(
      cols = all_of(nations),
      names_to = "Region",
      values_to = "IsMember"
    )
  
  df_long_emission <- norm_emission_matrix %>%
    mutate(Year = df_clean$Year) %>%
    pivot_longer(
      cols = all_of(nations),
      names_to = "Region",
      values_to = "NormEmission"
    )
  
  grid_data <- df_long_member %>%
    left_join(df_long_emission, by = c("Year", "Region")) %>%
    mutate(
      Region = factor(Region, levels = nation_order_plot),
      Region_Num = as.numeric(Region),
      IsMember = factor(IsMember, levels = c(0, 1)),
      xmin = Year - 0.45,
      xmax = Year + 0.45,
      y_line = Region_Num - 0.45 + NormEmission * 0.9
    )
  
  return(list(
    summary = summary_data,
    grid = grid_data
  ))
}

# ================= Top dual-axis plot =================
make_emission_temp_plot <- function(plot_data,
                                    panel_tag,
                                    axis_max,
                                    nice_step,
                                    coeff,
                                    show_legend = FALSE) {
  
  ggplot(plot_data, aes(x = Year)) +
    
    geom_vline(
      xintercept = tip_years,
      color = color_tip,
      linetype = "twodash",
      linewidth = 0.8,
      alpha = 0.7
    ) +
    
    annotate(
      "text",
      x = tip_years[1],
      y = axis_max,
      label = "Tipping",
      vjust = -1.2,
      size = 8,
      fontface = "bold",
      color = "black"
    ) +
    
    geom_line(
      aes(
        y = Coalition_Emission,
        color = "Coalition Emission",
        linetype = "Coalition Emission"
      ),
      linewidth = 1.2
    ) +
    
    geom_line(
      aes(
        y = Non_Coalition_Emission,
        color = "Non-Coalition Emission",
        linetype = "Non-Coalition Emission"
      ),
      linewidth = 1.2
    ) +
    
    geom_line(
      aes(
        y = (Temp - 1) * coeff,
        color = "Temperature Path",
        linetype = "Temperature Path"
      ),
      linewidth = 1.2
    ) +
    
    scale_x_continuous(
      expand = c(0, 0),
      limits = x_axis_limits,
      breaks = x_axis_breaks
    ) +
    
    scale_y_continuous(
      name = "Emission (GtC)",
      limits = c(0, axis_max),
      breaks = seq(0, axis_max, by = nice_step),
      sec.axis = sec_axis(
        ~ . / coeff + 1,
        name = "Temperature (°C)",
        breaks = seq(1, 4, by = 0.5)
      )
    ) +
    
    coord_cartesian(clip = "off") +
    
    scale_color_manual(
      name = NULL,
      values = c(
        "Coalition Emission" = "blue",
        "Non-Coalition Emission" = "black",
        "Temperature Path" = "red"
      )
    ) +
    
    scale_linetype_manual(
      name = NULL,
      values = c(
        "Coalition Emission" = "solid",
        "Non-Coalition Emission" = "solid",
        "Temperature Path" = "dashed"
      )
    ) +
    
    guides(
      color = guide_legend(nrow = 1, byrow = TRUE),
      linetype = guide_legend(nrow = 1, byrow = TRUE)
    ) +
    
    theme_bw() +
    
    labs(
      x = NULL,
      tag = panel_tag
    ) +
    
    theme(
      plot.title = element_blank(),
      
      plot.tag = element_text(
        size = all_element_size - 4,
        face = "bold"
      ),
      
      axis.title.x = element_blank(),
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      
      axis.title.y.left = element_text(
        size = all_element_size - 4,
        face = "bold",
        color = "black"
      ),
      axis.title.y.right = element_text(
        size = all_element_size - 4,
        face = "bold",
        color = "black"
      ),
      axis.text = element_text(
        size = all_element_size - 4,
        face = "bold"
      ),
      
      legend.position = ifelse(show_legend, "bottom", "none"),
      legend.direction = "horizontal",
      legend.justification = "center",
      legend.text = element_text(
        size = all_element_size - 4,
        face = "bold"
      ),
      legend.key.width = unit(2.5, "cm"),
      legend.background = element_blank(),
      
      panel.grid.minor = element_blank(),
      plot.margin = margin(t = 22, r = 8, b = 2, l = 8)
    )
}

# ================= Bottom membership grid =================
make_membership_grid_plot <- function(grid_data, show_legend = FALSE) {
  
  ggplot(grid_data) +
    
    geom_tile(
      aes(x = Year, y = Region_Num, fill = IsMember),
      color = "gray90",
      width = 1,
      height = 1
    ) +
    
    geom_vline(
      xintercept = tip_years,
      color = color_tip,
      linetype = "twodash",
      linewidth = 0.7,
      alpha = 0.8
    ) +
    
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
    
    scale_x_continuous(
      expand = c(0, 0),
      limits = x_axis_limits,
      breaks = x_axis_breaks
    ) +
    
    scale_y_continuous(
      expand = c(0, 0),
      breaks = 1:length(nation_order_plot),
      labels = nation_order_plot
    ) +
    
    labs(
      x = "Year",
      y = "Region"
    ) +
    
    theme_bw() +
    
    theme(
      panel.grid = element_blank(),
      
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
      
      legend.position = ifelse(show_legend, "bottom", "none"),
      legend.direction = "horizontal",
      legend.justification = "center",
      legend.title = element_text(
        size = all_element_size - 6,
        face = "bold"
      ),
      legend.text = element_text(
        size = all_element_size - 6,
        face = "bold"
      ),
      legend.key.width = unit(2.2, "cm"),
      legend.background = element_blank(),
      
      plot.margin = margin(t = 2, r = 8, b = 5, l = 8)
    )
}

# ================= Shared dual-axis scaling =================
get_axis_params <- function(df_future) {
  
  max_emis <- max(
    c(
      df_future$Coalition_Emission,
      df_future$Non_Coalition_Emission
    ),
    na.rm = TRUE
  )
  
  if (max_emis <= 0 || is.na(max_emis)) {
    max_emis <- 10
  }
  
  n_intervals <- 6
  raw_step <- max_emis / n_intervals
  mag <- 10^floor(log10(raw_step))
  rel_step <- raw_step / mag
  
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
  
  nice_step <- nice_rel * mag
  axis_max <- nice_step * n_intervals
  coeff <- axis_max / 3
  
  return(list(
    axis_max = axis_max,
    nice_step = nice_step,
    coeff = coeff
  ))
}

# ================= Main loop =================
cat("Processing the one-tipping Future file...\n")

sheet_names <- getSheetNames(file_future)

for (sheet_name in sheet_names) {
  
  cat("  -> Plotting Sheet:", sheet_name, "\n")
  
  data_future <- extract_plot_data(file_future, sheet_name)
  
  if (is.null(data_future)) {
    cat("    ⚠️ Future Data are missing; skipping this sheet...\n")
    next
  }
  
  df_future <- data_future$summary
  
  axis_params <- get_axis_params(df_future)
  
  # Use a temporary Future plot to extract the line legend
  p_line_legend_src <- make_emission_temp_plot(
    plot_data = df_future,
    panel_tag = "",
    axis_max = axis_params$axis_max,
    nice_step = axis_params$nice_step,
    coeff = axis_params$coeff,
    show_legend = TRUE
  )
  
  # Use a temporary grid to extract the membership legend
  p_member_legend_src <- make_membership_grid_plot(
    data_future$grid,
    show_legend = TRUE
  )
  
  line_legend <- cowplot::get_legend(p_line_legend_src)
  member_legend <- cowplot::get_legend(p_member_legend_src)
  
  p_future_top <- make_emission_temp_plot(
    plot_data = df_future,
    panel_tag = "",
    axis_max = axis_params$axis_max,
    nice_step = axis_params$nice_step,
    coeff = axis_params$coeff,
    show_legend = FALSE
  )
  
  p_future_grid <- make_membership_grid_plot(
    data_future$grid,
    show_legend = FALSE
  )
  
  # Combine the emissions-temperature plot and membership grid
  main_plot <- cowplot::plot_grid(
    p_future_top,
    p_future_grid,
    ncol = 1,
    align = "v",
    axis = "lr",
    rel_heights = c(1.0, 1.35)
  )
  
  # Stack and center both legends below the panels
  legend_block <- cowplot::plot_grid(
    line_legend,
    member_legend,
    ncol = 1,
    align = "v",
    rel_heights = c(1, 1)
  )
  
  final_plot <- cowplot::plot_grid(
    main_plot,
    legend_block,
    ncol = 1,
    rel_heights = c(1, 0.18)
  )
  
  safe_sheet_name <- gsub("[\\\\/:*?\"<>|]", "_", sheet_name)
  
  save_name <- file.path(
    save_dir,
    paste0("Coalition_Emissions_MembershipGrid_", safe_sheet_name, ".pdf")
  )
  
  suppressWarnings(
    ggsave(
      filename = save_name,
      plot = final_plot,
      width = 18,
      height = 14
    )
  )
  
  cat("     Saved to:", save_name, "\n")
}

cat("==== One-tipping Future emissions-temperature and membership-grid figures generated!  ====\n")
