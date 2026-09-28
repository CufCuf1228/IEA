# Plot the regional parameter scatter charts used in the appendix.
# Run this script from the R_code directory so all paths remain relative.

# ================= 0. Load packages =================
library(tidyverse)
library(ggrepel)

# ================= 1. Global plot settings =================

# Control all plot text with one parameter
text_size <- 16

# geom_text_repel uses a different size unit from theme
label_size <- text_size / ggplot2::.pt

# Point size
point_size <- 3.5

# Output file.
out_file <- file.path(
  ".",
  "IEA Figures Appendix",
  "IEA_parameter_scatter.pdf"
)

# ================= 2. Parameter data =================
df <- tibble(
  Region = c(
    "China", "US", "EU", "Japan",
    "Russia", "India", "MidEast", "LatAm",
    "OthAsia", "Eurasia", "OHI", "Africa"
  ),
  
  alpha = c(
    11.03, 24.41, 38.18, 27.56,
    12.75, 16.00, 19.05, 20.12,
    11.45, 12.19, 22.73, 17.11
  ),
  
  beta = c(
    3.60, 14.36, 35.01, 72.75,
    29.45, 17.26, 20.41, 19.53,
    9.39, 48.25, 39.12, 33.44
  )
)

# ================= 3. Region groups =================
df <- df %>%
  mutate(
    Group = case_when(
      
      Region %in% c(
        "US", "EU", "Japan", "OHI"
      ) ~ "Advanced regions",
      
      Region %in% c(
        "China", "Russia", "India", "MidEast",
        "LatAm", "OthAsia", "Eurasia", "Africa"
      ) ~ "Emerging & developing regions"
    )
  )

# Fix the legend order
df$Group <- factor(
  df$Group,
  levels = c(
    "Advanced regions",
    "Emerging & developing regions"
  )
)

# ================= 4. Color and marker settings =================

group_colors <- c(
  "Advanced regions" = "#2F5597",
  "Emerging & developing regions" = "#C55A11"
)

group_shapes <- c(
  "Advanced regions" = 16,                 # Filled circle.
  "Emerging & developing regions" = 17     # Filled triangle.
)

# ================= 5. Plot theme =================
theme_aer <- theme_classic(
  base_size = text_size
) +
  theme(
    
    # ---------- All text ----------
    text = element_text(
      size = text_size,
      colour = "black"
    ),
    
    # ---------- Axis titles ----------
    axis.title = element_text(
      size = text_size,
      face = "plain",
      colour = "black"
    ),
    
    # ---------- Axis tick labels ----------
    axis.text = element_text(
      size = text_size,
      face = "bold",
      colour = "black"
    ),
    
    # ---------- Axis lines ----------
    axis.line = element_line(
      linewidth = 0.45,
      colour = "black"
    ),
    
    axis.ticks = element_line(
      linewidth = 0.4,
      colour = "black"
    ),
    
    axis.ticks.length = unit(0.15, "cm"),
    
    # ---------- Title ----------
    plot.title = element_text(
      size = text_size,
      face = "bold",
      hjust = 0.5,
      colour = "black",
      margin = margin(b = 8)
    ),
    
    # ---------- legend ----------
    legend.title = element_blank(),
    
    legend.text = element_text(
      size = text_size,
      face = "bold",
      colour = "black"
    ),
    
    legend.position = "bottom",
    legend.direction = "horizontal",
    
    legend.key = element_blank(),
    legend.key.width = unit(0.9, "cm"),
    legend.spacing.x = unit(0.15, "cm"),
    
    # ---------- Plot margins ----------
    plot.margin = margin(
      t = 8,
      r = 15,
      b = 5,
      l = 10
    )
  )

# ================= 6. Benefit-parameter scatter plot =================
p_benefit <- ggplot(
  df,
  aes(
    x = alpha,
    y = beta,
    color = Group,
    shape = Group
  )
) +
  
  geom_point(
    size = point_size,
    alpha = 1,
    stroke = 0.4
  ) +
  
  geom_text_repel(
    aes(label = Region),
    
    size = label_size,
    color = "black",
    
    box.padding = 0.45,
    point.padding = 0.30,
    
    min.segment.length = 0,
    
    segment.color = "grey55",
    segment.linewidth = 0.30,
    
    max.overlaps = Inf,
    seed = 123,
    
    show.legend = FALSE
  ) +
  
  scale_color_manual(
    values = group_colors,
    drop = FALSE
  ) +
  
  scale_shape_manual(
    values = group_shapes,
    drop = FALSE
  ) +
  
  scale_x_continuous(
    expand = expansion(mult = c(0.08, 0.12))
  ) +
  
  scale_y_continuous(
    expand = expansion(mult = c(0.08, 0.12))
  ) +
  
  labs(
    title = "Benefit parameters",
    x = expression(alpha),
    y = expression(beta),
    color = NULL,
    shape = NULL
  ) +
  
  theme_aer

# ================= 7. Display plot =================
print(p_benefit)

# ================= 8. Save PDF =================
dir.create(
  dirname(out_file),
  recursive = TRUE,
  showWarnings = FALSE
)

ggsave(
  filename = out_file,
  plot = p_benefit,
  device = cairo_pdf,
  
  width = 7.2,
  height = 5.5,
  
  units = "in"
)

cat(
  "Figure saved to:\n",
  out_file,
  "\n"
)
