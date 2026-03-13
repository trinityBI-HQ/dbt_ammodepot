"""Shared Plotly dark theme for all Streamlit dashboard charts.

Usage:
    from utils.chart_theme import apply_theme
    fig = go.Figure(...)
    apply_theme(fig)                     # standard chart
    apply_theme(fig, height=400)         # override height
    apply_theme(fig, transparent=True)   # fully transparent bg (for hbar)
"""

import plotly.graph_objects as go

# -- Palette --
ACCENT = "#00d4aa"
ACCENT_DIM = "rgba(0, 212, 170, 0.20)"
TEXT_PRIMARY = "#e0e0e0"
TEXT_SECONDARY = "#999999"
GRID_COLOR = "rgba(255, 255, 255, 0.08)"
BG_PLOT = "#0e1117"
BG_PAPER = "#0e1117"

# -- Reusable legend dict --
LEGEND_DEFAULTS = dict(
    orientation="h",
    yanchor="bottom",
    y=1.02,
    xanchor="left",
    x=0,
    font=dict(size=11, color=TEXT_PRIMARY),
)

# -- Shared axis defaults --
_AXIS_DEFAULTS = dict(
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
    transparent: bool = False,
    show_legend: bool = True,
    margin: dict | None = None,
    legend_overrides: dict | None = None,
) -> go.Figure:
    """Apply the unified dark theme to a Plotly figure.

    Parameters
    ----------
    fig : go.Figure
    height : chart height in px (default 300)
    transparent : True → fully transparent backgrounds (useful for hbar overlays)
    show_legend : whether to show the legend
    margin : override default margin dict
    legend_overrides : merge into legend defaults
    """
    bg_plot = "rgba(0,0,0,0)" if transparent else BG_PLOT
    bg_paper = "rgba(0,0,0,0)" if transparent else BG_PAPER

    legend = {**LEGEND_DEFAULTS}
    if legend_overrides:
        legend.update(legend_overrides)

    fig.update_layout(
        height=height,
        margin=margin or dict(l=0, r=0, t=30, b=0),
        plot_bgcolor=bg_plot,
        paper_bgcolor=bg_paper,
        font=dict(color=TEXT_PRIMARY, size=12),
        showlegend=show_legend,
        legend=legend,
        xaxis=_AXIS_DEFAULTS,
        yaxis=_AXIS_DEFAULTS,
        hoverlabel=dict(
            bgcolor="#1e1e1e",
            font_size=12,
            font_color=TEXT_PRIMARY,
            bordercolor=ACCENT,
        ),
    )
    return fig
