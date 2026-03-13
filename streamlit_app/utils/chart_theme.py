"""Shared Plotly theme for all Streamlit dashboard charts.

Adapts to Streamlit's active theme (dark locally, light on SiS).
All chart backgrounds are transparent so they inherit the page background.

Usage:
    from utils.chart_theme import apply_theme
    fig = go.Figure(...)
    apply_theme(fig)                     # standard chart
    apply_theme(fig, height=400)         # override height
"""

import streamlit as st
import plotly.graph_objects as go


def _is_dark() -> bool:
    """Detect whether Streamlit is using a dark theme."""
    try:
        base = st.get_option("theme.base")
        if base:
            return base == "dark"
    except Exception:
        pass
    # Default: dark for local dev, but SiS typically is light
    from utils.db import _is_sis
    return not _is_sis


# -- Palette (resolved at call time) --
ACCENT = "#00d4aa"
ACCENT_DIM = "rgba(0, 212, 170, 0.20)"
INVENTORY_BLUE = "#5B9BD5"


def _palette():
    """Return theme-adaptive colors."""
    dark = _is_dark()
    return dict(
        text_primary="#e0e0e0" if dark else "#1a1a2e",
        text_secondary="#999999" if dark else "#555555",
        grid_color="rgba(255,255,255,0.08)" if dark else "rgba(0,0,0,0.08)",
        hover_bg="#1e1e1e" if dark else "#ffffff",
        hover_border=ACCENT,
    )


# -- Reusable legend builder --
def _legend(pal, overrides=None):
    d = dict(
        orientation="h",
        yanchor="bottom",
        y=1.02,
        xanchor="left",
        x=0,
        font=dict(size=11, color=pal["text_primary"]),
    )
    if overrides:
        d.update(overrides)
    return d


def apply_theme(
    fig: go.Figure,
    *,
    height: int = 300,
    show_legend: bool = True,
    margin: dict | None = None,
    legend_overrides: dict | None = None,
) -> go.Figure:
    """Apply the unified theme to a Plotly figure.

    Backgrounds are always transparent so charts inherit the Streamlit
    page theme (dark or light). Text and grid colors adapt automatically.
    """
    pal = _palette()
    axis = dict(
        color=pal["text_secondary"],
        gridcolor=pal["grid_color"],
        zerolinecolor=pal["grid_color"],
        title_font=dict(color=pal["text_secondary"], size=12),
        tickfont=dict(color=pal["text_secondary"], size=10),
    )

    fig.update_layout(
        height=height,
        margin=margin or dict(l=0, r=0, t=30, b=0),
        plot_bgcolor="rgba(0,0,0,0)",
        paper_bgcolor="rgba(0,0,0,0)",
        font=dict(color=pal["text_primary"], size=12),
        showlegend=show_legend,
        legend=_legend(pal, legend_overrides),
        xaxis=axis,
        yaxis=axis,
        hoverlabel=dict(
            bgcolor=pal["hover_bg"],
            font_size=12,
            font_color=pal["text_primary"],
            bordercolor=pal["hover_border"],
        ),
    )
    return fig


def secondary_axis_style() -> dict:
    """Return color + tickfont for a secondary y-axis (yaxis2)."""
    pal = _palette()
    return dict(color=pal["text_secondary"], tickfont=dict(color=pal["text_secondary"]))
