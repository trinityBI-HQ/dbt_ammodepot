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


def dark_dataframe(df, fmt=None, height=None, hide_index=True):
    """Render a DataFrame as a dark-themed HTML table via st.markdown.

    Parameters
    ----------
    df : pd.DataFrame
    fmt : dict mapping column name → Python format string (e.g. "${:,.0f}")
    height : optional max height in px (adds scrollbar)
    hide_index : hide the DataFrame index (default True)
    """
    import streamlit as st

    if df.empty:
        st.info("No data.")
        return

    styled = df.copy()
    if fmt:
        for col, f in fmt.items():
            if col in styled.columns:
                styled[col] = styled[col].apply(
                    lambda v, _f=f: _f.format(v) if v is not None and v == v else ""
                )

    # Build HTML table
    hdr = "".join(f"<th>{c}</th>" for c in styled.columns)
    rows = []
    for _, row in styled.iterrows():
        cells = "".join(f"<td>{v}</td>" for v in row)
        rows.append(f"<tr>{cells}</tr>")

    scroll = f"max-height:{height}px; overflow-y:auto;" if height else ""
    html = (
        f'<div style="background:{BG_CHART}; border-radius:8px; padding:8px; {scroll}">'
        '<table style="width:100%; border-collapse:collapse; font-size:13px;">'
        f'<thead><tr style="border-bottom:1px solid #333; color:{TEXT_SECONDARY};">{hdr}</tr></thead>'
        f'<tbody style="color:{TEXT_PRIMARY};">{"".join(rows)}</tbody>'
        '</table></div>'
    )
    st.markdown(html, unsafe_allow_html=True)
