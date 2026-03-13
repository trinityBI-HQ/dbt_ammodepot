"""Shared Plotly dark theme for all Streamlit dashboard charts.

Forces dark backgrounds on all charts to match KPI cards and tables,
consistent across both local dev and SiS (light page theme).

Usage:
    from utils.chart_theme import apply_theme
    fig = go.Figure(...)
    apply_theme(fig)                     # standard chart
    apply_theme(fig, height=400)         # override height
"""

import plotly.graph_objects as go

# -- Dark palette (always dark, matches KPI cards) --
ACCENT = "#00d4aa"
ACCENT_DIM = "rgba(0, 212, 170, 0.20)"
INVENTORY_BLUE = "#5B9BD5"

BG_CHART = "#1E1E1E"
BG_HOVER = "#1e1e1e"
TEXT_PRIMARY = "#e0e0e0"
TEXT_SECONDARY = "#999999"
GRID_COLOR = "rgba(255, 255, 255, 0.08)"

# -- Reusable legend defaults --
_LEGEND = dict(
    orientation="h",
    yanchor="bottom",
    y=1.02,
    xanchor="left",
    x=0,
    font=dict(size=11, color=TEXT_PRIMARY),
)

# -- Shared axis defaults --
_AXIS = dict(
    color=TEXT_SECONDARY,
    gridcolor=GRID_COLOR,
    zerolinecolor=GRID_COLOR,
    title_font=dict(color=TEXT_SECONDARY, size=12),
    tickfont=dict(color=TEXT_SECONDARY, size=10),
)


def apply_theme(
    fig: go.Figure,
    *,
    height: int = 300,
    show_legend: bool = True,
    margin: dict | None = None,
    legend_overrides: dict | None = None,
) -> go.Figure:
    """Apply the unified dark theme to a Plotly figure.

    All charts get a dark background (#1E1E1E) matching the KPI cards,
    with light text and subtle grid lines.
    """
    legend = {**_LEGEND}
    if legend_overrides:
        legend.update(legend_overrides)

    fig.update_layout(
        height=height,
        margin=margin or dict(l=0, r=0, t=30, b=0),
        plot_bgcolor=BG_CHART,
        paper_bgcolor=BG_CHART,
        font=dict(color=TEXT_PRIMARY, size=12),
        showlegend=show_legend,
        legend=legend,
        xaxis=_AXIS,
        yaxis=_AXIS,
        hoverlabel=dict(
            bgcolor=BG_HOVER,
            font_size=12,
            font_color=TEXT_PRIMARY,
            bordercolor=ACCENT,
        ),
    )
    return fig


def secondary_axis_style() -> dict:
    """Return color + tickfont for a secondary y-axis (yaxis2)."""
    return dict(color=TEXT_SECONDARY, tickfont=dict(color=TEXT_SECONDARY))
