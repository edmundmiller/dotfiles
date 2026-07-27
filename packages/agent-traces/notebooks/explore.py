import marimo

__generated_with = "0.23.11"
app = marimo.App(width="medium")


@app.cell
def _():
    import json
    import os
    from pathlib import Path

    import duckdb
    import marimo as mo

    return Path, duckdb, json, mo, os


@app.cell
def _(Path, duckdb, os):
    token = Path(os.environ["AGENT_TRACES_READ_TOKEN_FILE"]).read_text().strip().replace("'", "''")
    endpoint = os.environ["AGENT_TRACES_CATALOG_URI"].replace("'", "''")
    warehouse = os.environ["AGENT_TRACES_WAREHOUSE"].replace("'", "''")
    connection = duckdb.connect(":memory:")
    connection.execute("INSTALL iceberg; INSTALL httpfs; LOAD iceberg; LOAD httpfs")
    connection.execute(f"CREATE SECRET agent_traces_reader (TYPE ICEBERG, TOKEN '{token}')")
    connection.execute(
        f"ATTACH '{warehouse}' AS lake (TYPE ICEBERG, SECRET agent_traces_reader, ENDPOINT '{endpoint}')"
    )
    connection.execute("""
        CREATE TEMP VIEW latest_sessions AS
        SELECT * EXCLUDE (rank)
        FROM (
          SELECT *, row_number() OVER (
            PARTITION BY source, native_id ORDER BY native_modified_at DESC, observed_at DESC
          ) AS rank
          FROM lake.agent_traces.sessions
        )
        WHERE rank = 1
    """)
    connection.execute("""
        CREATE TEMP VIEW trajectory_records AS
        SELECT
          s.source, s.native_id, s.native_modified_at,
          CAST(j.key AS INTEGER) AS record_index,
          json_extract_string(j.value, '$.role') AS role,
          json_extract_string(j.value, '$.timestamp') AS timestamp,
          json_extract_string(j.value, '$.content') AS content,
          json_extract(j.value, '$.tool_calls') AS tool_calls
        FROM latest_sessions s, json_each(s.trajectory_json) j
        WHERE s.trajectory_json IS NOT NULL
    """)
    return (connection,)


@app.cell
def _(connection, mo):
    sources = [row[0] for row in connection.execute("SELECT DISTINCT source FROM latest_sessions ORDER BY source").fetchall()]
    source = mo.ui.dropdown(["all", *sources], value="all", label="Source")
    day = mo.ui.date(label="Modified date")
    status = mo.ui.dropdown(["all", "normalized", "raw_only"], value="all", label="Status")
    sql = mo.ui.text_area(
        value="SELECT source, count(*) AS sessions FROM latest_sessions GROUP BY source ORDER BY source",
        label="SQL",
        full_width=True,
        rows=8,
    )
    mo.vstack([mo.hstack([source, day, status]), sql])
    return day, source, sql, status


@app.cell
def _(connection, day, mo, source, sql, status):
    clauses = []
    parameters = []
    if source.value != "all":
        clauses.append("source = ?")
        parameters.append(source.value)
    if day.value is not None:
        clauses.append("CAST(native_modified_at AS DATE) = ?")
        parameters.append(day.value)
    if status.value != "all":
        clauses.append("normalization_status = ?")
        parameters.append(status.value)
    filtered = "SELECT * FROM latest_sessions" + (" WHERE " + " AND ".join(clauses) if clauses else "")
    sessions = connection.execute(filtered, parameters).fetchdf()
    query_result = connection.execute(sql.value).fetchdf()
    result_table = mo.ui.table(query_result, pagination=True, page_size=20, selection="single")
    raw_table = mo.ui.table(sessions, pagination=True, page_size=10, selection="single")
    mo.vstack([mo.md("## Query result"), result_table, mo.md("## Raw row inspector"), raw_table])
    return


if __name__ == "__main__":
    app.run()
