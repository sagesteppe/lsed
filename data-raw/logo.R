# -----------------------------------------------------------------------------
# lsed hex-sticker logo generator (development script; not part of the package).
# Run from the package root:  source("data-raw/logo.R")  -> man/figures/logo.png
# -----------------------------------------------------------------------------
library(sf)
library(ambient)
library(dplyr)
library(ggplot2)

set.seed(27) #27, 36

# -----------------------------------------------------------------------------
# 0. helpers / palette ---------------------------------------------------------
# -----------------------------------------------------------------------------

pal <- c('#439775', '#2A4747',  '#F6D8AE', '#7D80DA')
pal        <- c('#128B91', '#6BB3A0', '#9C7A97', '#F19953')

border_col <- '#2A4747'
bg_col     <- '#F7F3E9' # colour used to "mask" everything outside the hex

# -----------------------------------------------------------------------------
# 1. hex boundary --------------------------------------------------------------
# -----------------------------------------------------------------------------

# build a flat-top R-style hexagon directly from its vertices (radius R)
R <- 5
ang <- seq(0, 2 * pi, length.out = 7)            # 6 corners + closing point
verts <- cbind(R * cos(ang), R * sin(ang))
verts[nrow(verts), ] <- verts[1, ]              # ensure the ring is closed exactly
hex <- verts |>
  list() |>
  st_polygon() |>
  st_sfc() |>
  st_sf()

## inner and outer borders, so the edge of the hex can read as a ring ----------
hex_inner       <- st_buffer(hex, dist = -0.45)   # inner polygon (art lives here)
hex_outline     <- st_cast(hex, 'LINESTRING')        # outer edge
hex_inner_outln <- st_cast(hex_inner, 'LINESTRING')  # inner edge

# -----------------------------------------------------------------------------
# 2. ambient background fill ---------------------------------------------------
# -----------------------------------------------------------------------------

# noise fill, same recipe as ConferenceBookmarks/scripts/Mosaics.R:
# fracture() over sampled generators/fractals, binned into discrete shades.
fractals   <- list(ambient::billow, ambient::fbm, ambient::ridged)
generators <- list(ambient::gen_simplex, ambient::gen_perlin, ambient::gen_worley)
nshades    <- 50

# a long_grid covering the hex bbox; cropped (masked) to the inner hex below
bb <- st_bbox(hex)
n  <- 25
canvas <- long_grid(
  x = seq(bb['xmin'], bb['xmax'], length.out = n),
  y = seq(bb['ymin'], bb['ymax'], length.out = n)
) |>
  mutate(
    fill = fracture(
      x = x * sample(-4:3, 1),
      y = y * sample(-4:3, 1),
      noise     = sample(generators, 1)[[1]],
      fractal   = sample(fractals, 1)[[1]],
      octaves   = sample(10, 1),
      frequency = sample(10, 1) / 20, # <15 no good, >25 too random (per Mosaics)
      value     = "distance2"
    ) |>
      normalise(to = c(1, nshades)) |>
      round()
  )

# -----------------------------------------------------------------------------
# 3. rasterized letters --------------------------------------------------------
# -----------------------------------------------------------------------------

# A display face spelled out pixel-by-pixel so each letter SNAPS to the raster
# grid beneath it. Every glyph is a fixed 4-wide x 6-tall bitmap ('#' = lit).
# Black-Ops-One vibe: fixed widths, fixed heights, blocky.
glyphs <- list(
  L = c("#...",
        "#...",
        "#...",
        "#...",
        "##..",
        ".###"),
  S = c("####",
        "#...",
        "###.",
        ".###",
        "...#",
        "####"),
  E = c("####",
        "#...",
        "###.",
        "###.",
        "#...", 
        "####"),
  D = c("###.",
        "#..#",
        "#..#",
        "#..#",
        "#..#",
        "###.")
)

word     <- c("L", "S", "E", "D")
gap      <- 1   # blank raster columns between letters
row_shift <- 0  # nudge the word up (+) / down (-) by whole raster cells
col_shift <- 0  # nudge the word right (+) / left (-) by whole raster cells

# stitch the glyphs (+ gap columns) into one logical bitmap: rows top -> bottom
to_mat   <- function(ch) do.call(rbind, strsplit(glyphs[[ch]], "")) == "#"
blocks   <- lapply(word, to_mat)
nrow_bm  <- nrow(blocks[[1]])
sep      <- matrix(FALSE, nrow = nrow_bm, ncol = gap)
bm       <- blocks[[1]]
for (k in 2:length(blocks)) bm <- cbind(bm, sep, blocks[[k]])
ncol_bm  <- ncol(bm)

# the raster's own cell centres + spacing, so the letters land on exact cells
xs <- sort(unique(canvas$x)); dx <- xs[2] - xs[1]
ys <- sort(unique(canvas$y)); dy <- ys[2] - ys[1]

# centre the word block within the n x n grid (shifts bias horiz/vert)
start_col <- floor((n - ncol_bm) / 2) + 1 + col_shift
start_row <- floor((n - nrow_bm) / 2) + 1 + row_shift

# every lit pixel -> the (x, y) centre of the raster cell it occupies
lit <- which(bm, arr.ind = TRUE)                # columns: row (1 = top), col
letters_df <- data.frame(
  x = xs[start_col + lit[, "col"] - 1],
  y = ys[start_row + (nrow_bm - lit[, "row"])]  # flip: bitmap row 1 = top
)

# -----------------------------------------------------------------------------
# 4. DCA-like net-benefit curves ----------------------------------------------
# -----------------------------------------------------------------------------

# threshold probability on x, net benefit on y (stylised, not real data)
prev <- 0.3
p    <- seq(0.01, 0.75, length.out = 200)
p_tn <- seq(-0.12, 0.88, length.out = 200)   # wider span for the treat-none line
curves <- bind_rows(
  data.frame(curve = 'model',     p = p,    nb = prev - (1 - prev) * (p / (1 - p)) * 0.2 + 0.08),
  data.frame(curve = 'treat_all', p = p,    nb = prev - (1 - prev) * (p / (1 - p))),
  data.frame(curve = 'treat_none',p = p_tn, nb = 0)
) |>
  filter(nb > -0.15) |>
  # map the [0,0.75] x [-0.15,0.3] curve space into the lower band of the hex
  # curve_lift raises the whole family (band height is 2.6; ~25% ≈ 0.65)
  mutate(
    gx = (p / 0.75) * 6 - 3.25,
    gy = (nb + 0.15) / 0.45 * 2.6 - 3.4 + 1
  )

# -----------------------------------------------------------------------------
# 4b. pyramids (triangles) tiling the hex buffer ring --------------------------
# -----------------------------------------------------------------------------

# n_pyr triangles per hex side: base sits on the inner line, apex points outward
# to the outer edge, so each one spans the full width of the border band.
n_pyr <- 8
band  <- 0.45                       # == the hex_inner buffer distance

hex_v <- cbind(R * cos(ang), R * sin(ang))   # outer vertices (ang defined above)

tris <- list(); i <- 1L
for (k in 1:6) {
  A <- hex_v[k, ]; B <- hex_v[k + 1, ]
  M  <- (A + B) / 2
  ni <- -M / sqrt(sum(M^2))         # inward unit normal (toward centre)
  Ai <- A + ni * band; Bi <- B + ni * band   # inner-line endpoints of this edge
  for (j in 1:n_pyr) {
    P1   <- Ai + (Bi - Ai) * (j - 1) / n_pyr
    P2   <- Ai + (Bi - Ai) *  j      / n_pyr
    apex <- (P1 + P2) / 2 - ni * band          # back out onto the outer edge
    tris[[i]] <- st_polygon(list(rbind(P1, P2, apex, P1))); i <- i + 1L
  }
}
pyramids <- st_sf(id = seq_along(tris), geometry = st_sfc(tris))

# -----------------------------------------------------------------------------
# 5. mask frame (everything outside the inner hex) -----------------------------
# -----------------------------------------------------------------------------

frame <- st_difference(
  st_as_sfc(st_bbox(st_buffer(hex, 1))),
  st_geometry(hex_inner)
) |> st_sf()

# -----------------------------------------------------------------------------
# 6. plot ----------------------------------------------------------------------
# -----------------------------------------------------------------------------

logo <- ggplot() +
  # ambient noise fill
  geom_raster(data = canvas, aes(x, y, fill = fill), show.legend = FALSE) +
  scale_fill_gradientn(colours = pal) +
  # DCA-ish curves
  geom_line(
    data = curves,
    aes(gx, gy, group = curve, linetype = curve),
    colour = '#13293D', linewidth = 2.5, show.legend = FALSE
  ) +
  scale_linetype_manual(
    values = c(
      model = 'solid', 
      treat_all = 'dashed', 
      treat_none = 'dotted')
    ) +
  # display-face letters, snapped to the raster cells beneath
  geom_tile(data = letters_df, aes(x, y),
            width = dx, height = dy,
            fill = 'grey15',
            colour = '#9C7A97', linewidth = 0.1) + 
  # mask out everything beyond the inner hex, then draw the ring
  geom_sf(data = frame, fill = bg_col, colour = NA) +
  # pyramids tiling the buffer ring
  geom_sf(data = pyramids, fill = NA, colour = 'grey60', linewidth = 0.3) +
  geom_sf(data = hex_inner_outln, colour = border_col, linewidth = 1.2) +
  geom_sf(data = hex_outline,     colour = border_col, linewidth = 2.5) +
  coord_sf(expand = FALSE) +
  theme_void()

logo
# -----------------------------------------------------------------------------
# 7. save ----------------------------------------------------------------------
# -----------------------------------------------------------------------------

dir.create('man/figures', recursive = TRUE, showWarnings = FALSE)
ggsave(
  filename = 'man/figures/logo.png',
  plot = logo, width = 5, height = 5 * (sqrt(3) / 2),
  dpi = 300, bg = 'transparent'
)

## done
