# Compare minimum connection and sanction rates for the grand coalition.
# Run this script from the R_code directory so all paths remain relative.

# ================= 0. Load packages =================
library(readxl)
library(tidyverse)
library(patchwork)
library(scales)
library(stringr)
library(ggtext)

# ================= 1. File paths =================
file_con_future <- file.path("..", "code", "One Tipping Make Grand", "GrandCoalitionTrace_Once_Connection.xlsx")
file_san_future <- file.path("..", "code", "One Tipping Make Grand", "GrandCoalitionTrace_Once_Sanction.xlsx")

# Output directory
out_dir <- file.path(".", "IEA Figures 4.3")

if (!dir.exists(out_dir)) {
  dir.create(
    out_dir,
    recursive = TRUE
  )
}

if (!file.exists(file_con_future)) {
  stop(
    paste(
      "Could not find file:",
      file_con_future
    )
  )
}

if (!file.exists(file_san_future)) {
  stop(
    paste(
      "Could not find file:",
      file_san_future
    )
  )
}


# ================= 2. Match common sheet names =================
sheets_con_future <- excel_sheets(
  file_con_future
)

sheets_san_future <- excel_sheets(
  file_san_future
)

common_sheets <- intersect(
  sheets_con_future,
  sheets_san_future
)

if (length(common_sheets) == 0) {
  
  stop(
    "Error: no common scenario sheets were found."
  )
  
} else {
  
  message(
    "Matched ",
    length(common_sheets),
    " common sheets."
  )
}


# ================= 3. Read and process data =================
read_and_process <- function(
    file_path,
    mech_label,
    valid_sheets
) {
  
  data_list <- lapply(
    valid_sheets,
    function(s) {
      
      df <- read_excel(
        file_path,
        sheet = s
      )
      
      df$Scenario <- s
      df$Mechanism <- mech_label
      
      
      # ---------- Connection rate ----------
      if ("Conrate" %in% names(df)) {
        df <- df %>%
          rename(
            Rate = Conrate
          )
      }
      
      
      # ---------- Loss rate ----------
      if ("Lossrate" %in% names(df)) {
        df <- df %>%
          rename(
            Rate = Lossrate
          )
      }
      
      
      # ---------- Sanction rate ----------
      if ("Sanrate" %in% names(df)) {
        df <- df %>%
          rename(
            Rate = Sanrate
          )
      }
      
      
      # ---------- Check Year ----------
      if (!("Year" %in% names(df))) {
        stop(
          paste(
            "Sheet",
            s,
            "is missing the Year column."
          )
        )
      }
      
      
      # ---------- Check Rate ----------
      if (!("Rate" %in% names(df))) {
        stop(
          paste(
            "Sheet",
            s,
            "is missing the Conrate, Lossrate, and Sanrate columns."
          )
        )
      }
      
      
      # ---------- Clean ----------
      df <- df %>%
        mutate(
          Year = as.numeric(Year),
          Rate = as.numeric(Rate)
        ) %>%
        filter(
          !is.na(Year),
          !is.na(Rate)
        )
      
      
      return(df)
    }
  )
  
  
  bind_rows(
    data_list
  )
}


# ================= 4. Read connection data =================
df_con_future <- read_and_process(
  file_path = file_con_future,
  mech_label = "Connection",
  valid_sheets = common_sheets
)


# ================= 5. Read sanction data =================
df_san_future <- read_and_process(
  file_path = file_san_future,
  mech_label = "Sanction",
  valid_sheets = common_sheets
)


# ================= 6. Combine data =================
all_data <- bind_rows(
  df_con_future,
  df_san_future
)

all_data$Mechanism <- factor(
  all_data$Mechanism,
  levels = c(
    "Connection",
    "Sanction"
  )
)


# ================= 7. Aesthetic mappings and global settings =================
scenarios <- unique(
  all_data$Scenario
)

min_year <- min(
  all_data$Year,
  na.rm = TRUE
)

max_year <- max(
  all_data$Year,
  na.rm = TRUE
)

year_breaks <- seq(
  floor(min_year / 10) * 10,
  ceiling(max_year / 10) * 10,
  by = 10
)


# ================= Tipping settings =================

tipping_years <- c(2060)

color_tip <- "darkgray"


# ================= Font sizes =================
all_element_size <- 21


# ================= Colors =================
color_map <- c(
  "Connection" = "blue",
  "Sanction" = "red"
)


# ================= Line types =================
linetype_map <- c(
  "Connection" = "solid",
  "Sanction" = "solid"
)


# ================= Line widths =================
linewidth_map <- c(
  "Connection" = 1.2,
  "Sanction" = 1.2
)


# ================= 8. Shared theme =================
my_theme <- theme_minimal() +
  
  theme(
    
    # ---------- Axis text ----------
    axis.text = element_text(
      size = all_element_size - 2,
      face = "bold",
      color = "black"
    ),
    
    
    # ---------- Axis title ----------
    axis.title = element_text(
      size = all_element_size - 2,
      face = "bold",
      color = "black"
    ),
    
    
    # ---------- Axis line ----------
    axis.line = element_line(
      color = "black",
      linewidth = 0.8
    ),
    
    
    # ---------- Axis ticks ----------
    axis.ticks = element_line(
      color = "black",
      linewidth = 0.8
    ),
    
    
    axis.ticks.length = unit(
      0.15,
      "cm"
    ),
    
    
    # ---------- Grid ----------
    panel.grid.minor = element_blank(),
    
    
    # ---------- Legend ----------
    legend.position = "none",
    
    
    # =====================================================
    # Add top padding
    # =====================================================
    plot.margin = margin(
      t = 28,
      r = 10,
      b = 10,
      l = 10
    )
  )


custom_legend <- paste0(
  
  "<span style='color:blue; font-size:26px; font-weight:bold;'>—</span> ",
  
  "Connection",
  
  "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
  
  "<span style='color:red; font-size:26px; font-weight:bold;'>—</span> ",
  
  "Sanction"
)


for (scen in scenarios) {
  
  # ---------- Current scenario ----------
  plot_data <- all_data %>%
    filter(
      Scenario == scen
    )
  
  
  # =======================================================
  # Build plot
  # =======================================================
  p_future <- ggplot(
    
    plot_data,
    
    aes(
      x = Year,
      y = Rate,
      color = Mechanism,
      linetype = Mechanism,
      linewidth = Mechanism
    )
    
  ) +
    
    
    # ================= Connection / Sanction lines =================
  geom_line() +
    
    
    # =====================================================
  # Tipping vertical line
  #
  # 2060
  # =====================================================
  geom_vline(
    
    xintercept = tipping_years,
    
    color = color_tip,
    
    linetype = "twodash",
    
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
    
    x = tipping_years[1],
    
    y = 0.01,
    
    label = "Tipping",
    
    vjust = -1.0,
    
    size = 6.5,
    
    fontface = "bold",
    
    color = "black"
  ) +
    
    
    # ================= Color =================
  scale_color_manual(
    values = color_map
  ) +
    
    
    # ================= Linetype =================
  scale_linetype_manual(
    values = linetype_map
  ) +
    
    
    # ================= Linewidth =================
  scale_linewidth_manual(
    values = linewidth_map
  ) +
    
    
    # ================= X axis =================
  scale_x_continuous(
    
    limits = c(
      2025,
      2100
    ),
    
    breaks = seq(
      2025,
      2100,
      15
    ),
    
    expand = c(
      0,
      NA
    )
  ) +
    
    
    # ================= Y axis =================
  scale_y_continuous(
    
    labels = label_percent(),
    
    limits = c(
      0,
      0.01
    ),
    
    expand = expansion(
      mult = c(
        0,
        0.05
      )
    )
  ) +
    
    
    # =====================================================
  # clip = "off"
  #
  # Allow the Tipping label above the panel
  # =====================================================
  coord_cartesian(
    clip = "off"
  ) +
    
    
    # ================= Axis labels =================
  labs(
    x = "Year",
    y = "Minimum Connection / Sanction Rate"
  ) +
    
    
    # ================= Theme =================
  my_theme
  
  
  # =======================================================
  # Combined plot and custom legend
  # =======================================================
  final_plot <- p_future +
    
    plot_annotation(
      caption = custom_legend
    ) &
    
    theme(
      
      # ---------- Caption ----------
      plot.caption = element_markdown(
        size = all_element_size,
        face = "bold",
        hjust = 0.5,
        margin = margin(
          t = 15
        )
      )
    )
  
  
  # =======================================================
  # =======================================================
  filename <- paste0(
    out_dir,
    "\\Comparison_Min_Con_Sanc_",
    scen,
    ".pdf"
  )
  
  
  # =======================================================
  # Save output
  # =======================================================
  ggsave(
    
    filename = filename,
    
    plot = final_plot,
    
    width = 9,
    
    height = 6.5
  )
  
  
  message(
    "Saved plot: ",
    filename
  )
}


cat(
  "==== Future minimum connection and sanction rate figures generated with Tipping annotations!  ====\n"
)
