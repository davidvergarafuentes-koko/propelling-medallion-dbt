{% docs __overview__ %}
# Sales performance on a Medallion architecture

This dbt project turns the TPC-H sample data in Snowflake into a sales-performance star schema.
Every transformation is a dbt model, and every layer is tested.

| Layer | Schema | Job | Tables |
| --- | --- | --- | --- |
| Bronze | `BRONZE` | Unchanged copy of the source, plus load metadata | 8 |
| Silver | `SILVER` | Clean, readable, tested entities and one definition of every measure | 8 |
| Gold | `GOLD` | Star schema for BI tools: `fct_sales` and 5 dimensions | 6 |

**Who uses Gold:** sales leadership, regional managers and analysts, through the `REPORTER` role.

**See the lineage:** click the blue icon at the bottom right of this page.
It shows every table from the source through Bronze and Silver to Gold.

**Data note:** TPC-H is synthetic benchmark data, so its numbers show no real business patterns.
{% enddocs %}
