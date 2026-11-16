"""Sales Performance dashboard on the Gold star schema.

Runs as a Streamlit in Snowflake app: Snowsight > Projects > Streamlit > + Streamlit App,
then paste this file over the sample code.

The six tiles use the same SQL as analyses/dashboard_*.sql. Only the filter differs:
Streamlit builds the WHERE condition itself and sends the selected values as bind
parameters (the ? marks), so a selected value is never pasted into the SQL text.

Charts are drawn with Altair, which ships with Streamlit, so nothing extra has to be installed.
"""

import altair as alt
import pandas as pd
import streamlit as st

GOLD = "PROPELLING_DB.GOLD"
ALL_YEARS = "All years"

# One fixed colour per region, in a colour-blind-safe order. A region keeps its colour in every
# chart and under every filter, so "Asia is green" stays true wherever the reader looks.
REGION_COLORS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4"]
# Charts that are not about regions use a neutral ink, so nobody reads them as one region.
NEUTRAL = "#33415c"
MUTED_TEXT = "#52514e"

st.set_page_config(page_title="Sales Performance", layout="wide")


def snowflake_session():
    """Returns the Snowflake session on either Streamlit runtime.

    The warehouse runtime hands the app an active session. The container runtime (compute pool)
    does not, and the documented way there is st.connection("snowflake").
    """
    try:
        from snowflake.snowpark.context import get_active_session

        return get_active_session()
    except Exception:
        return st.connection("snowflake").session()


session = snowflake_session()


@st.cache_data(ttl=3600)
def run_query(sql: str, params: tuple = ()) -> pd.DataFrame:
    """Runs a query once per distinct SQL and filter values, then serves it from cache for an hour."""
    df = session.sql(sql, params=list(params) if params else None).to_pandas()
    # Snowflake sums arrive as Decimal objects, which charts cannot plot. Convert those to numbers
    # and leave text columns (names, regions) as they are.
    for column in df.columns:
        if df[column].dtype == "object":
            as_numbers = pd.to_numeric(df[column], errors="coerce")
            if as_numbers.notna().all():
                df[column] = as_numbers
    return df


def build_filter(regions: list, year: str) -> tuple:
    """Returns the WHERE condition and its bind values. No selection means no restriction."""
    conditions, params = [], []
    if regions:
        conditions.append(f"customers.customer_region in ({', '.join('?' for _ in regions)})")
        params.extend(regions)
    if year != ALL_YEARS:
        conditions.append("order_dates.year_number = ?")
        params.append(int(year))
    return (" and ".join(conditions) or "true"), tuple(params)


# Every tile joins the fact table to the customer (for region) and the order date (for year).
STAR_JOINS = f"""
from {GOLD}.fct_sales as sales
inner join {GOLD}.dim_customer as customers
    on sales.customer_sk = customers.customer_sk
inner join {GOLD}.dim_date as order_dates
    on sales.order_date_key = order_dates.date_key
"""

KPI_SQL = """
select
    sum(sales.net_amount)                                                       as net_revenue,
    round(100 * sum(sales.margin_amount) / nullif(sum(sales.net_amount), 0), 2) as margin_pct,
    count(distinct sales.order_key)                                             as orders,
    round(100 * avg(sales.late_line_count), 2)                                  as late_rate_pct
{joins}
where {where}
"""

MONTHLY_SQL = """
with last_order as (
    -- Ignores the filters on purpose: the last month of data does not depend on the selection.
    select max(order_dates.calendar_date) as last_order_date
    from {gold}.fct_sales as sales
    inner join {gold}.dim_date as order_dates
        on sales.order_date_key = order_dates.date_key
)
select
    date_trunc('month', order_dates.calendar_date) as month_start,
    sum(sales.net_amount)                          as net_revenue,
    sum(sales.margin_amount)                       as margin,
    count(distinct sales.order_key)                as orders
{joins}
cross join last_order
where {where}
  -- Orders stop part-way through the final month; without this the line ends in a false collapse.
  and order_dates.calendar_date < date_trunc('month', dateadd('day', 1, last_order.last_order_date))
group by month_start
order by month_start
"""

REGION_SQL = """
select
    customers.customer_region,
    sum(sales.net_amount)                                                       as net_revenue,
    sum(sales.margin_amount)                                                    as margin,
    round(100 * sum(sales.margin_amount) / nullif(sum(sales.net_amount), 0), 2) as margin_pct,
    count(distinct sales.order_key)                                             as orders
{joins}
where {where}
group by customers.customer_region
order by net_revenue desc
"""

TOP_CUSTOMERS_SQL = """
select
    customers.customer_name,
    customers.customer_nation,
    customers.customer_region,
    customers.market_segment,
    sum(sales.net_amount)                                                       as net_revenue,
    sum(sales.margin_amount)                                                    as margin,
    round(100 * sum(sales.margin_amount) / nullif(sum(sales.net_amount), 0), 2) as margin_pct,
    count(distinct sales.order_key)                                             as orders
{joins}
where {where}
group by
    customers.customer_key,
    customers.customer_name,
    customers.customer_nation,
    customers.customer_region,
    customers.market_segment
-- customer_key breaks ties, so the same 10 customers appear on every run.
qualify row_number() over (order by sum(sales.net_amount) desc, customers.customer_key) <= 10
order by net_revenue desc, customers.customer_key
"""

LATE_DELIVERY_SQL = """
select
    attributes.ship_mode,
    count(*)                                   as order_lines,
    sum(sales.late_line_count)                 as late_lines,
    round(100 * avg(sales.late_line_count), 2) as late_rate_pct,
    round(avg(sales.transit_days), 2)          as avg_transit_days
{joins}
inner join {gold}.dim_sale_attributes as attributes
    on sales.sale_attributes_sk = attributes.sale_attributes_sk
where {where}
group by attributes.ship_mode
order by late_rate_pct desc
"""

PRODUCT_SQL = """
select
    parts.part_material,
    sum(sales.net_amount)                                                       as net_revenue,
    sum(sales.margin_amount)                                                    as margin,
    round(100 * sum(sales.margin_amount) / nullif(sum(sales.net_amount), 0), 2) as margin_pct,
    sum(sales.quantity)                                                         as units_sold
{joins}
inner join {gold}.dim_part as parts
    on sales.part_sk = parts.part_sk
where {where}
group by parts.part_material
order by net_revenue desc
"""

TOP_SUPPLIERS_SQL = """
select
    suppliers.supplier_name,
    suppliers.supplier_nation,
    suppliers.supplier_region,
    sum(sales.net_amount)                                                       as net_revenue,
    sum(sales.margin_amount)                                                    as margin,
    round(100 * sum(sales.margin_amount) / nullif(sum(sales.net_amount), 0), 2) as margin_pct,
    count(*)                                                                    as order_lines
{joins}
inner join {gold}.dim_supplier as suppliers
    on sales.supplier_sk = suppliers.supplier_sk
where {where}
group by
    suppliers.supplier_key,
    suppliers.supplier_name,
    suppliers.supplier_nation,
    suppliers.supplier_region
-- supplier_key breaks ties, so the same 10 suppliers appear on every run.
qualify row_number() over (order by sum(sales.net_amount) desc, suppliers.supplier_key) <= 10
order by net_revenue desc, suppliers.supplier_key
"""


def tile(sql_template: str, where: str, params: tuple) -> pd.DataFrame:
    return run_query(sql_template.format(gold=GOLD, joins=STAR_JOINS, where=where), params)


# ---- Formatting helpers -----------------------------------------------------------------------
def billions(value: float) -> str:
    return f"{value / 1e9:,.1f} bn"


def millions(value: float) -> str:
    return f"{value / 1e6:,.2f} M"


# Readable column names for the data tables. Only the display changes, not the data.
LABELS = {
    "MONTH_START": "Month",
    "CUSTOMER_REGION": "Region",
    "CUSTOMER_NAME": "Customer",
    "CUSTOMER_NATION": "Nation",
    "MARKET_SEGMENT": "Segment",
    "SHIP_MODE": "Ship mode",
    "PART_MATERIAL": "Material",
    "UNITS_SOLD": "Units sold",
    "SUPPLIER_NAME": "Supplier",
    "SUPPLIER_NATION": "Supplier nation",
    "SUPPLIER_REGION": "Supplier region",
    "NET_REVENUE": "Net revenue",
    "MARGIN": "Margin",
    "MARGIN_PCT": "Margin %",
    "ORDERS": "Orders",
    "ORDER_LINES": "Order lines",
    "LATE_LINES": "Late lines",
    "LATE_RATE_PCT": "Late %",
    "AVG_TRANSIT_DAYS": "Avg transit days",
}
MONEY = ["Net revenue", "Margin"]
COUNTS = ["Orders", "Order lines", "Late lines", "Units sold"]
DECIMALS = ["Margin %", "Late %", "Avg transit days"]


def show_table(df: pd.DataFrame) -> None:
    """Shows the numbers behind a chart, folded away so the chart stays the focus."""
    df = df.drop(columns=[c for c in df.columns if c.startswith("_")]).rename(columns=LABELS)
    formats = {c: "{:,.0f}" for c in MONEY + COUNTS if c in df.columns}
    formats.update({c: "{:.2f}" for c in DECIMALS if c in df.columns})
    with st.expander("See the numbers"):
        st.dataframe(df.style.format(formats), hide_index=True, use_container_width=True)


# ---- Chart builders -----------------------------------------------------------------------------
def region_color(legend: bool, field: str = "CUSTOMER_REGION") -> alt.Color:
    """Same five colours for customer and supplier regions: both use the same region names."""
    return alt.Color(
        f"{field}:N",
        title="Region",
        scale=alt.Scale(domain=region_options, range=REGION_COLORS[: len(region_options)]),
        legend=alt.Legend(orient="top", title=None, labelFontSize=13) if legend else None,
    )


def horizontal_bars(df: pd.DataFrame, category: str, value: str, label: str, color,
                    tooltip: list, value_title: str, domain_max: float = None) -> alt.LayerChart:
    """Ranked horizontal bars with the value written at the end of each bar."""
    top = domain_max if domain_max is not None else df[value].max() * 1.22
    base = alt.Chart(df).encode(
        y=alt.Y(f"{category}:N", sort="-x", title=None, axis=alt.Axis(labelFontSize=13, labelLimit=240)),
        x=alt.X(f"{value}:Q", title=value_title, scale=alt.Scale(domain=[0, top]),
                axis=alt.Axis(labels=False, ticks=False, grid=False, titleColor=MUTED_TEXT)),
        tooltip=tooltip,
    )
    bars = base.mark_bar(cornerRadiusEnd=4)
    bars = bars.encode(color=color) if isinstance(color, alt.Color) else bars.encode(color=alt.value(color))
    labels = base.mark_text(align="left", dx=6, fontSize=13, color="#0b0b0b").encode(text=f"{label}:N")
    return (bars + labels).properties(height=max(44 * len(df), 120))


# ---- Header and filters -------------------------------------------------------------------
st.title("Sales Performance")
st.caption(
    "How a BI tool reads the Gold layer: every number below comes from the fct_sales fact table "
    "joined to its dimensions in PROPELLING_DB.GOLD. TPC-H is synthetic, evenly spread data, so "
    "regions and ship modes look alike. That is the data, not an error."
)

region_options = run_query(
    f"select distinct customer_region from {GOLD}.dim_customer order by 1"
)["CUSTOMER_REGION"].tolist()
year_options = run_query(
    f"select distinct year_number from {GOLD}.dim_date order by 1"
)["YEAR_NUMBER"].astype(int).astype(str).tolist()

filter_left, filter_right = st.columns([3, 1])
selected_regions = filter_left.multiselect("Customer region (leave empty for all)", region_options)
selected_year = filter_right.selectbox("Order year", [ALL_YEARS] + year_options)

where, params = build_filter(selected_regions, selected_year)

# ---- KPI row ------------------------------------------------------------------------------
kpis = tile(KPI_SQL, where, params).iloc[0]
kpi_cols = st.columns(4)
kpi_cols[0].metric("Net revenue", billions(kpis["NET_REVENUE"] or 0),
                   help="What customers paid after discounts, before tax.")
kpi_cols[1].metric("Margin", f"{kpis['MARGIN_PCT'] or 0:.1f}%",
                   help="Share of net revenue left after paying suppliers: (revenue - cost) / revenue.")
kpi_cols[2].metric("Orders", f"{int(kpis['ORDERS'] or 0):,}",
                   help="Number of distinct orders in the selection.")
kpi_cols[3].metric("Late deliveries", f"{kpis['LATE_RATE_PCT'] or 0:.1f}%",
                   help="Share of order lines received after the date promised to the customer.")

st.markdown("---")

# ---- Tiles 1 and 2 --------------------------------------------------------------------------
left, right = st.columns(2, gap="large")

with left:
    st.subheader("Is revenue growing?")
    st.caption("Net revenue per month, by order date. The last, incomplete month is left out.")
    monthly = tile(MONTHLY_SQL, where, params)
    monthly["MONTH_START"] = pd.to_datetime(monthly["MONTH_START"])
    monthly["_REVENUE_BN"] = monthly["NET_REVENUE"] / 1e9
    monthly["_REVENUE_LABEL"] = monthly["NET_REVENUE"].map(billions)
    one_year = selected_year != ALL_YEARS
    line = (
        alt.Chart(monthly)
        .mark_line(color=NEUTRAL, strokeWidth=2,
                   point=alt.OverlayMarkDef(color=NEUTRAL, filled=True, size=70 if one_year else 28))
        .encode(
            x=alt.X("MONTH_START:T", title=None,
                    axis=alt.Axis(format="%b" if one_year else "%Y", labelFontSize=13, grid=False)),
            y=alt.Y("_REVENUE_BN:Q", title="Net revenue (billions)", scale=alt.Scale(zero=True),
                    axis=alt.Axis(labelFontSize=13, titleColor=MUTED_TEXT)),
            tooltip=[
                alt.Tooltip("MONTH_START:T", title="Month", format="%B %Y"),
                alt.Tooltip("_REVENUE_LABEL:N", title="Net revenue"),
                alt.Tooltip("ORDERS:Q", title="Orders", format=","),
            ],
        )
        .properties(height=320)
    )
    st.altair_chart(line, use_container_width=True)
    if len(monthly):
        st.caption(f"An average month brings in {billions(monthly['NET_REVENUE'].mean())}.")
    show_table(monthly)

with right:
    st.subheader("Which regions buy the most?")
    st.caption("Net revenue by the customer's region. Each region keeps its colour on this page.")
    regions = tile(REGION_SQL, where, params)
    regions["_LABEL"] = regions["NET_REVENUE"].map(billions)
    region_chart = horizontal_bars(
        regions, "CUSTOMER_REGION", "NET_REVENUE", "_LABEL", region_color(legend=False),
        tooltip=[
            alt.Tooltip("CUSTOMER_REGION:N", title="Region"),
            alt.Tooltip("_LABEL:N", title="Net revenue"),
            alt.Tooltip("MARGIN_PCT:Q", title="Margin %", format=".1f"),
            alt.Tooltip("ORDERS:Q", title="Orders", format=","),
        ],
        value_title="Net revenue",
    )
    st.altair_chart(region_chart, use_container_width=True)
    if len(regions):
        leader = regions.iloc[0]
        share = 100 * leader["NET_REVENUE"] / regions["NET_REVENUE"].sum()
        st.caption(f"{leader['CUSTOMER_REGION']} leads with {share:.1f}% of the revenue shown.")
    show_table(regions)

st.markdown("---")

# ---- Tiles 3 and 4 --------------------------------------------------------------------------
left, right = st.columns(2, gap="large")

with left:
    st.subheader("Who are our biggest customers?")
    st.caption("The 10 customers with the most net revenue. Colour shows the customer's region.")
    customers = tile(TOP_CUSTOMERS_SQL, where, params)
    customers["_LABEL"] = customers["NET_REVENUE"].map(millions)
    customer_chart = horizontal_bars(
        customers, "CUSTOMER_NAME", "NET_REVENUE", "_LABEL", region_color(legend=True),
        tooltip=[
            alt.Tooltip("CUSTOMER_NAME:N", title="Customer"),
            alt.Tooltip("CUSTOMER_NATION:N", title="Nation"),
            alt.Tooltip("MARKET_SEGMENT:N", title="Segment"),
            alt.Tooltip("_LABEL:N", title="Net revenue"),
            alt.Tooltip("MARGIN_PCT:Q", title="Margin %", format=".1f"),
            alt.Tooltip("ORDERS:Q", title="Orders", format=","),
        ],
        value_title="Net revenue",
    )
    st.altair_chart(customer_chart, use_container_width=True)
    show_table(customers)

with right:
    st.subheader("Does the ship mode explain late deliveries?")
    st.caption("Share of order lines that arrived after the promised date, for each ship mode.")
    late = tile(LATE_DELIVERY_SQL, where, params)
    late["_LABEL"] = late["LATE_RATE_PCT"].map(lambda v: f"{v:.1f}%")
    late_chart = horizontal_bars(
        late, "SHIP_MODE", "LATE_RATE_PCT", "_LABEL", NEUTRAL,
        tooltip=[
            alt.Tooltip("SHIP_MODE:N", title="Ship mode"),
            alt.Tooltip("_LABEL:N", title="Late"),
            alt.Tooltip("ORDER_LINES:Q", title="Order lines", format=","),
            alt.Tooltip("AVG_TRANSIT_DAYS:Q", title="Avg transit days", format=".1f"),
        ],
        value_title="Late deliveries (% of lines, scale 0 to 100)",
        domain_max=100,
    )
    st.altair_chart(late_chart, use_container_width=True)
    if len(late):
        st.caption(
            f"Every ship mode is late {late['LATE_RATE_PCT'].min():.0f}–{late['LATE_RATE_PCT'].max():.0f}% "
            "of the time, so the ship mode does not explain lateness."
        )
    show_table(late)

st.markdown("---")

# ---- Tiles 5 and 6 --------------------------------------------------------------------------
left, right = st.columns(2, gap="large")

with left:
    st.subheader("Which products sell the most?")
    st.caption("Net revenue by the part's material, the last word of its type (e.g. Promo Burnished Copper).")
    products = tile(PRODUCT_SQL, where, params)
    products["_LABEL"] = products["NET_REVENUE"].map(billions)
    product_chart = horizontal_bars(
        products, "PART_MATERIAL", "NET_REVENUE", "_LABEL", NEUTRAL,
        tooltip=[
            alt.Tooltip("PART_MATERIAL:N", title="Material"),
            alt.Tooltip("_LABEL:N", title="Net revenue"),
            alt.Tooltip("MARGIN_PCT:Q", title="Margin %", format=".1f"),
            alt.Tooltip("UNITS_SOLD:Q", title="Units sold", format=","),
        ],
        value_title="Net revenue",
    )
    st.altair_chart(product_chart, use_container_width=True)
    if len(products):
        top_product = products.iloc[0]
        st.caption(
            f"{top_product['PART_MATERIAL']} parts lead with {billions(top_product['NET_REVENUE'])}, "
            f"at a {top_product['MARGIN_PCT']:.1f}% margin."
        )
    show_table(products)

with right:
    st.subheader("Which suppliers do we depend on most?")
    st.caption("The 10 suppliers behind the most net revenue. Colour shows the supplier's own region.")
    suppliers = tile(TOP_SUPPLIERS_SQL, where, params)
    suppliers["_LABEL"] = suppliers["NET_REVENUE"].map(millions)
    supplier_chart = horizontal_bars(
        suppliers, "SUPPLIER_NAME", "NET_REVENUE", "_LABEL",
        region_color(legend=True, field="SUPPLIER_REGION"),
        tooltip=[
            alt.Tooltip("SUPPLIER_NAME:N", title="Supplier"),
            alt.Tooltip("SUPPLIER_NATION:N", title="Nation"),
            alt.Tooltip("_LABEL:N", title="Net revenue"),
            alt.Tooltip("MARGIN_PCT:Q", title="Margin %", format=".1f"),
            alt.Tooltip("ORDER_LINES:Q", title="Order lines", format=","),
        ],
        value_title="Net revenue",
    )
    st.altair_chart(supplier_chart, use_container_width=True)
    st.caption("The region filter above picks the customers who bought, not the suppliers.")
    show_table(suppliers)
