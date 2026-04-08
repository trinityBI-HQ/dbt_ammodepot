"""Shared Plotly dark theme — copy-minus-duplication of the main dashboard's theme.

Kept self-contained so the cost monitor can deploy independently of
``streamlit_app/utils/``.
"""

import plotly.graph_objects as go

ACCENT = "#00d4aa"
ACCENT_DIM = "rgba(0, 212, 170, 0.20)"
WARNING = "#ff9f40"
DANGER = "#ff6384"

BG_CHART = "#1E1E1E"
TEXT_PRIMARY = "#e0e0e0"
TEXT_SECONDARY = "#999999"
GRID_COLOR = "rgba(255, 255, 255, 0.08)"

_LEGEND = dict(
    orientation="h",
    yanchor="bottom",
    y=1.02,
    xanchor="left",
    x=0,
    font=dict(size=11, color=TEXT_PRIMARY),
)

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
    height: int = 320,
    show_legend: bool = True,
    margin: dict | None = None,
) -> go.Figure:
    fig.update_layout(
        height=height,
        margin=margin or dict(l=0, r=0, t=30, b=0),
        plot_bgcolor=BG_CHART,
        paper_bgcolor=BG_CHART,
        font=dict(color=TEXT_PRIMARY, size=12),
        showlegend=show_legend,
        legend=_LEGEND,
        xaxis=_AXIS,
        yaxis=_AXIS,
        hoverlabel=dict(
            bgcolor=BG_CHART,
            font_size=12,
            font_color=TEXT_PRIMARY,
            bordercolor=ACCENT,
        ),
    )
    return fig


def kpi_card(label: str, value: str, delta: str | None = None, delta_color: str = "normal"):
    """Render a compact KPI card using st.metric (wrapper for consistency)."""
    import streamlit as st

    st.metric(label=label, value=value, delta=delta, delta_color=delta_color)


def dark_dataframe(df, fmt=None, height=None):
    """Render a DataFrame as a dark HTML table — SiS iframe can't style st.dataframe."""
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

    hdr = "".join(f"<th style='text-align:left; padding:6px 10px;'>{c}</th>" for c in styled.columns)
    rows = []
    for _, row in styled.iterrows():
        cells = "".join(f"<td style='padding:6px 10px;'>{v}</td>" for v in row)
        rows.append(f"<tr style='border-top:1px solid #2a2a2a;'>{cells}</tr>")

    scroll = f"max-height:{height}px; overflow-y:auto;" if height else ""
    html = (
        f'<div style="background:{BG_CHART}; border-radius:8px; padding:8px; {scroll}">'
        '<table style="width:100%; border-collapse:collapse; font-size:13px;">'
        f'<thead><tr style="color:{TEXT_SECONDARY};">{hdr}</tr></thead>'
        f'<tbody style="color:{TEXT_PRIMARY};">{"".join(rows)}</tbody>'
        "</table></div>"
    )
    st.markdown(html, unsafe_allow_html=True)
